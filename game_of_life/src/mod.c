#include "assert.h"
#include "mod.h"

uchar mod(uchar val, int dval, int divisor) {
    if (val != 0 && val != divisor) return(val + dval);
    if(val == 0 && dval == -1) return(divisor-1);
    if(val == divisor-1 && dval == 1) return(0);
    return(0);
}

void modTest(){
    assert (mod(10,1,11) == 0);
    assert (mod(5, 1, 10) == 6);
    assert (mod(0,-1,10) == 9);

}
