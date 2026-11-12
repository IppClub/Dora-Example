"""Exercise production Godot log queue and Dora forwarding without GPU dependencies."""
import os
from pathlib import Path
import subprocess
import sys
import tempfile
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'support'))
from godot_paths import ENGINE_ROOT
error_stub = r'''
#pragma once
#include <algorithm>
#include <vector>
enum ErrorHandlerType { ERR_HANDLER_ERROR, ERR_HANDLER_WARNING, ERR_HANDLER_SCRIPT, ERR_HANDLER_SHADER };
using ErrorHandlerFunc=void(*)(void*,const char*,const char*,int,const char*,const char*,bool,ErrorHandlerType);
struct ErrorHandlerList { ErrorHandlerFunc errfunc; void *userdata; ErrorHandlerList *next; };
inline std::vector<ErrorHandlerList *> errors;
inline void add_error_handler(ErrorHandlerList *p){errors.push_back(p);}
inline void remove_error_handler(const ErrorHandlerList *p){errors.erase(std::remove(errors.begin(),errors.end(),p),errors.end());}
'''
print_stub = r'''
#pragma once
#include <string>
struct String { std::string value; struct UTF8 {std::string value; const char *get_data()const{return value.c_str();}}; UTF8 utf8()const{return {value};} };
using PrintHandlerFunc=void(*)(void*,const String&,bool,bool);
struct PrintHandlerList { PrintHandlerFunc printfunc; void *userdata; PrintHandlerList *next; };
inline std::vector<PrintHandlerList *> prints;
inline void add_print_handler(PrintHandlerList *p){prints.push_back(p);}
inline void remove_print_handler(const PrintHandlerList *p){prints.erase(std::remove(prints.begin(),prints.end(),p),prints.end());}
'''
debug_stub = r'''
#pragma once
#include <string>
#include <utility>
#include <vector>
inline std::vector<std::pair<int,std::string>> forwarded;
#define Warn(format,text) forwarded.emplace_back(1,text)
#define Error(format,text) forwarded.emplace_back(2,text)
'''
program = r'''
#include "runtime_log.h"
#include "GodotRuntimeLog.h"
#include <cassert>
#include <thread>
void emit(const char *file,int line,const char *message,ErrorHandlerType type=ERR_HANDLER_SCRIPT) {
 for(auto *p:errors)p->errfunc(p->userdata,"_ready",file,line,message,"",false,type);
}
void printerr(const std::string &text,bool error=true) {
 for(auto *p:prints)p->printfunc(p->userdata,String{text},error,false);
}
int main(){
 DoraGodotLogAPI api{};api.size=sizeof(api);
 assert(!dora_godot_get_log_api(99,&api));assert(!dora_godot_get_log_api(1,nullptr));
 api.size=0;assert(!dora_godot_get_log_api(1,&api));api.size=sizeof(api);
 assert(dora_godot_get_log_api(1,&api));
 Dora::GodotRuntimeLog host;host.connect(api);DoraGodotDiagnostics::begin();
 emit("res://游戏.gd",7,"bad call");emit("res://second.gd",8,"second error");
 emit("res://main.gd",9,"warning",ERR_HANDLER_WARNING);printerr("stderr 中文");printerr("normal print",false);
 auto first=std::string(DoraGodotDiagnostics::get());assert(first=="res://游戏.gd:7: bad call [_ready]");
 host.pump();assert(forwarded.size()==4);assert(forwarded[0].first==2 && forwarded[2].first==1);
 assert(forwarded[3].second=="stderr 中文");host.pump();assert(forwarded.size()==4);
 assert(host.failureText(first).empty());assert(host.failureText(first+"\nnative failure")=="native failure");
 assert(std::string(DoraGodotDiagnostics::get())==first);
 {
  DoraGodotDiagnostics::ScopedMetadataQuery scope;
  emit("query.tscn",1,"query failed");printerr("query stderr");
  std::thread worker([]{emit("res://worker.gd",10,"live worker");});worker.join();
 }
 host.pump();assert(forwarded.size()==5 && forwarded.back().second.find("live worker")!=std::string::npos);
 // Draining and producers can run concurrently without borrowing Godot objects.
 std::vector<std::thread> workers;
 for(int i=0;i<4;++i)workers.emplace_back([]{for(int n=0;n<10;++n)emit("thread.gd",n,"thread error");});
 for(auto &worker:workers) { worker.join(); }
 host.pump();assert(forwarded.size()==45);
 host.beginProject();assert(host.failureText(first)==first);
 // Overflow retains the oldest records and reports the exact dropped count.
 for(int i=0;i<140;++i)printerr("overflow "+std::to_string(i));
 host.pump();assert(forwarded.size()==174 && forwarded.back().first==1);
 assert(forwarded.back().second=="Godot log queue overflow: dropped 12 records");
 printerr(std::string(8191,'x')+"中文");uint32_t level=0;
 const char *bounded=api.pop(&level);assert(bounded && std::string(bounded).size()==8191 && level==2);
 assert(!api.pop(&level));assert(!api.pop(nullptr));
 DoraGodotDiagnostics::end();printerr("teardown error");host.disconnect();
 assert(forwarded.back().second=="teardown error" && errors.empty() && prints.empty());
 printerr("disabled");host.pump();assert(!api.pop(&level));
 // An older runtime without the extension still reports native failures.
 Dora::GodotRuntimeLog old;old.connect([](const char*)->void*{return nullptr;});
 assert(old.failureText("fallback")=="fallback");old.disconnect();
}
'''
with tempfile.TemporaryDirectory(prefix='dora-godot-log-test-') as temp:
    root=Path(temp)
    for name, text in [('core/error/error_macros.h',error_stub),('core/string/print_string.h',print_stub),('Common/Debug.h',debug_stub)]:
        target=root/name;target.parent.mkdir(parents=True,exist_ok=True);target.write_text(text)
    (root/'GodotRuntimeLog.h').write_text((ENGINE_ROOT/'Source/Godot/GodotRuntimeLog.h').read_text())
    (root/'test.cpp').write_text(program)
    subprocess.run([os.environ.get('CXX','c++'),'-std=c++17','-pthread','-Wall','-Wextra','-Werror',
        '-I'+str(root),'-I'+str(ENGINE_ROOT/'Source/3rdParty/Godot/modules/dora_bridge'),
        str(root/'test.cpp'),'-o',str(root/'test')],check=True)
    subprocess.run([str(root/'test')],check=True)
print('PASS: Godot errors/warnings/stderr, Dora forwarding, first-error preservation, metadata isolation, workers, UTF-8/queue bounds, deduplication, shutdown and legacy fallback')
