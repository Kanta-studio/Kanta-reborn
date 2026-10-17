#ifndef GELO_LEGACY_COMPRESSION_H
#define GELO_LEGACY_COMPRESSION_H
#include <stdint.h>
enum { GELO_INFLATE_OK=0, GELO_INFLATE_INVALID=1, GELO_INFLATE_IO=2, GELO_INFLATE_CODEC=3, GELO_INFLATE_UNSUPPORTED=4 };
int32_t gelo_aes256_cbc_raw_inflate_file_range(const char *input_path, uint64_t offset,
 uint64_t encrypted_size, uint64_t compressed_size, const uint8_t *key, const uint8_t *iv,
 const char *output_path, uint64_t expected_size, uint64_t *written);
#endif
