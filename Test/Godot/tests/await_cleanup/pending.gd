extends Node

func wait_for_timeout():
	print("AWAIT_CLEANUP armed")
	await get_tree().create_timer(600).timeout
	push_error("AWAIT_CLEANUP unexpectedly resumed")
