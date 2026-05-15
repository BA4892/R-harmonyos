/* Minimal libuv stub for HarmonyOS (musl) */
/* Provides libuv-1.x symbols needed by httpuv and fs */

#include <stddef.h>
#include <stdint.h>

/* Minimal type definitions matching what the binaries expect */
typedef struct { void *data; } uv_loop_s;
typedef struct { void *data; } uv_handle_s;
typedef struct { void *data; } uv_stream_s;
typedef struct { void *data; } uv_tcp_s;
typedef struct { void *data; } uv_pipe_s;
typedef struct { void *data; } uv_timer_s;
typedef struct { void *data; } uv_async_s;
typedef struct { long result; void *ptr; } uv_fs_s;
typedef struct { char *base; size_t len; } uv_buf_s;
typedef struct { int dummy; } uv_mutex_s;
typedef struct { int dummy; } uv_cond_s;
typedef struct { long dummy; } uv_thread_s;
typedef struct { void *cb; } uv_write_s;

typedef uv_loop_s uv_loop_t;
typedef uv_handle_s uv_handle_t;
typedef uv_stream_s uv_stream_t;
typedef uv_tcp_s uv_tcp_t;
typedef uv_pipe_s uv_pipe_t;
typedef uv_timer_s uv_timer_t;
typedef uv_async_s uv_async_t;
typedef uv_fs_s uv_fs_t;
typedef uv_buf_s uv_buf_t;
typedef uv_mutex_s uv_mutex_t;
typedef uv_cond_s uv_cond_t;
typedef uv_thread_s uv_thread_t;
typedef uv_write_s uv_write_t;

typedef void (*uv_close_cb)(uv_handle_t*);
typedef void (*uv_async_cb)(uv_async_t*);
typedef void (*uv_timer_cb)(uv_timer_t*);
typedef void (*uv_walk_cb)(uv_handle_t*, void*);
typedef void (*uv_alloc_cb)(uv_handle_t*, size_t, uv_buf_t*);
typedef void (*uv_read_cb)(uv_stream_t*, long, const uv_buf_t*);
typedef void (*uv_connection_cb)(uv_stream_t*, int);
typedef void (*uv_write_cb)(uv_write_t*, int);

struct uv_dirent_s { const char *name; int type; };
typedef struct uv_dirent_s uv_dirent_t;

static char uv_loop_buf[sizeof(uv_loop_s)] = {0};

/* Core loop */
uv_loop_t* uv_default_loop(void) { return (uv_loop_t*)uv_loop_buf; }
int uv_loop_init(uv_loop_t *loop) { return 0; }
int uv_loop_close(uv_loop_t *loop) { return 0; }
int uv_run(uv_loop_t *loop, int mode) { return 0; }
int uv_stop(uv_loop_t *loop) { return 0; }
void uv_close(uv_handle_t *handle, uv_close_cb cb) { if (cb) cb(handle); }
int uv_is_closing(const uv_handle_t *handle) { return 0; }
void uv_walk(uv_loop_t *loop, uv_walk_cb cb, void *arg) {}
int uv_accept(uv_stream_t *server, uv_stream_t *client) { return -1; }
int uv_listen(uv_stream_t *stream, int backlog, uv_connection_cb cb) { return 0; }

/* TCP */
int uv_tcp_init(uv_loop_t *loop, uv_tcp_t *handle) { return 0; }
int uv_tcp_bind(uv_tcp_t *handle, const void *addr, unsigned int flags) { return 0; }
int uv_tcp_getpeername(const uv_tcp_t *handle, void *name, int *namelen) { return -1; }
int uv_tcp_getsockname(const uv_tcp_t *handle, void *name, int *namelen) { return -1; }

/* Pipe */
int uv_pipe_init(uv_loop_t *loop, uv_pipe_t *handle, int ipc) { return 0; }
int uv_pipe_bind(uv_pipe_t *handle, const char *name) { return 0; }

/* Stream I/O */
int uv_read_start(uv_stream_t *stream, uv_alloc_cb alloc_cb, uv_read_cb read_cb) { return 0; }
int uv_read_stop(uv_stream_t *stream) { return 0; }
int uv_write(uv_write_t *req, uv_stream_t *handle, const uv_buf_t bufs[], unsigned int nbufs, uv_write_cb cb) {
    if (cb) cb(req, 0);
    return 0;
}

/* Timer */
int uv_timer_init(uv_loop_t *loop, uv_timer_t *handle) { return 0; }
int uv_timer_start(uv_timer_t *handle, uv_timer_cb cb, uint64_t timeout, uint64_t repeat) { return 0; }

/* Async */
int uv_async_init(uv_loop_t *loop, uv_async_t *async, uv_async_cb cb) { return 0; }
int uv_async_send(uv_async_t *async) { return 0; }

/* Sync */
int uv_mutex_init(uv_mutex_t *mutex) { return 0; }
int uv_mutex_init_recursive(uv_mutex_t *mutex) { return 0; }
void uv_mutex_destroy(uv_mutex_t *mutex) {}
void uv_mutex_lock(uv_mutex_t *mutex) {}
void uv_mutex_unlock(uv_mutex_t *mutex) {}
int uv_cond_init(uv_cond_t *cond) { return 0; }
void uv_cond_destroy(uv_cond_t *cond) {}
void uv_cond_signal(uv_cond_t *cond) {}
void uv_cond_wait(uv_cond_t *cond, uv_mutex_t *mutex) {}

/* Thread */
int uv_thread_create(uv_thread_t *tid, void (*entry)(void*), void *arg) { return 0; }
int uv_thread_equal(const uv_thread_t *t1, const uv_thread_t *t2) { return 1; }
uv_thread_t uv_thread_self(void) { uv_thread_t t = {0}; return t; }

/* Address */
int uv_ip4_addr(const char *ip, int port, void *addr) { return 0; }
int uv_ip6_addr(const char *ip, int port, void *addr) { return 0; }
int uv_inet_pton(int af, const char *src, void *dst) { return -1; }

/* Error */
const char* uv_strerror(int err) { return "uv_stub_error"; }
const char* uv_err_name(int err) { return "UV_ESTUB"; }

/* Buffer */
uv_buf_t uv_buf_init(char *base, unsigned int len) {
    uv_buf_t buf = {base, len};
    return buf;
}

/* Filesystem */
int uv_fs_access(uv_loop_t *loop, uv_fs_t *req, const char *path, int mode, void *cb) { req->result = -1; return -1; }
int uv_fs_chmod(uv_loop_t *loop, uv_fs_t *req, const char *path, int mode, void *cb) { req->result = 0; return 0; }
int uv_fs_chown(uv_loop_t *loop, uv_fs_t *req, const char *path, int uid, int gid, void *cb) { req->result = 0; return 0; }
int uv_fs_close(uv_loop_t *loop, uv_fs_t *req, int file, void *cb) { req->result = 0; return 0; }
int uv_fs_copyfile(uv_loop_t *loop, uv_fs_t *req, const char *path, const char *new_path, int flags, void *cb) { req->result = -1; return -1; }
int uv_fs_link(uv_loop_t *loop, uv_fs_t *req, const char *path, const char *new_path, void *cb) { req->result = 0; return 0; }
int uv_fs_lstat(uv_loop_t *loop, uv_fs_t *req, const char *path, void *cb) { req->result = -1; return -1; }
int uv_fs_mkdir(uv_loop_t *loop, uv_fs_t *req, const char *path, int mode, void *cb) { req->result = -1; return -1; }
int uv_fs_open(uv_loop_t *loop, uv_fs_t *req, const char *path, int flags, int mode, void *cb) { req->result = -1; return -1; }
int uv_fs_readlink(uv_loop_t *loop, uv_fs_t *req, const char *path, void *cb) { req->result = -1; return -1; }
int uv_fs_realpath(uv_loop_t *loop, uv_fs_t *req, const char *path, void *cb) { req->result = -1; return -1; }
int uv_fs_rename(uv_loop_t *loop, uv_fs_t *req, const char *path, const char *new_path, void *cb) { req->result = 0; return 0; }
int uv_fs_rmdir(uv_loop_t *loop, uv_fs_t *req, const char *path, void *cb) { req->result = -1; return -1; }
int uv_fs_scandir(uv_loop_t *loop, uv_fs_t *req, const char *path, int flags, void *cb) { req->result = -1; return -1; }
int uv_fs_scandir_next(uv_fs_t *req, uv_dirent_t *ent) { return -1; }
int uv_fs_stat(uv_loop_t *loop, uv_fs_t *req, const char *path, void *cb) { req->result = -1; return -1; }
int uv_fs_symlink(uv_loop_t *loop, uv_fs_t *req, const char *path, const char *new_path, int flags, void *cb) { req->result = 0; return 0; }
int uv_fs_unlink(uv_loop_t *loop, uv_fs_t *req, const char *path, void *cb) { req->result = -1; return -1; }
int uv_fs_utime(uv_loop_t *loop, uv_fs_t *req, const char *path, double atime, double mtime, void *cb) { req->result = 0; return 0; }
void uv_fs_req_cleanup(uv_fs_t *req) {}
