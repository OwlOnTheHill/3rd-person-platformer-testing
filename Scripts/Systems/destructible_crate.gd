extends StaticBody3D

# Drag GoldCoin.tscn into Inspector
@export var loot_scene: PackedScene 
# Drag HitParticles.tscn into Inspector
@export var debris_scene: PackedScene 
@export var health: int = 20

func take_damage(amount: int, _source_pos: Vector3):
	health -= amount
	
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
	
	if loot_scene:
		spawn_loot()
		
	queue_free()

func spawn_loot():
	var loot = loot_scene.instantiate()
	get_parent().add_child(loot)
	loot.global_position = global_position + Vector3(0, 0.5, 0) # Spawn slightly above center
	
	# Apply a random "pop" force so it flies out
	if loot is RigidBody3D:
		var random_dir = Vector3(randf_range(-1, 1), 1, randf_range(-1, 1)).normalized()
		loot.apply_impulse(random_dir * 5.0) # Pop it into the air!
