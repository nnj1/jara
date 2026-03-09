extends StaticBody3D

@export var NORTH_LADDER: bool = false
@export var SOUTH_LADDER: bool = false
@export var EAST_LADDER: bool = false
@export var WEST_LADDER: bool = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# hide all child blocks
	$ladder_mesh_east.visible = EAST_LADDER
	$ladder_mesh_west.visible = WEST_LADDER
	$ladder_mesh_north.visible = NORTH_LADDER
	$ladder_mesh_south.visible = SOUTH_LADDER
