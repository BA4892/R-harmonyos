#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <zlib.h>

int main() {
    const char *data = "Hello, World! This is a test of zlib compression.";
    uLong inlen = strlen(data) + 1;
    uLong outlen = compressBound(inlen);
    Bytef *buf = malloc(outlen);
    
    printf("inlen: %lu, outlen bound: %lu\n", inlen, outlen);
    printf("Calling compress...\n");
    fflush(stdout);
    
    int res = compress(buf, &outlen, (const Bytef*)data, inlen);
    printf("compress returned: %d (Z_OK=%d, Z_MEM_ERROR=%d, Z_BUF_ERROR=%d)\n", 
           res, Z_OK, Z_MEM_ERROR, Z_BUF_ERROR);
    printf("outlen after compress: %lu\n", outlen);
    
    if (res == Z_OK) {
        printf("Compression succeeded!\n");
        
        uLong destlen = inlen * 2;
        char *dest = malloc(destlen);
        res = uncompress((Bytef*)dest, &destlen, buf, outlen);
        printf("uncompress returned: %d\n", res);
        printf("Decompressed: %s\n", dest);
        free(dest);
    }
    
    free(buf);
    return 0;
}
