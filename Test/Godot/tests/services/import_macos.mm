// Real embedded service regression: no external editor and no game loop.
#include "GodotBridgeImport.h"
#include "GodotBridgeCheck.h"
#include "GodotBridgeProject.h"
#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#include <dlfcn.h>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <cassert>
static NSDictionary *decode(const char *text) {
    assert(text);NSData *data=[[NSString stringWithUTF8String:text] dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *value=[NSJSONSerialization JSONObjectWithData:data options:0 error:nil];assert(value);return value;
}
int main(int argc,char **argv) { @autoreleasepool {
    assert(argc==3);void *library=dlopen(argv[1],RTLD_NOW|RTLD_LOCAL);if(!library){std::cerr<<dlerror();return 1;}
    auto getImport=(DoraGodotGetImportAPI)dlsym(library,"dora_godot_get_import_api");
    auto getCheck=(DoraGodotGetCheckAPI)dlsym(library,"dora_godot_get_check_api");
    auto getProject=(DoraGodotGetProjectAPI)dlsym(library,"dora_godot_get_project_api");
    DoraGodotImportAPI imports{};imports.size=sizeof(imports);assert(getImport && getImport(1,&imports));
    DoraGodotCheckAPI checks{};checks.size=sizeof(checks);assert(getCheck && getCheck(1,&checks));
    DoraGodotProjectAPI lifecycle{};lifecycle.size=sizeof(lifecycle);assert(getProject && getProject(1,&lifecycle));
    DoraGodotImportAPI configured{};configured.size=sizeof(configured);assert(getImport(DORA_GODOT_IMPORT_ABI_VERSION,&configured)&&configured.abi_version==DORA_GODOT_IMPORT_ABI_VERSION);
    assert(!getImport(99,&imports));DoraGodotImportAPI small{};assert(!getImport(1,&small));
    const std::string project=std::filesystem::canonical(argv[2]).string();const auto cwd=std::filesystem::current_path();
    id<MTLDevice> device=MTLCreateSystemDefaultDevice();assert(device);
    DoraGodotConfig config{sizeof(config),DORA_GODOT_METAL,1,1,2,project.c_str(),"",(__bridge void*)device};
    auto run=[&](const std::string &name,const char *options,const char *expected) {
        auto value=decode(imports.import_asset(&config,(project+"/"+name).c_str(),options));
        std::cout<<[[NSString alloc] initWithData:[NSJSONSerialization dataWithJSONObject:value options:0 error:nil] encoding:NSUTF8StringEncoding].UTF8String<<std::endl;
        assert([value[@"status"] isEqualToString:@(expected)]);assert(lifecycle.get_state()==DORA_GODOT_PROJECT_UNLOADED);
        assert(std::filesystem::current_path()==cwd);return value;
    };
    for(const auto name:{"sprite.svg","sound.wav","tone.ogg","tone.mp3","font.ttf","triangle.gltf"}) run(name,"{}","imported");
    run("sprite.svg","{}","skipped");run("sprite.svg","{\"force\":true}","imported");
    {std::ofstream file(project+"/sprite.svg",std::ios::app);file<<"\n";}
    run("sprite.svg","{}","imported");
    auto cached=run("sprite.svg","{}","skipped");
    const auto cachePath=project+"/"+std::string([cached[@"output"] UTF8String]).substr(6);
    {std::ofstream file(cachePath);file<<"corrupt";}
    run("sprite.svg","{}","imported");
    run("triangle.gltf","{}","imported"); // Dependencies are always refreshed.
    for(const auto name:{"bad.png","unsupported.blend","escape.png","managed.svg","broken.svg","blocked.svg"}) run(name,"{}","failed");
    auto image=run("sprite.svg",R"({"settings":{"mipmaps":true}})","imported");
    assert([image[@"settings"][@"mipmaps"] boolValue]);
    auto same=run("sprite.svg","{}","skipped");assert([same[@"settings"][@"mipmaps"] boolValue]);
    auto forced=run("sprite.svg",R"({"force":true})","imported");assert([forced[@"settings"][@"mipmaps"] boolValue]);
    run("sprite.svg",R"({"settings":{"mipmaps":false}})","imported");
    run("sprite.svg",R"({"settings":{"mipmaps":true}})","imported");
    run("sound.wav",R"({"settings":{"loop":true}})","imported");
    run("sound.wav",R"({"settings":{"loop":false}})","imported");
    run("sound.wav",R"({"settings":{"loop":true}})","imported");
    for(const auto name:{"tone.ogg","tone.mp3"}) {
        auto changed=run(name,R"({"settings":{"loop":true,"loopOffsetSeconds":0.02}})","imported");
        assert([changed[@"settings"][@"loop"] boolValue]);
        run(name,R"({"settings":{"loopOffsetSeconds":0.03}})","imported");
        auto same=run(name,"{}","skipped");assert([same[@"settings"][@"loop"] boolValue]);
        run(name,R"({"settings":{"loopOffsetSeconds":0.02}})","imported");
        run(name,R"({"settings":{"loopOffsetSeconds":0.02,"loop":true}})","skipped");
    }
    auto preserved=[&](const char *name,const char *options) {
        auto cached=run(name,"{}","skipped");
        const auto dest=project+"/"+std::string([cached[@"output"] UTF8String]).substr(6);
        NSString *sidecar=@((project+"/"+name+".import").c_str()),*output=@(dest.c_str());
        NSData *before=[NSData dataWithContentsOfFile:sidecar],*resource=[NSData dataWithContentsOfFile:output];
        run(name,options,"failed");
        assert([before isEqual:[NSData dataWithContentsOfFile:sidecar]]);
        assert([resource isEqual:[NSData dataWithContentsOfFile:output]]);
    };
    preserved("sprite.svg",R"({"settings":{"filter":"nearest"}})");
    preserved("sprite.svg",R"({"settings":{"mipmaps":1}})");
    preserved("sprite.svg",R"({"settings":{"loop":true}})");
    preserved("sprite.svg",R"({"settings":[]})");
    preserved("sprite.svg",R"({"settings":{},"typo":true})");
    preserved("sound.wav",R"({"settings":{"loopOffsetSeconds":0.02}})");
    preserved("tone.ogg",R"({"settings":{"loopOffsetSeconds":2}})");
    preserved("tone.mp3",R"({"settings":{"loopOffsetSeconds":-1}})");
    preserved("tone.mp3",R"({"settings":{"loop":false,"loopOffsetSeconds":1e300}})");
    run("font.ttf",R"({"settings":{"mipmaps":true}})","failed");
    auto bad=decode(checks.check(&config,(project+"/bad.gd").c_str(),"extends Node\nfunc broken(:\n"));
    assert(![bad[@"success"] boolValue]);
    auto good=decode(checks.check(&config,(project+"/good.gd").c_str(),"extends Node\nfunc answer():\n\treturn 42\n"));
    assert([good[@"success"] boolValue]);
auto loaded=decode(checks.check(&config,(project+"/load.gd").c_str(),
    "extends Node\nconst T=preload(\"res://sprite.svg\")\nconst A=preload(\"res://sound.wav\")\nconst O=preload(\"res://tone.ogg\")\nconst M=preload(\"res://tone.mp3\")\nconst F=preload(\"res://font.ttf\")\nconst S=preload(\"res://triangle.gltf\")\n"));
assert([loaded[@"success"] boolValue]);
assert(!std::filesystem::exists(project+"/AUTOLOAD_EXECUTED"));

    assert(!std::filesystem::exists(project+"/TOOL_EXECUTED"));
DoraGodotAPI api{};api.size=sizeof(api);auto getter=(DoraGodotGetAPI)dlsym(library,"dora_godot_get_api");assert(getter(1,&api));
config.width=32;config.height=32;
void *handle=api.open(&config);
if(!handle) {std::cerr<<api.last_error(nullptr)<<std::endl;return 1;}
auto active=decode(imports.import_asset(&config,(project+"/sprite.svg").c_str(),"{}"));assert(![active[@"success"] boolValue]);
assert(std::filesystem::exists(project+"/AUTOLOAD_EXECUTED"));
api.close(handle,nullptr);assert(lifecycle.get_state()==DORA_GODOT_PROJECT_UNLOADED);
run("sprite.svg","{}","skipped");
    assert(std::filesystem::exists(project+"/IMPORT_SETTINGS_VERIFIED"));
    api.shutdown();
    std::cout<<"EMBEDDED_IMPORT_CHECK_PASS"<<std::endl;
    // Shutdown before C++ static destructors run; do not dlclose Godot/ObjC classes.
    return 0;
}}
