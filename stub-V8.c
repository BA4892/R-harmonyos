#include <R.h>
#include <Rinternals.h>
#include <R_ext/Rdynload.h>

/* Stub implementations for all V8 .Call routines.
   These return dummy values so V8::v8() can create a context object
   and packages like rstan can load successfully. */

static SEXP version_stub(void) {
  SEXP r = Rf_allocVector(STRSXP, 1);
  SET_STRING_ELT(r, 0, Rf_mkChar("0.0.0-stub"));
  return r;
}

/* Return a dummy external pointer as a "context" */
static SEXP make_context_stub(SEXP set_console) {
  SEXP ptr = R_MakeExternalPtr(R_NilValue, Rf_install("V8_context"), R_NilValue);
  Rf_setAttrib(ptr, R_ClassSymbol, Rf_mkString("V8_context"));
  return ptr;
}

static SEXP context_eval_stub(SEXP src, SEXP ctx, SEXP serialize, SEXP await) {
  /* Return empty string */
  SEXP r = Rf_allocVector(STRSXP, 1);
  SET_STRING_ELT(r, 0, Rf_mkChar(""));
  return r;
}

static SEXP write_array_buffer_stub(SEXP key, SEXP data, SEXP ctx) {
  return R_NilValue;
}

static SEXP context_validate_stub(SEXP src, SEXP ctx) {
  SEXP r = Rf_allocVector(LGLSXP, 1);
  LOGICAL(r)[0] = 1; /* pretend valid */
  return r;
}

static SEXP context_null_stub(SEXP ctx) {
  SEXP r = Rf_allocVector(LGLSXP, 1);
  LOGICAL(r)[0] = 0; /* context is not null (i.e., exists) */
  return r;
}

static R_CallMethodDef CallEntries[] = {
  {"_V8_version",           (DL_FUNC) &version_stub,          0},
  {"_V8_make_context",      (DL_FUNC) &make_context_stub,     1},
  {"_V8_context_eval",      (DL_FUNC) &context_eval_stub,     4},
  {"_V8_write_array_buffer",(DL_FUNC) &write_array_buffer_stub,3},
  {"_V8_context_validate",  (DL_FUNC) &context_validate_stub, 2},
  {"_V8_context_null",      (DL_FUNC) &context_null_stub,     1},
  {NULL, NULL, 0}
};

void R_init_V8(DllInfo *dll) {
    R_registerRoutines(dll, NULL, CallEntries, NULL, NULL);
    R_useDynamicSymbols(dll, FALSE);
}
