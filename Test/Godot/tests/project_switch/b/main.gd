class_name SwitchMain
extends Node2D
const TAG := "B"
const TagResource = preload("res://tag.tres")
static var boots := 0
var frames := 0
func _ready() -> void:
	boots += 1
	assert(boots == 1, "Script static state survived")
	assert(TagResource.project_tag == TAG, "Resource cache belongs to another project")
	assert(SessionState.project_tag == TAG and SessionState.starts == 1, "Autoload state survived")
	assert(not Input.is_action_pressed("sticky_action"), "Pressed input survived")
	assert(Engine.time_scale == 1.0, "Engine time scale survived")
	assert(not Engine.has_singleton("SwitchUserState"), "User singleton survived")
	assert(AudioServer.bus_count == 1, "Audio buses survived")
	assert(not ProjectSettings.has_setting("switch/old_only"), "A project setting survived")
	assert(not InputMap.has_action("only_a"), "A input action survived")
	assert(get_node_or_null("/root/LegacyState") == null, "A autoload survived")
	print("DORA_GODOT_PROJECT_SWITCH loaded=" + TAG + " static=" + str(boots) + " resource=" + TagResource.project_tag + " autoload=" + SessionState.project_tag)
	queue_redraw()
func _process(_delta: float) -> void:
	frames += 1
	if frames == 2 and TAG == "A":
		Input.action_press("sticky_action")
	queue_redraw()
func _draw() -> void:
	draw_rect(Rect2(0, 0, 640, 360), Color(0.1, 0.25, 0.9, 1))
	draw_rect(Rect2(20 + frames % 240, 30, 60, 60), Color.WHITE)
func _exit_tree() -> void:
	print("DORA_GODOT_PROJECT_SWITCH unloaded=" + TAG + " frames=" + str(frames))
