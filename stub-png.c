#include <R.h>
#include <Rinternals.h>
#include <R_ext/Rdynload.h>

/* Stub implementations for png .Call routines */
SEXP write_png(SEXP image, SEXP target, SEXP dpi, SEXP asp, SEXP text) {
  Rf_error("png is not available on this platform");
  return R_NilValue;
}

SEXP read_png(SEXP source, SEXP native, SEXP is_file) {
  Rf_error("png is not available on this platform");
  return R_NilValue;
}

#define CALLDEF(name, n)  {#name, (DL_FUNC) &name, n}

static R_CallMethodDef CallEntries[] = {
  CALLDEF(write_png, 5),
  CALLDEF(read_png, 3),
  {NULL, NULL, 0}
};

void R_init_png(DllInfo *dll) {
    R_registerRoutines(dll, NULL, CallEntries, NULL, NULL);
    R_useDynamicSymbols(dll, FALSE);
}
