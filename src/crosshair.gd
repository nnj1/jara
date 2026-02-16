extends Sprite2D

## Path to the folder containing your crosshair .png files
@export_dir var crosshair_folder: String = "res://assets/sprites/kenney_crosshairPack/PNG/White/"

var crosshair_textures: Array[Texture2D] = []
var current_index: int = 0

func _ready() -> void:
	load_crosshairs()
	update_sprite()
	# Keeps the cursor hidden so only your sprite shows
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN

func _unhandled_input(event: InputEvent) -> void:
	# Keep the sprite locked to the mouse position
	#if event is InputEventMouseMotion:
	#	global_position = event.position

	# Change crosshair when Tab is pressed
	if event.is_action_pressed("ui_focus_next") or (event is InputEventKey and event.keycode == KEY_TAB):
		# We check !event.is_echo() so it only triggers once per physical press
		if event.pressed and !event.is_echo():
			change_crosshair(1)
	pass

func load_crosshairs() -> void:
	var dir = DirAccess.open(crosshair_folder)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		
		while file_name != "":
			# Ignore folders and the .import sidecar files
			if !dir.current_is_dir() and file_name.ends_with(".png"):
				var full_path = crosshair_folder + "/" + file_name
				var tex = ResourceLoader.load(full_path) as Texture2D
				if tex:
					crosshair_textures.append(tex)
			
			file_name = dir.get_next()
	else:
		push_error("Directory path not found: " + crosshair_folder)

func change_crosshair(direction: int) -> void:
	if crosshair_textures.is_empty():
		return
		
	# Cycle to the next index and wrap around to 0 at the end
	current_index = (current_index + direction) % crosshair_textures.size()
	update_sprite()

func update_sprite() -> void:
	if !crosshair_textures.is_empty():
		texture = crosshair_textures[current_index]
