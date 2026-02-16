@tool
extends EditorScript

# SET YOUR FOLDERS HERE
const FBX_DIR = "res://assets/models/PSX_Dungeon/Models/"  # Folder where your FBXs are
const SAVE_DIR = "res://scenes/model_scenes/"      # Folder to save the new .tscn files

func _run():
	var dir = DirAccess.open(FBX_DIR)
	if !dir: return
	
	dir.list_dir_begin()
	var file_name = dir.get_next()

	while file_name != "":
		if file_name.ends_with(".fbx"):
			process_fbx(file_name)
		file_name = dir.get_next()
	print("--- Clean Generation Complete ---")

func process_fbx(file_name: String):
	var fbx_path = FBX_DIR + file_name
	var fbx_resource = load(fbx_path)
	if not fbx_resource: return
		
	var fbx_instance = fbx_resource.instantiate()
	var root = Node3D.new()
	root.name = file_name.get_basename()
	
	# 1. Calculate the center before we do anything
	var center = get_combined_aabb_center(fbx_instance)
	
	# 2. Find all meshes and move them to our NEW root
	var meshes = fbx_instance.find_children("*", "MeshInstance3D")
	for m in meshes:
		var new_mesh_node = MeshInstance3D.new()
		new_mesh_node.name = m.name
		new_mesh_node.mesh = m.mesh
		
		# Transfer the transform and apply the centering offset
		# This effectively "bakes" the FBX offset into the new node
		var absolute_transform = get_relative_transform(m, fbx_instance)
		new_mesh_node.transform = absolute_transform
		new_mesh_node.position -= center
		
		root.add_child(new_mesh_node)
		new_mesh_node.owner = root
		
		# Transfer materials if they exist
		for i in m.get_surface_override_material_count():
			new_mesh_node.set_surface_override_material(i, m.get_surface_override_material(i))

	# 3. Save the new root as a standalone scene
	var packed = PackedScene.new()
	packed.pack(root)
	
	var save_path = SAVE_DIR + file_name.get_basename() + ".tscn"
	ResourceSaver.save(packed, save_path)
	
	# Cleanup memory
	fbx_instance.free()
	root.free()

func get_relative_transform(node: Node3D, root_node: Node3D) -> Transform3D:
	var t = node.transform
	var parent = node.get_parent()
	while parent != null and parent != root_node:
		if parent is Node3D:
			t = parent.transform * t
		parent = parent.get_parent()
	return t

func get_combined_aabb_center(root_node: Node3D) -> Vector3:
	var full_aabb = AABB()
	var first = true
	var meshes = root_node.find_children("*", "MeshInstance3D")
	for m in meshes:
		if m.mesh:
			var world_style_aabb = get_relative_transform(m, root_node) * m.mesh.get_aabb()
			if first:
				full_aabb = world_style_aabb
				first = false
			else:
				full_aabb = full_aabb.merge(world_style_aabb)
	return full_aabb.get_center()
