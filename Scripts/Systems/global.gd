extends Node

var coins: int = 0

func hit_stop(time_scale: float, duration: float):
	Engine.time_scale = time_scale
	
	# FIX: Just use 'duration'. Do not multiply by time_scale.
	# We want to wait 0.1 real seconds, not 0.005 seconds.
	await get_tree().create_timer(duration, true, false, true).timeout
	
	Engine.time_scale = 1.0
