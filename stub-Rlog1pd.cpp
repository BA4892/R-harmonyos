/* Stub for Rlog1p(double) - needed by MCMCglmm and flexsurv */
#include <math.h>

/* _Z6Rlog1pd demangles to Rlog1p(double) - log(1 + p) */
extern "C" double _Z6Rlog1pd(double p) {
    return log1p(p);
}
