// Real embedded static scene queries: no editor, ResourceLoader or script execution.
#include "GodotBridgeScene.h"
#include "GodotBridgeProject.h"
#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#include <dlfcn.h>
#include <filesystem>
#include <iostream>
#include <cassert>
static NSDictionary *decode(const char *text) {
    assert(text);NSData *data=[[NSString stringWithUTF8String:text] dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *value=[NSJSONSerialization JSONObjectWithData:data options:0 error:nil];assert(value);return value;
}
int main(int argc,char **argv) { @autoreleasepool {
    assert(argc==3);void *library=dlopen(argv[1],RTLD_NOW|RTLD_LOCAL);assert(library);
    auto getter=(DoraGodotGetSceneAPI)dlsym(library,"dora_godot_get_scene_api");
    DoraGodotSceneAPI scenes{};scenes.size=sizeof(scenes);assert(getter&&getter(1,&scenes));assert(!getter(99,&scenes));
    DoraGodotSceneAPI small{};assert(!getter(1,&small));
    const std::string project=std::filesystem::canonical(argv[2]).string();const auto cwd=std::filesystem::current_path();
    id<MTLDevice> device=MTLCreateSystemDefaultDevice();assert(device);
    DoraGodotConfig config{sizeof(config),DORA_GODOT_METAL,32,32,2,project.c_str(),"",(__bridge void*)device};
    auto query=[&](const char *file,const char *options,bool success) {
        auto value=decode(scenes.inspect(&config,(project+"/"+file).c_str(),options));
        std::cout<<[[NSString alloc] initWithData:[NSJSONSerialization dataWithJSONObject:value options:0 error:nil] encoding:NSUTF8StringEncoding].UTF8String<<std::endl;
        assert([value[@"success"] boolValue]==success);assert(std::filesystem::current_path()==cwd);return value;
    };
    auto main=query("main.tscn","{}",true);
    assert([main[@"nodeCount"] intValue]==3&&[main[@"resourceCount"] intValue]==4&&[main[@"subresourceCount"] intValue]==1);
    assert([main[@"connectionCount"] intValue]==1&&! [main[@"truncated"] boolValue]);
    NSArray *nodes=main[@"nodes"];
    assert([nodes[0][@"path"] isEqual:@"."]&&[nodes[1][@"path"] isEqual:@"Player"]);
    assert([nodes[0][@"script"][@"path"] isEqual:@"res://danger.gd"]);
    assert([nodes[2][@"instance"][@"path"] isEqual:@"res://child.tscn"]);
    auto filtered=query("main.tscn","{\"nodePath\":\"Player\"}",true);assert([filtered[@"nodes"] count]==1&&[filtered[@"matchedNodeCount"] intValue]==1);
    auto limited=query("main.tscn","{\"maxNodes\":1,\"maxProperties\":1}",true);assert([limited[@"truncated"] boolValue]&&[limited[@"nodes"] count]==1);
    auto inherited=query("inherited.tscn","{}",true);assert([inherited[@"nodes"][0][@"type"] isEqual:NSNull.null]);
    auto relative=query("relative.tscn","{}",true);assert([relative[@"resources"][0][@"exists"] boolValue]);
    query("large.tscn","{}",true);query("inline.tscn","{}",true);
    for(const auto file:{"bad.tscn","object.tscn","deep.tscn","first-child.tscn","escape.tscn","huge.tscn","binary.scn"})query(file,"{}",false);
    query("main.tscn","{\"maxNodes\":0}",false);query("main.tscn","{\"nodePath\":\"missing\"}",false);
    assert(!std::filesystem::exists(project+"/.godot"));
    assert(!std::filesystem::exists(project+"/SCRIPT_EXECUTED"));assert(!std::filesystem::exists(project+"/RESOURCE_EXECUTED"));assert(!std::filesystem::exists(project+"/AUTOLOAD_EXECUTED"));
    DoraGodotAPI api{};api.size=sizeof(api);assert(((DoraGodotGetAPI)dlsym(library,"dora_godot_get_api"))(1,&api));
    DoraGodotProjectAPI lifecycle{};lifecycle.size=sizeof(lifecycle);assert(((DoraGodotGetProjectAPI)dlsym(library,"dora_godot_get_project_api"))(1,&lifecycle));
    const auto running=project+"/running";DoraGodotConfig play=config;play.project_path=running.c_str();
    void *handle=api.open(&play);if(!handle){std::cerr<<api.last_error(nullptr)<<std::endl;return 1;}
    assert(lifecycle.get_state()==DORA_GODOT_PROJECT_ACTIVE);
    query("main.tscn","{}",true);assert(lifecycle.get_state()==DORA_GODOT_PROJECT_ACTIVE);
    const std::string previous_error=api.last_error(handle);
    std::filesystem::permissions(project+"/unreadable.tscn",std::filesystem::perms::none);
    query("unreadable.tscn","{}",false);
    std::filesystem::permissions(project+"/unreadable.tscn",std::filesystem::perms::owner_read|std::filesystem::perms::owner_write);
    assert(std::string(api.last_error(handle))==previous_error);
    api.close(handle,nullptr);assert(lifecycle.get_state()==DORA_GODOT_PROJECT_UNLOADED);
    query("main.tscn","{}",true);api.shutdown();
    std::cout<<"EMBEDDED_SCENE_QUERY_PASS"<<std::endl;return 0;
}}
