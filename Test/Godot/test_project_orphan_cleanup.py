#!/usr/bin/env python3
"""Execute the production orphan policy against deterministic object lifetimes.

This is a CPU policy regression, not Godot/GPU acceptance. Real project runs
exercise the concrete Node destructors separately.
"""
import os
from pathlib import Path
import subprocess
import sys
import tempfile

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'support'))
from godot_paths import ENGINE_ROOT

source = (ENGINE_ROOT / 'Source/3rdParty/Godot/modules/dora_bridge/runtime_project.h').read_text()
# Exercise the orphan policy without pulling in project startup and its engine dependencies.
policy = (
    source[source.index('inline std::set<uint64_t> preserved_nodes;'):source.index('inline bool start(')]
    + source[source.index('inline bool contains_preserved_node('):source.index('inline bool supported(')]
)
stub = r'''
#include <cassert>
#include <cstdint>
#include <functional>
#include <map>
#include <set>
#include <string>
#include <vector>
using ObjectID=uint64_t;
struct Object {
    static inline ObjectID next=1;
    static inline bool locked=false;
    static inline std::map<ObjectID,Object*> objects;
    ObjectID id=next++;
    Object(){objects[id]=this;}
    virtual ~Object(){assert(!locked);objects.erase(id);}
    ObjectID get_instance_id(){return id;}
    template<class T> static T *cast_to(Object *object){return dynamic_cast<T*>(object);}
};
struct Node: Object {
    Node *parent=nullptr;
    bool inside=false;
    bool cancel_free=false;
    std::vector<Node*> children;
    std::function<void()> on_delete;
    Node *get_parent(){return parent;}
    bool is_inside_tree(){return inside;}
    int get_child_count(bool){return int(children.size());}
    Node *get_child(int i,bool){return children.at(i);}
    void add(Node *child){children.push_back(child);child->parent=this;}
    ~Node(){
        if(on_delete)on_delete();
        while(!children.empty()){auto *child=children.back();children.pop_back();delete child;}
    }
};
struct ObjectDB {
    static void debug_objects(void(*callback)(Object*,void*),void *state){
        assert(!Object::locked);Object::locked=true;
        for(auto &entry:Object::objects)callback(entry.second,state);
        Object::locked=false;
    }
    static Object *get_instance(ObjectID id){
        assert(!Object::locked);auto it=Object::objects.find(id);
        return it==Object::objects.end()?nullptr:it->second;
    }
};
struct MessageQueue {
    static MessageQueue *get_singleton(){static MessageQueue queue;return &queue;}
    void flush(){assert(!Object::locked);}
};
template<class... Args> std::string vformat(const char *s,Args...){return s;}
void print_line(const std::string&){}
void checked_delete(Node *node){if(!node->cancel_free)delete node;}
#define memdelete(node) checked_delete(node)
'''
tests = r'''
int main(){
    using namespace DoraGodotProject;
    // The baseline survives, while a project-only root and its descendants go.
    auto *sentinel=new Node;auto sentinel_id=sentinel->id;
    begin_node_boundary();
    auto *root=new Node;auto *child=new Node;root->add(child);
    auto root_id=root->id,child_id=child->id;
    free_detached_project_nodes();
    assert(ObjectDB::get_instance(sentinel_id)==sentinel);
    assert(!ObjectDB::get_instance(root_id)&&!ObjectDB::get_instance(child_id));
    free_detached_project_nodes(); // repeated unload is harmless
    delete sentinel;

    // A new parent must not take a pre-existing descendant down with it.
    sentinel=new Node;sentinel_id=sentinel->id;
    begin_node_boundary();root=new Node;root->add(sentinel);root_id=root->id;
    free_detached_project_nodes();
    assert(ObjectDB::get_instance(root_id)&&ObjectDB::get_instance(sentinel_id));
    delete root;

    // Destructors can delete a later candidate. Revalidate its ObjectID.
    begin_node_boundary();root=new Node;child=new Node;
    auto later_id=child->id;
    root->on_delete=[later_id](){delete ObjectDB::get_instance(later_id);};
    free_detached_project_nodes();assert(Object::objects.empty());

    // Destructors can create another orphan, requiring a new scan.
    begin_node_boundary();root=new Node;ObjectID created=0;
    root->on_delete=[&created](){created=(new Node)->id;};
    free_detached_project_nodes();assert(created&&!ObjectDB::get_instance(created));

    // The drain is bounded even for a deliberately replenished orphan chain.
    int deleted=0;
    std::function<void()> replenish;
    replenish=[&](){++deleted;auto *node=new Node;node->on_delete=replenish;};
    begin_node_boundary();root=new Node;root->on_delete=replenish;
    free_detached_project_nodes();assert(deleted==8&&Object::objects.size()==1);
    root=static_cast<Node*>(Object::objects.begin()->second);root->on_delete={};delete root;

    // A node already in a live tree is never an orphan deletion candidate.
    begin_node_boundary();root=new Node;root->inside=true;root_id=root->id;
    free_detached_project_nodes();assert(ObjectDB::get_instance(root_id));delete root;

    // Cancellation is reported by remaining IDs; it must not count as progress.
    begin_node_boundary();root=new Node;root->cancel_free=true;root_id=root->id;
    free_detached_project_nodes();assert(ObjectDB::get_instance(root_id));delete root;
    assert(Object::objects.empty());
}
'''
with tempfile.TemporaryDirectory(prefix='dora-orphan-policy-') as temporary:
    path = Path(temporary)
    (path / 'policy.cpp').write_text(stub + '\nnamespace DoraGodotProject {\n' + policy + '\n}\n' + tests)
    subprocess.run([os.environ.get('CXX', 'c++'), '-std=c++17', '-Wall', '-Wextra', '-Werror',
                    str(path / 'policy.cpp'), '-o', str(path / 'policy')], check=True)
    subprocess.run([str(path / 'policy')], check=True)
print('PASS: production orphan policy; baseline/descendant preservation, revalidation, new orphans, bounded drain, live-tree exclusion, canceled deletion')
