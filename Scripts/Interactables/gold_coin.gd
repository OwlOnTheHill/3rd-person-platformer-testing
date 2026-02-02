extends RigidBody3D

@onready var pickup_area = $PickupArea

func _ready():
	pickup_area.body_entered.connect(_on_pickup_area_body_entered)

func _on_pickup_area_body_entered(body: Node3D):
	# Check if the body is the Player
	if body.is_in_group("Player"):
		collect()

func collect():
	# 1. Add to global score
	Global.coins += 1
	print("Coins collected: ", Global.coins)
	
	queue_free()
