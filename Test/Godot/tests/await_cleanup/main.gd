extends "res://pending.gd"

func _ready():
	var child = Node.new()
	child.set_script(load("res://pending.gd"))
	add_child(child)
	child.wait_for_timeout()
	wait_for_timeout()
	await get_tree().process_frame
	await get_tree().process_frame
	child.free()
	print("AWAIT_CLEANUP child freed; root pending until shutdown")
