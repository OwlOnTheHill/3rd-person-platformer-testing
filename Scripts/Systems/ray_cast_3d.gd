extends RayCast3D

var prev_collision: Node3D = null

func _ready():
	pass

func _physics_process(_delta):
	force_raycast_update()

	if is_colliding():
		var cur_collision: Node3D = get_collider()
		if cur_collision != prev_collision:
			if prev_collision != null:
				print("Collided object changed from: ", prev_collision, " to: ", cur_collision)
				handle_collision_exit(prev_collision)
			handle_collision_enter(cur_collision)
			prev_collision = cur_collision

func handle_collision_enter(collided_object: Node3D):
	print("Entered collision with: ", collided_object)
	if collided_object.has_method("on_raycast_enter"):
		collided_object.on_raycast_enter()

func handle_collision_exit(collided_object: Node3D):
	print("Exited collision with: ", collided_object)
	if collided_object.has_method("on_raycast_exit"):
		collided_object.on_raycast_exit()
