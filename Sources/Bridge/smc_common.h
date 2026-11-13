#ifndef smc_common_h
#define smc_common_h

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

static inline UInt32 four_char_to_uint32(const char *key) {
    UInt32 ans = 0;
    for (int i = 0; i < 4 && key[i] != '\0'; i++) {
        ans = (ans << 8) | (unsigned char)key[i];
    }
    return ans;
}

#endif /* smc_common_h */
