#include <R.h>
#include <Rinternals.h>
#include <R_ext/Rdynload.h>

/* Stub implementations for BWStest .Call routines */

static SEXP bws_stat_stub(SEXP x, SEXP y) {
  SEXP r = Rf_allocVector(REALSXP, 1);
  REAL(r)[0] = NA_REAL;
  return r;
}

static SEXP bws_cdf_stub(SEXP b, SEXP maxj, SEXP lower_tail) {
  SEXP r = Rf_allocVector(REALSXP, 1);
  REAL(r)[0] = NA_REAL;
  return r;
}

static SEXP murakami_stat_stub(SEXP x, SEXP y, SEXP flavor) {
  SEXP r = Rf_allocVector(REALSXP, 1);
  REAL(r)[0] = NA_REAL;
  return r;
}

static SEXP murakami_stat_perms_stub(SEXP nx, SEXP ny, SEXP flavor) {
  SEXP r = Rf_allocVector(REALSXP, 1);
  REAL(r)[0] = NA_REAL;
  return r;
}

static R_CallMethodDef CallEntries[] = {
  {"_BWStest_bws_stat",          (DL_FUNC) &bws_stat_stub,          2},
  {"_BWStest_bws_cdf",           (DL_FUNC) &bws_cdf_stub,           3},
  {"_BWStest_murakami_stat",     (DL_FUNC) &murakami_stat_stub,     3},
  {"_BWStest_murakami_stat_perms",(DL_FUNC) &murakami_stat_perms_stub,3},
  {NULL, NULL, 0}
};

void R_init_BWStest(DllInfo *dll) {
    R_registerRoutines(dll, NULL, CallEntries, NULL, NULL);
    R_useDynamicSymbols(dll, FALSE);
}
