extends StaticBody3D

@onready var impact_audio = $ImpactAudio
@onready var mesh = $MeshInstance3D
var damage_node = preload("res://Scenes/damage_number.tscn")

var active_damage_label: Label3D = null
var current_damage_sum: int = 0

var flash_mat = preload("res://Materials/flash_material.tres")

func take_damage(amount: int, source_pos: Vector3):
	# 1. Handle Recoil
	var knockback_dir = (global_position - source_pos).normalized()
	recoil(knockback_dir)
	
	# Play impact sound
	impact_audio.pitch_scale = randf_range(0.8, 1.2) # High variation makes hits feel messy/brutal
	impact_audio.play()
	
	flash()
	
	# The "Reset" Logic
	# If the label doesn't exist anymore, it means the previous combo ended.
	if not is_instance_valid(active_damage_label):
		current_damage_sum = 0
		active_damage_label = null

	# 3. Add to the total damage "stack"
	current_damage_sum += amount
	
	if active_damage_label == null:
		active_damage_label = damage_node.instantiate()
		get_parent().add_child(active_damage_label)
		# Place it once and NEVER change this position again. Use middle number to adjust number spawn point
		active_damage_label.global_position = global_position + Vector3(0, 0.6, 0)
	
	active_damage_label.set_number(current_damage_sum)
	active_damage_label.reset_timer()

func recoil(dir: Vector3):
	var tween = create_tween()
	
	# We want to tilt the TOP of the dummy away from the hit.
	# We'll calculate a target rotation based on the direction vector.
	# Multiplying by 0.3 (roughly 17 degrees) for a subtle tilt.
	var target_rotation = Vector3(dir.z * 0.6, 0, -dir.x * 0.6)
	
	# Tilt away
	tween.tween_property(mesh, "rotation", target_rotation, 0.05)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	# Bounce back to original (0,0,0)
	tween.tween_property(mesh, "rotation", Vector3.ZERO, 0.2)\
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

func flash():
	# 1. Apply the white material on top of the existing look
	mesh.material_overlay = flash_mat
	
	# 2. Create a tween to remove it
	var tween = create_tween()
	
	# Wait for 0.05 seconds (instant flash)
	tween.tween_interval(0.05)
	
	# 3. Clear the material automatically
	tween.tween_callback(func(): mesh.material_overlay = null)
