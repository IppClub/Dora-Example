#!/usr/bin/env python3
"""macOS Metal: exercise the bundled Godot compiler C ABI without an editor executable."""
import argparse
import hashlib
from pathlib import Path
import shutil
import subprocess
import sys
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'support'))
from godot_paths import ENGINE_ROOT

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--library', type=Path, required=True)
parser.add_argument('--output', type=Path, required=True)
a = parser.parse_args()
assert sys.platform == 'darwin', 'This probe exercises the macOS Metal compiler bridge'
a.output.mkdir(parents=True, exist_ok=False)
project = a.output / 'project'
project.mkdir()
sources = {
    'project.godot': 'config_version=5\n[application]\nconfig/name="Compiler probe"\nrun/main_scene="res://main.tscn"\n[rendering]\nrenderer/rendering_method="mobile"\n[shader_globals]\nprobe_tint={"type":"color","value":Color(1,1,1,1)}\n[autoload]\nCheckAutoload="*res://autoload.gd"\n',
    'main.gd': 'extends CheckBase\nvar cached_include: ShaderInclude\nfunc _ready() -> void:\n\tcached_include = load("res://common.gdshaderinc")\n\tvar file = FileAccess.open("res://scene-ran.txt", FileAccess.WRITE)\n\tfile.store_string("game started")\n',
    'main.tscn': '[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://main.gd" id="1"]\n[node name="Main" type="Node2D"]\nscript = ExtResource("1")\n',
    'common.gdshaderinc': '#include \"nested.gdshaderinc\"\nvec4 tint(vec4 value) { return value * SCALE; }\n',
    'nested.gdshaderinc': 'const float SCALE = 0.5;\n',
    'cycle-a.gdshaderinc': '#include \"cycle-b.gdshaderinc\"\n',
    'cycle-b.gdshaderinc': '#include \"cycle-a.gdshaderinc\"\n',
    'broken.gdshaderinc': 'vec4 broken() {\n\treturn vec3(1.0);\n}\n',
    'effect.gdshader': 'shader_type canvas_item;\n#include \"common.gdshaderinc\"\nvoid fragment() {\n\tCOLOR = tint(COLOR);\n}\n',
    'base.gd': 'class_name CheckBase\nextends Node2D\n',
    'checker-class.gd': 'extends CheckBase\n',
    'autoload.gd': 'extends Node\nfunc _init() -> void:\n\tvar file = FileAccess.open("res://autoload-ran.txt", FileAccess.WRITE)\n\tfile.store_string("autoload started")\n',
}
for name, text in sources.items():
    (project / name).write_text(text)
original = {name: hashlib.sha256((project / name).read_bytes()).hexdigest() for name in sources}
library = a.output / 'libdora_godot.dylib'
shutil.copy2(a.library, library)
probe = a.output / 'probe'
subprocess.run(['xcrun', 'clang++', '-std=c++17', '-I', str(ENGINE_ROOT / 'Source'), '-framework', 'Cocoa', '-framework', 'Metal', str(Path(__file__).with_name('embedded_code_check_probe.mm')), '-o', str(probe)], check=True)
result = subprocess.run([str(probe.resolve()), str(library.resolve()), str(project.resolve())], text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=60)
(a.output / 'probe.log').write_text(result.stdout)
assert result.returncode == 0, result.stdout[-8000:]
for name in sources:
    assert hashlib.sha256((project / name).read_bytes()).hexdigest() == original[name], name
assert {f.name for f in project.iterdir()} == set(sources) | {'scene-ran.txt', 'autoload-ran.txt'}
print('PASS: bundled runtime ABI checks syntax/types, project metadata, GDScript global classes and unsaved scenes, shaders/includes and include diagnostics; checks do not execute scenes/Autoloads or mutate source/cwd; gameplay can start and reopen afterwards')
