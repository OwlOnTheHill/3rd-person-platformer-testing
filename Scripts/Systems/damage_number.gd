extends Label3D
#Inspector Checklist:
#Label3D Settings:
#Billboard: Set to "Enabled" (so text always faces the camera).
#No Depth Test: Check this under Flags (so text renders through walls/enemies and isn't hidden).
#Pixel Size: This controls the base resolution/size of the text.

var current_tween: Tween

func _ready():
	# Start invisible so we don't see the text frame 1 before it animates
	modulate.a = 0
	# Label3D has an 'offset' property (x,y) that moves the text in 2D space 
	# relative to its 3D anchor point. We use this for the "floating up" animation.
	offset = Vector2.ZERO

func set_number(value: int):
	text = str(value)

func reset_timer():
	# Called by the Dummy whenever a new hit is added to the stack
	animate_number()

func animate_number():
	# If an animation is already playing (e.g., from the previous hit 0.1s ago),
	# we kill it immediately so the text doesn't freak out.
	if current_tween:
		current_tween.kill()
	
	current_tween = create_tween()
	
	# Reset alpha to visible immediately
	modulate.a = 1.0
	
	# --- TWEEN ANIMATION EXPLANATION ---
	# By default, Tweens run one after another (Sequence).
	# .parallel() tells the Tween: "Run this NEXT line at the same time as the previous line."
	
	# 1. THE POP EFFECT (Scale)
	# Instantly scale text UP to 0.007 (Pop), then shrink back to normal 0.005.
	# Note: For Label3D, "pixel_size" controls the scale.
	current_tween.parallel().tween_property(self, "pixel_size", 0.007, 0.1)
	current_tween.tween_property(self, "pixel_size", 0.005, 0.1)
	
	# 2. PHASE 1: RISE
	# Move the 'offset.y' up by 150 pixels over 0.3 seconds.
	# TRANS_BACK makes it "overshoot" slightly, giving it a bouncy cartoon feel.
	current_tween.tween_property(self, "offset:y", 150, 0.3)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# 3. PHASE 2: HOVER (Grace Period)
	# This creates a pause where the text sits still.
	# If the player hits again during this 0.6s window, 'reset_timer()' runs 
	# and this whole function starts over (killing this tween).
	# This creates the "Combo" window.
	current_tween.tween_interval(0.6)
	
	# 4. PHASE 3: DROP & FADE
	# Run movement (Drop) and Fade (Alpha) simultaneously.
	current_tween.parallel().tween_property(self, "offset:y", 100, 0.5)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	current_tween.parallel().tween_property(self, "modulate:a", 0, 0.5)
	
	# 5. CLEANUP
	# When the timeline finishes, delete this node from the game to save memory.
	current_tween.finished.connect(queue_free)
