"""CPU regression for the production project-scoped Godot error collector."""
import os
from pathlib import Path
import subprocess
import sys
import tempfile
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'support'))
from godot_paths import ENGINE_ROOT
source = (ENGINE_ROOT / 'Source/3rdParty/Godot/modules/dora_bridge/runtime_diagnostics.h').read_text()
source = source.replace('#pragma once', '').replace('#include "core/error/error_macros.h"', '')
stub = r'''
#include <cassert>
#include <thread>
#include <vector>
enum ErrorHandlerType { ERR_HANDLER_ERROR, ERR_HANDLER_WARNING, ERR_HANDLER_SCRIPT, ERR_HANDLER_SHADER };
using ErrorHandlerFunc=void(*)(void*,const char*,const char*,int,const char*,const char*,bool,ErrorHandlerType);
struct ErrorHandlerList { ErrorHandlerFunc errfunc; void *userdata; ErrorHandlerList *next; };
ErrorHandlerList *active=nullptr;
void add_error_handler(ErrorHandlerList *handler) { assert(!active); active=handler; }
void remove_error_handler(const ErrorHandlerList *handler) { assert(active==handler); active=nullptr; }
'''
tests = r'''
int main() {
 using namespace DoraGodotDiagnostics;
 begin(); assert(active && std::string(get()).empty());
 capture(nullptr,"_ready","res://main.gd",4,"warning","",false,ERR_HANDLER_WARNING);
 assert(std::string(get()).empty());
 capture(nullptr,"_process","res://main.gd",8,"invalid call","missing_method on null",false,ERR_HANDLER_SCRIPT);
 assert(std::string(get())=="res://main.gd:8: missing_method on null [_process]");
 capture(nullptr,"other","res://other.gd",9,"later error","",false,ERR_HANDLER_ERROR);
 assert(std::string(get()).find("main.gd:8")!=std::string::npos);
 begin(); assert(std::string(get()).empty());
 std::vector<std::thread> workers;
 for(int i=0;i<8;++i) workers.emplace_back([] { capture(nullptr,"worker","res://thread.gd",3,"thread error","",false,ERR_HANDLER_SCRIPT); });
 for(auto &worker:workers) worker.join();
 assert(std::string(get())=="res://thread.gd:3: thread error [worker]");
 begin(); std::string huge(20000,'x');
 capture(nullptr,nullptr,nullptr,0,huge.c_str(),nullptr,false,ERR_HANDLER_ERROR);
 assert(std::string(get()).size()==8192);
 end(); end(); assert(!active);
 begin(); assert(std::string(get()).empty()); end();
}
'''
with tempfile.TemporaryDirectory(prefix='dora-godot-diagnostics-') as temp:
    path=Path(temp); (path/'test.cpp').write_text(stub+source+tests)
    subprocess.run([os.environ.get('CXX','c++'),'-std=c++17','-pthread','-Wall','-Wextra','-Werror',str(path/'test.cpp'),'-o',str(path/'test')],check=True)
    subprocess.run([str(path/'test')],check=True)
print('PASS: Godot runtime diagnostics preserve file/line/first error, ignore warnings, bound storage, synchronize workers and reset per project')
