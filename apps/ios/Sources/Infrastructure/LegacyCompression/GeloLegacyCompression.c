#include "GeloLegacyCompression.h"
#include <stdio.h>
#include <stdlib.h>
#include <fcntl.h>
#include <unistd.h>
#include <string.h>
#include <zlib.h>
#if defined(__APPLE__)
#include <CommonCrypto/CommonCryptor.h>
#endif
/* Streaming, bounded codec. Caller provides an unpredictable private temp path.
 * The output is removed on every failure and is never opened through a symlink. */
int32_t gelo_aes256_cbc_raw_inflate_file_range(const char *input_path,uint64_t offset,
 uint64_t encrypted_size,uint64_t compressed_size,const uint8_t *key,const uint8_t *iv,
 const char *output_path,uint64_t expected_size,uint64_t *written) {
 if(written) *written=0;
 if(!input_path||!output_path||!key||!iv||!written||!encrypted_size||encrypted_size%16||
    !compressed_size||compressed_size>encrypted_size||encrypted_size-compressed_size>=16||
    expected_size==0||expected_size>64ULL*1024*1024||encrypted_size>64ULL*1024*1024+16||
    offset>INT64_MAX||encrypted_size>INT64_MAX-offset) return GELO_INFLATE_INVALID;
#if !defined(__APPLE__)
 return GELO_INFLATE_UNSUPPORTED;
#else
 int result=GELO_INFLATE_IO, fd=-1, initialized=0; FILE *input=NULL,*output=NULL;
 CCCryptorRef cipher=NULL; z_stream stream={0};
 uint8_t encrypted[65536],plain[65552],inflated[65536]; uint64_t consumed=0,total=0;
 input=fopen(input_path,"rb"); if(!input||fseeko(input,(off_t)offset,SEEK_SET))goto done;
 fd=open(output_path,O_WRONLY|O_CREAT|O_EXCL|O_NOFOLLOW,0600); if(fd<0)goto done;
 output=fdopen(fd,"wb"); if(!output){close(fd);unlink(output_path);goto done;} fd=-1;
 result=GELO_INFLATE_CODEC;
 if(CCCryptorCreate(kCCDecrypt,kCCAlgorithmAES,0,key,32,iv,&cipher)!=kCCSuccess)goto done;
 if(inflateInit2(&stream,-MAX_WBITS)!=Z_OK)goto done; initialized=1;
 for(uint64_t remaining=encrypted_size;remaining;){
  size_t count=remaining>sizeof(encrypted)?sizeof(encrypted):(size_t)remaining,produced=0;
  if(fread(encrypted,1,count,input)!=count){result=GELO_INFLATE_IO;goto done;}
  if(CCCryptorUpdate(cipher,encrypted,count,plain,sizeof(plain),&produced)!=kCCSuccess)goto done;
  remaining-=count; size_t available=(size_t)((compressed_size-consumed)<produced?(compressed_size-consumed):produced);
  consumed+=available; stream.next_in=plain;stream.avail_in=(uInt)available;
  while(stream.avail_in){
   stream.next_out=inflated;stream.avail_out=sizeof(inflated);uInt before=stream.avail_in;
   int status=inflate(&stream,Z_NO_FLUSH);size_t n=sizeof(inflated)-stream.avail_out;
   if(total+n>expected_size)goto done;
   if(n&&fwrite(inflated,1,n,output)!=n){result=GELO_INFLATE_IO;goto done;}total+=n;
   if(status==Z_STREAM_END){
    if(stream.avail_in||consumed!=compressed_size||remaining||total!=expected_size)goto done;
    size_t final_count=0;if(CCCryptorFinal(cipher,plain,sizeof(plain),&final_count)!=kCCSuccess||final_count)goto done;
    if(fflush(output)||fsync(fileno(output))){result=GELO_INFLATE_IO;goto done;}
    *written=total;result=GELO_INFLATE_OK;goto done;
   }
   if(status!=Z_OK||(before==stream.avail_in&&!n))goto done;
  }
 }
 done:
 if(initialized)inflateEnd(&stream);if(cipher)CCCryptorRelease(cipher);
 if(input)fclose(input);if(output){if(fclose(output)&&result==GELO_INFLATE_OK){*written=0;result=GELO_INFLATE_IO;}if(result!=GELO_INFLATE_OK)unlink(output_path);}
 return result;
#endif
}
