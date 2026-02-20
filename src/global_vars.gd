extends Node

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
