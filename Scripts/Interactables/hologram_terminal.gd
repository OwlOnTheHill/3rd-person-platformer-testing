extends Area3D

@onready var terminal_camera = $"../TerminalCamera"
@onready var viewport = $"../Viewport"          # <--- NEW
@onready var screen_mesh = $"../HologramScreen" # <--- NEW

@export var prompt_message = "Access Terminal"

var player: CharacterBody3D
var is_active = false

func _ready():
	# 1. Get the material from the screen mesh
	# (We assume the material is in the 'Surface Material Override' slot, which is index 0)
	var material = screen_mesh.get_surface_override_material(0)
	
	# 2. Assign the viewport texture manually
	# This avoids the "Parameter material is null" crash because the node is guaranteed to exist now
	if material:
		material.albedo_texture = viewport.get_texture()

func interact():
	if is_active:
		return 
		
	player = get_tree().get_first_node_in_group("Player")
	if not player: return
	
	is_active = true
	player.toggle_interaction_mode(true)
	terminal_camera.make_current()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _input(event):
	# If terminal isn't active, do nothing
	if not is_active:
		return

	# NEW: Listen for TAB (or whatever you bound to 'exit_interaction')
	if event.is_action_pressed("exit_interaction"):
		exit_terminal()

func exit_terminal():
	is_active = false
	if player:
		player.toggle_interaction_mode(false)
		player.camera.make_current()
	
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
