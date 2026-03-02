extends StaticBody3D

func _ready() -> void:
	# Interaction Setup
	self.set_meta('interaction_message', 'Cook something up?')
	self.set_meta('interaction_function', null)
