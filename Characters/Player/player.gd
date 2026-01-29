extends CharacterBody3D

const SPEED = 4.5
const SPRINT = 10.0
const JUMP_VELOCITY = 5.5
const WALL_GRAVITY = Vector3(0, -5.5, 0)

var jumped_on = false : set = set_jumped_on
func set_jumped_on(value):
	jumped_on = value
	print("jumped_on set to: ", value)

@onready var raycast = $MeshInstance3D/RayCast3D
@export var camera: Camera3D
@export var rotation_speed: float = 18.0

var debug_timer = 0.0
const DEBUG_INTERVAL = 0.5
var last_collided_wall: Node3D = null
var sprinting_before_jump = false
var was_on_floor = false

func _ready() -> void:
	pass

func _physics_process(delta: float) -> void:
	#Add the gravity
	if not is_on_floor():
		if is_on_wall_only() and raycast.is_colliding() and velocity.y < 0:
			velocity += WALL_GRAVITY * delta
		else:
			velocity += get_gravity() * delta
	
	# 1. detect when we just walked off a ledge
	if was_on_floor and not is_on_floor() and velocity.y <= 0:
		$CoyoteTimer.start()
	
	# 2. Update the "was_on_floor" state for the next frame
	was_on_floor = is_on_floor()
	
	# get input direction and handle movement/deceleration
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	#changes keys to be oriented to camera direction
	var camera_basis = $SpringArmPivot.transform.basis
	# Ensure the camera's forward vector is projected horizontally
	var forward_direction = camera_basis.z.normalized()
	forward_direction.y = 0
	forward_direction = forward_direction.normalized()
	
	var right_direction = camera_basis.x.normalized()
	right_direction.y = 0
	right_direction = right_direction.normalized()
	
	var direction = (forward_direction * input_dir.y + right_direction * input_dir.x).normalized()

	#rotates character mesh to be oriented to movement direction
	if input_dir != Vector2.ZERO:
		# Calculate the target rotation (where we WANT to face)
		var target_rotation = $SpringArmPivot.rotation.y - input_dir.angle() - deg_to_rad(90)
		
		# Smoothly rotate the mesh toward that target
		$MeshInstance3D.rotation.y = lerp_angle(
			$MeshInstance3D.rotation.y,
			target_rotation,
			rotation_speed * delta
		)
	
	var sprinting = Input.is_action_pressed("sprint")
	
	if sprinting and (is_on_floor() or sprinting_before_jump):
		velocity.x = direction.x * SPRINT
		velocity.z = direction.z * SPRINT
	else:
		if direction:
			velocity.x = direction.x * SPEED
			velocity.z = direction.z * SPEED
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED)
			velocity.z = move_toward(velocity.z, 0, SPEED)

	direction = direction.rotated(Vector3.UP, camera.global_rotation.y)

	move_and_slide()

	debug_timer += delta
	if debug_timer >= DEBUG_INTERVAL:
		debug_timer = 0.0 
		print("jumped_on: ", jumped_on)
		print("raycast.prev_collision: ", raycast.prev_collision)
		print("raycast.get_collider(): ", raycast.get_collider())

	if raycast.is_colliding():
		var current_collided_wall = raycast.get_collider()
		if current_collided_wall != last_collided_wall:
			jumped_on = false
			print("Collision changed, jumped_on set to false")
			last_collided_wall = current_collided_wall
	else:
		last_collided_wall = null

	print("After Collision Check: jumped_on:", jumped_on, "prev:", raycast.prev_collision, "cur:", raycast.get_collider(), "is_wall:", is_on_wall_only())

	if not is_on_floor() and Input.is_action_just_pressed("jump") and not jumped_on and raycast.is_colliding():
		velocity.y = JUMP_VELOCITY
		jumped_on = true
		sprinting_before_jump = sprinting

	if is_on_floor():
		jumped_on = false
		sprinting_before_jump = false
		print("on floor, jumped_on set to false")

	if (is_on_floor() or !$CoyoteTimer.is_stopped()) and Input.is_action_just_pressed("jump"):
		velocity.y = JUMP_VELOCITY
		sprinting_before_jump = sprinting
