extends Area3D

signal interact_triggered

@onready var mesh = $MeshInstance3D

func interact():
	print("Button pressed!")
	
	# Simple visual feedback (squish down)
	var tween = create_tween()
	tween.tween_property(mesh, "scale:y", 0.5, 0.1)
	tween.tween_property(mesh, "scale:y", 1.0, 0.1)
	
	# Tell the world something happened
	interact_triggered.emit()
