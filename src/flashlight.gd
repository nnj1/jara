extends Light3D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# only show this light if you're the authority
	if not is_multiplayer_authority():
		self.visible = false
	else:
		self.visible = true

func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority(): return
	if event.is_action_pressed('flashlight'):
		self.visible = not self.visible
