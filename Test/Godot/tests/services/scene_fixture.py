"""Authored scene fixtures; dependency scripts are traps and must never execute."""
import pathlib,json
SCENE='''[gd_scene load_steps=6 format=3]

[ext_resource type="Script" path="res://danger.gd" id="1_script"]
[ext_resource type="PackedScene" path="res://child.tscn" id="2_child"]
[ext_resource type="Texture2D" path="res://missing.png" id="3_image"]
[ext_resource type="Script" path="res://custom_resource.gd" id="4_custom"]

[sub_resource type="Resource" id="R_custom"]
script = ExtResource("4_custom")
data = {&"key": Vector2(2, 3), "textures": Array[Texture2D]([ExtResource("3_image")])}

[node name="Root" type="Node2D"]
script = ExtResource("1_script")
custom = SubResource("R_custom")
position = Vector2(10, 20)
node_path = NodePath("Player")
custom_array = Array[ExtResource("4_custom")]([SubResource("R_custom")])
lookup = Dictionary[String, int]({"hp": 3})
text = "中文场景"

[node name="Player" type="CharacterBody2D" parent="." groups=["actors"]]
position = Vector2(3, 4)

[node name="Child" parent="." instance=ExtResource("2_child")]

[connection signal="ready" from="Player" to="." method="on_ready" flags=3 binds=[5]]
'''
def make_fixture(project):
 project=pathlib.Path(project);project.mkdir(parents=True,exist_ok=True)
 (project/'project.godot').write_text('config_version=5\n[application]\nrun/main_scene="res://main.tscn"\n[autoload]\nTrap="*res://autoload.gd"\n')
 (project/'main.tscn').write_text(SCENE)
 (project/'child.tscn').write_text('[gd_scene format=3]\n[node name="Child" type="Node"]\n')
 (project/'danger.gd').write_text(f'extends Node2D\nstatic func _static_init():\n\tFileAccess.open({json.dumps(str(project/"SCRIPT_EXECUTED"))}, FileAccess.WRITE).store_string("bad")\n')
 (project/'custom_resource.gd').write_text(f'@tool\nextends Resource\nfunc _init():\n\tFileAccess.open({json.dumps(str(project/"RESOURCE_EXECUTED"))}, FileAccess.WRITE).store_string("bad")\n')
 (project/'autoload.gd').write_text(f'extends Node\nfunc _ready():\n\tFileAccess.open({json.dumps(str(project/"AUTOLOAD_EXECUTED"))}, FileAccess.WRITE).store_string("bad")\n')
 (project/'inherited.tscn').write_text('[gd_scene format=3]\n[ext_resource type="PackedScene" path="res://child.tscn" id="1"]\n[node name="Inherited" instance=ExtResource("1")]\n')
 (project/'relative.tscn').write_text('[gd_scene format=3]\n[ext_resource type="PackedScene" path="child.tscn" id="child"]\n[node name="Root" instance=ExtResource("child")]\n')
 (project/'inline.tscn').write_text('[gd_scene format=3]\n[node name="Root" type="Node"]\nresource = Resource("uid://static_only", "res://custom_resource.gd")\n')
 (project/'large.tscn').write_text('[gd_scene format=3]\n[node name="Root" type="Node"]\n'+''.join(f'[node name="Child{i}" type="Node" parent="."]\n' for i in range(200)))
 (project/'bad.tscn').write_text('[gd_scene format=3]\n[node name="Broken" type="Node"]\nposition = Vector2(1,\n')
 (project/'object.tscn').write_text('[gd_scene format=3]\n[node name="Root" type="Node"]\nvalue = Object(Resource,"script": Resource("res://custom_resource.gd"))\n')
 (project/'deep.tscn').write_text('[gd_scene format=3]\n[node name="Root" type="Node"]\nvalue = '+'['*70+'0'+']'*70+'\n')
 (project/'first-child.tscn').write_text('[gd_scene format=3]\n[node name="Orphan" parent="." type="Node"]\n')
 (project/'huge.tscn').write_text(';'+'x'*(2*1024*1024))
 (project/'unreadable.tscn').write_text('[gd_scene format=3]\n[node name="Hidden" type="Node"]\n')
 (project/'binary.scn').write_bytes(b'RSRC')
 (project/'escape.tscn').symlink_to('/etc/hosts')
 running=project/'running';running.mkdir()
 (running/'project.godot').write_text('config_version=5\n[application]\nrun/main_scene="res://main.tscn"\n')
 (running/'main.tscn').write_text('[gd_scene format=3]\n[node name="Main" type="Node"]\n')
