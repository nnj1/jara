extends Node3D

# Use absolute paths or ensure these names match your scene tree exactly
@onready var players_container = $players
@onready var fly_cam = $flying_camera
@onready var map_node = $map

func _ready() -> void:
	fly_cam.active = false

## Updated with safety checks
func get_spawn_position() -> Vector3:
	# Safety: Ensure map_node exists and has a child
	if map_node and map_node.get_child_count() > 0:
		var current_map = map_node.get_child(0)
		if current_map.has_node('player_spawn_point'):
			return current_map.get_node('player_spawn_point').global_position
	
	# Fallback if map isn't ready or node is missing
	print("Warning: Map not ready for spawn position, using default.")
	return Vector3(0, 5, 0) 

func toggle_mode():
	if not multiplayer.is_server(): return
	
	var local_player = players_container.get_node('1')
	if local_player.is_active:
		local_player.is_active = false
		local_player.get_node("Camera3D").current = false
		fly_cam.active = true
		fly_cam.make_current()
	else:
		fly_cam.active = false
		local_player.is_active = true
		local_player.get_node("Camera3D").make_current()
	
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
