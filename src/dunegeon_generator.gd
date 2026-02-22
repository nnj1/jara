extends Node3D

# --- RNG & Synchronization ---
var rng := RandomNumberGenerator.new()
var is_generated: bool = false

# SOME DEBUG SETTINGS
@export var VIEW_ROOM_BOUNDING_BOXES: bool = true
@export var VIEW_ROOM_CONNECTORS: bool = true
@export var VIEW_COORIDOR_BOUNDING_BOXES: bool = true

@export_category('Dungeon Models')

# FLOORS
@onready var floor_tile_scene: PackedScene = preload('res://scenes/model_scenes/structures/Floor_Tiles.tscn')

# WALLS
@onready var wall_01_scene: PackedScene = preload('res://scenes/model_scenes/structures/Wall_01.tscn')
@onready var wall_02_scene: PackedScene = preload('res://scenes/model_scenes/structures/Wall_02.tscn')
@onready var wall_border_01_scene: PackedScene = preload('res://scenes/model_scenes/structures/Wall_Border_01.tscn')
@onready var wall_border_02_scene: PackedScene = preload('res://scenes/model_scenes/structures/Wall_Border_02.tscn')
@onready var wall_ruin_scene: PackedScene = preload('res://scenes/model_scenes/structures/Wall_Ruin.tscn')
@onready var wall_windowed_01_scene: PackedScene = preload('res://scenes/model_scenes/structures/Windowed_Wall_01.tscn')
@onready var wall_windowed_02_scene: PackedScene = preload('res://scenes/model_scenes/structures/Windowed_Wall_02.tscn')
@onready var wall_skull_scene: PackedScene = preload('res://scenes/model_scenes/structures/Skull_Wall.tscn')

@onready var all_walls = [wall_01_scene, wall_02_scene, wall_ruin_scene, wall_windowed_01_scene, wall_windowed_02_scene, wall_skull_scene]
@onready var all_non_window_walls = [wall_01_scene, wall_02_scene, wall_ruin_scene, wall_skull_scene]
@onready var all_window_walls = [wall_windowed_01_scene, wall_windowed_02_scene]
@onready var all_wall_borders = [wall_border_01_scene, wall_border_02_scene]

# WALL DECORATORS
@onready var wall_table_scene: PackedScene = preload('res://scenes/model_scenes/structures/Wall_Table.tscn')

# DOORS AND DOOR FRAMES
@onready var door_frame_01_scene: PackedScene = preload('res://scenes/model_scenes/structures/Door_Frame_01.tscn')
@onready var door_frame_02_scene: PackedScene = preload('res://scenes/model_scenes/structures/Door_Frame_02.tscn')
@onready var door_01_scene: PackedScene = preload('res://scenes/model_scenes/structures/Door_01.tscn')
@onready var door_02_scene: PackedScene = preload('res://scenes/model_scenes/structures/Door_02.tscn')
@onready var door_03_scene: PackedScene = preload('res://scenes/model_scenes/structures/Door_03.tscn')
@onready var all_door_frames = [door_frame_01_scene, door_frame_02_scene]
@onready var all_doors = [door_01_scene, door_02_scene, door_03_scene]

# FLOOR DECORATORS
@onready var hexagon_scene: PackedScene = preload('res://scenes/model_scenes/structures/Hexagon.tscn')
@onready var debris_scene: PackedScene = preload('res://scenes/model_scenes/structures/Debris.tscn')
@onready var barrel_scene: PackedScene = preload('res://scenes/model_scenes/entities/Barrel.tscn')
@onready var chest_scene: PackedScene = preload('res://scenes/model_scenes/entities/Chest.tscn')
@onready var box_scene: PackedScene = preload('res://scenes/model_scenes/entities/Box.tscn')
@onready var spike_scene: PackedScene = preload('res://scenes/model_scenes/structures/Spikes.tscn')
@onready var skull_scene: PackedScene = preload('res://scenes/model_scenes/entities/Skull.tscn')

# PILLARS
@onready var pillar_scene: PackedScene = preload('res://scenes/model_scenes/structures/Pillar.tscn')
@onready var pillar_collapsed_1_scene: PackedScene = preload('res://scenes/model_scenes/structures/Pillar_Collapsed_01.tscn')
@onready var pillar_collapsed_2_scene: PackedScene = preload('res://scenes/model_scenes/structures/Pillar_Collapsed_02.tscn')
@onready var all_pillars = [pillar_scene, pillar_collapsed_1_scene, pillar_collapsed_2_scene]

# ROOF THINGS
@onready var arch_roof_scene: PackedScene = preload('res://scenes/model_scenes/structures/Arch_Roof.tscn')
@onready var arch_scene: PackedScene = preload('res://scenes/model_scenes/structures/Arch.tscn')
@onready var arch_fence_scene: PackedScene = preload('res://scenes/model_scenes/structures/Arch_Fence.tscn')
@onready var block_arch_scene: PackedScene = preload('res://scenes/model_scenes/structures/Block_Arch.tscn')
@onready var block_scene: PackedScene = preload('res://scenes/model_scenes/structures/Block.tscn')
@onready var chandelier_scene: PackedScene = preload('res://scenes/model_scenes/structures/Chandelier.tscn')

# STAIR THINGS
@onready var stair_scene: PackedScene = preload('res://scenes/model_scenes/structures/Arch_Roof.tscn')
enum ORIENT {POS_X, NEG_X, POS_Z, NEG_Z}

@export_category('Dungeon Settings')
@export var unit_size: float = 20.0
@export var max_width_units: int = 50   # X (Horizontal)
@export var max_height_units: int = 50  # Z (Horizontal)
@export var max_depth_units: int = 20   # Y (Vertical)

@export_category('Room Settings')
@export var room_count: int = 10
@export var min_room_width_units: int = 4
@export var max_room_width_units: int = 16
@export var min_room_height_units: int = 4
@export var max_room_height_units: int = 16
@export var min_room_depth_units: int = 2   # Vertical Min
@export var max_room_depth_units: int = 4   # Vertical Max

@export_category('Spacing Settings')
@export var min_room_width_spacing: int = 4
@export var min_room_height_spacing: int = 4 # Z spacing
@export var min_room_depth_spacing: int = 4  # Y spacing (Vertical)

@export_category('Hallway Settings')
@export var default_hallway_size: Vector3i = Vector3i(1, 1, 1) # X, Y, Z in units

enum ROOM_TYPES {START, BOSS, TREASURE, END, OTHER}
var rooms = []
var hallway_segments = []

func _ready() -> void:
	rng.randomize()
	draw_dungeon_outline()
	generate_rooms()
	var connection_matrix = generate_connections()
	generate_hallways(connection_matrix)
	actually_populate_rooms()
	center_camera()

func center_camera():
	# Position the camera to see the whole dungeon from above
	if has_node("flying_camera"):
		$flying_camera.global_position = Vector3(
			max_width_units * unit_size / 2, 
			max_depth_units * unit_size + 100,  
			max_height_units * unit_size / 2
		)

func generate_connections() -> Dictionary:
	# initialize the connection matrix to be a pure identity matrix
	var connection_matrix = {}
	var i = 0
	for room in rooms:
		connection_matrix[i] = {}
		var j = 0
		for otherroom in rooms:
			if room == otherroom:
				# every room should technically be connected to itself
				connection_matrix[i][j] = true
			else:
				connection_matrix[i][j] = false
			j += 1
		i += 1
		
	## THIS IS WHERE THE APPROPRIATE ALGORITHIM NEEDS TO BE USED
	## FOR NOW WE WILL USE A SHITTY 2 NEAREST NEIGHBORS THING
	i = 0
	for room in rooms:
		var distances_to_other_rooms = []
		for other_room in rooms:
			distances_to_other_rooms.append(get_room_center(room).distance_squared_to(get_room_center(other_room)))
		# now sort those distances and grab the closest two rooms
		var first_neighbor_index = get_nth_smallest_index(distances_to_other_rooms, 2)
		var second_neighbor_index = get_nth_smallest_index(distances_to_other_rooms, 3)
		connection_matrix[i][first_neighbor_index] = true
		connection_matrix[i][second_neighbor_index] = true
		i += 1	
		
	# draw the connections for debugging purposes
	if VIEW_ROOM_CONNECTORS:
		i = 0
		for room in rooms:
			var j = 0
			for room2 in connection_matrix[i]:
				if connection_matrix[i][j] and i != j:
					draw_dashed_line(get_room_center(rooms[i]), get_room_center(rooms[j]))  
				j += 1
			i += 1
	
	return connection_matrix
	
func generate_rooms():
	var attempts = 0
	var max_attempts = 2000 
	
	while rooms.size() < room_count and attempts < max_attempts:
		attempts += 1
		
		# 1. Randomize dimensions
		var w = rng.randi_range(min_room_width_units, max_room_width_units)
		var h = rng.randi_range(min_room_height_units, max_room_height_units)
		var d = rng.randi_range(min_room_depth_units, max_room_depth_units) # Vertical
		
		# 2. Randomize position (within bounds)
		var x = rng.randi_range(0, max_width_units - w)
		var z = rng.randi_range(0, max_height_units - h)
		var y = rng.randi_range(0, max_depth_units - d) # Vertical Position
		
		var new_room_data = {
			'width': w,
			'height': h,
			'depth': d,
			'x_unit_bounds': Vector2(x, x + w),
			'y_unit_bounds': Vector2(y, y + d), # Depth -> Y
			'z_unit_bounds': Vector2(z, z + h), # Height -> Z
			'type': ROOM_TYPES.OTHER
		}
		
		# 3. Overlap check with spacing
		if not is_overlapping(new_room_data):
			# Assign types based on current array size
			if rooms.size() == 0:
				new_room_data.type = ROOM_TYPES.START
			elif rooms.size() == room_count - 2:
				new_room_data.type = ROOM_TYPES.BOSS
			elif rooms.size() == room_count - 1:
				new_room_data.type = ROOM_TYPES.END
			elif rng.randf() < 0.25:
				new_room_data.type = ROOM_TYPES.TREASURE
			else:
				new_room_data.type = ROOM_TYPES.OTHER
				
			rooms.append(new_room_data)
			create_room(new_room_data)
	
	print("Rooms Generated: ", rooms.size(), " rooms placed in ", attempts, " attempts.")

func is_overlapping(new_room: Dictionary) -> bool:
	for r in rooms:
		# We check if (Room A + Spacing) overlaps Room B
		var x_overlap = new_room.x_unit_bounds.y + min_room_width_spacing > r.x_unit_bounds.x and \
						new_room.x_unit_bounds.x < r.x_unit_bounds.y + min_room_width_spacing
						
		var y_overlap = new_room.y_unit_bounds.y + min_room_depth_spacing > r.y_unit_bounds.x and \
						new_room.y_unit_bounds.x < r.y_unit_bounds.y + min_room_depth_spacing
						
		var z_overlap = new_room.z_unit_bounds.y + min_room_height_spacing > r.z_unit_bounds.x and \
						new_room.z_unit_bounds.x < r.z_unit_bounds.y + min_room_height_spacing
		
		if x_overlap and y_overlap and z_overlap:
			return true
	return false
	
func actually_populate_rooms():
	for room_data in rooms:
		# Add floors
		for unit_x in range(room_data.x_unit_bounds[0], room_data.x_unit_bounds[1]):
			for unit_z in range(room_data.z_unit_bounds[0], room_data.z_unit_bounds[1]):
				place_floor_tile(unit_x, unit_z, room_data.y_unit_bounds[0])
		
		# Add roof 
		for unit_x in range(room_data.x_unit_bounds[0], room_data.x_unit_bounds[1]):
			for unit_z in range(room_data.z_unit_bounds[0], room_data.z_unit_bounds[1]):
				place_block(unit_x, unit_z, room_data.y_unit_bounds[1])
				if rng.randf() < 0.25:
					place_chandelier(unit_x, unit_z, room_data.y_unit_bounds[1] - 1)
		
		# Add wall borders
		for unit_x in range(room_data.x_unit_bounds[0], room_data.x_unit_bounds[1]):
			place_x_wall_border(unit_x, room_data.z_unit_bounds[0], room_data.y_unit_bounds[0])
		for unit_z in range(room_data.z_unit_bounds[0], room_data.z_unit_bounds[1]):
			place_z_wall_border(room_data.x_unit_bounds[0], unit_z, room_data.y_unit_bounds[0])
		for unit_x in range(room_data.x_unit_bounds[0], room_data.x_unit_bounds[1]):
			place_x_wall_border(unit_x, room_data.z_unit_bounds[1], room_data.y_unit_bounds[0])
		for unit_z in range(room_data.z_unit_bounds[0], room_data.z_unit_bounds[1]):
			place_z_wall_border(room_data.x_unit_bounds[1], unit_z, room_data.y_unit_bounds[0])
		
		# Add walls
		var y_unit_offsets = []
		for y_unit in range(room_data.depth - 1):
			y_unit_offsets.append(y_unit + 0.5)
			
		for y_unit_offset in y_unit_offsets:
			for unit_x in range(room_data.x_unit_bounds[0], room_data.x_unit_bounds[1]):
				place_x_wall(unit_x, room_data.z_unit_bounds[0],room_data.y_unit_bounds[0] + y_unit_offset)
			for unit_z in range(room_data.z_unit_bounds[0], room_data.z_unit_bounds[1]):
				place_z_wall(room_data.x_unit_bounds[0], unit_z, room_data.y_unit_bounds[0] + y_unit_offset)
			for unit_x in range(room_data.x_unit_bounds[0], room_data.x_unit_bounds[1]):
				place_x_wall(unit_x, room_data.z_unit_bounds[1], room_data.y_unit_bounds[0] + y_unit_offset)
			for unit_z in range(room_data.z_unit_bounds[0], room_data.z_unit_bounds[1]):
				place_z_wall(room_data.x_unit_bounds[1], unit_z, room_data.y_unit_bounds[0] + y_unit_offset)
			
		# add the final thing
		for y_unit_offset in [room_data.depth - 0.5]:
			for unit_x in range(room_data.x_unit_bounds[0], room_data.x_unit_bounds[1]):
				place_x_arch(unit_x, room_data.z_unit_bounds[0],room_data.y_unit_bounds[0] + y_unit_offset)
				place_x_arch_fence(unit_x, room_data.z_unit_bounds[0],room_data.y_unit_bounds[0] + y_unit_offset)
			for unit_z in range(room_data.z_unit_bounds[0], room_data.z_unit_bounds[1]):
				place_z_arch(room_data.x_unit_bounds[0], unit_z, room_data.y_unit_bounds[0] + y_unit_offset)
				place_z_arch_fence(room_data.x_unit_bounds[0], unit_z, room_data.y_unit_bounds[0] + y_unit_offset)
			for unit_x in range(room_data.x_unit_bounds[0], room_data.x_unit_bounds[1]):
				place_x_arch(unit_x, room_data.z_unit_bounds[1], room_data.y_unit_bounds[0] + y_unit_offset)
				place_x_arch_fence(unit_x, room_data.z_unit_bounds[1], room_data.y_unit_bounds[0] + y_unit_offset)
			for unit_z in range(room_data.z_unit_bounds[0], room_data.z_unit_bounds[1]):
				place_z_arch(room_data.x_unit_bounds[1], unit_z, room_data.y_unit_bounds[0] + y_unit_offset)
				place_z_arch_fence(room_data.x_unit_bounds[1], unit_z, room_data.y_unit_bounds[0] + y_unit_offset)
			
func create_room(room_data: Dictionary) -> Node3D:
	var room_anchor = Node3D.new()
	room_anchor.name = "Room_" + str(rooms.size())
	
	# Mapping coordinates to Godot Vector3(X, Y, Z)
	room_anchor.position = Vector3(
		room_data.x_unit_bounds.x * unit_size,
		room_data.y_unit_bounds.x * unit_size, # Vertical
		room_data.z_unit_bounds.x * unit_size
	)
	
	var mesh_instance = MeshInstance3D.new()
	var box_mesh = BoxMesh.new()
	
	var visual_x = room_data.width * unit_size
	var visual_y = room_data.depth * unit_size   # Vertical thickness
	var visual_z = room_data.height * unit_size
	
	box_mesh.size = Vector3(visual_x, visual_y, visual_z)
	mesh_instance.mesh = box_mesh
	
	# Offset mesh so anchor is at the corner (min_x, min_y, min_z)
	mesh_instance.position = Vector3(visual_x / 2.0, visual_y / 2.0, visual_z / 2.0)
	
	apply_room_material(mesh_instance, room_data.type)
	
	# Room bounding box material
	if VIEW_ROOM_BOUNDING_BOXES:
		room_anchor.add_child(mesh_instance)
	
	add_child(room_anchor, true)
	return room_anchor

func apply_room_material(instance: MeshInstance3D, type: int):
	var room_color: Color
	match type:
		ROOM_TYPES.START: room_color = Color.GREEN
		ROOM_TYPES.BOSS: room_color = Color.PURPLE
		ROOM_TYPES.TREASURE: room_color = Color.GOLD
		ROOM_TYPES.END: room_color = Color.RED
		_: room_color = Color.GRAY

	# Ghostly Solid Body
	var main_mat = StandardMaterial3D.new()
	main_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	main_mat.albedo_color = room_color
	main_mat.albedo_color.a = 0.01
	main_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED 

	# Solid Black Edges
	var outline_mat = StandardMaterial3D.new()
	outline_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	outline_mat.albedo_color = Color.BLACK
	outline_mat.cull_mode = BaseMaterial3D.CULL_FRONT
	outline_mat.grow = true 
	outline_mat.grow_amount = 1.0 # Outline thickness
	outline_mat.render_priority = 1 

	main_mat.next_pass = outline_mat
	instance.material_override = main_mat
	
func draw_dungeon_outline():
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.name = "Dungeon_Outline_Edges"
	
	var immediate_mesh = ImmediateMesh.new()
	var material = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color.BLACK
	material.render_priority = 2 # Draw on top of everything
	
	var w = max_width_units * unit_size
	var h = max_depth_units * unit_size # Y
	var d = max_height_units * unit_size # Z
	
	immediate_mesh.surface_begin(Mesh.PRIMITIVE_LINES, material)
	var points = [
		Vector3(0,0,0), Vector3(w,0,0), Vector3(w,0,0), Vector3(w,0,d),
		Vector3(w,0,d), Vector3(0,0,d), Vector3(0,0,d), Vector3(0,0,0),
		Vector3(0,h,0), Vector3(w,h,0), Vector3(w,h,0), Vector3(w,h,d),
		Vector3(w,h,d), Vector3(0,h,d), Vector3(0,h,d), Vector3(0,h,0),
		Vector3(0,0,0), Vector3(0,h,0), Vector3(w,0,0), Vector3(w,h,0),
		Vector3(w,0,d), Vector3(w,h,d), Vector3(0,0,d), Vector3(0,h,d)
	]
	for p in points:
		immediate_mesh.surface_add_vertex(p)
	immediate_mesh.surface_end()
	
	mesh_instance.mesh = immediate_mesh
	add_child(mesh_instance)

# Returns the center of a room in 3D Godot coordinates
func get_room_center(room_data: Dictionary) -> Vector3:
	var x = (room_data.x_unit_bounds.x + room_data.x_unit_bounds.y) / 2.0
	var y = (room_data.y_unit_bounds.x + room_data.y_unit_bounds.y) / 2.0 # Vertical
	var z = (room_data.z_unit_bounds.x + room_data.z_unit_bounds.y) / 2.0 # Horizontal
	return Vector3(x * unit_size, y * unit_size, z * unit_size)

func draw_dashed_line(start_pos: Vector3, end_pos: Vector3, color: Color = Color.BLACK, dash_length: float = 5.0, gap_length: float = 5.0):
	var mesh_instance = MeshInstance3D.new()
	var immediate_mesh = ImmediateMesh.new()
	var material = StandardMaterial3D.new()

	# 1. Setup Material
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.render_priority = 3 # Ensure it draws over room fills

	# 2. Calculate segments
	var total_dist = start_pos.distance_to(end_pos)
	var direction = (end_pos - start_pos).normalized()
	var current_dist = 0.0
	
	immediate_mesh.surface_begin(Mesh.PRIMITIVE_LINES, material)
	
	while current_dist < total_dist:
		# Define the start of this specific dash
		var segment_start = start_pos + (direction * current_dist)
		
		# Ensure the dash doesn't overshot the end point
		var remaining_dist = total_dist - current_dist
		var current_dash_length = min(dash_length, remaining_dist)
		
		var segment_end = segment_start + (direction * current_dash_length)
		
		# Add the two points for this line segment
		immediate_mesh.surface_add_vertex(segment_start)
		immediate_mesh.surface_add_vertex(segment_end)
		
		# Move forward by the dash + the gap
		current_dist += dash_length + gap_length
		
	immediate_mesh.surface_end()
	
	mesh_instance.mesh = immediate_mesh
	add_child(mesh_instance)
	
## Returns the original index of the nth smallest value.
## n: 1 for smallest, 2 for second smallest, etc.
func get_nth_smallest_index(list: Array, n: int) -> int:
	# 1. Validation: Ensure n is within the bounds of the list
	if n < 1 or n > list.size():
		push_error("n is out of bounds for the given list.")
		return -1
	
	# 2. Create an array of indices [0, 1, 2, ...]
	var indices = range(list.size())
	
	# 3. Sort indices based on the values in the original list
	indices.sort_custom(func(a, b):
		return list[a] < list[b]
	)
	
	# 4. Return the index at position n-1
	return indices[n - 1]

## CODE TO GENERATE HALLWAYS
func generate_hallways(matrix: Dictionary):
	var processed_connections = []
	var hallway_container = Node3D.new()
	hallway_container.name = "Hallways"
	add_child(hallway_container)
	
	for i in matrix.keys():
		for j in matrix[i].keys():
			if matrix[i][j] and i != j and not [j, i] in processed_connections:
				# You can pass different Vector3i sizes here if you want!
				create_corridor(rooms[i], rooms[j], hallway_container, default_hallway_size)
				processed_connections.append([i, j])

func create_corridor(room_a: Dictionary, room_b: Dictionary, container: Node3D, h_size: Vector3i):
	var start_pos = get_wall_connection_point(room_a, room_b, h_size)
	var end_pos = get_wall_connection_point(room_b, room_a, h_size)
	
	var current = start_pos
	
	# 1. MOVE HORIZONTALLY (X)
	while current.x != end_pos.x:
		spawn_hallway_segment(current, container, h_size)
		current.x += clampi(end_pos.x - current.x, -h_size.x, h_size.x)
	
	# 2. MOVE HORIZONTALLY (Z)
	while current.z != end_pos.z:
		spawn_hallway_segment(current, container, h_size)
		current.z += clampi(end_pos.z - current.z, -h_size.z, h_size.z)

	# 3. MOVE VERTICALLY (Y) - The "Shaft" or "Landing"
	# This now happens at the corner where X and Z are already aligned
	while current.y != end_pos.y:
		spawn_hallway_segment(current, container, h_size)
		current.y += clampi(end_pos.y - current.y, -h_size.y, h_size.y)

	# 4. FINAL SEGMENT
	spawn_hallway_segment(end_pos, container, h_size)
	
# Helper function to find the point on the wall closest to the target room
func get_wall_connection_point(from_room: Dictionary, to_room: Dictionary, h_size: Vector3i) -> Vector3i:
	var center_from = get_room_center(from_room) / unit_size
	var center_to = get_room_center(to_room) / unit_size
	var diff = center_to - center_from
	var out_point = Vector3i()
	
	# Logic: Exit the wall that faces the target room most directly
	if abs(diff.x) > abs(diff.z):
		# Exit Left/Right wall
		var x_pos = from_room.x_unit_bounds.y if diff.x > 0 else from_room.x_unit_bounds.x - h_size.x
		out_point = Vector3i(
			int(x_pos),
			int(from_room.y_unit_bounds.x), # Floor level
			int((from_room.z_unit_bounds.x + from_room.z_unit_bounds.y) / 2.0 - (h_size.z / 2.0))
		)
	else:
		# Exit Front/Back wall
		var z_pos = from_room.z_unit_bounds.y if diff.z > 0 else from_room.z_unit_bounds.x - h_size.z
		out_point = Vector3i(
			int((from_room.x_unit_bounds.x + from_room.x_unit_bounds.y) / 2.0 - (h_size.x / 2.0)),
			int(from_room.y_unit_bounds.x), # Floor level
			int(z_pos)
		)
	return out_point
	
func spawn_hallway_segment(grid_pos: Vector3i, container: Node3D, h_size: Vector3i):
	var segment_name = "Hall_%d_%d_%d" % [grid_pos.x, grid_pos.y, grid_pos.z]
	if container.has_node(segment_name): return 

	# 1. STRICT ROOM CHECK
	# We check if this segment's BOUNDS overlap a room's BOUNDS.
	if is_hallway_overlapping_room(grid_pos, h_size):
		return 

	var mesh_instance = MeshInstance3D.new()
	mesh_instance.name = segment_name
	
	var box = BoxMesh.new()
	var visual_size = Vector3(h_size.x * unit_size, h_size.y * unit_size, h_size.z * unit_size)
	box.size = visual_size
	mesh_instance.mesh = box
	
	# 2. ANCHOR POSITIONING (Matching create_room logic)
	# This sets the "corner" of the hallway at the grid_pos
	mesh_instance.position = Vector3(
		grid_pos.x * unit_size + (visual_size.x / 2.0),
		grid_pos.y * unit_size + (visual_size.y / 2.0),
		grid_pos.z * unit_size + (visual_size.z / 2.0)
	)
	
	# Material Setup
	var main_mat = StandardMaterial3D.new()
	main_mat.albedo_color = get_random_bright_color()
	main_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	
	var outline_mat = StandardMaterial3D.new()
	outline_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	outline_mat.albedo_color = Color.BLACK
	outline_mat.cull_mode = BaseMaterial3D.CULL_FRONT
	outline_mat.grow = true
	outline_mat.grow_amount = 0.5
	
	main_mat.next_pass = outline_mat
	mesh_instance.material_override = main_mat
	container.add_child(mesh_instance)
	
	hallway_segments.append({
		'grid_pos': grid_pos
	})


func is_hallway_overlapping_room(pos: Vector3i, h_size: Vector3i) -> bool:
	# Define hallway bounds based on its anchor (pos) and its size (h_size)
	var h_x_min = pos.x
	var h_x_max = pos.x + h_size.x
	var h_y_min = pos.y
	var h_y_max = pos.y + h_size.y
	var h_z_min = pos.z
	var h_z_max = pos.z + h_size.z

	for room in rooms:
		# Standard AABB overlap check
		var x_overlap = h_x_max > room.x_unit_bounds.x and h_x_min < room.x_unit_bounds.y
		var y_overlap = h_y_max > room.y_unit_bounds.x and h_y_min < room.y_unit_bounds.y
		var z_overlap = h_z_max > room.z_unit_bounds.x and h_z_min < room.z_unit_bounds.y
		
		if x_overlap and y_overlap and z_overlap:
			return true
	return false

## ENVIRONMENT PLACEMENT FUNCTIONS

func place_floor_tile(x_unit, z_unit, y_unit = 0.0):
	var floor_instance = floor_tile_scene.instantiate()
	floor_instance.position = Vector3(x_unit * unit_size + 10.0, y_unit * unit_size, z_unit * unit_size + 10.0)
	self.add_child(floor_instance)
	
func place_stair(x_unit, z_unit, y_unit = 0.0, orientation = ORIENT.POS_X):
	var stair_instance = stair_scene.instantiate()
	var aabb_size = get_first_mesh_size(stair_instance)
	match orientation:
		ORIENT.NEG_X: stair_instance.rotation.y = PI
		ORIENT.POS_Z: stair_instance.rotation.y = 3*PI/2
		ORIENT.NEG_Z: stair_instance.rotation.y = PI/2
	stair_instance.position = Vector3(x_unit * unit_size + aabb_size.z/2.0, y_unit * unit_size + aabb_size.y/2.0, z_unit * unit_size + aabb_size.x/2.0)
	self.add_child(stair_instance)
	
func place_hexagon(x_unit, z_unit, y_unit = 0.0):
	var hexagon_instance = hexagon_scene.instantiate()
	var aabb_size = get_first_mesh_size(hexagon_instance)
	hexagon_instance.position = Vector3(x_unit * unit_size + aabb_size.x/2.0, y_unit * unit_size + aabb_size.y/2.0, z_unit * unit_size + aabb_size.z/2.0)
	self.add_child(hexagon_instance)

func place_arch_roof(x_unit, z_unit, y_unit = 1.0):
	var arch_roof_instance = arch_roof_scene.instantiate()
	var aabb_size = get_first_mesh_size(arch_roof_instance)
	arch_roof_instance.position = Vector3(x_unit * unit_size + aabb_size.x/2.0, y_unit * unit_size + aabb_size.y/2.0, z_unit * unit_size + aabb_size.z/2.0)
	self.add_child(arch_roof_instance)

func place_pillar(x_unit, z_unit, y_unit = 0.0):
	var selected_pillar = all_pillars[rng.randi() % all_pillars.size()]
	var pillar_instance = selected_pillar.instantiate()
	var aabb_size = get_first_mesh_size(pillar_instance)
	pillar_instance.position = Vector3(x_unit * unit_size + aabb_size.x/2.0, y_unit * unit_size + aabb_size.y/2.0, z_unit * unit_size + aabb_size.z/2.0)
	if selected_pillar == pillar_collapsed_2_scene:
		pillar_instance.rotation.y = rng.randf_range(0, 2*PI)
	self.add_child(pillar_instance)
	
func place_spike(x_unit, z_unit, y_unit = 0.0):
	var spike_instance = spike_scene.instantiate()
	var aabb_size = get_first_mesh_size(spike_instance)
	spike_instance.position = Vector3(x_unit * unit_size + aabb_size.x/2.0 + 3, y_unit * unit_size + aabb_size.y/2.0, z_unit * unit_size + aabb_size.z/2.0 + 1)
	self.add_child(spike_instance)
	
func place_debris(x_unit, z_unit, y_unit = 0.0):
	var debris_instance = debris_scene.instantiate()
	var aabb_size = get_first_mesh_size(debris_instance)
	debris_instance.position = Vector3(x_unit * unit_size + aabb_size.x/2.0 + rng.randf_range(0, 20), y_unit * unit_size + aabb_size.y/2.0, z_unit * unit_size + aabb_size.z/2.0 + rng.randf_range(0, 20))
	debris_instance.rotation.y = rng.randf_range(0, 2*PI)
	self.add_child(debris_instance)

func place_x_arch(x_unit, z_unit, y_unit = 1.0):
	var arch_instance = arch_scene.instantiate()
	var aabb_size = get_first_mesh_size(arch_instance)
	arch_instance.position = Vector3(x_unit * unit_size + aabb_size.x/2.0, y_unit * unit_size + aabb_size.y/2.0, z_unit * unit_size + aabb_size.z/2.0)
	self.add_child(arch_instance)

func place_x_arch_fence(x_unit, z_unit, y_unit = 1.0):
	var arch_fence_instance = arch_fence_scene.instantiate()
	var aabb_size = get_first_mesh_size(arch_fence_instance)
	arch_fence_instance.position = Vector3(x_unit * unit_size + aabb_size.x/2.0 + 2, y_unit * unit_size + aabb_size.y/2.0, z_unit * unit_size + aabb_size.z/2.0)
	self.add_child(arch_fence_instance)
	
func place_x_wall(x_unit, z_unit, y_unit = 0.0):
	var selected_wall = all_walls[rng.randi() % all_walls.size()]
	var wall_instance = selected_wall.instantiate()
	var aabb_size = get_first_mesh_size(wall_instance)
	wall_instance.position = Vector3(x_unit * unit_size + aabb_size.x/2.0, y_unit * unit_size + aabb_size.y/2.0, z_unit * unit_size + aabb_size.z/2.0)
	self.add_child(wall_instance)

func place_x_window_wall(x_unit, z_unit, y_unit = 0.0):
	var selected_wall = all_window_walls[rng.randi() % all_window_walls.size()]
	var wall_instance = selected_wall.instantiate()
	var aabb_size = get_first_mesh_size(wall_instance)
	wall_instance.position = Vector3(x_unit * unit_size + aabb_size.x/2.0, y_unit * unit_size + aabb_size.y/2.0, z_unit * unit_size + aabb_size.z/2.0)
	self.add_child(wall_instance)

func place_z_arch(x_unit, z_unit, y_unit = 1.0):
	var arch_instance = arch_scene.instantiate()
	var aabb_size = get_first_mesh_size(arch_instance)
	arch_instance.rotation.y = PI/2
	arch_instance.position = Vector3(x_unit * unit_size + aabb_size.z/2.0, y_unit * unit_size + aabb_size.y/2.0, z_unit * unit_size + aabb_size.x/2.0)
	self.add_child(arch_instance)
	
func place_z_arch_fence(x_unit, z_unit, y_unit = 1.0):
	var arch_fence_instance = arch_fence_scene.instantiate()
	var aabb_size = get_first_mesh_size(arch_fence_instance)
	arch_fence_instance.rotation.y = PI/2
	arch_fence_instance.position = Vector3(x_unit * unit_size + aabb_size.z/2.0, y_unit * unit_size + aabb_size.y/2.0, z_unit * unit_size + aabb_size.x/2.0 + 2)
	self.add_child(arch_fence_instance)
	
func place_z_wall(x_unit, z_unit, y_unit = 0.0):
	var selected_wall = all_walls[rng.randi() % all_walls.size()]
	var wall_instance = selected_wall.instantiate()
	var aabb_size = get_first_mesh_size(wall_instance)
	wall_instance.rotation.y = PI/2
	wall_instance.position = Vector3(x_unit * unit_size + aabb_size.z/2.0, y_unit * unit_size + aabb_size.y/2.0, z_unit * unit_size + aabb_size.x/2.0)
	self.add_child(wall_instance)

func place_z_window_wall(x_unit, z_unit, y_unit = 0.0):
	var selected_wall = all_window_walls[rng.randi() % all_window_walls.size()]
	var wall_instance = selected_wall.instantiate()
	var aabb_size = get_first_mesh_size(wall_instance)
	wall_instance.rotation.y = PI/2
	wall_instance.position = Vector3(x_unit * unit_size + aabb_size.z/2.0, y_unit * unit_size + aabb_size.y/2.0, z_unit * unit_size + aabb_size.x/2.0)
	self.add_child(wall_instance)

func place_x_wall_border(x_unit, z_unit, y_unit = 0.0):
	var selected_wall_border = all_wall_borders[rng.randi() % all_wall_borders.size()]
	var wall_border_instance = selected_wall_border.instantiate()
	var aabb_size = get_first_mesh_size(wall_border_instance)
	wall_border_instance.position = Vector3(x_unit * unit_size + aabb_size.x/2.0, y_unit * unit_size + aabb_size.y/2.0, z_unit * unit_size + aabb_size.z/2.0)
	self.add_child(wall_border_instance)

func place_z_wall_border(x_unit, z_unit, y_unit = 0.0):
	var selected_wall_border = all_wall_borders[rng.randi() % all_wall_borders.size()]
	var wall_border_instance = selected_wall_border.instantiate()
	var aabb_size = get_first_mesh_size(wall_border_instance)
	wall_border_instance.rotation.y = PI/2
	wall_border_instance.position = Vector3(x_unit * unit_size + aabb_size.z/2.0, y_unit * unit_size + aabb_size.y/2.0, z_unit * unit_size + aabb_size.x/2.0)
	self.add_child(wall_border_instance)

func place_x_door_frame(x_unit, z_unit, y_unit = 0.0):
	var selected_wall = all_door_frames[rng.randi() % all_door_frames.size()]
	var wall_instance = selected_wall.instantiate()
	var aabb_size = get_first_mesh_size(wall_instance)
	wall_instance.position = Vector3(x_unit * unit_size + aabb_size.x/2.0, y_unit * unit_size + aabb_size.y/2.0, z_unit * unit_size + aabb_size.z/2.0)
	self.add_child(wall_instance)

func place_z_door_frame(x_unit, z_unit, y_unit = 0.0):
	var selected_wall = all_door_frames[rng.randi() % all_door_frames.size()]
	var wall_instance = selected_wall.instantiate()
	var aabb_size = get_first_mesh_size(wall_instance)
	wall_instance.rotation.y = PI/2
	wall_instance.position = Vector3(x_unit * unit_size + aabb_size.z/2.0, y_unit * unit_size + aabb_size.y/2.0, z_unit * unit_size + aabb_size.x/2.0)
	self.add_child(wall_instance)

func place_block(x_unit, z_unit, y_unit = 2.0):
	var block_instance = block_scene.instantiate()
	var aabb_size = get_first_mesh_size(block_instance)
	block_instance.position = Vector3(x_unit * unit_size + aabb_size.x/2.0, y_unit * unit_size + aabb_size.y/2.0, z_unit * unit_size + aabb_size.z/2.0)
	self.add_child(block_instance)

func place_chandelier(x_unit, z_unit, y_unit = 2.0):
	var chandelier_instance = chandelier_scene.instantiate()
	var aabb_size = get_first_mesh_size(chandelier_instance)
	chandelier_instance.position = Vector3(x_unit * unit_size + aabb_size.x/2.0 + (unit_size - aabb_size.x)/2, y_unit * unit_size + aabb_size.y/2.0 + (unit_size - aabb_size.y), z_unit * unit_size + aabb_size.z/2.0 + (unit_size - aabb_size.z)/2)
	self.add_child(chandelier_instance)
	
## HELPER FUNCTIONS

func get_first_mesh_size(root_node: Node) -> Vector3:
	var mesh_instance = _find_first_mesh_instance(root_node)
	if mesh_instance and mesh_instance.mesh:
		var aabb: AABB = mesh_instance.get_mesh().get_aabb()
		return aabb.size * root_node.scale
	return Vector3.ZERO

func _find_first_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D: return node
	for child in node.get_children():
		var found = _find_first_mesh_instance(child)
		if found: return found
	return null
	
func get_random_bright_color() -> Color:
	# Hue: 0.0 to 1.0 (all colors of the rainbow)
	# Saturation: 0.7 to 1.0 (keeps it from looking washed out/white)
	# Value: 0.8 to 1.0 (keeps it from looking dark/black)
	return Color.from_hsv(randf(), randf_range(0.7, 1.0), randf_range(0.8, 1.0))
