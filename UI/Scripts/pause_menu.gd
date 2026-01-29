extends Control

@onready var game = $"../"
@onready var resume_button = $VBoxContainer/Resume
@onready var quit_button = $VBoxContainer/Quit

func _ready():
	resume_button.pressed.connect(_on_resume_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

func _on_resume_pressed():
	# 1. Play closing book animation
	$AnimationPlayer.play("close_book")
	
	# 2. wait for animation to finish
	await $AnimationPlayer.animation_finished
	
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	game.pauseMenu()

func _on_quit_pressed():
	get_tree().quit()
