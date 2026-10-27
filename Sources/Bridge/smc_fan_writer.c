#include <stdio.h>
#include <stdlib.h>
#include <string.h>
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

static int smc_open(void) {
    if (g_smcConn != 0) return 0;
    io_service_t service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"));
    if (!service) return -1;
    kern_return_t kr = IOServiceOpen(service, mach_task_self(), 0, &g_smcConn);
    IOObjectRelease(service);
    return (kr == kIOReturnSuccess) ? 0 : -1;
}

static UInt32 four_char_to_uint32(const char *key) {
    UInt32 ans = 0;
    for (int i = 0; i < 4 && key[i] != '\0'; i++) {
        ans = (ans << 8) | (unsigned char)key[i];
    }
    return ans;
}

static int smc_write_key(const char *key, const unsigned char *bytes, UInt32 dataSize) {
    if (smc_open() != 0) return -1;
    SMCKeyData_t input = {0};
    SMCKeyData_t output = {0};
    input.key = four_char_to_uint32(key);
    input.data8 = 9; // READ_KEYINFO
    
    size_t structInSize = sizeof(SMCKeyData_t);
    size_t structOutSize = sizeof(SMCKeyData_t);
    kern_return_t kr = IOConnectCallStructMethod(g_smcConn, 2, &input, structInSize, &output, &structOutSize);
    if (kr != kIOReturnSuccess) return -1;
    
    UInt32 keySize = output.keyInfo.dataSize;
    
    memset(&input, 0, sizeof(SMCKeyData_t));
    memset(&output, 0, sizeof(SMCKeyData_t));
    input.key = four_char_to_uint32(key);
    input.keyInfo.dataSize = keySize;
    input.data8 = 6; // WRITE_BYTES
    memcpy(input.bytes, bytes, dataSize < keySize ? dataSize : keySize);
    
    kr = IOConnectCallStructMethod(g_smcConn, 2, &input, structInSize, &output, &structOutSize);
    return (kr == kIOReturnSuccess && output.result == 0) ? 0 : -1;
}

int main(int argc, char **argv) {
    if (argc < 2) {
        printf("Usage: %s {auto|manual <rpm>}\n", argv[0]);
        return 1;
    }
    
    if (strcmp(argv[1], "auto") == 0) {
        unsigned char modeBytes[2] = {0x00, 0x00};
        if (smc_write_key("FS! ", modeBytes, 2) == 0) {
            if (g_smcConn != 0) IOServiceClose(g_smcConn);
            printf("FAN_AUTO_OK\n");
            return 0;
        } else {
            if (g_smcConn != 0) IOServiceClose(g_smcConn);
            printf("FAN_AUTO_FAIL\n");
            return 1;
        }
    } else if (strcmp(argv[1], "manual") == 0 && argc >= 3) {
        char *endptr = NULL;
        long parsed = strtol(argv[2], &endptr, 10);
        if (endptr == argv[2] || *endptr != '\0') {
            if (g_smcConn != 0) IOServiceClose(g_smcConn);
            printf("FAN_MANUAL_INVALID_RPM\n");
            return 1;
        }
        int targetRpm = (int)parsed;
        if (targetRpm < 1200) targetRpm = 1200;
        if (targetRpm > 7200) targetRpm = 7200;
        
        // 1. Enable manual mode (bit 0 = 1)
        unsigned char modeBytes[2] = {0x00, 0x01};
        smc_write_key("FS! ", modeBytes, 2);
        
        // 2. Write Target RPM in fpe2 format (rpm * 4)
        int raw = targetRpm * 4;
        unsigned char rpmBytes[2] = { (unsigned char)((raw >> 8) & 0xFF), (unsigned char)(raw & 0xFF) };
        if (smc_write_key("F0Tg", rpmBytes, 2) == 0) {
            if (g_smcConn != 0) IOServiceClose(g_smcConn);
            printf("FAN_MANUAL_OK %d\n", targetRpm);
            return 0;
        } else {
            if (g_smcConn != 0) IOServiceClose(g_smcConn);
            printf("FAN_MANUAL_FAIL\n");
            return 1;
        }
    }
    if (g_smcConn != 0) IOServiceClose(g_smcConn);
    return 1;
}
