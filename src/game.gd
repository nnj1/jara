extends Node3D

@onready var player = $players/Player
@onready var current_map = $map/Procedural
@onready var fly_cam = $flying_camera

func _ready() -> void:
	fly_cam.active = false
	player.is_active = true
	player.get_node("Camera3D").make_current()
	player.global_position = current_map.get_node('player_spawn_point').global_position

func _input(event):
	if event.is_action_pressed("debug"):
		toggle_mode()

func toggle_mode():
	if player.is_active:
		# Switch to Fly Cam
		player.is_active = false
		fly_cam.active = true
		fly_cam.make_current()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	else:
		# Switch to Player
		fly_cam.active = false
		player.is_active = true
		player.get_node("Camera3D").make_current()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
