extends RayCast3D

var prev_collision: Node3D = null

func _ready():
	pass

func _physics_process(_delta):
	force_raycast_update()

	if is_colliding():
		var cur_collision: Node3D = get_collider()
		if cur_collision != prev_collision:
			prev_collision = cur_collision
