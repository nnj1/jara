extends Node3D

# --- RNG & Synchronization ---
var rng := RandomNumberGenerator.new()
var is_generated: bool = false

# -- SETUP THE DUNGEON PLACER --
@onready var placer = get_node('PsxDungeonPlacer')

# SOME DEBUG SETTINGS
@export var VIEW_ROOM_BOUNDING_BOXES: bool = true
@export var VIEW_ROOM_CONNECTORS: bool = true
@export var VIEW_COORIDOR_BOUNDING_BOXES: bool = true

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
	placer.rng = rng
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
			'type': ROOM_TYPES.OTHER,
			'connections': [] 
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
				placer.place_floor_tile(unit_x, unit_z, room_data.y_unit_bounds[0])
		
		# Add roof 
		for unit_x in range(room_data.x_unit_bounds[0], room_data.x_unit_bounds[1]):
			for unit_z in range(room_data.z_unit_bounds[0], room_data.z_unit_bounds[1]):
				placer.place_block(unit_x, unit_z, room_data.y_unit_bounds[1])
				if rng.randf() < 0.25:
					placer.place_chandelier(unit_x, unit_z, room_data.y_unit_bounds[1] - 1)
		
		# Add wall borders and walls
		for unit_x in range(room_data.x_unit_bounds[0], room_data.x_unit_bounds[1] + 1):
			for unit_z in range(room_data.z_unit_bounds[0], room_data.z_unit_bounds[1] + 1):
				if unit_x == room_data.x_unit_bounds[0] or unit_x == room_data.x_unit_bounds[1]:
					
					# place border and first wall
					if not is_connection(room_data, Vector3i(unit_x, room_data.y_unit_bounds[0], unit_z)):
						placer.place_z_wall_border(unit_x, unit_z, room_data.y_unit_bounds[0])
						placer.place_z_wall(unit_x, unit_z, room_data.y_unit_bounds[0] + 0.5)
					else:
						placer.place_z_door_frame(unit_x, unit_z, room_data.y_unit_bounds[0])
					
					# fill up with the rest of the walls
					for y_offset in range(room_data.depth - 2):
						placer.place_z_wall(unit_x, unit_z, room_data.y_unit_bounds[0] + 1.5 + y_offset)
					
					# place arches
					placer.place_z_arch(unit_x, unit_z, room_data.y_unit_bounds[0] + room_data.depth - 0.5)
					placer.place_z_arch_fence(unit_x, unit_z, room_data.y_unit_bounds[0] + room_data.depth - 0.5)
		
					pass
					
				if unit_z == room_data.z_unit_bounds[0] or unit_z == room_data.z_unit_bounds[1]:
					# place border and first wall
					if not is_connection(room_data, Vector3i(unit_x, room_data.y_unit_bounds[0], unit_z)):
						placer.place_x_wall_border(unit_x, unit_z, room_data.y_unit_bounds[0])
						placer.place_x_wall(unit_x, unit_z, room_data.y_unit_bounds[0] + 0.5)
					else:
						placer.place_x_door_frame(unit_x, unit_z, room_data.y_unit_bounds[0])
					
					# fill up with the rest of the walls
					for y_offset in range(room_data.depth - 2):
						placer.place_x_wall(unit_x, unit_z, room_data.y_unit_bounds[0] + 1.5 + y_offset)
					
					
					# place arches
					placer.place_x_arch(unit_x, unit_z, room_data.y_unit_bounds[0] + room_data.depth - 0.5)
					placer.place_x_arch_fence(unit_x, unit_z, room_data.y_unit_bounds[0] + room_data.depth - 0.5)
					pass 
		
		
		
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
				# 1. Get the points
				var start_pt = get_wall_connection_point(rooms[i], rooms[j], default_hallway_size)
				var end_pt = get_wall_connection_point(rooms[j], rooms[i], default_hallway_size)
				# 2. Store them in the room data
				rooms[i].connections.append(start_pt)
				rooms[j].connections.append(end_pt)
				# 3. Create the corridor (pass the points so you don't calculate them twice)
				create_corridor_at_points(rooms[i], rooms[j], start_pt, end_pt, hallway_container, default_hallway_size)
				processed_connections.append([i, j])

@warning_ignore("unused_parameter")
func create_corridor_at_points(room_a: Dictionary, room_b: Dictionary, start_pos: Vector3i, end_pos: Vector3i, container: Node3D, h_size: Vector3i):	
	var current = start_pos
	var segments_to_spawn = []
	
	# Collect all points first
	segments_to_spawn.append(Vector3i(current))
	while current.x != end_pos.x:
		current.x += clampi(end_pos.x - current.x, -h_size.x, h_size.x)
		segments_to_spawn.append(Vector3i(current))
	while current.z != end_pos.z:
		current.z += clampi(end_pos.z - current.z, -h_size.z, h_size.z)
		segments_to_spawn.append(Vector3i(current))
	while current.y != end_pos.y:
		current.y += clampi(end_pos.y - current.y, -h_size.y, h_size.y)
		segments_to_spawn.append(Vector3i(current))

	# Spawn segments with a skip-check for the ends
	for i in range(segments_to_spawn.size()):
		var is_end_piece = (i == 0 or i == segments_to_spawn.size() - 1)
		spawn_hallway_segment(segments_to_spawn[i], container, h_size, is_end_piece)
	
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
	
func spawn_hallway_segment(grid_pos: Vector3i, container: Node3D, h_size: Vector3i, ignore_rooms: bool = false):
	var segment_name = "Hall_%d_%d_%d" % [grid_pos.x, grid_pos.y, grid_pos.z]
	if container.has_node(segment_name): return 

	# 1. STRICT ROOM CHECK
	# We check if this segment's BOUNDS overlap a room's BOUNDS.
	if not ignore_rooms and is_hallway_overlapping_room(grid_pos, h_size):
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
	var buffer = 1 # The "1 unit away" rule
	
	var h_x_min = pos.x
	var h_x_max = pos.x + h_size.x
	var h_y_min = pos.y
	var h_y_max = pos.y + h_size.y
	var h_z_min = pos.z
	var h_z_max = pos.z + h_size.z

	for room in rooms:
		# We "inflate" the room bounds by the buffer for the check
		# but only on the X and Z axes (usually you don't mind corridors 
		# running directly above/below rooms, but you can add Y if needed).
		var r_x_min = room.x_unit_bounds.x - buffer
		var r_x_max = room.x_unit_bounds.y + buffer
		var r_z_min = room.z_unit_bounds.x - buffer
		var r_z_max = room.z_unit_bounds.y + buffer
		
		# Vertical check (usually corridors and rooms are on the same floor)
		var r_y_min = room.y_unit_bounds.x
		var r_y_max = room.y_unit_bounds.y

		var x_overlap = h_x_max > r_x_min and h_x_min < r_x_max
		var y_overlap = h_y_max > r_y_min and h_y_min < r_y_max
		var z_overlap = h_z_max > r_z_min and h_z_min < r_z_max
		
		if x_overlap and y_overlap and z_overlap:
			# If we are overlapping the INFLATED box, we check if we are 
			# actually inside the REAL box.
			@warning_ignore("unused_variable")
			var strictly_inside_x = h_x_max > room.x_unit_bounds.x and h_x_min < room.x_unit_bounds.y
			@warning_ignore("unused_variable")
			var strictly_inside_z = h_z_max > room.z_unit_bounds.x and h_z_min < room.z_unit_bounds.y
			
			# If it's strictly inside, it's a collision.
			# If it's in the buffer zone, it's also a collision.
			return true
	return false
	
func get_random_bright_color() -> Color:
	# Hue: 0.0 to 1.0 (all colors of the rainbow)
	# Saturation: 0.7 to 1.0 (keeps it from looking washed out/white)
	# Value: 0.8 to 1.0 (keeps it from looking dark/black)
	return Color.from_hsv(randf(), randf_range(0.7, 1.0), randf_range(0.8, 1.0))

func is_connection(room_data: Dictionary, current_pos: Vector3i) -> bool:
	for conn_pos in room_data.connections:
		# We check if the wall segment's X and Z match the connection
		# We usually ignore Y if you want a full-height hole, 
		# or include it if you only want the 'floor' level open.
		if current_pos.x == conn_pos.x and current_pos.z == conn_pos.z and current_pos.y == conn_pos.y:
			return true
	return false
