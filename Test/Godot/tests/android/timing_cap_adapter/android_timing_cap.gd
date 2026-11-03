extends "res://main.gd"

func _init() -> void:
    var file := FileAccess.open("res://dora-output-path.txt", FileAccess.READ)
    if file == null:
        push_error("TIMING_CAP Android output configuration missing")
        return
    var directory := file.get_as_text()
    file.close()
    if not directory.is_absolute_path():
        push_error("TIMING_CAP Android output configuration is not absolute")
        return
    OS.set_environment("DORA_TIMING_CAP_OUTPUT", directory)
    OS.set_environment("DORA_TIMING_CAP_HOST_CAPTURE", "0")
