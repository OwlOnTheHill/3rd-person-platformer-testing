extends Node3D

var min_spring_length = 2.5
var max_spring_length = 15
var mouse_sens: float = 0.001

@export_range(-90.0, 0.0, 0.1, "radians_as_degrees") var min_vertical_angle: float = -PI/2
@export_range(0.0, 90.0, 0.1, "radians_as_degrees") var max_vertical_angle: float = PI/4

@onready var spring_arm := $SpringArm3D

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _process(_delta: float) -> void:
	pass

func _unhandled_input(event: InputEvent) -> void:
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
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
