extends AnimatableBody3D

@onready var anim = $AnimationPlayer

func activate_platform():
	if not anim.is_playing():
		anim.play("move")
