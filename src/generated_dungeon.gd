extends Node3D

@onready var main_game_node = get_parent() if get_tree().get_root().get_node_or_null('Game') == null else get_tree().get_root().get_node('Game')

# --- RNG & Synchronization ---
var rng := RandomNumberGenerator.new()
var is_generated: bool = false

# -- SETUP THE DUNGEON PLACER --
@onready var placer = get_node('PsxDungeonPlacer')

# SOME DEBUG SETTINGS
@export var VIEW_ROOM_BOUNDING_BOXES: bool = true
@export var VIEW_ROOM_CONNECTORS: bool = true
@export var VIEW_COORIDOR_BOUNDING_BOXES: bool = true
@export var SPAWN_ENTITIES: bool = false

@export_category('Dungeon Settings')
@export var unit_size: float = 20.0
@export var max_width_units: int = 75   # X (Horizontal)
@export var max_height_units: int = 75  # Z (Horizontal)
@export var max_depth_units: int = 10   # Y (Vertical)

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
var hallway_segments_surroundings = {}
var astar := AStar3D.new()

func _ready() -> void:
	
	if multiplayer.is_server():
		# HOST: We already have the seed.
		print("Host: Building with seed: ", MultiplayerManager.server_settings["map_seed"])
		generate_dungeon()
	else:
		# CLIENT: Force a reset of the local seed to 0 so we KNOW if it hasn't arrived
		MultiplayerManager.server_settings["map_seed"] = 0
		
		# If the settings haven't arrived yet, wait.
		# Note: We use a lambda to ensure it only runs once.
		var on_settings = func():
			print("Client: Building with RECEIVED seed: ", MultiplayerManager.server_settings["map_seed"])
			generate_dungeon()
			
		MultiplayerManager.settings_received.connect(on_settings, CONNECT_ONE_SHOT)

func generate_dungeon():
	if is_generated: return
	is_generated = true
	
	# Set the  RNG seed from the multiplayer manager
	if MultiplayerManager:
		rng.seed = MultiplayerManager.server_settings["map_seed"]
	placer.rng = rng
		
	draw_dungeon_outline()
	generate_rooms()
	
	# --- NEW: Build the pathfinding grid once ---
	initialize_astar_grid()
	
	var connection_matrix = generate_connections()
	generate_hallways(connection_matrix)
	
	actually_populate_hallways()
	
	# rooms don't bother to place mesh if a block was placed by the populate_hallways so meshes don't overlap
	actually_populate_rooms()
	center_camera()
	move_player_to_start()
	
func initialize_astar_grid():
	astar.clear()
	# Step 1: Register all possible points in the dungeon volume
	for y in range(max_depth_units):
		for x in range(max_width_units):
			for z in range(max_height_units):
				var pos = Vector3i(x, y, z)
				var id = pos_to_id(pos)
				astar.add_point(id, Vector3(pos))
				
				# Disable points inside rooms to force hallways to go around
				if is_pos_inside_any_room(pos):
					astar.set_point_disabled(id, true)
	
	# Step 2: Create connections between adjacent points
	for y in range(max_depth_units):
		for x in range(max_width_units):
			for z in range(max_height_units):
				var pos = Vector3i(x, y, z)
				var id = pos_to_id(pos)
				for neighbor in [Vector3i(1,0,0), Vector3i(0,1,0), Vector3i(0,0,1)]:
					var next = pos + neighbor
					if is_within_bounds(next):
						astar.connect_points(id, pos_to_id(next))
	
func move_player_to_start():
	# 1. Find the start room
	var start_room = null
	for room in rooms:
		if room.type == ROOM_TYPES.START:
			start_room = room
			break
	
	if start_room == null:
		push_error("No start room found!")
		return

	# 2. Pick a random unit coordinate inside the room
	# We subtract 1 from the max bounds to ensure the player isn't inside a wall
	var random_x = rng.randi_range(start_room.x_unit_bounds.x + 1, start_room.x_unit_bounds.y - 1)
	var random_z = rng.randi_range(start_room.z_unit_bounds.x + 1, start_room.z_unit_bounds.y - 1)
	var y_level = start_room.y_unit_bounds.x # The floor level
	
	# 3. Convert unit coordinates to Godot world position
	# We add 0.5 to center the player in the middle of the tile
	var spawn_pos = Vector3(
		(random_x + 0.5) * unit_size,
		(y_level + 0.1) * unit_size, # Slightly above floor to prevent clipping
		(random_z + 0.5) * unit_size
	)
	
	# 4. Move the node
	if has_node("player_spawn_point"):
		$player_spawn_point.global_position = spawn_pos
		print("Player spawn moved to start room at: ", spawn_pos)
	else:
		push_error("Node 'player_spawn_point' not found in scene.")

func center_camera():
	# Position the camera to see the whole dungeon from above
	if has_node("flying_camera"):
		$flying_camera.global_position = Vector3(
			max_width_units * unit_size / 2, 
			max_depth_units * unit_size + 100,  
			max_height_units * unit_size / 2
		)
		
func actually_populate_hallways():
	for segment in hallway_segments:
		var pos = segment.grid_pos
		
		# add a potential roach
		if rng.randf() < 0.05:
			placer.spawn_roach(pos.x, pos.z, pos.y)

		# 1. FLOOR (Place a floor block or tile)
		var below_pos = pos + Vector3i(0, -1, 0)
		if not segment.faces.down and not is_pos_inside_any_room(below_pos) and not is_pos_hallway(below_pos):
			if not is_any_room_connection(below_pos):
				placer.place_block(below_pos.x, below_pos.z, below_pos.y)
				hallway_segments_surroundings[below_pos] = true
				#placer.place_roof_tile(below_pos.x, below_pos.z, below_pos.y)
			
		# ROOF (Place a block above the path)
		var top_pos = pos + Vector3i(0, 1, 0)
		if not segment.faces.up and not is_pos_inside_any_room(top_pos) and not is_pos_hallway(top_pos):
			if not is_any_room_connection(top_pos):
				placer.place_block(top_pos.x, top_pos.z, top_pos.y)
				hallway_segments_surroundings[top_pos] = true

		# 2. HORIZONTAL WALLS
		# Check North (-Z)
		var north_pos = pos + Vector3i(0, 0, -1)
		if not segment.faces.north and not is_pos_inside_any_room(north_pos) and not is_pos_hallway(north_pos):
			# Only place block if it's NOT a door
			if not is_any_room_connection(north_pos):
				placer.place_block(north_pos.x, north_pos.z, north_pos.y)
				hallway_segments_surroundings[north_pos] = true
		
		# Check South (+Z)
		var south_pos = pos + Vector3i(0, 0, 1)
		if not segment.faces.south and not is_pos_inside_any_room(south_pos) and not is_pos_hallway(south_pos):
			if not is_any_room_connection(south_pos):
				placer.place_block(south_pos.x, south_pos.z, south_pos.y)
				hallway_segments_surroundings[south_pos] = true

		# Check West (-X)
		var west_pos = pos + Vector3i(-1, 0, 0)
		if not segment.faces.west and not is_pos_inside_any_room(west_pos) and not is_pos_hallway(west_pos):
			if not is_any_room_connection(west_pos):
				placer.place_block(west_pos.x, west_pos.z, west_pos.y)
				hallway_segments_surroundings[west_pos] = true
				
		# Check East (+X)
		var east_pos = pos + Vector3i(1, 0, 0)
		if not segment.faces.east and not is_pos_inside_any_room(east_pos) and not is_pos_hallway(east_pos):
			if not is_any_room_connection(east_pos):
				placer.place_block(east_pos.x, east_pos.z, east_pos.y)
				hallway_segments_surroundings[east_pos] = true
			
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
				# only place floor tile if there's not a block below it:
				if not hallway_segments_surroundings.has(Vector3i(unit_x,  room_data.y_unit_bounds[0] - 1, unit_z)):
					placer.place_floor_tile(unit_x, unit_z, room_data.y_unit_bounds[0])
				
		# Add roof 
		for unit_x in range(room_data.x_unit_bounds[0], room_data.x_unit_bounds[1]):
			for unit_z in range(room_data.z_unit_bounds[0], room_data.z_unit_bounds[1]):
				placer.place_block(unit_x, unit_z, room_data.y_unit_bounds[1])
				if rng.randf() < 0.25:
					placer.place_chandelier(unit_x, unit_z, room_data.y_unit_bounds[1] - 1)
		
		# Add wall borders and walls
		for unit_x in range(room_data.x_unit_bounds[0], room_data.x_unit_bounds[0] + room_data.width + 1):
			for unit_z in range(room_data.z_unit_bounds[0], room_data.z_unit_bounds[0] + room_data.height + 1):
				if (unit_x == room_data.x_unit_bounds[0] or unit_x == room_data.x_unit_bounds[1]) and unit_z < room_data.z_unit_bounds[0] + room_data.height:
					
					# place border and first wall
					if not is_connection(room_data, Vector3i(unit_x, room_data.y_unit_bounds[0], unit_z)):
						if not hallway_segments_surroundings.has(Vector3i(unit_x,  room_data.y_unit_bounds[0], unit_z)):
							placer.place_z_wall_border(unit_x, unit_z, room_data.y_unit_bounds[0])
							placer.place_z_wall(unit_x, unit_z, room_data.y_unit_bounds[0] + 0.5)
						else:
							placer.place_z_wall_border(unit_x, unit_z, room_data.y_unit_bounds[0] + 1)
					else:
						placer.place_z_door_frame(unit_x, unit_z, room_data.y_unit_bounds[0])
						#placer.remove_structure('Wall_z', unit_x, unit_z + 1, room_data.y_unit_bounds[0])
						#placer.remove_structure('Wall_z', unit_x, unit_z - 1, room_data.y_unit_bounds[0])
						placer.place_z_door(unit_x, unit_z, room_data.y_unit_bounds[0])
						placer.place_z_wall_border(unit_x, unit_z, room_data.y_unit_bounds[0] + 1)
						
					# fill up with the rest of the walls
					for y_offset in range(room_data.depth - 2):
						placer.place_z_wall(unit_x, unit_z, room_data.y_unit_bounds[0] + 1.5 + y_offset)
					
					# place arches
					placer.place_z_arch(unit_x, unit_z, room_data.y_unit_bounds[0] + room_data.depth - 0.5)
					placer.place_z_arch_fence(unit_x, unit_z, room_data.y_unit_bounds[0] + room_data.depth - 0.5)
		
					pass
					
				if (unit_z == room_data.z_unit_bounds[0] or unit_z == room_data.z_unit_bounds[1]) and unit_x < room_data.x_unit_bounds[0] + room_data.width:
					# place border and first wall
					if not is_connection(room_data, Vector3i(unit_x, room_data.y_unit_bounds[0], unit_z)):
						if not hallway_segments_surroundings.has(Vector3i(unit_x,  room_data.y_unit_bounds[0], unit_z)):
							placer.place_x_wall_border(unit_x, unit_z, room_data.y_unit_bounds[0])
							placer.place_x_wall(unit_x, unit_z, room_data.y_unit_bounds[0] + 0.5)
						else:
							placer.place_x_wall_border(unit_x, unit_z, room_data.y_unit_bounds[0] + 1)
					else:
						placer.place_x_door_frame(unit_x, unit_z, room_data.y_unit_bounds[0])
						#placer.remove_structure('Wall_x', unit_x - 1, unit_z, room_data.y_unit_bounds[0])
						#placer.remove_structure('Wall_x', unit_x + 1, unit_z, room_data.y_unit_bounds[0])
						placer.place_x_door(unit_x, unit_z, room_data.y_unit_bounds[0])
						placer.place_x_wall_border(unit_x, unit_z, room_data.y_unit_bounds[0] + 1)
					
					# fill up with the rest of the walls
					for y_offset in range(room_data.depth - 2):
						placer.place_x_wall(unit_x, unit_z, room_data.y_unit_bounds[0] + 1.5 + y_offset)
					
					# place arches
					placer.place_x_arch(unit_x, unit_z, room_data.y_unit_bounds[0] + room_data.depth - 0.5)
					placer.place_x_arch_fence(unit_x, unit_z, room_data.y_unit_bounds[0] + room_data.depth - 0.5)
					pass 
		
		# add entities
		if SPAWN_ENTITIES:
			# spawn any special monsters if boss room
			if room_data.type == ROOM_TYPES.BOSS:
				var center_room_position_x = int((room_data.x_unit_bounds[0] + room_data.x_unit_bounds[1]) /2)
				var center_room_position_z = int((room_data.z_unit_bounds[0] + room_data.z_unit_bounds[1]) /2)
				placer.spawn_dragon(center_room_position_x, center_room_position_z, room_data.y_unit_bounds[0])
			elif room_data.type == ROOM_TYPES.START:
				var center_room_position_x = int((room_data.x_unit_bounds[0] + room_data.x_unit_bounds[1]) /2)
				var center_room_position_z = int((room_data.z_unit_bounds[0] + room_data.z_unit_bounds[1]) /2)
				placer.spawn_vendor(center_room_position_x, center_room_position_z, room_data.y_unit_bounds[0])
			else:
				for unit_x in range(room_data.x_unit_bounds[0], room_data.x_unit_bounds[1]):
					for unit_z in range(room_data.z_unit_bounds[0], room_data.z_unit_bounds[1]):
						if rng.randf() < 0.05:
							for i in rng.randi_range(0, 4):
								placer.place_skull(unit_x, unit_z, room_data.y_unit_bounds[0])
						elif rng.randf() < 0.02:
							var num = rng.randf()
							if num < 0.5:
								placer.spawn_skeleton(unit_x, unit_z, room_data.y_unit_bounds[0])
							elif num < 0.75:
								placer.spawn_monster(unit_x, unit_z, room_data.y_unit_bounds[0])

						if unit_x % 2 == 0 and unit_z % 2 == 0:
							if rng.randf() < 0.1:
								placer.place_hexagon(unit_x, unit_z, room_data.y_unit_bounds[0])
							elif rng.randf() < 0.3:
								var sub_roll = rng.randf()
								if sub_roll < 0.33:
									placer.place_pillar(unit_x, unit_z, room_data.y_unit_bounds[0])
								elif sub_roll < 0.66:
									var things = ['barrel', 'debris', 'chest', 'box']
									var thing = things[rng.randi() % things.size()]
									placer.call('place_' + thing, unit_x, unit_z, room_data.y_unit_bounds[0])
								else:
									placer.place_spike(unit_x, unit_z, room_data.y_unit_bounds[0])
		
func create_room(room_data: Dictionary) -> Node3D:
	var room_anchor = Node3D.new()
	room_anchor.name = "Room_" + str(rooms.size())
	
	# Mapping coordinates to Godot Vector3(X, Y, Z)
	room_anchor.position = Vector3(
		room_data.x_unit_bounds.x * unit_size,
		room_data.y_unit_bounds.x * unit_size, 
		room_data.z_unit_bounds.x * unit_size
	)
	
	var visual_x = room_data.width * unit_size
	var visual_y = room_data.depth * unit_size
	var visual_z = room_data.height * unit_size
	
	# --- 1. Create the Area3D ---
	var area = Area3D.new()
	# Set collision mask to look for players
	area.set_collision_mask_value(2, true)
	area.collision_layer = 0 # The area itself doesn't need to be on a layer
	
	# --- 2. Create the CollisionShape3D ---
	var collision_shape = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = Vector3(visual_x, visual_y, visual_z)
	collision_shape.shape = box_shape
	
	# Match the mesh offset so the area aligns with the visual box
	area.position = Vector3(visual_x / 2.0, visual_y / 2.0, visual_z / 2.0)
	
	# --- 3. Connect the Signal ---
	area.body_entered.connect(_on_player_entered_room.bind(room_data))
	
	# Assemble the Area
	area.add_child(collision_shape)
	room_anchor.add_child(area)

	# --- Visual Mesh Logic ---
	var mesh_instance = MeshInstance3D.new()
	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(visual_x, visual_y, visual_z)
	mesh_instance.mesh = box_mesh
	mesh_instance.position = area.position # Keep them synced
	
	apply_room_material(mesh_instance, room_data.type)
	
	if VIEW_ROOM_BOUNDING_BOXES:
		room_anchor.add_child(mesh_instance)
	
	add_child(room_anchor, true)
	return room_anchor

# --- 4. The Callback Function for when a player enters the room---
func _on_player_entered_room(body: Node3D, given_room_data: Dictionary):
	#print("Player entered room: ", given_room_data.type)
	if main_game_node:
		if body.is_multiplayer_authority():
			var room_text_label = main_game_node.get_node_or_null('UI/room_info/VBoxContainer/RichTextLabel')
			if room_text_label:
				room_text_label.text = dictionary_to_string_with_newlines(given_room_data)

func dictionary_to_string_with_newlines(dictionary):
	var result_string = ""
	for key in dictionary: # Iterating over the dictionary naturally iterates over its keys
		# Format the key and value as a string, adding a newline character at the end
		result_string += "%s: %s\n" % [key, dictionary[key]]
	return result_string		

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
				#await get_tree().process_frame
				# 1. Get the points
				var start_pt = get_wall_connection_point(rooms[i], rooms[j], default_hallway_size)
				var end_pt = get_wall_connection_point(rooms[j], rooms[i], default_hallway_size)
				# 2. Store them in the room data
				rooms[i].connections.append(start_pt)
				rooms[j].connections.append(end_pt)
				# 3. Create the corridor (pass the points so you don't calculate them twice)
				create_corridor_at_points(rooms[i], rooms[j], start_pt, end_pt, hallway_container, default_hallway_size)
				processed_connections.append([i, j])

func create_corridor_at_points(room_a: Dictionary, room_b: Dictionary, start_pos: Vector3i, end_pos: Vector3i, container: Node3D, h_size: Vector3i):
	var path_points = get_astar_path(start_pos, end_pos, room_a, room_b)
	
	if path_points.is_empty():
		push_warning("Hallway failed: No path found between rooms.")
		return

	var prev_segment = null
	for i in range(path_points.size()):
		var is_terminal = (i == 0 or i == path_points.size() - 1)
		
		# We set ignore_rooms to true because A* is already handling room avoidance
		var current_segment = spawn_hallway_segment(path_points[i], container, h_size, true)
		
		if current_segment:
			if is_terminal: 
				current_segment["is_doorway"] = true
			
			if prev_segment != null:
				# We don't need the 'is_room_connection' bypass anymore because
				# A* generates a single continuous chain of segments.
				link_segments(prev_segment, current_segment, false)
				
		prev_segment = current_segment
		
func link_segments(seg_a: Dictionary, seg_b: Dictionary, is_room_connection: bool):
	# If this link is between a terminal segment and its neighbor,
	# we might want to keep the wall closed or handle it differently.
	if is_room_connection:
		return # Do not link faces; keeps the hallway 'box' sealed at the room entrance
		
	var diff = seg_b.grid_pos - seg_a.grid_pos
	
	if diff.x > 0: # Moving East (+X)
		seg_a.faces.east = true
		seg_b.faces.west = true
	elif diff.x < 0: # Moving West (-X)
		seg_a.faces.west = true
		seg_b.faces.east = true
	elif diff.z > 0: # Moving South (+Z)
		seg_a.faces.south = true
		seg_b.faces.north = true
	elif diff.z < 0: # Moving North (-Z)
		seg_a.faces.north = true
		seg_b.faces.south = true
	elif diff.y > 0: # Moving Up (+Y)
		seg_a.faces.up = true
		seg_b.faces.down = true
	elif diff.y < 0: # Moving Down (-Y)
		seg_a.faces.down = true
		seg_b.faces.up = true
			
# Helper function to find the point on the wall closest to the target room
func get_wall_connection_point(from_room: Dictionary, to_room: Dictionary, h_size: Vector3i) -> Vector3i:
	var center_from = get_room_center(from_room) / unit_size
	var center_to = get_room_center(to_room) / unit_size
	var diff = center_to - center_from
	var out_point = Vector3i()
	
	# Logic: Determine which wall (X or Z) faces the target room
	if abs(diff.x) > abs(diff.z):
		# Target is further away on X-axis: Use Left/Right walls
		# We pick the X coordinate exactly on the boundary
		var x_pos = from_room.x_unit_bounds.y if diff.x > 0 else from_room.x_unit_bounds.x
		
		out_point = Vector3i(
			int(x_pos),
			int(from_room.y_unit_bounds.x), # Floor level
			# Center the hallway on the Z wall
			int(floor((from_room.z_unit_bounds.x + from_room.z_unit_bounds.y) / 2.0 - (h_size.z / 2.0)))
		)
	else:
		# Target is further away on Z-axis: Use Front/Back walls
		# We pick the Z coordinate exactly on the boundary
		var z_pos = from_room.z_unit_bounds.y if diff.z > 0 else from_room.z_unit_bounds.x
		
		out_point = Vector3i(
			# Center the hallway on the X wall
			int(floor((from_room.x_unit_bounds.x + from_room.x_unit_bounds.y) / 2.0 - (h_size.x / 2.0))),
			int(from_room.y_unit_bounds.x), # Floor level
			int(z_pos)
		)
		
	return out_point
	
func spawn_hallway_segment(grid_pos: Vector3i, container: Node3D, h_size: Vector3i, ignore_rooms: bool = false) -> Variant:
	var segment_name = "Hall_%d_%d_%d" % [grid_pos.x, grid_pos.y, grid_pos.z]
	
	# 1. Check if this segment already exists (don't duplicate work)
	# We search the array instead of has_node for data consistency
	for existing in hallway_segments:
		if existing.grid_pos == grid_pos:
			return existing

	# 2. Room Collision Check
	if not ignore_rooms and is_hallway_overlapping_room(grid_pos, h_size):
		return null

	# 3. Initialize Segment Data
	# These bools determine which sides of the "box" are open
	var segment_data = {
		"grid_pos": grid_pos,
		"faces": {
			"up": false,    # +Y
			"down": false,  # -Y
			"north": false, # -Z
			"south": false, # +Z
			"east": false,  # +X
			"west": false   # -X
		},
		"mesh_instance": null # Reference to the visual node if needed
	}

	# 4. Visual Representation (Bounding Box)
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.name = segment_name
	
	var box = BoxMesh.new()
	var visual_size = Vector3(h_size.x * unit_size, h_size.y * unit_size, h_size.z * unit_size)
	box.size = visual_size
	mesh_instance.mesh = box
	
	# Positioning (Center the box on the grid coordinate)
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
	
	# 5. Finalize
	if VIEW_COORIDOR_BOUNDING_BOXES:
		container.add_child(mesh_instance)
	
	segment_data.mesh_instance = mesh_instance
	hallway_segments.append(segment_data)
	
	return segment_data

func is_hallway_overlapping_room(pos: Vector3i, h_size: Vector3i) -> bool:
	var buffer = 0 # The "1 unit away" rule
	
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
	return Color.from_hsv(rng.randf(), rng.randf_range(0.7, 1.0), rng.randf_range(0.8, 1.0), 0.25)

func is_connection(room_data: Dictionary, current_pos: Vector3i) -> bool:
	for conn_pos in room_data.connections:
		# 1. Height Check (Doorway height)
		var within_y = (current_pos.y >= conn_pos.y and current_pos.y < conn_pos.y + 2)
		if not within_y: continue

		# 2. Precise Wall Alignment
		# Check if the wall we are currently building is the same X or Z as the connection
		var on_x_wall = (current_pos.x == conn_pos.x)
		var on_z_wall = (current_pos.z == conn_pos.z)

		
		# 3. Footprint Check
		# Only punch the hole if we are on the correct wall AND aligned with hallway width
		
		# If we are on the X-boundary wall (Left/Right), check Z alignment
		if on_x_wall and (conn_pos.x == room_data.x_unit_bounds.x or conn_pos.x == room_data.x_unit_bounds.y):
			var dz = abs(current_pos.z - conn_pos.z)
			if dz < default_hallway_size.z:
				return true
				
		# If we are on the Z-boundary wall (Front/Back), check X alignment
		if on_z_wall and (conn_pos.z == room_data.z_unit_bounds.x or conn_pos.z == room_data.z_unit_bounds.y):
			var dx = abs(current_pos.x - conn_pos.x)
			if dx < default_hallway_size.x:
				return true
			
	return false
	
func is_any_room_connection(pos: Vector3i) -> bool:
	for room in rooms:
		if is_connection(room, pos):
			return true
	return false

func is_pos_inside_any_room(pos: Vector3i) -> bool:
	for room in rooms:
		# Check if the coordinate is strictly within the room's interior volume
		var in_x = pos.x >= room.x_unit_bounds.x and pos.x < room.x_unit_bounds.y
		var in_y = pos.y >= room.y_unit_bounds.x and pos.y < room.y_unit_bounds.y
		var in_z = pos.z >= room.z_unit_bounds.x and pos.z < room.z_unit_bounds.y
		
		if in_x and in_y and in_z:
			return true
	return false

func is_pos_hallway(pos: Vector3i) -> bool:
	for segment in hallway_segments:
		if segment.grid_pos == pos:
			return true
	return false

@export var jut_distance: int = 2

func get_astar_path(start: Vector3i, end: Vector3i, room_a: Dictionary, room_b: Dictionary) -> Array[Vector3i]:
	var start_id = pos_to_id(start)
	var end_id = pos_to_id(end)
	
	# Enable start/end points (they are usually disabled because they are on room walls)
	astar.set_point_disabled(start_id, false)
	astar.set_point_disabled(end_id, false)
	
	# Add weight preference to the exit directions to prevent immediate turns
	var jut_start = start + get_exit_direction(start, room_a)
	var jut_end = end + get_exit_direction(end, room_b)
	
	if is_within_bounds(jut_start): astar.set_point_weight_scale(pos_to_id(jut_start), 0.1)
	if is_within_bounds(jut_end): astar.set_point_weight_scale(pos_to_id(jut_end), 0.1)

	# The actual pathfinding (now near-instant)
	var p = astar.get_id_path(start_id, end_id)
	
	# Reset weights and re-disable start/end for the next hallway
	if is_within_bounds(jut_start): astar.set_point_weight_scale(pos_to_id(jut_start), 1.0)
	if is_within_bounds(jut_end): astar.set_point_weight_scale(pos_to_id(jut_end), 1.0)
	astar.set_point_disabled(start_id, true)
	astar.set_point_disabled(end_id, true)

	var path: Array[Vector3i] = []
	for node_id in p:
		path.append(id_to_pos(node_id))
	return path

func get_exit_direction(pos: Vector3i, room: Dictionary) -> Vector3i:
	# If the door is on the Min X boundary, it must jut further Min (-1)
	if pos.x == room.x_unit_bounds.x: return Vector3i(-1, 0, 0)
	if pos.x == room.x_unit_bounds.y: return Vector3i(1, 0, 0)
	if pos.z == room.z_unit_bounds.x: return Vector3i(0, 0, -1)
	if pos.z == room.z_unit_bounds.y: return Vector3i(0, 0, 1)
	return Vector3i.ZERO

# Helper to turn 3D coords into a unique ID
func pos_to_id(pos: Vector3i) -> int:
	return pos.x + (pos.z * max_width_units) + (pos.y * max_width_units * max_height_units)

func id_to_pos(id: int) -> Vector3i:
	@warning_ignore("integer_division")
	var y = id / (max_width_units * max_height_units)
	var rem = id % (max_width_units * max_height_units)
	@warning_ignore("integer_division")
	var z = rem / max_width_units
	var x = rem % max_width_units
	return Vector3i(x, y, z)

func is_within_bounds(p: Vector3i) -> bool:
	return p.x >= 0 and p.x < max_width_units and p.y >= 0 and p.y < max_depth_units and p.z >= 0 and p.z < max_height_units
