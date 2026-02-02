extends StaticBody3D

# --- NODES & PRELOADS ---
@onready var impact_audio = $ImpactAudio
@onready var mesh = $MeshInstance3D

# "preload" loads the file into memory when the game starts. 
# We do this so we don't have lag when we hit an enemy for the first time.
var damage_node = preload("res://Scenes/damage_number.tscn")
var flash_mat = preload("res://Materials/flash_material.tres")

# --- COMBO LOGIC VARIABLES ---
# We store a reference to the active label so we can "feed" it more numbers 
# if the player attacks fast enough.
var active_damage_label: Label3D = null
var current_damage_sum: int = 0

func _ready() -> void:
	# Adds this node to the "Enemy" group so the Player script 
	# knows to give Fury when hitting it.
	add_to_group("Enemy")

func take_damage(amount: int, source_pos: Vector3):
	# 1. VISUAL & AUDIO FEEDBACK
	# Calculate direction from the sword (source_pos) to the dummy (self).
	var knockback_dir = (global_position - source_pos).normalized()
	recoil(knockback_dir)
	
	# Random pitch makes repetitive attacks sound less robotic.
	impact_audio.pitch_scale = randf_range(0.8, 1.2) 
	impact_audio.play()
	
	flash()
	
	# 2. DAMAGE NUMBER LOGIC (The "Stacking" System)
	# Check if the previous number label has disappeared (freed) or doesn't exist.
	# is_instance_valid() returns FALSE if the node has been queue_free()'d.
	if not is_instance_valid(active_damage_label):
		# RESET: If the old label is gone, start a new combo count.
		current_damage_sum = 0
		active_damage_label = null

	# Add the new damage to the running total
	current_damage_sum += amount
	
	# If we don't have a label currently floating, create one.
	if active_damage_label == null:
		active_damage_label = damage_node.instantiate()
		get_parent().add_child(active_damage_label)
		
		# SPAWN POSITION
		# We set the position once when it spawns.
		# Vector3(0, 0.6, 0) -> Adjust '0.6' to move the text higher or lower relative to the enemy center.
		active_damage_label.global_position = global_position + Vector3(0, 0.6, 0)
	
	# Update the text on the label to show the new Total Sum
	active_damage_label.set_number(current_damage_sum)
	
	# Restart the "Pop" animation so it stays on screen longer
	active_damage_label.reset_timer()

func recoil(dir: Vector3):
	var tween = create_tween()
	
	# RECOIL MATH EXPLAINED:
	# To make an object look like it's hit, we tilt the top AWAY from the hit.
	# If hit from the Front (+Z), we rotate around X axis.
	# '0.6' is the intensity multiplier. Higher number = more tilt.
	var target_rotation = Vector3(dir.z * 0.6, 0, -dir.x * 0.6)
	
	# Tween 1: Snap away quickly (0.05s)
	tween.tween_property(mesh, "rotation", target_rotation, 0.05)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	# Tween 2: Bounce back to zero slowly (0.2s) using Elastic easing for a "wobbly" feel
	tween.tween_property(mesh, "rotation", Vector3.ZERO, 0.2)\
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

func flash():
	# Simple flash effect: Overlay a white material, wait, then remove it.
	mesh.material_overlay = flash_mat
	
	var tween = create_tween()
	tween.tween_interval(0.05) # How long the flash lasts
	tween.tween_callback(func(): mesh.material_overlay = null)
