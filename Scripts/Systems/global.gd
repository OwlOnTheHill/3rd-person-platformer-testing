extends Node

#Inspector Checklist:
#Globals: You must go to Project Settings -> Globals and add this script with the name Global.

var coins: int = 0

# Creates a "Freeze Frame" effect for heavy impacts (like Zelda or Street Fighter).
# time_scale: How slow time gets (0.05 = 5% speed).
# duration: How long the freeze lasts in REAL seconds.
func hit_stop(time_scale: float, duration: float):
	Engine.time_scale = time_scale
	
	# We use a timer that ignores the time scale (true, false, true).
	# This ensures the freeze only lasts exactly 'duration' seconds, 
	# regardless of how slow the game is currently running.
	await get_tree().create_timer(duration, true, false, true).timeout
	
	Engine.time_scale = 1.0
