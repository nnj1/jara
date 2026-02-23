extends Node3D

@onready var main_game_node = get_parent() if get_tree().get_root().get_node_or_null('Game') == null else get_tree().get_root().get_node('Game')

@export var unit_size: float = 20.0

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

# Random Number generation
@onready var rng: RandomNumberGenerator

## ENTITY PLACEMENT FUNCTIONS

func place_barrel(x_unit, z_unit, y_unit = 0.0):
	var barrel_instance = barrel_scene.instantiate()
	barrel_instance.name = "Barrel_" + str(x_unit) + "_" + str(z_unit) # Unique Name
	var aabb_size = get_first_mesh_size(barrel_instance)
	barrel_instance.position = Vector3(x_unit * unit_size + aabb_size.x/2.0 + rng.randf_range(0, 20), y_unit * unit_size + aabb_size.y/2.0, z_unit * unit_size + aabb_size.z/2.0 + rng.randf_range(0, 20))
	barrel_instance.rotation.y = rng.randf_range(0, 2*PI)
	if multiplayer.is_server():
		main_game_node.get_node('entities').add_child(barrel_instance, true)

func place_chest(x_unit, z_unit, y_unit = 0.0):
	var chest_instance = chest_scene.instantiate()
	chest_instance.name = "Chest_" + str(x_unit) + "_" + str(z_unit) # Unique Name
	var aabb_size = get_first_mesh_size(chest_instance)
	chest_instance.position = Vector3(x_unit * unit_size + aabb_size.x/2.0 + rng.randf_range(0, 20), y_unit * unit_size + aabb_size.y, z_unit * unit_size + aabb_size.z/2.0 + rng.randf_range(0, 20))
	chest_instance.rotation.y = rng.randf_range(0, 2*PI)
	if multiplayer.is_server():
		main_game_node.get_node('entities').add_child(chest_instance, true)
	
func place_box(x_unit, z_unit, y_unit = 0.0):
	var box_instance = box_scene.instantiate()
	box_instance.name = "Box_" + str(x_unit) + "_" + str(z_unit) # Unique Name
	var aabb_size = get_first_mesh_size(box_instance)
	box_instance.position = Vector3(x_unit * unit_size + aabb_size.x/2.0 + rng.randf_range(0, 20), y_unit * unit_size + aabb_size.y/2.0, z_unit * unit_size + aabb_size.z/2.0 + rng.randf_range(0, 20))
	box_instance.rotation.y = rng.randf_range(0, 2*PI)
	if multiplayer.is_server():
		main_game_node.get_node('entities').add_child(box_instance, true)
	
func place_skull(x_unit, z_unit, y_unit = 0.0):
	var skull_instance = skull_scene.instantiate()
	skull_instance.name = "Skull_" + str(x_unit) + "_" + str(z_unit) # Unique Name
	var aabb_size = get_first_mesh_size(skull_instance)
	skull_instance.position = Vector3(x_unit * unit_size + aabb_size.x/2.0 + rng.randf_range(0, 20), y_unit * unit_size + 5, z_unit * unit_size + aabb_size.z/2.0 + rng.randf_range(0, 20))
	skull_instance.rotation.y = rng.randf_range(0, 2*PI)
	skull_instance.rotation.x = rng.randf_range(0, 2*PI)
	skull_instance.rotation.z = rng.randf_range(0, 2*PI)
	if multiplayer.is_server():
		main_game_node.get_node('entities').add_child(skull_instance, true)

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


# ENEMY PLACEMENT FUNCTIONS

func spawn_skeleton(x_unit, z_unit, y_unit = 0.0):
	# Note: Only spawn on server if these are synced enemies!
	var skeleton_instance = preload('res://scenes/model_scenes/enemies/skeleton.tscn').instantiate()
	skeleton_instance.name = "Skeleton_" + str(x_unit) + "_" + str(z_unit) # Unique Name
	skeleton_instance.position = Vector3(x_unit * unit_size + unit_size/2.0, y_unit * unit_size + 3.0, z_unit * unit_size + unit_size/2.0)
	skeleton_instance.rotation.y = rng.randf_range(0, 2*PI)
	if multiplayer.is_server():
		main_game_node.get_node('enemies').add_child(skeleton_instance, true)

func spawn_monster(x_unit, z_unit, y_unit = 0.0):
	# Note: Only spawn on server if these are synced enemies!
	var monster_instance = preload('res://scenes/model_scenes/enemies/monster.tscn').instantiate()
	monster_instance.name = "Monster_" + str(x_unit) + "_" + str(z_unit) # Unique Name
	monster_instance.position = Vector3(x_unit * unit_size + unit_size/2.0, y_unit * unit_size + 3.0, z_unit * unit_size + unit_size/2.0)
	monster_instance.rotation.y = rng.randf_range(0, 2*PI)
	if multiplayer.is_server():
		main_game_node.get_node('enemies').add_child(monster_instance, true)

# DOOR FUNCS
func place_x_door(x_unit, z_unit, y_unit = 0.0):
	var selected_door = all_doors[rng.randi() % all_doors.size()]
	var door_instance = selected_door.instantiate()
	door_instance.name = "Door_" + str(x_unit) + "_" + str(z_unit) # Unique Name
	var aabb_size = get_first_mesh_size(door_instance)
	door_instance.position = Vector3(x_unit * unit_size + aabb_size.x, y_unit * unit_size + aabb_size.y/2.0, z_unit * unit_size + aabb_size.z)
	if multiplayer.is_server():
		main_game_node.get_node('entities').add_child(door_instance, true)

func place_z_door(x_unit, z_unit, y_unit = 0.0):
	var selected_door = all_doors[rng.randi() % all_doors.size()]
	var door_instance = selected_door.instantiate()
	door_instance.name = "Door_" + str(x_unit) + "_" + str(z_unit) # Unique Name
	var aabb_size = get_first_mesh_size(door_instance)
	door_instance.rotation.y = PI/2
	door_instance.position = Vector3(x_unit * unit_size + aabb_size.z, y_unit * unit_size + aabb_size.y/2.0, z_unit * unit_size + aabb_size.x)
	if multiplayer.is_server():	
		main_game_node.get_node('entities').add_child(door_instance, true)

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
