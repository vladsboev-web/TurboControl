#include "SMCBridge.h"
#include <string.h>
#include <pthread.h>
#include <IOKit/IOKitLib.h>

typedef struct {
    char major;
    char minor;
    char build;
    char reserved[1];
    UInt16 release;
} SMCKeyData_vers_t;

typedef struct {
    UInt16 version;
    UInt16 length;
    UInt32 cpuPLimit;
    UInt32 gpuPLimit;
    UInt32 memPLimit;
} SMCKeyData_pLimitData_t;

typedef struct {
    UInt32 dataSize;
    UInt32 dataType;
    char dataAttributes;
} SMCKeyData_keyInfo_t;

typedef struct {
    UInt32 key;
    SMCKeyData_vers_t vers;
    SMCKeyData_pLimitData_t pLimitData;
    SMCKeyData_keyInfo_t keyInfo;
    char result;
    char status;
    char data8;
    UInt32 data32;
    char bytes[32];
} SMCKeyData_t;

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

static UInt32 four_char_to_uint32(const char *key) {
    UInt32 ans = 0;
    for (int i = 0; i < 4 && key[i] != '\0'; i++) {
        ans = (ans << 8) | (unsigned char)key[i];
    }
    return ans;
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
