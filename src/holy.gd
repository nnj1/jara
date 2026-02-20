extends Node3D

@export var is_active: bool : set = set_active

func set_active(value):
	if value:
		self.show()
	else:
		self.hide()

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	self.hide()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	$MeshInstance3D.rotate_y(delta/4.0)
	# TODO: undo any parent rotation
	self.rotate_y(get_parent().rotation.y)
