#include "smc_common.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <IOKit/IOKitLib.h>

static io_connect_t g_smcConn = 0;

static int smc_open(void) {
    if (g_smcConn != 0) return 0;
    io_service_t service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"));
    if (!service) return -1;
    kern_return_t kr = IOServiceOpen(service, mach_task_self(), 0, &g_smcConn);
    IOObjectRelease(service);
    return (kr == kIOReturnSuccess) ? 0 : -1;
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

static int smc_write_fan_target_rpm(const char *key, int targetRpm) {
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
    UInt32 keyType = output.keyInfo.dataType;
    if (keySize == 0) return -1;
    
    unsigned char writeBytes[32] = {0};
    UInt32 bytesToWrite = 0;
    
    // T2 and newer Mac: 'flt ' (0x666C7420) or dataSize == 4 (IEEE 754 float)
    if (keyType == 0x666C7420 || keySize == 4) {
        float fval = (float)targetRpm;
        memcpy(writeBytes, &fval, sizeof(float));
        bytesToWrite = 4;
    } else {
        // Pre-T2 Mac: 'fpe2' (0x66706532) format (rpm * 4, 16-bit big-endian)
        int raw = targetRpm * 4;
        writeBytes[0] = (unsigned char)((raw >> 8) & 0xFF);
        writeBytes[1] = (unsigned char)(raw & 0xFF);
        bytesToWrite = 2;
    }
    
    memset(&input, 0, sizeof(SMCKeyData_t));
    memset(&output, 0, sizeof(SMCKeyData_t));
    input.key = four_char_to_uint32(key);
    input.keyInfo.dataSize = keySize;
    input.data8 = 6; // WRITE_BYTES
    memcpy(input.bytes, writeBytes, bytesToWrite < keySize ? bytesToWrite : keySize);
    
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
        int r1 = smc_write_key("FS! ", modeBytes, 2);
        unsigned char mdByte[1] = {0x00};
        int r2 = smc_write_key("F0Md", mdByte, 1);
        smc_write_key("F1Md", mdByte, 1);
        if (r1 == 0 || r2 == 0) {
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
        
        // 1. Enable manual mode (FS! = 0x0003 for 1 or 2 fans, plus F0Md/F1Md if present)
        unsigned char modeBytes[2] = {0x00, 0x03};
        if (smc_write_key("FS! ", modeBytes, 2) != 0) {
            unsigned char modeSingle[2] = {0x00, 0x01};
            smc_write_key("FS! ", modeSingle, 2);
        }
        unsigned char mdByte[1] = {0x01};
        smc_write_key("F0Md", mdByte, 1);
        smc_write_key("F1Md", mdByte, 1);
        
        // 2. Write Target RPM (supports both Pre-T2 fpe2 and T2 flt format)
        int ok0 = smc_write_fan_target_rpm("F0Tg", targetRpm);
        smc_write_fan_target_rpm("F1Tg", targetRpm);
        if (ok0 == 0) {
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
