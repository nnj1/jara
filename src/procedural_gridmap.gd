extends Node3D

## REQUIRES: A GridMap child node named "GridMap" with a valid MeshLibrary assigned.
@onready var grid_map: GridMap = $GridMap
@onready var main_game_node = get_tree().get_root().get_node('Game')

@export_category('Dungeon Settings')
@export var unit_size: float = 20.0
@export var height_units: int = 100
@export var width_units: int = 100

@export_category('MeshLibrary IDs')
## Match these IDs to the indexes in your MeshLibrary (.tres)
enum Tile { 
	FLOOR = 0, 
	WALL = 1, 
	WINDOW_WALL = 2, 
	DOOR_FRAME = 3, 
	PILLAR = 4, 
	BLOCK = 5,
	BORDER = 6,
	ARCH = 7,
	ARCH_FENCE = 8
}

## GridMap Orientation Codes (Orthogonal Angles)
const ROT_0 = 0
const ROT_90 = 22  # Y-Rotate 90
const ROT_180 = 10 # Y-Rotate 180
const ROT_270 = 16 # Y-Rotate 270

@export_category('Dynamic Scenes')
## Keep scenes for items that need scripts or random sub-tile placement
@onready var chandelier_scene: PackedScene = preload('res://scenes/model_scenes/structures/Chandelier.tscn')
@onready var skull_scene: PackedScene = preload('res://scenes/model_scenes/entities/Skull.tscn')
@onready var barrel_scene: PackedScene = preload('res://scenes/model_scenes/entities/Barrel.tscn')
@onready var chest_scene: PackedScene = preload('res://scenes/model_scenes/entities/Chest.tscn')
@onready var box_scene: PackedScene = preload('res://scenes/model_scenes/entities/Box.tscn')
@onready var debris_scene: PackedScene = preload('res://scenes/model_scenes/structures/Debris.tscn')
@onready var spike_scene: PackedScene = preload('res://scenes/model_scenes/structures/Spikes.tscn')
@onready var hexagon_scene: PackedScene = preload('res://scenes/model_scenes/structures/Hexagon.tscn')

func _ready() -> void:
	if not grid_map:
		push_error("GridMap node not found! Please add a GridMap child.")
		return
		
	setup_gridmap()
	generate_dungeon()

func setup_gridmap():
	grid_map.cell_size = Vector3(unit_size, unit_size, unit_size)
	grid_map.cell_center_y = false # Keeps floors at Y=0
	grid_map.clear()

func generate_dungeon():
	for x in range(width_units):
		for z in range(height_units):
			# 1. CORE STRUCTURE (GridMap)
			# Place Floor at Level 0, Block (Roof) at Level 3
			grid_map.set_cell_item(Vector3i(x, 0, z), Tile.FLOOR)
			grid_map.set_cell_item(Vector3i(x, 2, z), Tile.BLOCK)
			
			# 2. DYNAMIC OBJECTS (Scenes)
			if randf() < 0.1:
				place_scene_object(chandelier_scene, x, z, 3.0)
			
			if randf() < 0.05:
				for i in randi_range(1, 4):
					place_skull(x, z)
			elif randf() < 0.01:
				spawn_skeleton(x, z)

			# 3. PROCEDURAL LAYOUT (Hybrid)
			if x % 2 == 0 and z % 2 == 0:
				handle_sparse_placement(x, z)

func handle_sparse_placement(x: int, z: int):
	var roll = randf()
	if roll < 0.1:
		place_scene_object(hexagon_scene, x, z)
	elif roll < 0.3:
		var sub_roll = randf()
		if sub_roll < 0.5:
			grid_map.set_cell_item(Vector3i(x, 1, z), Tile.PILLAR)
		elif sub_roll < 0.8:
			var loot = [barrel_scene, chest_scene, box_scene, debris_scene].pick_random()
			place_scene_object(loot, x, z, 20.0, true)
		else:
			place_scene_object(spike_scene, x, z, 20.0, true)
	else:
		# Wall logic using GridMap Orientations
		if randf() < 0.5:
			# X-Axis Walls
			var wall_type = Tile.WINDOW_WALL if randf() < 0.3 else Tile.WALL
			grid_map.set_cell_item(Vector3i(x, 1, z), wall_type, ROT_0)
			grid_map.set_cell_item(Vector3i(x + 1, 1, z), wall_type, ROT_0)
			grid_map.set_cell_item(Vector3i(x, 2, z), Tile.ARCH, ROT_0)
		else:
			# Z-Axis Walls (Rotated)
			var wall_type = Tile.WINDOW_WALL if randf() < 0.3 else Tile.WALL
			grid_map.set_cell_item(Vector3i(x, 1, z), wall_type, ROT_90)
			grid_map.set_cell_item(Vector3i(x, 1, z + 1), wall_type, ROT_90)
			grid_map.set_cell_item(Vector3i(x, 2, z), Tile.ARCH, ROT_90)

## Helper to place scenes with your original unit_size math
func place_scene_object(scene: PackedScene, x: int, z: int, y_offset: float = 20.0, random_pos: bool = false):
	var inst = scene.instantiate()
	var pos = Vector3(x * unit_size + (unit_size/2.0), y_offset * unit_size, z * unit_size + (unit_size/2.0))
	
	if random_pos:
		pos.x += randf_range(-5, 5)
		pos.z += randf_range(-5, 5)
		inst.rotation.y = randf_range(0, TAU)
		
	inst.position = pos
	add_child(inst)

func place_skull(x, z):
	var inst = skull_scene.instantiate()
	inst.position = Vector3(
		x * unit_size + randf_range(2, 18), 
		5.0, # Slight height as per original
		z * unit_size + randf_range(2, 18)
	)
	inst.rotation = Vector3(randf_range(0, TAU), randf_range(0, TAU), randf_range(0, TAU))
	main_game_node.get_node('entities').add_child(inst, true)

func spawn_skeleton(x, z):
	var skeleton_scene = load('res://scenes/model_scenes/skeleton.tscn')
	var inst = skeleton_scene.instantiate()
	inst.position = Vector3(x * unit_size + unit_size/2.0, 3.0, z * unit_size + unit_size/2.0)
	main_game_node.get_node('enemies').add_child(inst, true)
