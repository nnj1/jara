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
			players_container.get_node(str(multiplayer.get_unique_id())).capture_mouse(false)
		else:
			settings_menu.queue_free()
			settings_menu = false
			# make player recapture mouse unless in dialogic chat
			if not Dialogic.current_timeline:
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

func fade_out_and_in(duration: float = 1.0):
	# 1. Create the tween
	var tween = create_tween()
	
	# Define your colors
	var transparent = Color(0, 0, 0, 0)
	var black = Color(0.0, 0.0, 0.0, 1.0)  # BLACK
	
	$UI/ColorRect.color = transparent
	tween.tween_property($UI/ColorRect, "color", black, duration/2.0).set_trans(Tween.TRANS_SINE)
	tween.tween_property($UI/ColorRect, "color", transparent,  duration/2.0).set_trans(Tween.TRANS_SINE)


func flash_title_card(message: String, duration: float = 1.0):
	var label = $UI/title_card
	label.text = message
	label.self_modulate.a = 0
	label.show()
	
	var tween = create_tween()
	# Fade In
	tween.tween_property(label, "self_modulate:a", 1.0, duration/3.0)
	# Wait for 2 seconds
	tween.tween_interval(duration/3.0)
	# Fade Out
	tween.tween_property(label, "self_modulate:a", 0.0, duration/3.0)
		

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

func flash_damage_animation():
	# 1. Create the tween
	var tween = create_tween()
	
	# Define your colors
	var transparent = Color(1, 0, 0, 0)      # Red, but invisible
	var light_red = Color(1, 0.3, 0.3, 0.6)  # Semi-transparent light red
	$UI/ColorRect.color = transparent
	
	# 2. Flash TO light red (takes 0.1 seconds)
	tween.tween_property($UI/ColorRect, "color", light_red, 0.1).set_trans(Tween.TRANS_SINE)
	
	# 3. Fade BACK to transparent (takes 0.2 seconds)
	tween.tween_property($UI/ColorRect, "color", transparent, 0.2).set_trans(Tween.TRANS_SINE)
