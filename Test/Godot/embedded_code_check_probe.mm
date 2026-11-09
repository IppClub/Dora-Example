#import <Cocoa/Cocoa.h>
#import <Metal/Metal.h>
#include "Godot/GodotBridgeCheck.h"
#include "Godot/GodotBridgeProject.h"
#include <dlfcn.h>
#include <cstdio>
#include <fstream>
#include <sstream>
#include <string>
#include <cassert>
#include <filesystem>
static std::string read(const char *path){std::ifstream f(path);std::ostringstream s;s<<f.rdbuf();return s.str();}
int main(int argc,char **argv){@autoreleasepool {
    assert(argc==3);[NSApplication sharedApplication];
    void *lib=dlopen(argv[1],RTLD_NOW|RTLD_LOCAL|RTLD_FIRST);if(!lib){puts(dlerror());return 1;}
    auto get=(DoraGodotGetCheckAPI)dlsym(lib,"dora_godot_get_check_api");assert(get);
    DoraGodotCheckAPI check{};check.size=sizeof(check);assert(get(1,&check));
    DoraGodotAPI api{};api.size=sizeof(api);assert(((DoraGodotGetAPI)dlsym(lib,"dora_godot_get_api"))(1,&api));
    id<MTLDevice> device=MTLCreateSystemDefaultDevice();assert(device);
    const std::string root=argv[2],gd=root+"/main.gd",scene=root+"/main.tscn";
    DoraGodotConfig config{sizeof(config),DORA_GODOT_METAL,32,32,2,root.c_str(),"",(__bridge void*)device};
    auto verify=[&](const std::string &file,const std::string &content,bool expected,int row){
        const auto working_directory=std::filesystem::current_path();
        const char *text=check.check(&config,file.c_str(),content.c_str());
        assert(std::filesystem::current_path()==working_directory);assert(text);puts(text);
        NSDictionary *result=[NSJSONSerialization JSONObjectWithData:[[NSString stringWithUTF8String:text] dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
        assert(result && [result[@"success"] boolValue]==expected);
        if(row) {NSArray *diagnostics=result[@"info"];assert(diagnostics.count>0);assert([diagnostics[0][2] intValue]==row);}
        return result;
    };
    verify(root+"/project.godot",read((root+"/project.godot").c_str()),true,0);
    verify(gd,"extends Node2D\nvar value: int = \"wrong\"\n",false,2);
    verify(gd,"extends Node2D\nfunc broken(\n",false,2);
    verify(gd,read(gd.c_str()),true,0);
    verify(root+"/checker-class.gd","extends CheckBase\n",true,0);
    verify(scene,"[gd_scene format=3]\n\n[node name=\"Bad\" type=]\n",false,3);
    verify(scene,read(scene.c_str()),true,0);
    verify(scene,"[gd_scene load_steps=2 format=3]\n[ext_resource type=\"Script\" path=\"res://absent.gd\" id=\"1\"]\n[node name=\"Main\" type=\"Node2D\"]\nscript=ExtResource(\"1\")\n",false,1);
    const std::string shader=root+"/effect.gdshader",include=root+"/common.gdshaderinc";
    verify(shader,read(shader.c_str()),true,0);
    verify(include,read(include.c_str()),true,0);
    verify(shader,"shader_type spatial;\nvoid fragment() { ALBEDO = vec3(1.0); }\n",true,0);
    verify(shader,"shader_type canvas_item;\nvoid fragment() { COLOR = vec3(1.0); }\n",false,2);
    verify(shader,"shader_type canvas_item;\nvoid fragment() { ALBEDO = vec3(1.0); }\n",false,2);
    verify(shader,"shader_type invalid;\n",false,1);
    verify(shader,"shader_type canvas_item;\n#include \"missing.gdshaderinc\"\n",false,2);
    verify(shader,"shader_type canvas_item;\nglobal uniform vec4 probe_tint;\nvoid fragment() { COLOR = probe_tint; }\n",true,0);
    verify(shader,"shader_type canvas_item;\nglobal uniform float probe_tint;\n",false,2);
    verify(include,"vec4 tint(vec4 value) {\n\treturn vec3(1.0);\n}\n",false,2);
    verify(include,"#error unsaved include error\n",false,1);
    verify(root+"/cycle-a.gdshaderinc",read((root+"/cycle-a.gdshaderinc").c_str()),false,1);
    verify(shader,"shader_type canvas_item;\nvoid fragment( {\n",false,2);
    auto nested=verify(shader,"shader_type canvas_item;\n#include \"broken.gdshaderinc\"\n",false,2);
    assert([nested[@"info"][0][1] isEqualToString:[NSString stringWithUTF8String:(root+"/broken.gdshaderinc").c_str()]]);
    // A dependency repaired on disk must be re-read by the next native check.
    {std::ofstream f(root+"/nested.gdshaderinc");f<<"#error changed dependency\n";}
    auto changed=verify(shader,read(shader.c_str()),false,1);
    assert([changed[@"info"][0][1] isEqualToString:[NSString stringWithUTF8String:(root+"/nested.gdshaderinc").c_str()]]);
    {std::ofstream f(root+"/nested.gdshaderinc");f<<"const float SCALE = 0.5;\n";}
    verify(shader,read(shader.c_str()),true,0);
    assert(![[NSFileManager defaultManager] fileExistsAtPath:[[NSString stringWithUTF8String:root.c_str()] stringByAppendingPathComponent:@"scene-ran.txt"]]);
    assert(![[NSFileManager defaultManager] fileExistsAtPath:[[NSString stringWithUTF8String:root.c_str()] stringByAppendingPathComponent:@"autoload-ran.txt"]]);
    verify(gd,"extends Node2D\nfunc _ready() -> void:\n\tCheckAutoload.get_node(\".\")\n",true,0);
    void *handle=api.open(&config);if(!handle){puts(api.last_error(nullptr));return 2;}
    assert([[NSFileManager defaultManager] fileExistsAtPath:[[NSString stringWithUTF8String:root.c_str()] stringByAppendingPathComponent:@"scene-ran.txt"]]);
    verify(gd,read(gd.c_str()),true,0); // active scene remains alive during checks
    verify(shader,read(shader.c_str()),true,0);
    {std::ofstream f(root+"/nested.gdshaderinc");f<<"#error changed while game caches include\n";}
    auto active_error=verify(shader,read(shader.c_str()),false,1);
    assert([active_error[@"info"][0][1] isEqualToString:[NSString stringWithUTF8String:(root+"/nested.gdshaderinc").c_str()]]);
    {std::ofstream f(root+"/nested.gdshaderinc");f<<"const float SCALE = 0.5;\n";}
    verify(shader,read(shader.c_str()),true,0);
    DoraGodotStats stats{};stats.size=sizeof(stats);api.close(handle,&stats);
    verify(gd,"extends Node2D\nfunc broken(\n",false,2); // idle compiler works after gameplay
    verify(scene,read(scene.c_str()),true,0);
    handle=api.open(&config);if(!handle){puts(api.last_error(nullptr));return 3;}api.close(handle,&stats);
    api.shutdown();
    puts("PASS: direct bundled runtime compiler, unsaved gd/tscn, dependencies, no scene execution during checks, active/idle checking and game reopen after validation");
}}
