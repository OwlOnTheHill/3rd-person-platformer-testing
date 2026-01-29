extends Control

@onready var game = $"../"
@onready var resume_button = $CenterContainer/VBoxContainer/Resume
@onready var quit_button = $CenterContainer/VBoxContainer/Quit

func _ready():
	resume_button.pressed.connect(_on_resume_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

func _on_resume_pressed():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	game.pauseMenu()

func _on_quit_pressed():
	get_tree().quit()
