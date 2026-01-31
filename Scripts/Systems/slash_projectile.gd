extends Area3D

var speed: float = 15.0
var damage: int = 25
var lifetime: float = 0.5 # Short range (half a second)

func _ready():
	# 1. Connect signals via code (so you don't forget!)
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	
	# 2. Delete self automatically after lifetime ends
	await get_tree().create_timer(lifetime).timeout
	queue_free()

func _physics_process(delta):
	# Move forward in local space (whatever direction we were spawned facing)
	position -= transform.basis.z * speed * delta

func _on_body_entered(body):
	# If we hit a wall or floor, destroy the projectile
	if body is StaticBody3D or body is CSGShape3D:
		queue_free()

func _on_area_entered(area):
	var target = area.get_parent()
	
	# Ensure we don't hit the player or ourselves
	if target.has_method("take_damage") and not target.is_in_group("Player"):
		target.take_damage(damage, global_position)
		# We DON'T queue_free() here! 
		# This allows the wave to pass through multiple enemies (AOE attack).
