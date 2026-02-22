extends Node3D

# Use absolute paths or ensure these names match your scene tree exactly
@onready var players_container = $players
@onready var fly_cam = $flying_camera
@onready var map_node = $map

# internal variables
var settings_menu = null

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if not settings_menu:
			settings_menu = preload('res://scenes/main_scenes/settings.tscn').instantiate()
			$UI.add_child(settings_menu)
		else:
			settings_menu.queue_free()
			settings_menu = false
			# make player recapture mouse
			players_container.get_node(str(multiplayer.get_unique_id())).capture_mouse(true)
	if event.is_action_pressed("flyingcam"):
		toggle_mode()
	
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
