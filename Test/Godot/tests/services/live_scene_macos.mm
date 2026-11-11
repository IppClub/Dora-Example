#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#include "Godot/GodotBridge.h"
#include "Godot/GodotBridgeRuntimeScene.h"
#include "Godot/GodotBridgeProject.h"
#include <cassert>
#include <dlfcn.h>
#include <filesystem>
#include <iostream>
static NSDictionary *decode(const char *text) {
    assert(text);auto data=[NSData dataWithBytes:text length:strlen(text)];
    NSDictionary *value=[NSJSONSerialization JSONObjectWithData:data options:0 error:nil];assert(value);return value;
}
int main(int argc,char **argv) {@autoreleasepool {
    assert(argc==3);void *lib=dlopen(argv[1],RTLD_NOW|RTLD_LOCAL);assert(lib);
    auto get=(DoraGodotGetRuntimeSceneAPI)dlsym(lib,"dora_godot_get_runtime_scene_api");assert(get);
    DoraGodotRuntimeSceneAPI live{};live.size=sizeof(live);assert(get(1,&live));assert(!get(99,&live));
    DoraGodotRuntimeSceneAPI small{};assert(!get(1,&small));
    DoraGodotAPI api{};api.size=sizeof(api);assert(((DoraGodotGetAPI)dlsym(lib,"dora_godot_get_api"))(1,&api));
    auto project=std::filesystem::canonical(argv[2]).string();
    id<MTLDevice> device=MTLCreateSystemDefaultDevice();assert(device);
    DoraGodotConfig config{sizeof(config),DORA_GODOT_METAL,32,32,2,project.c_str(),"",(__bridge void*)device};
    auto query=[&](const char *options,bool success=true) {
        auto cwd=std::filesystem::current_path();
        const char *text=live.inspect(&config,options);assert(text&&strlen(text)<=128*1024);
        auto value=decode(text);assert([value[@"success"] boolValue]==success);assert(cwd==std::filesystem::current_path());return value;
    };
    query("{}",false);void *handle=api.open(&config);if(!handle){std::cerr<<api.last_error(nullptr);return 2;}
    // Initialization may legitimately use script hooks; isolate query side effects.
    for(const auto marker:{"GETTER_EXECUTED","GET_EXECUTED","PROPERTY_LIST_EXECUTED","TO_STRING_EXECUTED"})std::filesystem::remove(project+"/"+marker);
    auto first=query("{\"nodePath\":\"Main\",\"maxNodes\":1,\"properties\":[\"position\",\"script:hp\",\"script:won\",\"script:getter_hits\",\"script:danger\",\"script:bag\",\"script:large\",\"script:inherited_hp\",\"danger\"]}");
    NSDictionary *values=first[@"nodes"][0][@"properties"];
    assert([values[@"position"][@"value"][0] intValue]==10&&[values[@"position"][@"value"][1] intValue]==20);
    assert([values[@"script:hp"][@"value"] intValue]==3&&! [values[@"script:won"][@"value"] boolValue]);
    assert([values[@"script:inherited_hp"][@"value"] intValue]==7);
    assert([values[@"script:getter_hits"][@"value"] intValue]==0);
    assert(values[@"script:danger"][@"unavailable"]&&values[@"script:bag"][@"unavailable"]&&values[@"danger"][@"unavailable"]);
    assert([values[@"script:large"][@"truncated"] boolValue]&&[values[@"script:large"][@"value"] length]==512);
    assert([first[@"truncated"] boolValue]);
    auto filtered=query("{\"nodeType\":\"AudioStreamPlayer\",\"maxNodes\":1,\"properties\":[\"playing\"]}");
    assert([filtered[@"nodes"] count]==1&&[filtered[@"nodes"][0][@"type"] isEqual:@"AudioStreamPlayer"]);
    auto none=query("{\"nodePath\":\"Main/Payloads\",\"nodeType\":\"CharacterBody3D\"}");assert([none[@"nodes"] count]==0&&! [none[@"truncated"] boolValue]);
    auto traversal=query("{\"nodePath\":\"Main/Oversized\",\"nodeType\":\"AudioStreamPlayer\"}");
    assert([traversal[@"nodes"] count]==0&&[traversal[@"truncated"] boolValue]&&[traversal[@"visitedNodeCount"] intValue]<=4096);
    auto audio=query("{\"nodePath\":\"Main/Music\",\"properties\":[\"playing\",\"stream_paused\",\"volume_db\"]}");
    assert([audio[@"nodes"][0][@"properties"][@"playing"][@"value"] boolValue]);
    auto bounded=query("{\"maxNodes\":2,\"properties\":[]}");assert([bounded[@"nodes"] count]==2&&[bounded[@"truncated"] boolValue]);
    auto overlong=std::string(8193,' ');query(overlong.c_str(),false);
    NSMutableArray *names=[NSMutableArray array];for(int i=0;i<32;++i)[names addObject:[NSString stringWithFormat:@"script:payload%d",i]];
    NSDictionary *byteOptions=@{@"nodePath":@"Main/Payloads",@"properties":names};
    auto byteJSON=[NSJSONSerialization dataWithJSONObject:byteOptions options:0 error:nil];
    auto byteResult=query([[NSString alloc] initWithData:byteJSON encoding:NSUTF8StringEncoding].UTF8String);
    assert([byteResult[@"truncated"] boolValue]&&[byteResult[@"nodes"] count]<11);
    [names addObject:@"script:extra"];
    auto tooMany=[NSJSONSerialization dataWithJSONObject:byteOptions options:0 error:nil];
    query([[NSString alloc] initWithData:tooMany encoding:NSUTF8StringEncoding].UTF8String,false);
    auto subtree=query("{\"nodePath\":\"Main/Music\",\"properties\":[]}");assert([subtree[@"nodes"] count]==1&&! [subtree[@"truncated"] boolValue]);
    for(const auto options:{"[]","{\"nodePath\":\"..\"}","{\"nodePath\":\"/root/Main\"}","{\"nodePath\":\"Main:hp\"}","{\"nodePath\":\"missing\"}","{\"properties\":[\"script:hp + 1\"]}","{\"maxNodes\":257}","{\"maxNodes\":0}","{\"maxNodes\":1.5}","{\"maxNodes\":true}","{\"unexpected\":true}","{\"nodeType\":\"Node+1\"}","{\"nodeType\":42}"})query(options,false);
    auto original=std::string(config.project_path);auto other=project+"/different";config.project_path=other.c_str();query("{}",false);config.project_path=original.c_str();
    for(int i=0;i<100;++i)query("{\"nodePath\":\"Main\",\"maxNodes\":1,\"properties\":[\"script:danger\",\"script:hp\"]}");
    assert(!std::filesystem::exists(project+"/GETTER_EXECUTED"));
    assert(!std::filesystem::exists(project+"/GET_EXECUTED"));
    assert(!std::filesystem::exists(project+"/TO_STRING_EXECUTED"));
    assert(!std::filesystem::exists(project+"/PROPERTY_LIST_EXECUTED"));
    api.close(handle,nullptr);query("{}",false);
    handle=api.open(&config);assert(handle);query("{}");api.close(handle,nullptr);api.shutdown();
    std::cout<<"LIVE_SCENE_QUERY_PASS: native state, backing fields, inherited storage, getter exclusion, input/output bounds, project identity, unload/reopen"<<std::endl;
}}
