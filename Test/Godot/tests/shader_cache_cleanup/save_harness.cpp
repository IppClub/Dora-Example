// Execute the production saver against queried capacities and actual GL lengths.
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <memory>
#include <string>
#include <vector>
using GLuint=unsigned; using GLenum=unsigned; using GLint=int; using GLsizei=int; using Error=int;
#define ANDROID_ENABLED 1
#define ERR_FAIL_COND(c) do {if(c)std::abort();} while(false)
static void require(bool b,const char *why){if(!b){std::fprintf(stderr,"%s\n",why);std::exit(1);}}
constexpr int GL_PROGRAM_BINARY_LENGTH=1;
template<class T>struct Vector:std::vector<T>{using std::vector<T>::vector;T *ptrw(){return this->data();}const T *ptr()const{return this->data();}int size()const{return int(std::vector<T>::size());}};
using PackedByteArray=Vector<uint8_t>;
struct String{std::string s;String(const char *p):s(p){}String(std::string p):s(p){}String path_join(const String &p)const{return s+"/"+p.s;}friend String operator+(const String &p,const char *q){return p.s+q;}};
template<class T>struct Ref{std::shared_ptr<T> p;Ref(T *v=nullptr):p(v){}bool is_null()const{return !p;}T *operator->()const{return p.get();}};
template<class K,class V>struct KeyValue{K key;V value;};
static std::vector<uint8_t> disk;static int capacity=16,actual=16;
struct FileAccess{enum{WRITE};static Ref<FileAccess> open(const String&,int,Error*){disk.clear();return new FileAccess;}
 void store_buffer(const uint8_t *p,int n){disk.insert(disk.end(),p,p+n);}void store_32(uint32_t v){for(int i=0;i<4;i++)disk.push_back(uint8_t(v>>(8*i)));}void store_64(uint64_t v){store_32(v);store_32(v>>32);}};
static void glGetProgramiv(GLuint,int,GLint *v){*v=capacity;}
static void glGetProgramBinary(GLuint,int n,GLsizei *length,GLenum *format,void *bytes){if(length)*length=actual;*format=0x93a6;for(int i=0;i<n && i<actual;i++)static_cast<uint8_t*>(bytes)[i]=uint8_t(i+1);}
static const char *shader_file_header="GLSC";static const uint32_t cache_file_version=3;
class ShaderGLES3{public:struct Version{struct Specialization{GLuint id=7;};std::vector<std::vector<KeyValue<uint64_t,Specialization>>> variants={{{42,{7}}}};};
 bool shader_cache_dir_valid=true;String shader_cache_dir{"cache"},name{"fixture"},base_sha256{"hash"};int variant_count=1;String _version_get_sha1(Version*){return "version";}void _save_to_cache(Version*);};
// @PRODUCTION_SAVER@
static uint32_t u32(size_t p){uint32_t v=0;for(int i=0;i<4;i++)v|=uint32_t(disk.at(p+i))<<(8*i);return v;}
int main(){ShaderGLES3 shader;ShaderGLES3::Version version;int cases=0;
 for(int n:{16,7,1,0,-1,17}){actual=n;shader._save_to_cache(&version);
  require(u32(4)==3 && u32(8)==1 && u32(12)==1,"Invalid cache header");
  bool valid=n>0 && n<=capacity;require(u32(24)==uint32_t(valid?n:0),"Persisted length differs from actual returned bytes");
  require(disk.size()==size_t(valid?32+n:28),"Trailing/uninitialized bytes persisted");
  if(valid){require(u32(28)==0x93a6,"Format lost");for(int i=0;i<n;i++)require(disk[32+i]==i+1,"Payload changed");}++cases;
 }
 capacity=0;actual=0;shader._save_to_cache(&version);require(u32(24)==0 && disk.size()==28,"Zero-capacity entry must be skipped");
 std::printf("PASS: %d binary length cases plus zero capacity\n",cases);}
