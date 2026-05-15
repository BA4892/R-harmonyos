/* nloptr stub - provides NLoptR_Optimize and all nlopt_* callables */
#include <R.h>
#include <Rinternals.h>
#include <R_ext/Rdynload.h>
#include <stdlib.h>

/* nlopt.h constants */
typedef enum {
  NLOPT_SUCCESS = 1,
  NLOPT_STOPVAL_REACHED = 2,
  NLOPT_FTOL_REACHED = 3,
  NLOPT_XTOL_REACHED = 4,
  NLOPT_MAXEVAL_REACHED = 5,
  NLOPT_MAXTIME_REACHED = 6,
  NLOPT_FAILURE = -1,
  NLOPT_INVALID_ARGS = -2,
  NLOPT_OUT_OF_MEMORY = -3,
  NLOPT_ROUNDOFF_LIMITED = -4,
  NLOPT_FORCED_STOP = -5,
  NLOPT_NUM_RESULTS = -6
} nlopt_result;

typedef struct {} nlopt_opt;
typedef double (*nlopt_func)(unsigned, const double*, double*, void*);
typedef double (*nlopt_mfunc)(unsigned, const double*, double*, unsigned, const double*, double*, void*);
typedef void (*nlopt_precond)(unsigned, const double*, double*, void*);

SEXP NLoptR_Optimize(SEXP args) {
  /* Return a list with the expected structure that nloptr R code expects.
     This is a stub so we return NLOPT_FAILURE with appropriate fields. */
  SEXP ret, sol, status, msg, iters, obj, ver_maj, ver_min, ver_bug, names;
  const char *cnames[] = {"status", "message", "iterations", "objective",
                           "solution", "version_major", "version_minor",
                           "version_bugfix"};
  int i, nprot = 0;

  PROTECT(args); nprot++;

  ret = PROTECT(allocVector(VECSXP, 8)); nprot++;
  sol = PROTECT(allocVector(REALSXP, 1)); nprot++;
  status = PROTECT(allocVector(INTSXP, 1)); nprot++;
  msg = PROTECT(allocVector(STRSXP, 1)); nprot++;
  iters = PROTECT(allocVector(INTSXP, 1)); nprot++;
  obj = PROTECT(allocVector(REALSXP, 1)); nprot++;
  ver_maj = PROTECT(allocVector(INTSXP, 1)); nprot++;
  ver_min = PROTECT(allocVector(INTSXP, 1)); nprot++;
  ver_bug = PROTECT(allocVector(INTSXP, 1)); nprot++;
  names = PROTECT(allocVector(STRSXP, 8)); nprot++;

  REAL(sol)[0] = 0.0;
  INTEGER(status)[0] = NLOPT_FAILURE;
  SET_STRING_ELT(msg, 0, mkChar("nloptr stub: NLopt not available"));
  INTEGER(iters)[0] = 0;
  REAL(obj)[0] = 0.0;
  INTEGER(ver_maj)[0] = 2;
  INTEGER(ver_min)[0] = 10;
  INTEGER(ver_bug)[0] = 0;

  for (i = 0; i < 8; i++)
    SET_STRING_ELT(names, i, mkChar(cnames[i]));

  SET_VECTOR_ELT(ret, 0, status);
  SET_VECTOR_ELT(ret, 1, msg);
  SET_VECTOR_ELT(ret, 2, iters);
  SET_VECTOR_ELT(ret, 3, obj);
  SET_VECTOR_ELT(ret, 4, sol);
  SET_VECTOR_ELT(ret, 5, ver_maj);
  SET_VECTOR_ELT(ret, 6, ver_min);
  SET_VECTOR_ELT(ret, 7, ver_bug);

  setAttrib(ret, R_NamesSymbol, names);

  UNPROTECT(nprot);
  return ret;
}

nlopt_opt *nlopt_create(int algorithm, unsigned n) { return NULL; }
void nlopt_destroy(nlopt_opt *opt) {}
nlopt_opt *nlopt_copy(const nlopt_opt *opt) { return NULL; }
nlopt_result nlopt_optimize(nlopt_opt *opt, double *x, double *opt_f) { return NLOPT_FAILURE; }
const char *nlopt_algorithm_name(nlopt_opt *opt) { return "stub"; }
void nlopt_srand(unsigned long seed) {}
void nlopt_srand_time(void) {}
const char *nlopt_version(void) { return "2.10.0"; }
int nlopt_get_algorithm(nlopt_opt *opt) { return 0; }
unsigned nlopt_get_dimension(nlopt_opt *opt) { return 0; }

nlopt_result nlopt_set_lower_bounds(nlopt_opt *opt, const double *lb) { return NLOPT_SUCCESS; }
nlopt_result nlopt_set_lower_bounds1(nlopt_opt *opt, double lb) { return NLOPT_SUCCESS; }
nlopt_result nlopt_get_lower_bounds(const nlopt_opt *opt, double *lb) { return NLOPT_FAILURE; }
nlopt_result nlopt_set_upper_bounds(nlopt_opt *opt, const double *ub) { return NLOPT_SUCCESS; }
nlopt_result nlopt_set_upper_bounds1(nlopt_opt *opt, double ub) { return NLOPT_SUCCESS; }
nlopt_result nlopt_get_upper_bounds(const nlopt_opt *opt, double *ub) { return NLOPT_FAILURE; }
nlopt_result nlopt_remove_inequality_constraints(nlopt_opt *opt) { return NLOPT_SUCCESS; }
nlopt_result nlopt_add_inequality_constraint(nlopt_opt *opt, nlopt_func fc, void *fc_data, double tol) { return NLOPT_SUCCESS; }
nlopt_result nlopt_add_precond_inequality_constraint(nlopt_opt *opt, nlopt_func fc, nlopt_precond pre, void *fc_data, double tol) { return NLOPT_SUCCESS; }
nlopt_result nlopt_add_inequality_mconstraint(nlopt_opt *opt, unsigned m, nlopt_mfunc fc, void *fc_data, const double *tol) { return NLOPT_SUCCESS; }
nlopt_result nlopt_remove_equality_constraints(nlopt_opt *opt) { return NLOPT_SUCCESS; }
nlopt_result nlopt_add_equality_constraint(nlopt_opt *opt, nlopt_func fc, void *fc_data, double tol) { return NLOPT_SUCCESS; }
nlopt_result nlopt_add_precond_equality_constraint(nlopt_opt *opt, nlopt_func fc, nlopt_precond pre, void *fc_data, double tol) { return NLOPT_SUCCESS; }
nlopt_result nlopt_add_equality_mconstraint(nlopt_opt *opt, unsigned m, nlopt_mfunc fc, void *fc_data, const double *tol) { return NLOPT_SUCCESS; }
nlopt_result nlopt_set_stopval(nlopt_opt *opt, double stopval) { return NLOPT_SUCCESS; }
double nlopt_get_stopval(const nlopt_opt *opt) { return 0; }
nlopt_result nlopt_set_ftol_rel(nlopt_opt *opt, double tol) { return NLOPT_SUCCESS; }
double nlopt_get_ftol_rel(const nlopt_opt *opt) { return 0; }
nlopt_result nlopt_set_ftol_abs(nlopt_opt *opt, double tol) { return NLOPT_SUCCESS; }
double nlopt_get_ftol_abs(const nlopt_opt *opt) { return 0; }
nlopt_result nlopt_set_xtol_rel(nlopt_opt *opt, double tol) { return NLOPT_SUCCESS; }
double nlopt_get_xtol_rel(const nlopt_opt *opt) { return 0; }
nlopt_result nlopt_set_xtol_abs1(nlopt_opt *opt, double tol) { return NLOPT_SUCCESS; }
nlopt_result nlopt_set_xtol_abs(nlopt_opt *opt, const double *tol) { return NLOPT_SUCCESS; }
nlopt_result nlopt_get_xtol_abs(const nlopt_opt *opt, double *tol) { return NLOPT_FAILURE; }
nlopt_result nlopt_set_maxeval(nlopt_opt *opt, int maxeval) { return NLOPT_SUCCESS; }
int nlopt_get_maxeval(const nlopt_opt *opt) { return 0; }
nlopt_result nlopt_set_maxtime(nlopt_opt *opt, double maxtime) { return NLOPT_SUCCESS; }
double nlopt_get_maxtime(const nlopt_opt *opt) { return 0; }
nlopt_result nlopt_force_stop(nlopt_opt *opt) { return NLOPT_SUCCESS; }
nlopt_result nlopt_set_force_stop(nlopt_opt *opt, int val) { return NLOPT_SUCCESS; }
int nlopt_get_force_stop(const nlopt_opt *opt) { return 0; }
nlopt_result nlopt_set_local_optimizer(nlopt_opt *opt, const nlopt_opt *local_opt) { return NLOPT_SUCCESS; }
nlopt_result nlopt_set_population(nlopt_opt *opt, unsigned pop) { return NLOPT_SUCCESS; }
unsigned nlopt_get_population(const nlopt_opt *opt) { return 0; }
nlopt_result nlopt_set_vector_storage(nlopt_opt *opt, unsigned dim) { return NLOPT_SUCCESS; }
unsigned nlopt_get_vector_storage(const nlopt_opt *opt) { return 0; }
nlopt_result nlopt_set_default_initial_step(nlopt_opt *opt, const double *x) { return NLOPT_SUCCESS; }
nlopt_result nlopt_set_initial_step(nlopt_opt *opt, const double *dx) { return NLOPT_SUCCESS; }
nlopt_result nlopt_set_initial_step1(nlopt_opt *opt, double dx) { return NLOPT_SUCCESS; }
nlopt_result nlopt_get_initial_step(const nlopt_opt *opt, const double *x, double *dx) { return NLOPT_FAILURE; }
nlopt_result nlopt_set_min_objective(nlopt_opt *opt, nlopt_func f, void *f_data) { return NLOPT_SUCCESS; }
nlopt_result nlopt_set_max_objective(nlopt_opt *opt, nlopt_func f, void *f_data) { return NLOPT_SUCCESS; }
nlopt_result nlopt_set_precond_min_objective(nlopt_opt *opt, nlopt_func f, nlopt_precond pre, void *f_data) { return NLOPT_SUCCESS; }
nlopt_result nlopt_set_precond_max_objective(nlopt_opt *opt, nlopt_func f, nlopt_precond pre, void *f_data) { return NLOPT_SUCCESS; }

static const R_CallMethodDef CallEntries[] = {
  {"NLoptR_Optimize", (DL_FUNC) &NLoptR_Optimize, 1},
  {NULL, NULL, 0}
};

void R_init_nloptr(DllInfo *info) {
  R_RegisterCCallable("nloptr", "nlopt_algorithm_name", (DL_FUNC) &nlopt_algorithm_name);
  R_RegisterCCallable("nloptr", "nlopt_srand", (DL_FUNC) &nlopt_srand);
  R_RegisterCCallable("nloptr", "nlopt_srand_time", (DL_FUNC) &nlopt_srand_time);
  R_RegisterCCallable("nloptr", "nlopt_version", (DL_FUNC) &nlopt_version);
  R_RegisterCCallable("nloptr", "nlopt_create", (DL_FUNC) &nlopt_create);
  R_RegisterCCallable("nloptr", "nlopt_destroy", (DL_FUNC) &nlopt_destroy);
  R_RegisterCCallable("nloptr", "nlopt_copy", (DL_FUNC) &nlopt_copy);
  R_RegisterCCallable("nloptr", "nlopt_optimize", (DL_FUNC) &nlopt_optimize);
  R_RegisterCCallable("nloptr", "nlopt_set_min_objective", (DL_FUNC) &nlopt_set_min_objective);
  R_RegisterCCallable("nloptr", "nlopt_set_max_objective", (DL_FUNC) &nlopt_set_max_objective);
  R_RegisterCCallable("nloptr", "nlopt_set_precond_min_objective", (DL_FUNC) &nlopt_set_precond_min_objective);
  R_RegisterCCallable("nloptr", "nlopt_set_precond_max_objective", (DL_FUNC) &nlopt_set_precond_max_objective);
  R_RegisterCCallable("nloptr", "nlopt_get_algorithm", (DL_FUNC) &nlopt_get_algorithm);
  R_RegisterCCallable("nloptr", "nlopt_get_dimension", (DL_FUNC) &nlopt_get_dimension);
  R_RegisterCCallable("nloptr", "nlopt_set_lower_bounds", (DL_FUNC) &nlopt_set_lower_bounds);
  R_RegisterCCallable("nloptr", "nlopt_set_lower_bounds1", (DL_FUNC) &nlopt_set_lower_bounds1);
  R_RegisterCCallable("nloptr", "nlopt_get_lower_bounds", (DL_FUNC) &nlopt_get_lower_bounds);
  R_RegisterCCallable("nloptr", "nlopt_set_upper_bounds", (DL_FUNC) &nlopt_set_upper_bounds);
  R_RegisterCCallable("nloptr", "nlopt_set_upper_bounds1", (DL_FUNC) &nlopt_set_upper_bounds1);
  R_RegisterCCallable("nloptr", "nlopt_get_upper_bounds", (DL_FUNC) &nlopt_get_upper_bounds);
  R_RegisterCCallable("nloptr", "nlopt_remove_inequality_constraints", (DL_FUNC) &nlopt_remove_inequality_constraints);
  R_RegisterCCallable("nloptr", "nlopt_add_inequality_constraint", (DL_FUNC) &nlopt_add_inequality_constraint);
  R_RegisterCCallable("nloptr", "nlopt_add_precond_inequality_constraint", (DL_FUNC) &nlopt_add_precond_inequality_constraint);
  R_RegisterCCallable("nloptr", "nlopt_add_inequality_mconstraint", (DL_FUNC) &nlopt_add_inequality_mconstraint);
  R_RegisterCCallable("nloptr", "nlopt_remove_equality_constraints", (DL_FUNC) &nlopt_remove_equality_constraints);
  R_RegisterCCallable("nloptr", "nlopt_add_equality_constraint", (DL_FUNC) &nlopt_add_equality_constraint);
  R_RegisterCCallable("nloptr", "nlopt_add_precond_equality_constraint", (DL_FUNC) &nlopt_add_precond_equality_constraint);
  R_RegisterCCallable("nloptr", "nlopt_add_equality_mconstraint", (DL_FUNC) &nlopt_add_equality_mconstraint);
  R_RegisterCCallable("nloptr", "nlopt_set_stopval", (DL_FUNC) &nlopt_set_stopval);
  R_RegisterCCallable("nloptr", "nlopt_get_stopval", (DL_FUNC) &nlopt_get_stopval);
  R_RegisterCCallable("nloptr", "nlopt_set_ftol_rel", (DL_FUNC) &nlopt_set_ftol_rel);
  R_RegisterCCallable("nloptr", "nlopt_get_ftol_rel", (DL_FUNC) &nlopt_get_ftol_rel);
  R_RegisterCCallable("nloptr", "nlopt_set_ftol_abs", (DL_FUNC) &nlopt_set_ftol_abs);
  R_RegisterCCallable("nloptr", "nlopt_get_ftol_abs", (DL_FUNC) &nlopt_get_ftol_abs);
  R_RegisterCCallable("nloptr", "nlopt_set_xtol_rel", (DL_FUNC) &nlopt_set_xtol_rel);
  R_RegisterCCallable("nloptr", "nlopt_get_xtol_rel", (DL_FUNC) &nlopt_get_xtol_rel);
  R_RegisterCCallable("nloptr", "nlopt_set_xtol_abs1", (DL_FUNC) &nlopt_set_xtol_abs1);
  R_RegisterCCallable("nloptr", "nlopt_set_xtol_abs", (DL_FUNC) &nlopt_set_xtol_abs);
  R_RegisterCCallable("nloptr", "nlopt_get_xtol_abs", (DL_FUNC) &nlopt_get_xtol_abs);
  R_RegisterCCallable("nloptr", "nlopt_set_maxeval", (DL_FUNC) &nlopt_set_maxeval);
  R_RegisterCCallable("nloptr", "nlopt_get_maxeval", (DL_FUNC) &nlopt_get_maxeval);
  R_RegisterCCallable("nloptr", "nlopt_set_maxtime", (DL_FUNC) &nlopt_set_maxtime);
  R_RegisterCCallable("nloptr", "nlopt_get_maxtime", (DL_FUNC) &nlopt_get_maxtime);
  R_RegisterCCallable("nloptr", "nlopt_force_stop", (DL_FUNC) &nlopt_force_stop);
  R_RegisterCCallable("nloptr", "nlopt_set_force_stop", (DL_FUNC) &nlopt_set_force_stop);
  R_RegisterCCallable("nloptr", "nlopt_get_force_stop", (DL_FUNC) &nlopt_get_force_stop);
  R_RegisterCCallable("nloptr", "nlopt_set_local_optimizer", (DL_FUNC) &nlopt_set_local_optimizer);
  R_RegisterCCallable("nloptr", "nlopt_set_population", (DL_FUNC) &nlopt_set_population);
  R_RegisterCCallable("nloptr", "nlopt_get_population", (DL_FUNC) &nlopt_get_population);
  R_RegisterCCallable("nloptr", "nlopt_set_vector_storage", (DL_FUNC) &nlopt_set_vector_storage);
  R_RegisterCCallable("nloptr", "nlopt_get_vector_storage", (DL_FUNC) &nlopt_get_vector_storage);
  R_RegisterCCallable("nloptr", "nlopt_set_default_initial_step", (DL_FUNC) &nlopt_set_default_initial_step);
  R_RegisterCCallable("nloptr", "nlopt_set_initial_step", (DL_FUNC) &nlopt_set_initial_step);
  R_RegisterCCallable("nloptr", "nlopt_set_initial_step1", (DL_FUNC) &nlopt_set_initial_step1);
  R_RegisterCCallable("nloptr", "nlopt_get_initial_step", (DL_FUNC) &nlopt_get_initial_step);

  R_registerRoutines(info, NULL, CallEntries, NULL, NULL);
  R_useDynamicSymbols(info, FALSE);
  R_forceSymbols(info, TRUE);
}
