class_name SwitchMain
extends Node2D
const TAG := "A"
const TagResource = preload("res://tag.tres")
static var boots := 0
var frames := 0
func _ready() -> void:
	boots += 1
	assert(boots == 1, "Script static state survived")
	assert(TagResource.project_tag == TAG, "Resource cache belongs to another project")
	assert(SessionState.project_tag == TAG and SessionState.starts == 1, "Autoload state survived")
	assert(not Input.is_action_pressed("sticky_action"), "Pressed input survived")
	print("DORA_GODOT_PROJECT_SWITCH loaded=" + TAG + " static=" + str(boots) + " resource=" + TagResource.project_tag + " autoload=" + SessionState.project_tag)
	assert(Engine.time_scale == 1.0, "Engine time scale survived")
	assert(not Engine.has_singleton("SwitchUserState"), "User singleton survived")
	Engine.register_singleton("SwitchUserState", self)
	AudioServer.add_bus()
	AudioServer.set_bus_name(1, "LegacyBus")
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 48000
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_end = 4800
	var data := PackedByteArray()
	data.resize(9600)
	for i in range(4800):
		data.encode_s16(i * 2, int(sin(float(i) * TAU / 120.0) * 10000.0))
	wav.data = data
	var player := AudioStreamPlayer.new()
	player.stream = wav
	add_child(player)
	player.play()
	Engine.time_scale = 0.5
	queue_redraw()
func _process(_delta: float) -> void:
	frames += 1
	if frames == 2 and TAG == "A":
		Input.action_press("sticky_action")
	queue_redraw()
func _draw() -> void:
	draw_rect(Rect2(0, 0, 640, 360), Color(0.85, 0.1, 0.1, 1))
	draw_rect(Rect2(20 + frames % 240, 30, 60, 60), Color.WHITE)
func _exit_tree() -> void:
	print("DORA_GODOT_PROJECT_SWITCH unloaded=" + TAG + " frames=" + str(frames))
