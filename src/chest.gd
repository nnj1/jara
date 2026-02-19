extends StaticBody3D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	set_meta('interaction_message', 'Press E to open')
	set_meta('interaction_function', 'open_chest')

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass
	
func open_chest(_player = null):
	tween_hinge($hinge, true)
	set_meta('interaction_message', 'Press E to close')
	set_meta('interaction_function', 'close_chest')
	$openSound.play()
	
func close_chest(_player = null):
	tween_hinge($hinge, false)
	set_meta('interaction_message', 'Press E to open')
	set_meta('interaction_function', 'open_chest')
	$closeSound.play()

@warning_ignore("shadowed_variable")
func tween_hinge(node: Node3D, open: bool):
	# Create a new tween instance
	var tween = create_tween()
	
	# Determine the target angle based on the 'open' boolean
	var target_angle = -120.0 if open else 0.0
	
	# Transition the X-axis rotation
	# Parameters: (Property, Final Value, Duration in seconds)
	tween.tween_property(node, "rotation_degrees:x", target_angle, 1.0)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_OUT)
