/* Stub gfortran runtime library for HarmonyOS
   Provides minimal gfortran symbols needed by packages like Hmisc, acepack, etc. */

#include <stddef.h>

/* These are helper functions in libgfortran */
void _gfortran_runtime_error_at(const char *where, int line, const char *msg) {
    /* Stub - no-op */
}

void _gfortran_os_error_at(const char *where, int line) {
    /* Stub - no-op */
}

void _gfortran_pack(char *ret, const char *array, const char *vector,
                    const int *kind, const char *shape, int *ret_shape,
                    int rank, int vrank, int rank_len) {
    /* Stub - no-op */
}

/* Needed by acepack, Hmisc */
void _gfortran_matmul_r8(void *ret, void *a, void *b, int *a_rows, int *a_cols,
                          int *b_rows, int *b_cols, int *ret_rows, int *ret_cols) {
    /* Stub - no-op */
}

/* Needed by acepack */
void _gfortran_reshape_4(void *ret, const void *source, const int *shape,
                          const int *pad, const int *order, int ranks[]) {
    /* Stub - no-op */
}

/* Needed by lbfgsb3c */
void _gfortran_cpu_time_4(float *time) {
    if (time) *time = 0.0f;
}

/* Needed by sm */
void _gfortran_internal_pack(void *ret, const void *source, const int *rank,
                              const int *dims, const int *offset) {
    /* Stub - no-op */
}

/* Needed by various Fortran packages */
void _gfortran_internal_unpack(void *ret, const void *source, const int *rank,
                                const int *dims, const int *offset) {
    /* Stub - no-op */
}
