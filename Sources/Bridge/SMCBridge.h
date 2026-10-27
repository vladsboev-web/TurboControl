#ifndef SMCBridge_h
#define SMCBridge_h

#include <stdio.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

int smc_init(void);
void smc_close(void);
double smc_get_cpu_temp(void);
double smc_get_gpu_temp(void);
double smc_get_fan_rpm(void);
double smc_get_fan_min_rpm(void);
double smc_get_fan_max_rpm(void);

#ifdef __cplusplus
}
#endif

#endif /* SMCBridge_h */
