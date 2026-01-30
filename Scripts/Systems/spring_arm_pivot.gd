extends Node3D

var min_spring_length = 2.5
var max_spring_length = 15
var mouse_sens: float = 0.001
var locked_target: Node3D = null

@export_range(-90.0, 0.0, 0.1, "radians_as_degrees") var min_vertical_angle: float = -PI/2
@export_range(0.0, 90.0, 0.1, "radians_as_degrees") var max_vertical_angle: float = PI/4

@onready var spring_arm := $SpringArm3D

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _process(delta: float) -> void:
	if locked_target:
		# Calculate direction to target
		var target_pos = locked_target.global_position
		# Adjust this offset so the camera looks at the dummy's "chest" instead of its feet
		target_pos.y += -1.0
		
		var target_dir = global_position.direction_to(target_pos)
		var target_basis = Basis.looking_at(target_dir)
		
		# Smoothly rotate the pivot (SpringArmPivot) toward the enemy
		# We use slerp for the basis to get clean 3D rotation
		global_basis = global_basis.slerp(target_basis, 10.0 * delta)
		
		# This prevents the camera from looking too far down/up
		# Adjust -0.5 and 0.5 to find your preferred limit
		rotation.x = clamp(rotation.x, deg_to_rad(-20), deg_to_rad(-10))
		
		# Clear the X and Z rotation on the player-relative basis if needed 
		# to prevent the camera from tilting sideways
		rotation.z = 0

func _unhandled_input(event: InputEvent) -> void:
	if locked_target == null:
		if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			rotation.y -= event.relative.x * mouse_sens
			rotation.y = wrapf(rotation.y, 0.0, TAU)
			
			rotation.x -= event.relative.y * mouse_sens
			rotation.x = clamp(rotation.x, min_vertical_angle, max_vertical_angle)

	if event.is_action_pressed("wheel_up") and not spring_arm.spring_length <= min_spring_length:
		spring_arm.spring_length -= 1
	if event.is_action_pressed("wheel_down") and not spring_arm.spring_length >= max_spring_length:
		spring_arm.spring_length += 1

	Input.flush_buffered_events()

	if Input.is_action_just_pressed("pause"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			if owner.has_node("Reticle"):
				owner.get_node("Reticle").hide()
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
