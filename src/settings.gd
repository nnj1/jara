extends Panel

# Node references
@onready var music_slider = $VBoxContainer/HBoxContainer/HSlider
@onready var sfx_slider = $VBoxContainer/HBoxContainer2/HSlider
@onready var master_slider = $VBoxContainer/HBoxContainer3/HSlider
@onready var res_options = $VBoxContainer/HBoxContainer4/OptionButton
@onready var fullscreen_toggle = $VBoxContainer/HBoxContainer4/CheckBox # Add this to your scene!
@onready var main_menu_btn = $VBoxContainer/Button
@onready var exit_desktop_btn = $VBoxContainer/Button2
@onready var post_processor_options = $VBoxContainer/HBoxContainer5/OptionButton

@onready var master_bus_index: int = AudioServer.get_bus_index("Master")

# Resolution table
var resolutions: Dictionary = {
	"1280x720 (HD)": Vector2i(1280, 720),
	"1366x768 (Laptop)": Vector2i(1366, 768),
	"1600x900": Vector2i(1600, 900),
	"1920x1080 (FHD)": Vector2i(1920, 1080),
	"2560x1440 (2K)": Vector2i(2560, 1440),
	"3840x2160 (4K)": Vector2i(3840, 2160),
	"2560x1080 (Ultrawide)": Vector2i(2560, 1080),
	"3440x1440 (Ultrawide)": Vector2i(3440, 1440)
}

func _ready():
	# 1. Initialize Audio
	setup_audio_slider(master_slider, "Master")
	setup_audio_slider(music_slider, "Music")
	setup_audio_slider(sfx_slider, "Sfx")
	
	# 2. Initialize Resolutions
	setup_resolution_menu()
	
	# 3. Initialize Fullscreen Toggle
	# Set toggle to match current window state
	fullscreen_toggle.button_pressed = ((get_window().mode == Window.MODE_EXCLUSIVE_FULLSCREEN) or (get_window().mode == Window.MODE_FULLSCREEN))
	fullscreen_toggle.toggled.connect(_on_fullscreen_toggled)
	
	# 4. Connect Navigation Buttons
	main_menu_btn.pressed.connect(_on_main_menu_pressed)
	exit_desktop_btn.pressed.connect(_on_exit_desktop_pressed)

	
	# 5. Initialize PSX audio options
	var is_currently_on = AudioServer.is_bus_effect_enabled(master_bus_index, 0)
	if is_currently_on:
		$VBoxContainer/HBoxContainer5/CheckBox.button_pressed = true
	else:
		$VBoxContainer/HBoxContainer5/CheckBox.button_pressed = false
	
	# 5. Initialize post-processor options
	var current_shader_file_name = GlobalVars.get_shader_file_name(PostProcessor.get_node('ColorRect').material)
	for shader_file in GlobalVars.get_files_with_extension('res://shaders/post/','.gdshader'):
		post_processor_options.add_item(shader_file)
	GlobalVars.select_option_by_value(post_processor_options, current_shader_file_name)
			
	
# --- Audio Logic ---

func setup_audio_slider(slider: HSlider, bus_name: String):
	var bus_index = AudioServer.get_bus_index(bus_name)
	if bus_index == -1:
		push_warning("Audio bus '" + bus_name + "' not found!")
		return
		
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.value = 0.5 
	
	_apply_volume_logic(bus_index, 0.5)
	
	slider.value_changed.connect(func(value):
		_apply_volume_logic(bus_index, value)
	)

func _apply_volume_logic(bus_index: int, slider_value: float):
	if slider_value <= 0.0:
		AudioServer.set_bus_mute(bus_index, true)
	else:
		AudioServer.set_bus_mute(bus_index, false)
		var db_val = (slider_value - 0.5) * 40
		AudioServer.set_bus_volume_db(bus_index, db_val)

# --- Video Logic ---

func setup_resolution_menu():
	res_options.clear()
	var def_w = ProjectSettings.get_setting("display/window/size/viewport_width")
	var def_h = ProjectSettings.get_setting("display/window/size/viewport_height")
	var default_res = Vector2i(def_w, def_h)
	
	res_options.add_item("Default (%dx%d)" % [def_w, def_h])
	res_options.set_item_metadata(0, default_res)
	
	var i = 1
	for res_name in resolutions:
		res_options.add_item(res_name)
		res_options.set_item_metadata(i, resolutions[res_name])
		i += 1
	res_options.item_selected.connect(_on_resolution_selected)

func _on_resolution_selected(index: int):
	var target_size = res_options.get_item_metadata(index)
	
	# If we change resolution, it's usually best to drop out of fullscreen
	fullscreen_toggle.button_pressed = false
	get_window().mode = Window.MODE_WINDOWED
	
	get_window().size = target_size
	
	# Center window
	var screen_rect = DisplayServer.screen_get_usable_rect(get_window().current_screen)
	var window_pos = screen_rect.position + (screen_rect.size / 2) - (target_size / 2)
	get_window().position = Vector2i(window_pos)

func _on_fullscreen_toggled(is_pressed: bool):
	if is_pressed:
		get_window().mode = Window.MODE_EXCLUSIVE_FULLSCREEN
	else:
		get_window().mode = Window.MODE_WINDOWED
		# Center the window again when returning to windowed mode
		_on_resolution_selected(res_options.selected)

# --- Navigation Logic ---

func _on_main_menu_pressed():
	MultiplayerManager.leave_game()
	get_tree().change_scene_to_file("res://scenes/main_scenes/main.tscn")

func _on_exit_desktop_pressed():
	MultiplayerManager.leave_game()
	get_tree().quit()


## Disables all effects on the Master bus
func disable_psx_effects():
	var effect_count = AudioServer.get_bus_effect_count(master_bus_index)
	for i in range(effect_count):
		AudioServer.set_bus_effect_enabled(master_bus_index, i, false)
	print("PSX Effects Disabled: Audio is now modern/clean.")

## Enables all effects on the Master bus
func enable_psx_effects():
	var effect_count = AudioServer.get_bus_effect_count(master_bus_index)
	for i in range(effect_count):
		AudioServer.set_bus_effect_enabled(master_bus_index, i, true)
	print("PSX Effects Enabled: Time to party like it's 1996.")

func _on_check_box_toggled(toggled_on: bool) -> void:
	if not toggled_on:
		disable_psx_effects()
	else:
		enable_psx_effects()

func _on_option_button_item_selected(index: int) -> void:
	var shader_path = 'res://shaders/post/' + post_processor_options.get_item_text(index)
	PostProcessor.get_node('ColorRect').material.shader = GlobalVars.load_resource_from_path(shader_path)
