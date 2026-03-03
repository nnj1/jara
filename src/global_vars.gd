extends Node

var lore_data = {}
var save_data = {}

func _ready() -> void:
	lore_data = load_json_with_resource_loader('res://lore/lore.json')

func save_json_to_user_dir(data: Dictionary, filename: String):
	# 1. Define the full path (user:// is the persistent save folder)
	var full_path = "user://" + filename
	
	# 2. Convert the Dictionary/Array into a formatted JSON string
	# The 'true' argument adds indentations (tabs) for human readability
	var json_string = JSON.stringify(data, "\t")
	
	# 3. Open the file for writing
	var file = FileAccess.open(full_path, FileAccess.WRITE)
	
	if file:
		# 4. Store the string and close the file
		file.store_string(json_string)
		file.close() # Good practice, though FileAccess closes when it leaves scope
		print("Successfully saved JSON to: ", ProjectSettings.globalize_path(full_path))
	else:
		push_error("Failed to open file for writing: " + full_path)
		
func load_json_with_resource_loader(path: String):
	# 1. Load the file as a JSON resource
	var json_resource = load(path) as JSON
	
	if json_resource:
		# 2. Access the 'data' property to get your Dictionary or Array
		return json_resource.data
		#print(data)
	else:
		push_error("Failed to load JSON resource at: " + path)
	
func get_files_with_extension(path: String, extension: String = "") -> Array:
	var files = []
	var dir = DirAccess.open(path)
	
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		
		while file_name != "":
			if not dir.current_is_dir():
				# Check if an extension filter is provided
				if extension == "" or file_name.ends_with(extension):
					files.append(file_name)
			file_name = dir.get_next()
	else:
		print("Error: Could not open path: ", path)
		
	return files

func load_resource_from_path(path: String) -> Resource:
	# Check if the file actually exists before trying to load it
	if not FileAccess.file_exists(path):
		printerr("Error: File does not exist at path: ", path)
		return null
		
	# ResourceLoader.load() is the standard way to bring assets into memory
	var resource = ResourceLoader.load(path)
	
	if resource:
		return resource
	else:
		printerr("Error: Failed to load resource at: ", path)
		return null

func get_shader_file_name(material: ShaderMaterial) -> String:
	if material and material.shader:
		# resource_path returns the full path (e.g., "res://shaders/fire.gdshader")
		var full_path = material.shader.resource_path
		
		# get_file() strips the directory and returns just the name
		return full_path.get_file()
		
	return "No shader found"

func select_option_by_value(option_menu: OptionButton, value: String) -> void:
	for i in range(option_menu.item_count):
		if option_menu.get_item_text(i) == value:
			option_menu.selected = i
			return
			
	push_warning("Value '" + value + "' not found in OptionButton.")
