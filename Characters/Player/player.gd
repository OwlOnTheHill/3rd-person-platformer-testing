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

@onready var fury_bar_1 = $HUD/VBoxContainer/Fury1
@onready var fury_bar_2 = $HUD/VBoxContainer/Fury2
@onready var swing_audio = $MeshInstance3D/WeaponAnchor/SwingAudio
@onready var interact_label = $HUD/InteractLabel
@onready var hitbox = $MeshInstance3D/WeaponAnchor/CSGBox3D/Hitbox
@onready var weapon_anchor = $MeshInstance3D/WeaponAnchor
@onready var raycast = $MeshInstance3D/RayCast3D
@onready var reticle = $Reticle
@export var camera: Camera3D
@export var rotation_speed: float = 18.0
@export var max_lock_distance: float = 24.0

var is_combat_mode = false
var last_collided_wall: Node3D = null
var sprinting_before_jump = false
var was_on_floor = false
var is_attacking = false
var locked_target: Node3D = null
var is_locked_on: bool = false
var reticle_tween: Tween
var particle_scene = preload("res://Scenes/VFX/hit_particles.tscn")
var already_hit_targets = []
var slash_scene = preload("res://Scenes/slash_projectile.tscn")
# Fury Logic
var current_fury: float = 0.0
var max_fury: float = 2.0
var fury_gain_per_hit: float = 0.5  # 0.5 means 2 hits = 1 full charge

func _ready() -> void:
	add_to_group("Player")
	
	# If we forgot to assign the camera in the inspector, try to find it
	if camera == null:
		camera = get_viewport().get_camera_3d()



func _process(_delta: float) -> void:
	if is_locked_on and locked_target:
		# Show the reticle
		reticle.visible = true
		
		# Start animation if not running
		if reticle_tween == null or not reticle_tween.is_running():
			start_reticle_throb()
		
		# Handle Fade Logic
		if is_line_of_sight_clear(locked_target):
			reticle.modulate.a = 1.0
		else:
			reticle.modulate.a = 0.4
		
		# Get the enemy's 3D position (offset slightly for the chest)
		var target_pos = locked_target.global_position + Vector3(0, 0.6, 0)
		
		# Convert 3D position to 2D screen coordinates
		var screen_pos = camera.unproject_position(target_pos)
		
		# Move the UI element to that position
		reticle.position = screen_pos - (reticle.size / 2) # Center the X on the target
	else:
		# Hide it when not locked on
		reticle.visible = false
		
		if reticle_tween:
			reticle_tween.kill() # stop animation when lock on is lost
			reticle.scale = Vector2.ONE # reset size
	
	# NEW: Check for interactables to show UI
	var interactable = get_valid_interactable()
	
	if interactable:
		interact_label.visible = true
		interact_label.text = "Press F to Interact"
	else:
		interact_label.visible = false
	
	# NEW: Check for secondary attack
	if Input.is_action_just_pressed("secondary_attack"):
		try_slash_attack()



func _physics_process(delta: float) -> void:
	# 1. Logic that runs EVERY frame regardless of state
	apply_gravity(delta)
	handle_coyote_time()
	
	if Input.is_action_just_pressed("equip"):
		toggle_weapon()
	
	if Input.is_action_just_pressed("lock_on"):
		toggle_lock_on()
	
	if Input.is_action_just_pressed("interact"):
		try_interact()

	# 2. State Switcher: Only runs the code for our current mode
	match current_state:
		State.IDLE:
			if is_locked_on: change_state(State.COMBAT_IDLE)
			else: handle_idle_state(delta)
		State.MOVE:
			if is_locked_on: change_state(State.COMBAT_MOVE)
			else: handle_move_state(delta)
		State.COMBAT_IDLE:
			if not is_locked_on: change_state(State.IDLE)
			else: handle_combat_idle_state(delta)
		State.COMBAT_MOVE:
			if not is_locked_on: change_state(State.MOVE)
			else: handle_combat_move_state(delta)
		State.JUMP:
			handle_jump_state(delta)
		State.ATTACK:
			handle_attack_state(delta)

	# 3. Final Movement: Apply all the velocity changes we calculated
	move_and_slide()
	
	# Wall collision reset logic (your raycast logic)
	handle_wall_detection()
	
	if is_on_floor():
		jumped_on = false
		last_collided_wall = null
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
		if is_on_floor() or not $CoyoteTimer.is_stopped() or (not jumped_on and raycast.is_colliding()):
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
		if is_on_floor() or not $CoyoteTimer.is_stopped() or (not jumped_on and raycast.is_colliding()):
			sprinting_before_jump = Input.is_action_pressed("sprint")
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
	
	if Input.is_action_just_pressed("jump"):
		if not jumped_on and raycast.is_colliding():
			velocity.y = JUMP_VELOCITY
			jumped_on = true
	
	if is_on_floor():
		change_state(State.IDLE)
	
	if is_locked_on:
		look_at_target(delta)
	elif input_dir != Vector2.ZERO:
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
	already_hit_targets.clear()
	
	# Play sound with random pitch for variety
	swing_audio.pitch_scale = randf_range(0.9, 1.1)
	swing_audio.play()
	
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



func handle_combat_idle_state(delta: float):
	# Face the target
	look_at_target(delta)
	
	# Transitions
	if Input.get_vector("move_left", "move_right", "move_forward", "move_back") != Vector2.ZERO:
		change_state(State.COMBAT_MOVE)
	
	if Input.is_action_just_pressed("jump"):
		if is_on_floor() or not $CoyoteTimer.is_stopped() or (not jumped_on and raycast.is_colliding()):
			change_state(State.JUMP)

	if Input.is_action_just_pressed("attack") and is_combat_mode:
		change_state(State.ATTACK)



func handle_combat_move_state(delta: float):
	look_at_target(delta)
	
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var camera_basis = $SpringArmPivot.transform.basis
	var direction = (camera_basis.z * input_dir.y + camera_basis.x * input_dir.x).normalized()
	direction.y = 0
	
	velocity.x = direction.x * SPEED
	velocity.z = direction.z * SPEED
	
	# Transitions
	if input_dir == Vector2.ZERO:
		change_state(State.COMBAT_IDLE)
		
	if Input.is_action_just_pressed("jump"):
		if is_on_floor() or not $CoyoteTimer.is_stopped() or (not jumped_on and raycast.is_colliding()):
			change_state(State.JUMP)

	if Input.is_action_just_pressed("attack") and is_combat_mode:
		change_state(State.ATTACK)



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
		pass

func change_state(new_state: State):
	current_state = new_state
	state_just_changed = true

func _on_hitbox_area_entered(area: Area3D) -> void:
	# Get the enemy root node (the dummy)
	var target = area.get_parent()
	
	# CHECK 1: Have we already hit this specific enemy with this swing?
	if target in already_hit_targets:
		return # Stop here! Do not damage them again.
	
	# CHECK 2: Is it a valid enemy?
	if target.has_method("take_damage"):
		# Mark them as "Hit" for this swing
		already_hit_targets.append(target)
		
		# Now apply the damage and effects
		target.take_damage(10, global_position)
		
		# Check group to give Fury
		if target.is_in_group("Enemy"):
			gain_fury(fury_gain_per_hit)
		
		# Spawn Particles
		var vfx = particle_scene.instantiate()
		get_tree().root.add_child(vfx)
		vfx.global_position = hitbox.global_position 
		
		# Hit Stop
		# first number means how fast time moves by percentage
		# second number is duration of freeze in real time in seconds so 0.1 = a tenth of a second
		Global.hit_stop(0.05, 0.1)

func find_closest_target():
	# Safety Check: if no camera, cant check frustum
	if camera == null:
		print("Error: No camera assigned to player!")
		return null
	
	var targets = $LockOnArea.get_overlapping_bodies()
	var closest_target = null
	var min_dist = INF
	
	for target in targets:
		# check if its a valid target
		if target.has_method("take_damage") and target != self:
			# 1. Camera Visibility: can I actually see target
			if not camera.is_position_in_frustum(target.global_position):
				continue
			
			# Wall Check. Is there a solid object between
			if not is_line_of_sight_clear(target):
				continue
			
			var dist = global_position.distance_to(target.global_position)
			if dist < min_dist:
				min_dist = dist
				closest_target = target
	
	return closest_target

func toggle_lock_on():
	if is_locked_on:
		is_locked_on = false
		locked_target = null
		$SpringArmPivot.locked_target = null
	else:
		var target = find_closest_target()
		if target:
			locked_target = target
			is_locked_on = true
			$SpringArmPivot.locked_target = target

func look_at_target(delta: float):
	if locked_target:
		# Get the direction to the target
		var pos = locked_target.global_position
		pos.y = global_position.y # Keep rotation on the horizontal plane
		
		# Create a look-at transform
		var target_dir = global_position.direction_to(pos)
		var target_basis = Basis.looking_at(target_dir)
		
		# Smoothly rotate the MeshInstance3D toward that direction
		$MeshInstance3D.global_basis = $MeshInstance3D.global_basis.slerp(target_basis, rotation_speed * delta)
		
		if is_locked_on and locked_target:
			var dist = global_position.distance_to(locked_target.global_position)
			if dist > max_lock_distance:
				toggle_lock_on() # This will clear the target and turn off is_locked_on

func is_line_of_sight_clear(target: Node3D) -> bool:
	var space_state = get_world_3d().direct_space_state
	
	# We cast a ray from the camera's position to the enemy's center
	var query = PhysicsRayQueryParameters3D.create(
		camera.global_position, 
		target.global_position + Vector3(0, 0.6, 0) # Aim for the chest
	)
	
	# Ignore the player so the ray doesn't hit your own back
	query.exclude = [get_rid()] 
	var result = space_state.intersect_ray(query)
	
	if result:
		# If the first thing the ray hits is our target, the path is clear
		return result.collider == target
	
	return false

func start_reticle_throb():
	reticle_tween = create_tween().set_loops() # Infinite loop
	# Scale up to 120% size over 0.5 seconds
	reticle_tween.tween_property(reticle, "scale", Vector2(1.2, 1.2), 0.5).set_trans(Tween.TRANS_SINE)
	# Scale back to 100% size over 0.5 seconds
	reticle_tween.tween_property(reticle, "scale", Vector2(1.0, 1.0), 0.5).set_trans(Tween.TRANS_SINE)

func try_interact():
	var item = get_valid_interactable()
	if item:
		item.interact()

func get_valid_interactable():
	var overlapping_areas = $InteractionArea.get_overlapping_areas()
	
	var closest_item = null
	var closest_distance = INF
	
	for area in overlapping_areas:
		if area.has_method("interact"):
			var dist = global_position.distance_to(area.global_position)
			
			if dist < closest_distance:
				closest_distance = dist
				closest_item = area
	
	return closest_item

func update_fury_ui():
	# Bar 1 fills from 0.0 to 1.0 fury
	fury_bar_1.value = clamp(current_fury * 100, 0, 100)
	
	# Bar 2 fills from 1.0 to 2.0 fury
	# We subtract 1.0 so it only starts filling after we have more than 1 charge
	fury_bar_2.value = clamp((current_fury - 1.0) * 100, 0, 100)

func gain_fury(amount: float):
	current_fury = clamp(current_fury + amount, 0, max_fury)
	update_fury_ui()

func spend_fury(amount: float) -> bool:
	if current_fury >= amount:
		current_fury -= amount
		update_fury_ui()
		return true
	return false

func try_slash_attack():
	# 1. Check if we have enough Fury (1.0 = 1 full diamond)
	if spend_fury(1.0):
		spawn_slash()

func spawn_slash():
	var slash = slash_scene.instantiate()
	get_parent().add_child(slash)
	
	# Spawn in front of player, at chest height
	slash.global_position = global_position + Vector3(0, 1.0, 0) + (transform.basis.z * 1.0)
	
	# Match player rotation
	slash.global_rotation = $MeshInstance3D.global_rotation
	
	# Optional: Play Swing Sound again
	swing_audio.pitch_scale = 0.8 # Lower pitch for "heavy" attack
	swing_audio.play()
