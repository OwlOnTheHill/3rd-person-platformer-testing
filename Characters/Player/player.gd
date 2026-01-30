extends CharacterBody3D
# All possible player states
enum State { IDLE, MOVE, JUMP, ATTACK, COMBAT_IDLE, COMBAT_MOVE }
# The current state of the player
var current_state = State.IDLE
# helps track if we just entered a state
var state_just_changed = false

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
	# 1. Logic that runs EVERY frame regardless of state
	apply_gravity(delta)
	handle_coyote_time()
	
	if Input.is_action_just_pressed("equip"):
		toggle_weapon()

	# 2. State Switcher: Only runs the code for our current mode
	match current_state:
		State.IDLE:
			handle_idle_state(delta)
		State.MOVE:
			handle_move_state(delta)
		State.JUMP:
			handle_jump_state(delta)
		State.ATTACK:
			handle_attack_state(delta)

	# 3. Final Movement: Apply all the velocity changes we calculated
	move_and_slide()
	
	# Wall collision reset logic (your raycast logic)
	handle_wall_detection()
	
	# Update this for next frame
	was_on_floor = is_on_floor()



func handle_idle_state(_delta: float):
	# Slow down to a stop
	velocity.x = move_toward(velocity.x, 0, SPEED)
	velocity.z = move_toward(velocity.z, 0, SPEED)
	
	# Transitions
	if Input.get_vector("move_left", "move_right", "move_forward", "move_back") != Vector2.ZERO:
		change_state(State.MOVE)
		
	if Input.is_action_just_pressed("jump"):
		sprinting_before_jump = false # No sprint boost from standstill
		change_state(State.JUMP)
		
	if Input.is_action_just_pressed("attack") and is_combat_mode and not is_attacking:
		change_state(State.ATTACK)



func handle_move_state(delta: float):
	# 1. Get Input
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	
	# 2. Calculate Direction relative to Camera
	var camera_basis = $SpringArmPivot.transform.basis
	var forward = camera_basis.z.normalized()
	forward.y = 0
	var right = camera_basis.x.normalized()
	right.y = 0
	var direction = (forward * input_dir.y + right * input_dir.x).normalized()
	
	# 3. Transitions: If we stop moving, go to IDLE. If we jump, go to JUMP.
	if input_dir == Vector2.ZERO:
		change_state(State.IDLE)
	
	if Input.is_action_just_pressed("jump"):
		sprinting_before_jump = Input.is_action_pressed("sprint")
		
		# THE FIX: If we are touching a wall while jumping off the ground, 
		# mark it as 'used' immediately so we can't double-jump off it.
		if raycast.is_colliding():
			last_collided_wall = raycast.get_collider()
			jumped_on = true # This forces the player to find a NEW wall or look away
		else:
			jumped_on = false
			
		change_state(State.JUMP)
		
	if Input.is_action_just_pressed("attack") and is_combat_mode and not is_attacking:
		change_state(State.ATTACK)

	# 4. Mesh Rotation (Your original smooth lerp math)
	if input_dir != Vector2.ZERO:
		var target_rotation = $SpringArmPivot.rotation.y - input_dir.angle() - deg_to_rad(90)
		$MeshInstance3D.rotation.y = lerp_angle($MeshInstance3D.rotation.y, target_rotation, rotation_speed * delta)
	
	# 5. Velocity Calculation (Sprinting vs Walking)
	var sprinting = Input.is_action_pressed("sprint")
	var target_speed = SPRINT if sprinting and (is_on_floor() or sprinting_before_jump) else SPEED
	
	if direction:
		velocity.x = direction.x * target_speed
		velocity.z = direction.z * target_speed
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)



func handle_jump_state(delta: float):
	# 1. Use the same movement math as Move State (so you can steer in mid-air)
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var camera_basis = $SpringArmPivot.transform.basis
	var forward = (camera_basis.z * Vector3(1, 0, 1)).normalized()
	var right = (camera_basis.x * Vector3(1, 0, 1)).normalized()
	var direction = (forward * input_dir.y + right * input_dir.x).normalized()
	
	# 2. Set air speed (Sprinting vs Walking)
	var speed = SPRINT if sprinting_before_jump else SPEED
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed

	# 3. Apply the Jump Force
	# We only do this if we JUST entered the jump state
	if state_just_changed:
		velocity.y = JUMP_VELOCITY
		state_just_changed = false

	# 4. Transitions
	if is_on_floor():
		change_state(State.IDLE)
	
	# Wall Jump logic from your original code
	if Input.is_action_just_pressed("jump") and not jumped_on and raycast.is_colliding():
		velocity.y = JUMP_VELOCITY
		jumped_on = true
	
	if is_on_floor():
		change_state(State.IDLE)
	
	# Mesh Rotation (Your original smooth lerp math)
	if input_dir != Vector2.ZERO:
		var target_rotation = $SpringArmPivot.rotation.y - input_dir.angle() - deg_to_rad(90)
		$MeshInstance3D.rotation.y = lerp_angle($MeshInstance3D.rotation.y, target_rotation, rotation_speed * delta)



func handle_attack_state(_delta: float):
	# We stop horizontal movement so the attack feels "grounded"
	velocity.x = move_toward(velocity.x, 0, SPEED)
	velocity.z = move_toward(velocity.z, 0, SPEED)

	# If we just entered this state, start the swing
	if state_just_changed:
		state_just_changed = false
		execute_attack_animation()

func execute_attack_animation():
	is_attacking = true
	hitbox.monitoring = true
	
	var tween = create_tween()
	# Swing forward
	tween.tween_property(weapon_anchor, "rotation:x", deg_to_rad(-90), 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	# Return to start
	tween.tween_property(weapon_anchor, "rotation:x", deg_to_rad(0), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	tween.finished.connect(func(): 
		is_attacking = false
		hitbox.monitoring = false
		# Go back to IDLE once the sword is back in place
		change_state(State.IDLE)
	)



func toggle_weapon():
	is_combat_mode = !is_combat_mode
	weapon_anchor.visible = is_combat_mode

func apply_gravity(delta):
	if not is_on_floor():
		if is_on_wall_only() and raycast.is_colliding() and velocity.y < 0:
			velocity += WALL_GRAVITY * delta
		else:
			velocity += get_gravity() * delta

func handle_coyote_time():
	if was_on_floor and not is_on_floor() and velocity.y <= 0:
		$CoyoteTimer.start()

func handle_wall_detection():
	# This must run every frame to track WHICH wall we are looking at
	if raycast.is_colliding():
		var current_collided_wall = raycast.get_collider()
		
		# If the wall we see now is different from the last one, reset the jump
		if current_collided_wall != last_collided_wall:
			jumped_on = false
			last_collided_wall = current_collided_wall
	else:
		# If we aren't looking at any wall, clear the last wall reference
		last_collided_wall = null

func change_state(new_state: State):
	current_state = new_state
	state_just_changed = true


func _on_hitbox_area_entered(area: Area3D) -> void:
	# This reaches out to dummy script
	if area.get_parent().has_method("take_damage"):
		area.get_parent().take_damage(10, global_position)
