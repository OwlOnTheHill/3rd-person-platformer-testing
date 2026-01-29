extends CharacterBody3D

const SPEED = 4.5
const SPRINT = 10.0
const JUMP_VELOCITY = 5.5
const WALL_GRAVITY = Vector3(0, -5.5, 0)

var jumped_on = false : set = set_jumped_on
func set_jumped_on(value):
	jumped_on = value

@onready var hitbox = $MeshInstance3D/WeaponAnchor/CSGBox3D/Hitbox
@onready var weapon_anchor = $MeshInstance3D/WeaponAnchor
@onready var raycast = $MeshInstance3D/RayCast3D
@export var camera: Camera3D
@export var rotation_speed: float = 18.0

var is_combat_mode = false
var last_collided_wall: Node3D = null
var sprinting_before_jump = false
var was_on_floor = false
var is_attacking = false

func _ready() -> void:
	pass

func _physics_process(delta: float) -> void:
	# Add the gravity
	if not is_on_floor():
		if is_on_wall_only() and raycast.is_colliding() and velocity.y < 0:
			velocity += WALL_GRAVITY * delta
		else:
			velocity += get_gravity() * delta
	
	# Coyote Time logic
	if was_on_floor and not is_on_floor() and velocity.y <= 0:
		$CoyoteTimer.start()
	
	was_on_floor = is_on_floor()
	
	if Input.is_action_just_pressed("equip"):
		toggle_weapon()
	
	if Input.is_action_just_pressed("attack") and is_combat_mode and not is_attacking:
		attack()
	
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var camera_basis = $SpringArmPivot.transform.basis
	
	var forward_direction = camera_basis.z.normalized()
	forward_direction.y = 0
	forward_direction = forward_direction.normalized()
	
	var right_direction = camera_basis.x.normalized()
	right_direction.y = 0
	right_direction = right_direction.normalized()
	
	var direction = (forward_direction * input_dir.y + right_direction * input_dir.x).normalized()
	
	# Smooth Mesh Rotation
	if input_dir != Vector2.ZERO:
		var target_rotation = $SpringArmPivot.rotation.y - input_dir.angle() - deg_to_rad(90)
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

	if camera:
		direction = direction.rotated(Vector3.UP, camera.global_rotation.y)

	move_and_slide()

	# Wall collision reset logic
	if raycast.is_colliding():
		var current_collided_wall = raycast.get_collider()
		if current_collided_wall != last_collided_wall:
			jumped_on = false
			last_collided_wall = current_collided_wall
	else:
		last_collided_wall = null

	# Jump Logic
	if not is_on_floor() and Input.is_action_just_pressed("jump") and not jumped_on and raycast.is_colliding():
		velocity.y = JUMP_VELOCITY
		jumped_on = true
		sprinting_before_jump = sprinting

	if is_on_floor():
		jumped_on = false
		sprinting_before_jump = false

	if (is_on_floor() or !$CoyoteTimer.is_stopped()) and Input.is_action_just_pressed("jump"):
		velocity.y = JUMP_VELOCITY
		sprinting_before_jump = sprinting
	
func toggle_weapon():
	is_combat_mode = !is_combat_mode
	weapon_anchor.visible = is_combat_mode

func attack():
	is_attacking = true
	hitbox.monitoring = true
	
	#create the tween
	var tween = create_tween()
	
	# 1. swing forward (rotate anchor) the end number is duration in seconds then the set trans and set ease makes swing start slow and finish fast for realism/weight
	tween.tween_property(weapon_anchor, "rotation:x", deg_to_rad(-90), 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
	# 2. return to start. trans back makes return go slightly past 0 then bounce to place. The ease out starts fast and ends slow so it looks like youre bringing sword up fast and slowing back into idle
	tween.tween_property(weapon_anchor, "rotation:x", deg_to_rad(0), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# 3. Reset attacking state
	tween.finished.connect(func(): 
		is_attacking = false
		hitbox.monitoring = false
	)


func _on_hitbox_area_entered(area: Area3D) -> void:
	# check if the thing hit has a "take_damage" function
	if area.get_parent().has_method("take_damage"):
		area.get_parent().take_damage(10)
