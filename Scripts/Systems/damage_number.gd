extends Label3D

var current_tween: Tween

func _ready():
	# Keep the node itself invisible until the tween starts
	modulate.a = 0
	# Set a default offset so it doesn't jump
	offset = Vector2.ZERO

func set_number(value: int):
	text = str(value)

func reset_timer():
	animate_number()

func animate_number():
	if current_tween:
		current_tween.kill()
	
	current_tween = create_tween()
	modulate.a = 1.0
	
	# AT THE SAME TIME the number starts rising.
	current_tween.parallel().tween_property(self, "pixel_size", 0.007, 0.1)
	current_tween.tween_property(self, "pixel_size", 0.005, 0.1)
	
	# PHASE 1: RISE (Moving the OFFSET, not the position)
	# This moves the text up 150 pixels relative to the anchor point
	current_tween.tween_property(self, "offset:y", 150, 0.3)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# PHASE 2: HOVER. Change this value to affect combo grace period
	current_tween.tween_interval(0.6)
	
	# PHASE 3: DROP & FADE
	# Drop back down to 100 pixels while fading
	current_tween.parallel().tween_property(self, "offset:y", 100, 0.5)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	current_tween.parallel().tween_property(self, "modulate:a", 0, 0.5)
	
	current_tween.finished.connect(queue_free)
