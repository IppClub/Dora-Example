// Executes the production cache loader/initializer/clear methods with a fake GL
// driver and serialized cache inputs. No GPU or emulator is required.
#include <algorithm>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <map>
#include <memory>
#include <string>
#include <vector>
using GLuint = unsigned;
using GLint = int;
constexpr int GL_TRUE = 1, GL_LINK_STATUS = 1, GL_INTERLEAVED_ATTRIBS = 2;
#define ANDROID_ENABLED 1
#define ERR_FAIL_COND_V(c, v) do { if (c) return v; } while (false)
#define ERR_FAIL_COND_V_MSG(c, v, ...) ERR_FAIL_COND_V(c, v)
#define ERR_FAIL_COND(c) do { if (c) std::abort(); } while (false)
static int warnings = 0;
#define WARN_PRINT_ONCE(...) (++warnings)
static void require(bool condition, const char *message) {
    if (!condition) { std::fprintf(stderr, "%s\n", message); std::exit(1); }
}
template<class T> struct Vector : std::vector<T> {
    using std::vector<T>::vector;
    bool is_empty() const { return this->empty(); }
    int size() const { return int(std::vector<T>::size()); }
    T *ptrw() { return this->data(); }
    const T *ptr() const { return this->data(); }
};
template<class T> using LocalVector = Vector<T>;
template<class K, class V> struct KeyValue { K key; V value; };
template<class K, class V> struct AHashMap : Vector<KeyValue<K,V>> {
    void insert(K key, const V &value) {
        for (auto &entry : *this) if (entry.key == key) { entry.value = value; return; }
        this->push_back({key, value});
    }
};
struct String {
    std::string value;
    String(const char *s) : value(s) {}
    String(std::string s) : value(std::move(s)) {}
    String path_join(const String &s) const { return value + "/" + s.value; }
    friend String operator+(const String &s, const char *tail) { return s.value + tail; }
    friend bool operator!=(const char *s, const String &other) { return s != other.value; }
};
template<class T> struct Ref {
    std::shared_ptr<T> value;
    Ref(T *p = nullptr) : value(p) {}
    bool is_null() const { return !value; }
    T *operator->() const { return value.get(); }
};
static std::vector<uint8_t> cache;
static bool file_exists = true;
struct FileAccess {
    enum { READ };
    size_t cursor = 0;
    static Ref<FileAccess> open(const String &, int) { return file_exists ? new FileAccess : nullptr; }
    uint32_t get_buffer(uint8_t *out, uint32_t size) {
        auto n = std::min<size_t>(size, cache.size() - cursor);
        if (n) std::memcpy(out, cache.data() + cursor, n);
        cursor += n;
        return uint32_t(n);
    }
    uint32_t get_32() { uint32_t n = 0; for (int i=0;i<4;++i) { uint8_t b=0; get_buffer(&b,1); n |= uint32_t(b) << (8*i); } return n; }
    uint64_t get_64() { uint64_t low=get_32(); return low | (uint64_t(get_32()) << 32); }
};
static GLuint next_program = 1;
static int creates = 0, deletes = 0, fail_create = -1, feedback_calls = 0;
static std::map<GLuint, bool> live;
static GLuint glCreateProgram() {
    if (++creates == fail_create) return 0;
    live[next_program] = false;
    return next_program++;
}
static void glDeleteProgram(GLuint program) {
    require(program != 0 && live.erase(program) == 1, "Invalid or duplicate program deletion");
    ++deletes;
}
static void glDeleteShader(GLuint shader) { require(shader == 0, "Binary cache unexpectedly owns shader objects"); }
static void glTransformFeedbackVaryings(GLuint, int n, const char *const *, int) {
    require(n > 0, "Empty transform feedback binding"); ++feedback_calls;
}
static void glProgramBinary(GLuint id, uint32_t, const void *bytes, int size) {
    if (id) { require(live.count(id), "Missing program"); live[id] = size > 0 && *static_cast<const uint8_t *>(bytes) != 0; }
}
static void glGetProgramiv(GLuint id, int, GLint *status) { *status = id && live.at(id) ? GL_TRUE : 0; }
namespace GLES3 {
struct Config {
    bool disable_transform_feedback_shader_cache = false;
    static Config *get_singleton() { static Config c; return &c; }
};
}
static const char *shader_file_header = "GLSC";
static const uint32_t cache_file_version = 3;
struct ShaderGLES3 {
    struct Version {
        struct Specialization { GLuint id=0, vert_id=0, frag_id=0; bool ok=false; };
        LocalVector<AHashMap<uint64_t,Specialization>> variants;
    };
    struct Feedback { uint64_t specialization; const char *name; };
    int variant_count=2, feedback_count=0, source_compiles=0, saves=0;
    uint64_t specialization_default_mask=0;
    bool shader_cache_dir_valid=true;
    Feedback feedbacks[2]={{0,"position"},{1,"normal"}};
    String shader_cache_dir{"cache"},name{"Scene"},base_sha256{"base"};
    String _version_get_sha1(Version *) { return "version"; }
    void _get_uniform_locations(Version::Specialization &, Version *) {}
    void _compile_specialization(Version::Specialization &s, int, Version *, uint64_t) {
        s.id=glCreateProgram(); s.ok=true; live[s.id]=true; ++source_compiles;
    }
    void _save_to_cache(Version *) { ++saves; }
    bool _load_from_cache(Version *);
    void _clear_version(Version *);
    void _initialize_version(Version *);
};
// @PRODUCTION_METHODS@
static void u32(uint32_t n) { for (int i=0;i<4;++i) cache.push_back(uint8_t(n >> (8*i))); }
static void u64(uint64_t n) { u32(uint32_t(n)); u32(uint32_t(n >> 32)); }
static void reset() {
    require(live.empty(), "program(s) still live after cache failure/teardown");
    cache={'G','L','S','C'}; u32(3); u32(2);
    creates=deletes=feedback_calls=warnings=0; fail_create=-1; file_exists=true;
}
// Each integer is one specialization: 1 links, 0 fails, -1 truncates, -2 is empty.
static void cache_fixture(std::initializer_list<int> a, std::initializer_list<int> b) {
    reset();
    for (auto entries : {a,b}) {
        u32(uint32_t(entries.size())); uint64_t key=0;
        for (int result : entries) {
            u64(++key); u32(result == -2 ? 0 : result == -1 ? 4 : 1);
            if (result == -2) continue;
            u32(123); cache.push_back(result == 0 ? 0 : 1);
        }
    }
}
static int cases=0;
static void expect_failure(ShaderGLES3 &shader) {
    ShaderGLES3::Version version;
    require(!shader._load_from_cache(&version), "Invalid cache was accepted");
    require(version.variants.is_empty(), "Partial cache committed to live version");
    require(live.empty(), "program(s) still live after cache failure/teardown");
    require(deletes == creates - (fail_create > 0 ? 1 : 0), "Not every created program was deleted exactly once");
    ++cases;
}
int main() {
    { ShaderGLES3 s; cache_fixture({0},{}); expect_failure(s); require(warnings==1,"Missing source-fallback warning"); }
    { ShaderGLES3 s; cache_fixture({1,0},{}); expect_failure(s); }
    { ShaderGLES3 s; cache_fixture({1,1},{1,0}); expect_failure(s); }
    { ShaderGLES3 s; cache_fixture({1,1},{1,-1}); expect_failure(s); }
    { ShaderGLES3 s; s.feedback_count=2; cache_fixture({1},{0}); expect_failure(s); require(feedback_calls==2,"Feedback path not exercised"); }
    { ShaderGLES3 s; cache_fixture({1},{1}); fail_create=2; expect_failure(s); }
    { ShaderGLES3 s; reset(); file_exists=false; expect_failure(s); }
    { ShaderGLES3 s; reset(); cache[0]='X'; expect_failure(s); }
    { ShaderGLES3 s; reset(); cache[4]=99; expect_failure(s); }
    { ShaderGLES3 s; reset(); cache[8]=99; expect_failure(s); }
    { ShaderGLES3 s; cache_fixture({1,1},{1,1}); ShaderGLES3::Version v;
      require(s._load_from_cache(&v),"Valid cache rejected"); require(live.size()==4 && deletes==0,"Successful programs released too early");
      s._clear_version(&v); require(live.empty() && deletes==4,"Version teardown leaked or double-freed"); ++cases; }
    { ShaderGLES3 s; cache_fixture({-2},{1}); ShaderGLES3::Version v;
      require(s._load_from_cache(&v) && creates==1,"Empty cache entry created a program"); s._clear_version(&v); ++cases; }
    { ShaderGLES3 s; cache_fixture({1},{1,0}); ShaderGLES3::Version v;
      s._initialize_version(&v);
      require(s.source_compiles==2 && s.saves==1,"Source fallback/cache saving changed");
      require(live.size()==2 && deletes==3,"Failed cache programs survived source fallback");
      s._clear_version(&v); require(live.empty(),"Fallback programs leaked"); ++cases; }
    for (int i=0;i<500;++i) { ShaderGLES3 s; cache_fixture({1,1},{1,0}); expect_failure(s); }
    std::printf("PASS: %d cache ownership cases; successful transfer, source fallback and repeated failures verified\n",cases);
}
