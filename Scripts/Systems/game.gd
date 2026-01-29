extends Node3D

@onready var pause_menu = $PauseMenu
var paused = false

func _process(_delta):
	if Input.is_action_just_pressed("pause"):
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
