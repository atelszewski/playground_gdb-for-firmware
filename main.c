#include "uart.h"
#include "stm32f0xx.h"

int main(void)
{
    volatile int iii = 0;
    volatile int jjj = 0;

    while (1)
    {
        ++iii;
        ++jjj;
    }

    return 0;
}
