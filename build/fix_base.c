#include <R.h>
#include <Rinternals.h>
#include <R_ext/Rdynload.h>

/* The task callback C functions exist in libR.so.
   We declare them here so R_init_fixbase can register them. */
extern SEXP R_addTaskCallback(SEXP, SEXP, SEXP, SEXP);
extern SEXP R_removeTaskCallback(SEXP);
extern SEXP R_getTaskCallbackNames(void);

static const R_CallMethodDef callMethods[] = {
    {"R_addTaskCallback",      (DL_FUNC) &R_addTaskCallback,      4},
    {"R_removeTaskCallback",   (DL_FUNC) &R_removeTaskCallback,   1},
    {"R_getTaskCallbackNames", (DL_FUNC) &R_getTaskCallbackNames, 0},
    {NULL, NULL, 0}
};

void R_init_fixbase(DllInfo *dll) {
    R_registerRoutines(dll, NULL, callMethods, NULL, NULL);
}
