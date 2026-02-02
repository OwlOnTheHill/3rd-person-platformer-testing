extends Node3D

@onready var pause_menu = $PauseMenu
var paused = false

func _process(_delta):
	if Input.is_action_just_pressed("pause"):
		# 1. Find the player to check their status
		var player = get_tree().get_first_node_in_group("Player")
		
		# 2. Safety Check: If player exists AND is busy interacting...
		if player and not player.is_interacting:
			pauseMenu()

func pauseMenu():
	if paused:
		pause_menu.hide()
		get_tree().paused = false
	else:
		pause_menu.show()
		pause_menu.get_node("AnimationPlayer").play("open_book")
		get_tree().paused = true
	
	paused = !paused
