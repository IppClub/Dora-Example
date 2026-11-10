#include "Source/Godot/GodotRuntimeServices.h"
#include <cassert>
#include <cstring>
static int mode=0;
static std::string storage;
static const char *invoke(const DoraGodotConfig *,const char *,const char *) {storage="{\"success\":true}";return mode==4?nullptr:storage.c_str();}
static int checks(uint32_t version,DoraGodotCheckAPI *api) {
    assert(version==DORA_GODOT_CHECK_ABI_VERSION);
    *api={sizeof(*api),mode==2?99u:version,mode==3?nullptr:invoke};if(mode==5)api->size=0;return mode!=1;
}
static int imports(uint32_t version,DoraGodotImportAPI *api) {
    assert(version==DORA_GODOT_IMPORT_ABI_VERSION);
    *api={sizeof(*api),mode==2?99u:version,mode==3?nullptr:invoke};if(mode==5)api->size=0;return mode!=1;
}
int main() {
    DoraGodotConfig config{};
    for(bool importing:{false,true}) {
        auto resolve=[](const char *name)->void * {
            if(mode==6)return nullptr;
            if(std::strcmp(name,"dora_godot_get_check_api")==0)return reinterpret_cast<void *>(checks);
            assert(std::strcmp(name,"dora_godot_get_import_api")==0);return reinterpret_cast<void *>(imports);
        };
        for(mode=1;mode<=6;++mode)assert(!GodotRuntimeServices::call(importing,config,"file","source",resolve).first);
        mode=0;auto result=GodotRuntimeServices::call(importing,config,"file","source",resolve);assert(result.first);
        storage="invalidated by next runtime call";assert(result.second=="{\"success\":true}");
    }
}
