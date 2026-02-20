extends StaticBody3D

@onready var hinge = $hinge		

# The 'setter' runs this code every time the value changes (locally or via network)
@export var is_open: bool = false:
	set(value):
		is_open = value
		_update_visuals(value)

func _ready() -> void:
	_update_visuals(is_open)

## --- Interaction (Local) ---

func open_chest(_p = null): _request_toggle.rpc_id(1, true)
func close_chest(_p = null): _request_toggle.rpc_id(1, false)

## --- Network Logic (Server Only) ---

@rpc("any_peer", "call_local", "reliable")
func _request_toggle(should_open: bool):
	if not multiplayer.is_server(): return
	
	# Spam filter: Ignore if already in that state or currently tweening
	if is_open == should_open or get_tree().get_processed_tweens().size() > 0:
		return
	
	# Changing this on the server automatically updates all clients via Synchronizer
	is_open = should_open

## --- Visuals (Runs on everyone) ---

func _update_visuals(open: bool):
	# 1. Update UI prompts
	set_meta('interaction_message', 'Press E to ' + ('close' if open else 'open'))
	set_meta('interaction_function', 'close_chest' if open else 'open_chest')
	
	# 2. Animate the lid
	var tween = create_tween()
	var target = -120.0 if open else 0.0
	tween.tween_property(hinge, "rotation_degrees:x", target, 0.8).set_trans(Tween.TRANS_QUAD)

	# 3. Play sounds (only if the node is inside the tree and active)
	if is_inside_tree():
		if open: 
			$openSound.play() 
		else: 
			$closeSound.play()
