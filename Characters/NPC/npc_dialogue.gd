extends Area3D

@export var prompt_message: String = "Chat"

@export_multiline var dialogue_lines: Array[String] = [
	"Hello there, traveler.",
	"I am a cube.",
	"This is a test of the dialogue system."
]

func interact():
	# Find the player so we can access their UI
	var player = get_tree().get_first_node_in_group("Player")
	
	if player:
		# Send our lines to the player's dialogue box
		player.dialogue_manager.start_dialogue(dialogue_lines)
