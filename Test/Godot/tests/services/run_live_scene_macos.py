#!/usr/bin/env python3
"""Exercise read-only live snapshots against the embedded Metal runtime."""
import argparse,pathlib,subprocess,sys
sys.path.insert(0,str(pathlib.Path(__file__).resolve().parents[3]/'support'))
from godot_paths import ENGINE_ROOT
p=argparse.ArgumentParser(description=__doc__);p.add_argument('--runtime',type=pathlib.Path,required=True);p.add_argument('--output',type=pathlib.Path,required=True);a=p.parse_args()
out=a.output.resolve();assert not out.exists();out.mkdir(parents=True);project=out/'project';project.mkdir()
(project/'project.godot').write_text('config_version=5\n[application]\nrun/main_scene="res://main.tscn"\n[rendering]\nrenderer/rendering_method="mobile"\n')
(project/'main.tscn').write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://main.gd" id="1"]\n[node name="Main" type="Node2D"]\nposition=Vector2(10,20)\nscript=ExtResource("1")\n')
(project/'base.gd').write_text('extends Node2D\nvar inherited_hp := 7\n')
(project/'payload.gd').write_text('extends Node\n'+''.join('var payload'+str(i)+' := "\\\"\\n".repeat(512)\n' for i in range(32)))
(project/'main.gd').write_text('''extends "res://base.gd"
var hp := 3
var won := false
var getter_hits := 0
var large := "x".repeat(2000)
var danger: int:
	get:
		getter_hits += 1
		FileAccess.open("res://GETTER_EXECUTED",FileAccess.WRITE).store_string("bad")
		return 42
class Trap:
	extends RefCounted
	func _to_string():
		FileAccess.open("res://TO_STRING_EXECUTED",FileAccess.WRITE).store_string("bad")
		return "trap"
var bag := [Trap.new()]
func _get(_property):
	FileAccess.open("res://GET_EXECUTED",FileAccess.WRITE).store_string("bad")
	return null
func _get_property_list():
	FileAccess.open("res://PROPERTY_LIST_EXECUTED",FileAccess.WRITE).store_string("bad")
	return []
func _ready():
	var music := AudioStreamPlayer.new()
	music.name = "Music"
	var wave := AudioStreamWAV.new()
	wave.data = PackedByteArray([0,1,2,3,4,3,2,1])
	wave.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wave.loop_end = 8
	music.stream = wave
	add_child(music)
	music.play()
	var payloads := Node.new()
	payloads.name = "Payloads"
	add_child(payloads)
	for i in range(10):
		var child := Node.new()
		child.name = "Data" + str(i)
		child.set_script(load("res://payload.gd"))
		payloads.add_child(child)
	var oversized := Node.new()
	oversized.name = "Oversized"
	add_child(oversized)
	for i in range(4500):
		var child := Node.new()
		child.name = "Leaf" + str(i)
		oversized.add_child(child)
	for i in range(300):
		var child := Node.new()
		child.name = "Extra" + str(i)
		add_child(child)
''')
exe=out/'live-scene-test';subprocess.run(['clang++','-std=c++17','-fobjc-arc','-I'+str(ENGINE_ROOT/'Source'),str(pathlib.Path(__file__).with_name('live_scene_macos.mm')),'-framework','Foundation','-framework','Metal','-o',str(exe)],check=True)
with (out/'run.log').open('w') as log:subprocess.run([str(exe),str(a.runtime.resolve()),str(project)],stdout=log,stderr=subprocess.STDOUT,check=True,timeout=90)
assert 'LIVE_SCENE_QUERY_PASS' in (out/'run.log').read_text();print('PASS: embedded live scene snapshots')
