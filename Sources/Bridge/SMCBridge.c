#include "SMCBridge.h"
#include "smc_common.h"
#include <string.h>
#include <pthread.h>
#include <IOKit/IOKitLib.h>
#include <IOKit/kext/KextManager.h>

static io_connect_t g_smcConn = 0;
static pthread_mutex_t g_smcMutex = PTHREAD_MUTEX_INITIALIZER;

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
    memset(&input, 0, sizeof(SMCKeyData_t));
    memset(&output, 0, sizeof(SMCKeyData_t));
    
    UInt32 keyCode = four_char_to_uint32(key);
    input.key = keyCode;
    input.data8 = 9; // READ_KEYINFO
    
    size_t inSize = sizeof(SMCKeyData_t);
    size_t outSize = sizeof(SMCKeyData_t);
    
    kern_return_t kr = IOConnectCallStructMethod(g_smcConn, 2, &input, inSize, &output, &outSize);
    if (kr != kIOReturnSuccess) {
        pthread_mutex_unlock(&g_smcMutex);
        return -1.0;
    }
    
    UInt32 dataSize = output.keyInfo.dataSize;
    UInt32 dataType = output.keyInfo.dataType;
    
    memset(&input, 0, sizeof(SMCKeyData_t));
    memset(&output, 0, sizeof(SMCKeyData_t));
    input.key = keyCode;
    input.keyInfo.dataSize = dataSize;
    input.data8 = 5; // READ_BYTES
    
    kr = IOConnectCallStructMethod(g_smcConn, 2, &input, inSize, &output, &outSize);
    pthread_mutex_unlock(&g_smcMutex);
    
    if (kr != kIOReturnSuccess) return -1.0;
    
    char typeStr[5] = {
        (char)((dataType >> 24) & 0xFF),
        (char)((dataType >> 16) & 0xFF),
        (char)((dataType >> 8) & 0xFF),
        (char)(dataType & 0xFF),
        '\0'
    };
    
    if (strcmp(typeStr, "sp78") == 0 && dataSize >= 2) {
        int val = ((int8_t)output.bytes[0] << 8) | (unsigned char)output.bytes[1];
        return (double)val / 256.0;
    } else if (strcmp(typeStr, "fpe2") == 0 && dataSize >= 2) {
        int val = ((unsigned char)output.bytes[0] << 8) | (unsigned char)output.bytes[1];
        return (double)val / 4.0;
    } else if (strcmp(typeStr, "flt ") == 0 && dataSize >= 4) {
        float val = 0.0f;
        memcpy(&val, output.bytes, 4);
        return (double)val;
    } else if (strcmp(typeStr, "ui16") == 0 && dataSize >= 2) {
        int val = ((unsigned char)output.bytes[0] << 8) | (unsigned char)output.bytes[1];
        return (double)val;
    } else if (strcmp(typeStr, "ui8 ") == 0 && dataSize >= 1) {
        return (double)((unsigned char)output.bytes[0]);
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
    const char *keys[] = {"TCGC", "TG0D", "TG0P", "TG1D", "TG1P", NULL};
    for (int i = 0; keys[i] != NULL; i++) {
        double t = smc_read_key(keys[i]);
        if (t > 10.0 && t < 125.0) {
            return t;
        }
    }
    // If GPU sensor is missing (integrated GPU often shares die), fallback to CPU proximity
    double cpuProx = smc_read_key("TC0P");
    if (cpuProx > 10.0 && cpuProx < 125.0) return cpuProx;
    return -1.0;
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
