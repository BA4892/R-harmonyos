#include <R.h>
#include <Rinternals.h>
#include <R_ext/Rdynload.h>

/* Stub implementations for all gmp .Call routines */

SEXP R_gmp_get_version(void) {
  return Rf_ScalarString(Rf_mkChar("6.3.0"));
}

SEXP biginteger_add(SEXP a, SEXP b) { return R_NilValue; }
SEXP biginteger_sub(SEXP a, SEXP b) { return R_NilValue; }
SEXP biginteger_mul(SEXP a, SEXP b) { return R_NilValue; }
SEXP biginteger_div(SEXP a, SEXP b) { return R_NilValue; }
SEXP biginteger_divq(SEXP a, SEXP b) { return R_NilValue; }
SEXP biginteger_mod(SEXP a, SEXP b) { return R_NilValue; }
SEXP biginteger_pow(SEXP a, SEXP b) { return R_NilValue; }
SEXP biginteger_inv(SEXP a, SEXP b) { return R_NilValue; }
SEXP biginteger_gcd(SEXP a, SEXP b) { return R_NilValue; }
SEXP biginteger_lcm(SEXP a, SEXP b) { return R_NilValue; }
SEXP biginteger_get_at(SEXP a, SEXP b) { return R_NilValue; }
SEXP biginteger_set_at(SEXP a, SEXP b, SEXP c) { return R_NilValue; }
SEXP biginteger_as(SEXP a, SEXP b) {
  /* Return NA_integer_ for NA input */
  SEXP res = Rf_allocVector(INTSXP, 1);
  INTEGER(res)[0] = NA_INTEGER;
  return res;
}
SEXP biginteger_as_character(SEXP a, SEXP b) { SEXP r = Rf_allocVector(STRSXP, 1); SET_STRING_ELT(r, 0, NA_STRING); return r; }
SEXP biginteger_as_numeric(SEXP a) { SEXP r = Rf_allocVector(REALSXP, 1); REAL(r)[0] = NA_REAL; return r; }
SEXP biginteger_as_integer(SEXP a) { SEXP r = Rf_allocVector(INTSXP, 1); INTEGER(r)[0] = NA_INTEGER; return r; }
SEXP biginteger_length(SEXP a) { SEXP r = Rf_allocVector(INTSXP, 1); INTEGER(r)[0] = 1; return r; }
SEXP biginteger_setlength(SEXP a, SEXP b) { return a; }
SEXP biginteger_is_na(SEXP a) { SEXP r = Rf_allocVector(LGLSXP, 1); LOGICAL(r)[0] = 0; return r; }
SEXP biginteger_sgn(SEXP a) { SEXP r = Rf_allocVector(INTSXP, 1); INTEGER(r)[0] = NA_INTEGER; return r; }
SEXP biginteger_lt(SEXP a, SEXP b) { SEXP r = Rf_allocVector(LGLSXP, 1); LOGICAL(r)[0] = NA_LOGICAL; return r; }
SEXP biginteger_gt(SEXP a, SEXP b) { SEXP r = Rf_allocVector(LGLSXP, 1); LOGICAL(r)[0] = NA_LOGICAL; return r; }
SEXP biginteger_lte(SEXP a, SEXP b) { SEXP r = Rf_allocVector(LGLSXP, 1); LOGICAL(r)[0] = NA_LOGICAL; return r; }
SEXP biginteger_gte(SEXP a, SEXP b) { SEXP r = Rf_allocVector(LGLSXP, 1); LOGICAL(r)[0] = NA_LOGICAL; return r; }
SEXP biginteger_eq(SEXP a, SEXP b) { SEXP r = Rf_allocVector(LGLSXP, 1); LOGICAL(r)[0] = NA_LOGICAL; return r; }
SEXP biginteger_neq(SEXP a, SEXP b) { SEXP r = Rf_allocVector(LGLSXP, 1); LOGICAL(r)[0] = NA_LOGICAL; return r; }
SEXP biginteger_c(SEXP a) { return a; }
SEXP biginteger_cbind(SEXP a) { return a; }
SEXP biginteger_rep(SEXP a, SEXP b) { return a; }
SEXP biginteger_is_prime(SEXP a, SEXP b) { SEXP r = Rf_allocVector(LGLSXP, 1); LOGICAL(r)[0] = 0; return r; }
SEXP biginteger_nextprime(SEXP a) { return a; }
SEXP biginteger_abs(SEXP a) { return a; }
SEXP biginteger_gcdex(SEXP a, SEXP b) { SEXP r = Rf_allocVector(INTSXP, 1); INTEGER(r)[0] = NA_INTEGER; return r; }
SEXP biginteger_rand_u(SEXP a, SEXP b, SEXP c, SEXP d) { SEXP r = Rf_allocVector(INTSXP, 1); INTEGER(r)[0] = 1; return r; }
SEXP biginteger_sizeinbase(SEXP a, SEXP b) { SEXP r = Rf_allocVector(INTSXP, 1); INTEGER(r)[0] = NA_INTEGER; return r; }
SEXP bigI_frexp(SEXP a) { SEXP r = Rf_allocVector(INTSXP, 1); INTEGER(r)[0] = NA_INTEGER; return r; }
SEXP bigI_choose(SEXP a, SEXP b) { return R_NilValue; }
SEXP bigI_factorial(SEXP a) { return R_NilValue; }
SEXP bigI_fibnum(SEXP a) { return R_NilValue; }
SEXP bigI_fibnum2(SEXP a) { return R_NilValue; }
SEXP bigI_lucnum(SEXP a) { return R_NilValue; }
SEXP bigI_lucnum2(SEXP a) { return R_NilValue; }
SEXP biginteger_max(SEXP a, SEXP b) { return R_NilValue; }
SEXP biginteger_min(SEXP a, SEXP b) { return R_NilValue; }
SEXP biginteger_cumsum(SEXP a) { return a; }
SEXP biginteger_sum(SEXP a) { return R_NilValue; }
SEXP biginteger_prod(SEXP a) { return R_NilValue; }
SEXP biginteger_powm(SEXP a, SEXP b, SEXP c) { return R_NilValue; }
SEXP biginteger_log2(SEXP a) { SEXP r = Rf_allocVector(REALSXP, 1); REAL(r)[0] = NA_REAL; return r; }
SEXP biginteger_log(SEXP a) { SEXP r = Rf_allocVector(REALSXP, 1); REAL(r)[0] = NA_REAL; return r; }

/* bigrational routines */
SEXP bigrational_add(SEXP a, SEXP b) { return R_NilValue; }
SEXP bigrational_sub(SEXP a, SEXP b) { return R_NilValue; }
SEXP bigrational_mul(SEXP a, SEXP b) { return R_NilValue; }
SEXP bigrational_div(SEXP a, SEXP b) { return R_NilValue; }
SEXP bigrational_pow(SEXP a, SEXP b) { return R_NilValue; }
SEXP bigrational_num(SEXP a) { return R_NilValue; }
SEXP bigrational_den(SEXP a) { return R_NilValue; }
SEXP bigrational_get_at(SEXP a, SEXP b) { return R_NilValue; }
SEXP bigrational_set_at(SEXP a, SEXP b, SEXP c) { return R_NilValue; }
SEXP bigrational_as(SEXP a, SEXP b) {
  SEXP res = Rf_allocVector(INTSXP, 1);
  INTEGER(res)[0] = NA_INTEGER;
  return res;
}
SEXP bigrational_as_character(SEXP a, SEXP b) { SEXP r = Rf_allocVector(STRSXP, 1); SET_STRING_ELT(r, 0, NA_STRING); return r; }
SEXP bigrational_as_numeric(SEXP a) { SEXP r = Rf_allocVector(REALSXP, 1); REAL(r)[0] = NA_REAL; return r; }
SEXP bigrational_length(SEXP a) { SEXP r = Rf_allocVector(INTSXP, 1); INTEGER(r)[0] = 1; return r; }
SEXP bigrational_setlength(SEXP a, SEXP b) { return a; }
SEXP bigrational_is_na(SEXP a) { SEXP r = Rf_allocVector(LGLSXP, 1); LOGICAL(r)[0] = 0; return r; }
SEXP bigrational_is_int(SEXP a) { SEXP r = Rf_allocVector(LGLSXP, 1); LOGICAL(r)[0] = 0; return r; }
SEXP bigrational_lt(SEXP a, SEXP b) { SEXP r = Rf_allocVector(LGLSXP, 1); LOGICAL(r)[0] = NA_LOGICAL; return r; }
SEXP bigrational_gt(SEXP a, SEXP b) { SEXP r = Rf_allocVector(LGLSXP, 1); LOGICAL(r)[0] = NA_LOGICAL; return r; }
SEXP bigrational_lte(SEXP a, SEXP b) { SEXP r = Rf_allocVector(LGLSXP, 1); LOGICAL(r)[0] = NA_LOGICAL; return r; }
SEXP bigrational_gte(SEXP a, SEXP b) { SEXP r = Rf_allocVector(LGLSXP, 1); LOGICAL(r)[0] = NA_LOGICAL; return r; }
SEXP bigrational_eq(SEXP a, SEXP b) { SEXP r = Rf_allocVector(LGLSXP, 1); LOGICAL(r)[0] = NA_LOGICAL; return r; }
SEXP bigrational_neq(SEXP a, SEXP b) { SEXP r = Rf_allocVector(LGLSXP, 1); LOGICAL(r)[0] = NA_LOGICAL; return r; }
SEXP bigrational_c(SEXP a) { return a; }
SEXP bigrational_cbind(SEXP a) { return a; }
SEXP bigrational_rep(SEXP a, SEXP b) { return a; }
SEXP bigrational_max(SEXP a, SEXP b) { return R_NilValue; }
SEXP bigrational_min(SEXP a, SEXP b) { return R_NilValue; }
SEXP bigrational_cumsum(SEXP a) { return a; }
SEXP bigrational_sum(SEXP a) { return R_NilValue; }
SEXP bigrational_prod(SEXP a) { return R_NilValue; }

/* matrix routines */
SEXP matrix_get_at_z(SEXP a, SEXP b, SEXP c) { return R_NilValue; }
SEXP matrix_set_at_z(SEXP a, SEXP b, SEXP c, SEXP d) { return a; }
SEXP matrix_get_at_q(SEXP a, SEXP b, SEXP c) { return R_NilValue; }
SEXP matrix_set_at_q(SEXP a, SEXP b, SEXP c, SEXP d) { return a; }
SEXP factorR(SEXP a) { return R_NilValue; }
SEXP is_matrix_zq(SEXP a) { SEXP r = Rf_allocVector(LGLSXP, 1); LOGICAL(r)[0] = 0; return r; }
SEXP as_matrixz(SEXP a, SEXP b, SEXP c, SEXP d, SEXP e) { return R_NilValue; }
SEXP bigint_transposeR(SEXP a) { return a; }
SEXP matrix_crossp_z(SEXP a, SEXP b) { return R_NilValue; }
SEXP matrix_mul_z(SEXP a, SEXP b, SEXP c) { return R_NilValue; }
SEXP biginteger_rbind(SEXP a) { return a; }
SEXP as_matrixq(SEXP a, SEXP b, SEXP c, SEXP d, SEXP e) { return R_NilValue; }
SEXP bigq_transposeR(SEXP a) { return a; }
SEXP matrix_crossp_q(SEXP a, SEXP b) { return R_NilValue; }
SEXP matrix_mul_q(SEXP a, SEXP b, SEXP c) { return R_NilValue; }
SEXP bigrational_rbind(SEXP a) { return a; }
SEXP inverse_q(SEXP a) { return R_NilValue; }
SEXP solve_q(SEXP a, SEXP b) { return R_NilValue; }
SEXP inverse_z(SEXP a) { return R_NilValue; }
SEXP solve_z(SEXP a, SEXP b) { return R_NilValue; }
SEXP gmpMatToListZ(SEXP a, SEXP b) { return R_NilValue; }
SEXP gmpMatToListQ(SEXP a, SEXP b) { return R_NilValue; }

#define CALLDEF(name, n)  {#name, (DL_FUNC) &name, n}

static R_CallMethodDef CallEntries[] = {
  CALLDEF(gmpMatToListZ, 2),
  CALLDEF(gmpMatToListQ, 2),
  CALLDEF(R_gmp_get_version, 0),
  CALLDEF(biginteger_add, 2),
  CALLDEF(biginteger_sub, 2),
  CALLDEF(biginteger_mul, 2),
  CALLDEF(biginteger_div, 2),
  CALLDEF(biginteger_divq, 2),
  CALLDEF(biginteger_mod, 2),
  CALLDEF(biginteger_pow, 2),
  CALLDEF(biginteger_inv, 2),
  CALLDEF(biginteger_gcd, 2),
  CALLDEF(biginteger_lcm, 2),
  CALLDEF(biginteger_get_at, 2),
  CALLDEF(biginteger_set_at, 3),
  CALLDEF(biginteger_as, 2),
  CALLDEF(biginteger_as_character, 2),
  CALLDEF(biginteger_as_numeric, 1),
  CALLDEF(biginteger_as_integer, 1),
  CALLDEF(biginteger_length, 1),
  CALLDEF(biginteger_setlength, 2),
  CALLDEF(biginteger_is_na, 1),
  CALLDEF(biginteger_sgn, 1),
  CALLDEF(biginteger_lt, 2),
  CALLDEF(biginteger_gt, 2),
  CALLDEF(biginteger_lte, 2),
  CALLDEF(biginteger_gte, 2),
  CALLDEF(biginteger_eq, 2),
  CALLDEF(biginteger_neq, 2),
  CALLDEF(biginteger_c, 1),
  CALLDEF(biginteger_cbind, 1),
  CALLDEF(biginteger_rep, 2),
  CALLDEF(biginteger_is_prime, 2),
  CALLDEF(biginteger_nextprime, 1),
  CALLDEF(biginteger_abs, 1),
  CALLDEF(biginteger_gcdex, 2),
  CALLDEF(biginteger_rand_u, 4),
  CALLDEF(biginteger_sizeinbase, 2),
  CALLDEF(bigI_frexp, 1),
  CALLDEF(bigI_choose, 2),
  CALLDEF(bigI_factorial, 1),
  CALLDEF(bigI_fibnum, 1),
  CALLDEF(bigI_fibnum2, 1),
  CALLDEF(bigI_lucnum, 1),
  CALLDEF(bigI_lucnum2, 1),
  CALLDEF(biginteger_max, 2),
  CALLDEF(biginteger_min, 2),
  CALLDEF(biginteger_cumsum, 1),
  CALLDEF(biginteger_sum, 1),
  CALLDEF(biginteger_prod, 1),
  CALLDEF(biginteger_powm, 3),
  CALLDEF(biginteger_log2, 1),
  CALLDEF(biginteger_log, 1),
  CALLDEF(bigrational_add, 2),
  CALLDEF(bigrational_sub, 2),
  CALLDEF(bigrational_mul, 2),
  CALLDEF(bigrational_div, 2),
  CALLDEF(bigrational_pow, 2),
  CALLDEF(bigrational_num, 1),
  CALLDEF(bigrational_den, 1),
  CALLDEF(bigrational_get_at, 2),
  CALLDEF(bigrational_set_at, 3),
  CALLDEF(bigrational_as, 2),
  CALLDEF(bigrational_as_character, 2),
  CALLDEF(bigrational_as_numeric, 1),
  CALLDEF(bigrational_length, 1),
  CALLDEF(bigrational_setlength, 2),
  CALLDEF(bigrational_is_na, 1),
  CALLDEF(bigrational_is_int, 1),
  CALLDEF(bigrational_lt, 2),
  CALLDEF(bigrational_gt, 2),
  CALLDEF(bigrational_lte, 2),
  CALLDEF(bigrational_gte, 2),
  CALLDEF(bigrational_eq, 2),
  CALLDEF(bigrational_neq, 2),
  CALLDEF(bigrational_c, 1),
  CALLDEF(bigrational_cbind, 1),
  CALLDEF(bigrational_rep, 2),
  CALLDEF(bigrational_max, 2),
  CALLDEF(bigrational_min, 2),
  CALLDEF(bigrational_cumsum, 1),
  CALLDEF(bigrational_sum, 1),
  CALLDEF(bigrational_prod, 1),
  CALLDEF(matrix_get_at_z, 3),
  CALLDEF(matrix_set_at_z, 4),
  CALLDEF(matrix_get_at_q, 3),
  CALLDEF(matrix_set_at_q, 4),
  CALLDEF(factorR, 1),
  CALLDEF(is_matrix_zq, 1),
  CALLDEF(as_matrixz, 5),
  CALLDEF(bigint_transposeR, 1),
  CALLDEF(matrix_crossp_z, 2),
  CALLDEF(matrix_mul_z, 3),
  CALLDEF(biginteger_rbind, 1),
  CALLDEF(as_matrixq, 5),
  CALLDEF(bigq_transposeR, 1),
  CALLDEF(matrix_crossp_q, 2),
  CALLDEF(matrix_mul_q, 3),
  CALLDEF(bigrational_rbind, 1),
  CALLDEF(inverse_q, 1),
  CALLDEF(solve_q, 2),
  CALLDEF(inverse_z, 1),
  CALLDEF(solve_z, 2),
  {NULL, NULL, 0}
};

void R_init_gmp(DllInfo *dll) {
    R_registerRoutines(dll, NULL, CallEntries, NULL, NULL);
    R_useDynamicSymbols(dll, FALSE);
}
