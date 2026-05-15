#include <R.h>
#include <Rinternals.h>
#include <R_ext/Rdynload.h>

/* Stub implementations for rstan .Call routines */

static SEXP CPP_stan_version(void) {
  SEXP r = Rf_allocVector(STRSXP, 1);
  SET_STRING_ELT(r, 0, Rf_mkChar("0.0.0-stub"));
  return r;
}

static SEXP get_stream_(void) {
  SEXP r = Rf_allocVector(INTSXP, 1);
  INTEGER(r)[0] = 1;
  return r;
}

static SEXP get_rng_(SEXP seed) {
  SEXP r = Rf_allocVector(INTSXP, 1);
  INTEGER(r)[0] = 0;
  return r;
}

static SEXP effective_sample_size(SEXP sim, SEXP n) {
  SEXP r = Rf_allocVector(REALSXP, 1);
  REAL(r)[0] = NA_REAL;
  return r;
}

static SEXP effective_sample_size2(SEXP sims) {
  SEXP r = Rf_allocVector(REALSXP, 1);
  REAL(r)[0] = NA_REAL;
  return r;
}

static SEXP extract_sparse_components(SEXP A) {
  return R_NilValue;
}

static SEXP is_Null_NS(SEXP ns) {
  SEXP r = Rf_allocVector(LGLSXP, 1);
  LOGICAL(r)[0] = 0;
  return r;
}

static SEXP seq_permutation(SEXP conf) {
  SEXP r = Rf_allocVector(INTSXP, 1);
  INTEGER(r)[0] = 1;
  return r;
}

static SEXP split_potential_scale_reduction(SEXP sim, SEXP n) {
  SEXP r = Rf_allocVector(REALSXP, 1);
  REAL(r)[0] = 1.0;
  return r;
}

static SEXP split_potential_scale_reduction2(SEXP sims) {
  SEXP r = Rf_allocVector(REALSXP, 1);
  REAL(r)[0] = 1.0;
  return r;
}

/* Rcpp module boot functions - these are needed by Rcpp::loadModule */
SEXP _rcpp_module_boot_class_model_base(void) {
  /* Return a dummy external pointer to satisfy Rcpp module loading */
  return R_MakeExternalPtr(R_NilValue, Rf_install("rcpp_module_boot"), R_NilValue);
}

SEXP _rcpp_module_boot_class_stan_fit(void) {
  return R_MakeExternalPtr(R_NilValue, Rf_install("rcpp_module_boot"), R_NilValue);
}

#define CALLDEF(name, n)  {#name, (DL_FUNC) &name, n}

static R_CallMethodDef CallEntries[] = {
  CALLDEF(CPP_stan_version, 0),
  CALLDEF(get_stream_, 0),
  CALLDEF(get_rng_, 1),
  CALLDEF(effective_sample_size, 2),
  CALLDEF(effective_sample_size2, 1),
  CALLDEF(extract_sparse_components, 1),
  CALLDEF(is_Null_NS, 1),
  CALLDEF(seq_permutation, 1),
  CALLDEF(split_potential_scale_reduction, 2),
  CALLDEF(split_potential_scale_reduction2, 1),
  {NULL, NULL, 0}
};

void R_init_rstan(DllInfo *dll) {
    R_registerRoutines(dll, NULL, CallEntries, NULL, NULL);
    R_useDynamicSymbols(dll, FALSE);
}
