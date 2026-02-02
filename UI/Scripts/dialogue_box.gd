extends Panel

@onready var text_label = $TextLabel

var dialogue_lines: Array[String] = []
var current_line_index: int = 0
var is_active: bool = false
var is_typing: bool = false
var current_tween: Tween 

func _ready():
	visible = false

func start_dialogue(lines: Array[String]):
	dialogue_lines = lines
	current_line_index = 0
	is_active = true
	visible = true
	show_current_line()

func show_current_line():
	var next_text = dialogue_lines[current_line_index]
	text_label.text = next_text
	
	# Reset to invisible
	text_label.visible_ratio = 0.0
	is_typing = true
	
	if current_tween:
		current_tween.kill() # Safety check
	current_tween = create_tween()
	
	var duration = next_text.length() * 0.03
	current_tween.tween_property(text_label, "visible_ratio", 1.0, duration)
	
	current_tween.finished.connect(func(): is_typing = false)

func advance_dialogue():
	# Skip Typing
	if is_typing:
		# STOP the animation immediately!
		if current_tween:
			current_tween.kill()
		
		# Force the text to appear instantly
		text_label.visible_ratio = 1.0
		is_typing = false
		return # Stop here, do not go to next page
		
	# Normal logic: Go to next line
	current_line_index += 1
	
	if current_line_index < dialogue_lines.size():
		show_current_line()
	else:
		close_dialogue()

func close_dialogue():
	visible = false
	is_active = false
