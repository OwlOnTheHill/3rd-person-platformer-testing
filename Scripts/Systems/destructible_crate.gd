extends StaticBody3D

# 1. Drag your GoldCoin.tscn into this slot in the Inspector
@export var loot_scene: PackedScene 

# 2. Drag your HitParticles.tscn here too (to reuse the explosion effect)
@export var debris_scene: PackedScene 

@export var health: int = 20

func take_damage(amount: int, source_pos: Vector3):
	health -= amount
	
	# Optional: Flash white (if you want to copy the dummy logic later)
	# flash() 
	
	if health <= 0:
		break_object()

func break_object():
	# 1. Spawn Debris (Visuals)
	if debris_scene:
		var debris = debris_scene.instantiate()
		get_parent().add_child(debris)
		debris.global_position = global_position
		# Make the explosion bigger for a crate
		debris.process_material.scale_min = 1.0
	
	# 2. Spawn Loot
	if loot_scene:
		spawn_loot()
		
	# 3. Delete the crate
	queue_free()

func spawn_loot():
	# Instantiate the coin
	var loot = loot_scene.instantiate()
	get_parent().add_child(loot)
	loot.global_position = global_position + Vector3(0, 0.5, 0) # Spawn slightly above center
	
	# Apply a random "pop" force so it flies out
	if loot is RigidBody3D:
		var random_dir = Vector3(randf_range(-1, 1), 1, randf_range(-1, 1)).normalized()
		loot.apply_impulse(random_dir * 5.0) # Pop it into the air!
