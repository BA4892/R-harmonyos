typedef struct backtrace_state backtrace_state;
backtrace_state *backtrace_create_state(const char *filename, int threaded,
    int (*error_callback)(void *, const char *, int, void *),
    void *data) { return (void *)0; }
void backtrace_simple(struct backtrace_state *state, int skip,
    int (*callback)(void *, unsigned long, void *),
    int (*error_callback)(void *, const char *, int, void *),
    void *data) {}
