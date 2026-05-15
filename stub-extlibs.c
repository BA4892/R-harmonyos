/* Comprehensive external library stub for HarmonyOS
   Provides minimal stub symbols for packages needing:
   - Fortran (bayesQR)
   - OpenSSL (PKI)
   - libcurl (RCurl)
   - unixODBC (RODBC)
   - GLPK (Rglpk)
   - Brotli (brotli)
   - FFTW (fftw, fftwtools)
*/

#include <stddef.h>

/* ======== bayesQR Fortran stubs ======== */
double norm_rand(void) { return 0.0; }
double unif_rand(void) { return 0.5; }
void qrb_al_mcmc_(void) { }
void qrb_mcmc_(void) { }
void qrc_al_mcmc_(void) { }
void qrc_mcmc_(void) { }

/* ======== OpenSSL stubs (PKI) ======== */
void OPENSSL_init_ssl(void) { }
void OPENSSL_cleanup(void) { }
int ERR_get_error(void) { return 0; }
void BN_free(void *a) { }
void ASN1_STRING_free(void *a) { }
void EVP_CIPHER_CTX_free(void *a) { }
void EVP_CIPHER_CTX_reset(void *a) { }
void ERR_error_string(void) { }
void EVP_CipherInit(void) { }
void EVP_CipherUpdate(void) { }
void EVP_CipherFinal(void) { }
void EVP_PKEY_assign(void) { }
void EVP_PKEY_free(void *a) { }
void d2i_X509(void) { }

/* ======== libcurl stubs (RCurl) ======== */
void curl_easy_cleanup(void *a) { }
void curl_easy_reset(void *a) { }
void curl_free(void *a) { }
void curl_global_cleanup(void) { }
void curl_formfree(void *a) { }
void curl_slist_free_all(void *a) { }

/* ======== unixODBC stubs (RODBC) ======== */
void SQLDisconnect(void *a) { }
void SQLEndTran(void) { }
void SQLFreeHandle(void) { }
void SQLFreeStmt(void) { }

/* ======== GLPK stubs (Rglpk) ======== */
void glp_delete_prob(void *a) { }
void glp_set_prob_name(void) { }
void glp_set_obj_name(void) { }
void glp_set_obj_dir(void) { }
void glp_set_row_name(void) { }
void glp_set_col_name(void) { }
void glp_set_row_bnds(void) { }
void glp_set_col_bnds(void) { }
void glp_set_obj_coef(void) { }
void glp_set_col_kind(void) { }
void glp_error_hook(void) { }
void glp_free_env(void) { }
void glp_term_hook(void) { }
void glp_term_out(void) { }
void glp_version(void) { }
void glp_init_smcp(void) { }
void glp_init_iocp(void) { }
void glp_simplex(void) { }
void glp_intopt(void) { }
void glp_load_matrix(void) { }
void glp_mpl_alloc_wksp(void) { }
void glp_mpl_build_prob(void) { }
void glp_mpl_free_wksp(void) { }
void glp_mpl_generate(void) { }
void glp_mpl_read_model(void) { }
void glp_print_ranges(void) { }
void glp_read_lp(void) { }
void glp_read_mps(void) { }
void glp_write_lp(void) { }
void glp_write_mps(void) { }
void glp_write_prob(void) { }

/* ======== Brotli stubs ======== */
void BrotliDecoderDestroyInstance(void *a) { }

/* Brotli data lookup tables (referenced as extern data) */
const char _kBrotliContextLookupTable[1] = {0};
const char _kBrotliPrefixCodeRanges[1] = {0};

/* ======== FFTW stubs (fftw, fftwtools) ======== */
void fftw_destroy_plan(void *a) { }
void fftw_execute(void) { }
void fftw_free(void *a) { }

/* Functions returning non-void */
#define STUB_PTR(name) void *name(void) { return (void*)0; }
#define STUB_INT(name) int name(void) { return 0; }
#define STUB_DBL(name) double name(void) { return 0.0; }
#define STUB_STR(name) const char *name(void) { return "stub"; }

/* OpenSSL returning ptr/int */
STUB_INT(BN_new)
STUB_INT(BN_set_word)
STUB_INT(BIO_new)
STUB_INT(BIO_new_mem_buf)
STUB_INT(BIO_s_mem)
STUB_INT(BIO_ctrl)
STUB_INT(ASN1_TIME_set)
STUB_INT(ASN1_TIME_diff)
STUB_INT(EVP_CIPHER_CTX_new)
STUB_INT(EVP_CIPHER_CTX_get_block_size)
STUB_INT(EVP_CIPHER_get_key_length)
STUB_INT(EVP_CIPHER_get_iv_length)
STUB_INT(EVP_CIPHER_fetch)
STUB_INT(EVP_PKEY_new)
STUB_INT(EVP_PKEY_get1_RSA)
STUB_INT(EVP_PKEY_get_base_id)
STUB_INT(EVP_aes_128_cbc)
STUB_INT(EVP_aes_128_ecb)
STUB_INT(EVP_aes_128_ofb)
STUB_INT(EVP_aes_256_cbc)
STUB_INT(EVP_aes_256_ecb)
STUB_INT(EVP_aes_256_ofb)
STUB_INT(EVP_sha1)
STUB_STR(OpenSSL_version)
STUB_INT(OSSL_LIB_CTX_new)
STUB_INT(OSSL_PROVIDER_load)

/* OpenSSL returning int */
STUB_INT(OpenSSL_version_num)

/* libcurl returning ptr/int */
STUB_INT(curl_easy_init)
STUB_INT(curl_easy_setopt)
STUB_INT(curl_easy_perform)
STUB_INT(curl_easy_duphandle)
STUB_INT(curl_easy_getinfo)
STUB_STR(curl_easy_strerror)
STUB_INT(curl_escape)
STUB_INT(curl_unescape)
STUB_INT(curl_slist_append)
STUB_INT(curl_formadd)
STUB_INT(curl_global_init)
STUB_INT(curl_multi_init)
STUB_INT(curl_multi_add_handle)
STUB_INT(curl_multi_remove_handle)
STUB_INT(curl_multi_perform)
STUB_INT(curl_multi_fdset)
STUB_STR(curl_version)
STUB_INT(curl_version_info)

/* unixODBC returning int */
STUB_INT(SQLAllocHandle)
STUB_INT(SQLBindCol)
STUB_INT(SQLBindParameter)
STUB_INT(SQLColumns)
STUB_INT(SQLDataSources)
STUB_INT(SQLDescribeCol)
STUB_INT(SQLDriverConnect)
STUB_INT(SQLError)
STUB_INT(SQLExecDirect)
STUB_INT(SQLExecute)
STUB_INT(SQLFetch)
STUB_INT(SQLFetchScroll)
STUB_INT(SQLGetDiagRec)
STUB_INT(SQLGetInfo)
STUB_INT(SQLGetTypeInfo)
STUB_INT(SQLNumResultCols)
STUB_INT(SQLPrepare)
STUB_INT(SQLPrimaryKeys)
STUB_INT(SQLRowCount)
STUB_INT(SQLSetConnectAttr)
STUB_INT(SQLSetEnvAttr)
STUB_INT(SQLSetStmtAttr)
STUB_INT(SQLSpecialColumns)
STUB_INT(SQLTables)

/* GLPK returning ptr/int */
STUB_INT(glp_create_prob)
STUB_INT(glp_add_rows)
STUB_INT(glp_add_cols)
STUB_INT(glp_get_num_rows)
STUB_INT(glp_get_num_cols)
STUB_INT(glp_get_num_nz)
STUB_INT(glp_get_num_int)
STUB_INT(glp_get_num_bin)
STUB_INT(glp_get_obj_dir)
STUB_STR(glp_get_obj_name)
STUB_DBL(glp_get_obj_val)
STUB_STR(glp_get_prob_name)
STUB_STR(glp_get_row_name)
STUB_STR(glp_get_col_name)
STUB_DBL(glp_get_row_lb)
STUB_DBL(glp_get_row_ub)
STUB_INT(glp_get_row_type)
STUB_INT(glp_get_row_stat)
STUB_DBL(glp_get_row_dual)
STUB_DBL(glp_get_row_prim)
STUB_DBL(glp_get_col_lb)
STUB_DBL(glp_get_col_ub)
STUB_INT(glp_get_col_type)
STUB_INT(glp_get_col_stat)
STUB_DBL(glp_get_col_dual)
STUB_DBL(glp_get_col_prim)
STUB_INT(glp_get_mat_row)
STUB_INT(glp_get_status)
STUB_DBL(glp_mip_col_val)
STUB_DBL(glp_mip_obj_val)
STUB_DBL(glp_mip_row_val)
STUB_INT(glp_mip_status)

/* Brotli returning ptr/int */
STUB_INT(BrotliDecoderCreateInstance)
STUB_INT(BrotliDecoderDecompressStream)
STUB_INT(BrotliDefaultAllocFunc)
STUB_INT(BrotliDefaultFreeFunc)
STUB_INT(BrotliGetDictionary)
STUB_INT(BrotliGetTransforms)

/* FFTW returning ptr/int */
STUB_INT(fftw_malloc)
STUB_INT(fftw_import_system_wisdom)
STUB_INT(fftw_plan_dft_1d)
STUB_INT(fftw_plan_r2r_1d)
STUB_INT(fftw_plan_dft)
STUB_INT(fftw_plan_dft_2d)
STUB_INT(fftw_plan_dft_3d)
STUB_INT(fftw_plan_dft_c2r_1d)
STUB_INT(fftw_plan_dft_r2c_1d)
STUB_INT(fftw_plan_dft_r2c_2d)
STUB_INT(fftw_plan_dft_r2c_3d)
STUB_INT(fftw_plan_many_dft)
STUB_INT(fftw_plan_many_dft_c2r)
STUB_INT(fftw_plan_many_dft_r2c)
