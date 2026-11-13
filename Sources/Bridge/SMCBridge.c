#include "SMCBridge.h"
#include "smc_common.h"
#include <string.h>
#include <pthread.h>
#include <IOKit/IOKitLib.h>
#include <IOKit/kext/KextManager.h>

static io_connect_t g_smcConn = 0;
static pthread_mutex_t g_smcMutex = PTHREAD_MUTEX_INITIALIZER;

#define SMC_KEYINFO_CACHE_CAP 64

typedef struct {
    UInt32 keyCode;
    UInt32 dataSize;
    UInt32 dataType;
    int exists; // 1 = valid, -1 = not supported on this Mac
} SMCKeyInfoCacheEntry;

static SMCKeyInfoCacheEntry g_keyInfoCache[SMC_KEYINFO_CACHE_CAP];
static int g_keyInfoCacheCount = 0;

static int g_cachedGpuTempIdx = -1;
static int g_cachedCpuPowerIdx = -1;
static int g_cachedSysPowerIdx = -1;

int smc_init(void) {
    pthread_mutex_lock(&g_smcMutex);
    if (g_smcConn != 0) {
        pthread_mutex_unlock(&g_smcMutex);
        return 0;
    }
    io_service_t service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"));
    if (!service) {
        pthread_mutex_unlock(&g_smcMutex);
        return -1;
    }
    kern_return_t kr = IOServiceOpen(service, mach_task_self(), 0, &g_smcConn);
    IOObjectRelease(service);
    pthread_mutex_unlock(&g_smcMutex);
    return (kr == kIOReturnSuccess) ? 0 : -1;
}

void smc_close(void) {
    pthread_mutex_lock(&g_smcMutex);
    if (g_smcConn != 0) {
        IOServiceClose(g_smcConn);
        g_smcConn = 0;
    }
    g_keyInfoCacheCount = 0;
    pthread_mutex_unlock(&g_smcMutex);
}

static double smc_read_key(const char *key) {
    if (smc_init() != 0) return -1.0;
    
    pthread_mutex_lock(&g_smcMutex);
    if (g_smcConn == 0) {
        pthread_mutex_unlock(&g_smcMutex);
        return -1.0;
    }
    
    SMCKeyData_t input;
    SMCKeyData_t output;
    UInt32 keyCode = four_char_to_uint32(key);
    size_t inSize = sizeof(SMCKeyData_t);
    size_t outSize = sizeof(SMCKeyData_t);
    
    int cacheIdx = -1;
    for (int i = 0; i < g_keyInfoCacheCount; i++) {
        if (g_keyInfoCache[i].keyCode == keyCode) {
            cacheIdx = i;
            break;
        }
    }
    
    UInt32 dataSize = 0;
    UInt32 dataType = 0;
    
    if (cacheIdx >= 0) {
        if (g_keyInfoCache[cacheIdx].exists < 0) {
            pthread_mutex_unlock(&g_smcMutex);
            return -1.0;
        }
        dataSize = g_keyInfoCache[cacheIdx].dataSize;
        dataType = g_keyInfoCache[cacheIdx].dataType;
    } else {
        memset(&input, 0, sizeof(SMCKeyData_t));
        memset(&output, 0, sizeof(SMCKeyData_t));
        input.key = keyCode;
        input.data8 = 9; // READ_KEYINFO
        
        kern_return_t kr = IOConnectCallStructMethod(g_smcConn, 2, &input, inSize, &output, &outSize);
        if (kr != kIOReturnSuccess || output.result != 0 || output.keyInfo.dataSize == 0) {
            if (g_keyInfoCacheCount < SMC_KEYINFO_CACHE_CAP) {
                g_keyInfoCache[g_keyInfoCacheCount++] = (SMCKeyInfoCacheEntry){keyCode, 0, 0, -1};
            }
            pthread_mutex_unlock(&g_smcMutex);
            return -1.0;
        }
        
        dataSize = output.keyInfo.dataSize;
        dataType = output.keyInfo.dataType;
        if (g_keyInfoCacheCount < SMC_KEYINFO_CACHE_CAP) {
            g_keyInfoCache[g_keyInfoCacheCount++] = (SMCKeyInfoCacheEntry){keyCode, dataSize, dataType, 1};
        }
    }
    
    memset(&input, 0, sizeof(SMCKeyData_t));
    memset(&output, 0, sizeof(SMCKeyData_t));
    input.key = keyCode;
    input.keyInfo.dataSize = dataSize;
    input.data8 = 5; // READ_BYTES
    
    kern_return_t kr = IOConnectCallStructMethod(g_smcConn, 2, &input, inSize, &output, &outSize);
    pthread_mutex_unlock(&g_smcMutex);
    
    if (kr != kIOReturnSuccess || output.result != 0) return -1.0;
    
    char typeStr[5] = {
        (char)((dataType >> 24) & 0xFF),
        (char)((dataType >> 16) & 0xFF),
        (char)((dataType >> 8) & 0xFF),
        (char)(dataType & 0xFF),
        '\0'
    };
    
    if (typeStr[0] == 's' && typeStr[1] == 'p' && dataSize >= 2) {
        int fracBits = -1;
        char c = typeStr[3];
        if (c >= '0' && c <= '9') fracBits = c - '0';
        else if (c >= 'a' && c <= 'f') fracBits = 10 + (c - 'a');
        else if (c >= 'A' && c <= 'F') fracBits = 10 + (c - 'A');
        if (fracBits >= 0 && fracBits <= 15) {
            int16_t val = (int16_t)(((unsigned char)output.bytes[0] << 8) | (unsigned char)output.bytes[1]);
            return (double)val / (double)(1 << fracBits);
        }
    } else if (typeStr[0] == 'f' && typeStr[1] == 'p' && dataSize >= 2) {
        int fracBits = -1;
        char c = typeStr[3];
        if (c >= '0' && c <= '9') fracBits = c - '0';
        else if (c >= 'a' && c <= 'f') fracBits = 10 + (c - 'a');
        else if (c >= 'A' && c <= 'F') fracBits = 10 + (c - 'A');
        if (fracBits >= 0 && fracBits <= 15) {
            uint16_t val = ((unsigned char)output.bytes[0] << 8) | (unsigned char)output.bytes[1];
            return (double)val / (double)(1 << fracBits);
        }
    } else if (strcmp(typeStr, "flt ") == 0 && dataSize >= 4) {
        float val = 0.0f;
        memcpy(&val, output.bytes, 4);
        return (double)val;
    } else if (strcmp(typeStr, "ui16") == 0 && dataSize >= 2) {
        int val = ((unsigned char)output.bytes[0] << 8) | (unsigned char)output.bytes[1];
        return (double)val;
    } else if (strcmp(typeStr, "si16") == 0 && dataSize >= 2) {
        int16_t val = (int16_t)(((unsigned char)output.bytes[0] << 8) | (unsigned char)output.bytes[1]);
        return (double)val;
    } else if (strcmp(typeStr, "ui8 ") == 0 && dataSize >= 1) {
        return (double)((unsigned char)output.bytes[0]);
    } else if (strcmp(typeStr, "si8 ") == 0 && dataSize >= 1) {
        return (double)((int8_t)output.bytes[0]);
    }
    return -1.0;
}

static double smc_read_first_in_range(const char *const keys[], int count, double minVal, double maxVal, int *cachedIdx) {
    int idx = __atomic_load_n(cachedIdx, __ATOMIC_RELAXED);
    if (idx >= 0 && idx < count) {
        double v = smc_read_key(keys[idx]);
        if (v > minVal && v < maxVal) {
            return v;
        }
    }
    for (int i = 0; i < count; i++) {
        if (i == idx) continue;
        double v = smc_read_key(keys[i]);
        if (v > minVal && v < maxVal) {
            __atomic_store_n(cachedIdx, i, __ATOMIC_RELAXED);
            return v;
        }
    }
    return -1.0;
}

double smc_get_cpu_temp(void) {
    const char *keys[] = {"TC0E", "TC0F", "TC1C", "TC0P", "TCXC", "TC0D", NULL};
    double maxTemp = -1.0;
    for (int i = 0; keys[i] != NULL; i++) {
        double t = smc_read_key(keys[i]);
        if (t > 10.0 && t < 125.0) {
            if (t > maxTemp) maxTemp = t;
        }
    }
    return maxTemp;
}

double smc_get_gpu_temp(void) {
    // Fallback to TC0P (CPU proximity) when dedicated GPU sensor is absent (integrated GPU)
    static const char *const keys[] = {"TCGC", "TG0D", "TG0P", "TG1D", "TG1P", "TC0P"};
    return smc_read_first_in_range(keys, 6, 10.0, 125.0, &g_cachedGpuTempIdx);
}

double smc_get_fan_rpm(void) {
    double rpm = smc_read_key("F0Ac");
    if (rpm < 0.0) rpm = smc_read_key("F1Ac");
    return (rpm >= 0.0) ? rpm : 0.0;
}

double smc_get_fan_min_rpm(void) {
    double rpm = smc_read_key("F0Mn");
    if (rpm <= 0.0) rpm = 1200.0;
    return rpm;
}

double smc_get_fan_max_rpm(void) {
    double rpm = smc_read_key("F0Mx");
    if (rpm <= 0.0) rpm = 7200.0;
    return rpm;
}

int smc_is_fan_manual_mode(void) {
    double fs = smc_read_key("FS! ");
    if (fs >= 0.0) {
        return (((int)fs & 1) != 0) ? 1 : 0;
    }
    double md = smc_read_key("F0Md");
    if (md >= 0.0) {
        return (((int)md & 1) != 0) ? 1 : 0;
    }
    return 0;
}

int smc_is_kext_loaded(const char *bundle_id) {
    if (!bundle_id) return 0;
    CFStringRef cfBundle = CFStringCreateWithCString(kCFAllocatorDefault, bundle_id, kCFStringEncodingUTF8);
    if (!cfBundle) return 0;
    CFArrayRef ids = CFArrayCreate(kCFAllocatorDefault, (const void **)&cfBundle, 1, &kCFTypeArrayCallBacks);
    if (!ids) {
        CFRelease(cfBundle);
        return 0;
    }
    CFDictionaryRef loaded = KextManagerCopyLoadedKextInfo(ids, NULL);
    CFRelease(ids);
    if (!loaded) {
        CFRelease(cfBundle);
        return 0;
    }
    Boolean found = CFDictionaryContainsKey(loaded, cfBundle);
    CFRelease(cfBundle);
    CFRelease(loaded);
    return found ? 1 : 0;
}

double smc_get_cpu_power_watts(void) {
    static const char *const keys[] = {"PCPC", "PC0R", "PCPG", "PCPR"};
    return smc_read_first_in_range(keys, 4, 0.0, 300.0, &g_cachedCpuPowerIdx);
}

double smc_get_system_power_watts(void) {
    static const char *const keys[] = {"PSTR", "PDTR", "PB0R"};
    return smc_read_first_in_range(keys, 3, 0.0, 400.0, &g_cachedSysPowerIdx);
}

int smc_get_battery_charge_limit(void) {
    double val = smc_read_key("BCLM");
    if (val >= 1.0 && val <= 100.0) {
        return (int)val;
    }
    return -1;
}

int smc_is_charge_inhibited(void) {
    double ch0b = smc_read_key("CH0B");
    double ch0c = smc_read_key("CH0C");
    if (ch0b < 0.0 && ch0c < 0.0) {
        return -1;
    }
    if (ch0b > 0.0 || ch0c > 0.0) {
        return 1;
    }
    return 0;
}

int smc_supports_charge_limit(void) {
    if (smc_read_key("BCLM") >= 0.0) return 1;
    if (smc_read_key("CH0B") >= 0.0) return 1;
    if (smc_read_key("CH0C") >= 0.0) return 1;
    return 0;
}
