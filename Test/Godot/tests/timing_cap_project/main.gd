extends Control
var frames := 0
var physics_frames := 0
var script_clock := 0.0
var raw_clock := 0.0
var previous_ticks := 0
var captures := {}
var panel: ColorRect
var output: String
var waiting_capture := ""

func _ready() -> void:
    output = OS.get_environment("DORA_TIMING_CAP_OUTPUT")
    assert(not output.is_empty())
    assert(Engine.max_physics_steps_per_frame == 1)
    panel = ColorRect.new()
    panel.position = Vector2(128, 64)
    panel.size = Vector2(384, 64)
    var shader := Shader.new()
    shader.code = """
shader_type canvas_item;
render_mode unshaded;
uniform highp float script_clock = 0.0;
void fragment() {
    highp float t = UV.y < 0.5 ? TIME : script_clock;
    highp uint code = uint(floor(t * 64.0)) & 65535u;
    highp uint bit = uint(floor(UV.x * 16.0));
    float value = float((code >> bit) & 1u);
    COLOR = vec4(vec3(value), 1.0);
}
"""
    var material := ShaderMaterial.new()
    material.shader = shader
    panel.material = material
    add_child(panel)
    print("TIMING_CAP ready max_steps=1 delay_ms=80")

func _physics_process(_delta: float) -> void:
    if Engine.time_scale > 0.0:
        physics_frames += 1

func _process(delta: float) -> void:
    var ticks := Time.get_ticks_usec()
    if previous_ticks != 0:
        raw_clock += (ticks - previous_ticks) / 1000000.0 * Engine.time_scale
    previous_ticks = ticks
    if not waiting_capture.is_empty():
        if not FileAccess.file_exists(output.path_join(waiting_capture + ".ack")):
            return
        waiting_capture = ""
        Engine.time_scale = 1.0
    if frames >= 24:
        return
    frames += 1
    script_clock += delta
    panel.material.set_shader_parameter("script_clock", script_clock)
    OS.delay_msec(80)
    if frames == 8 or frames == 24:
        await RenderingServer.frame_post_draw
        var name := "clock-a" if frames == 8 else "clock-b"
        var metadata := {"frames": frames, "physics_frames": physics_frames, "script_clock": script_clock, "raw_clock": raw_clock}
        if OS.get_environment("DORA_TIMING_CAP_HOST_CAPTURE") == "1":
            # The imported render target is owned by the host. Observe its
            # displayed texture through the host capture API, then resume.
            Engine.time_scale = 0.0
            waiting_capture = name
            var marker := FileAccess.open(output.path_join(name + ".ready"), FileAccess.WRITE)
            marker.store_string(JSON.stringify(metadata))
            marker.close()
        else:
            var image := get_viewport().get_texture().get_image()
            if image == null or image.is_empty():
                push_error("TIMING_CAP empty viewport image")
                return
            var saved := image.save_png(output.path_join(name + ".png"))
            if saved != OK:
                push_error("TIMING_CAP image save failed: " + str(saved))
                return
            metadata["width"] = image.get_width()
            metadata["height"] = image.get_height()
        captures[name] = metadata
        if frames == 24:
            var file := FileAccess.open(output.path_join("result.json"), FileAccess.WRITE)
            assert(file != null)
            file.store_string(JSON.stringify(captures))
            file.close()
            print("TIMING_CAP complete captures=2 frames=24")
            if OS.get_environment("DORA_TIMING_CAP_STANDALONE") == "1":
                get_tree().quit()
