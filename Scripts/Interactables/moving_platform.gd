extends AnimatableBody3D

@onready var anim = $AnimationPlayer

func activate_platform():
	# Check if we are already moving to avoid restarting it
	if not anim.is_playing():
		anim.play("move")
