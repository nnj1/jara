extends Node3D

@export_category('Dungeon Settings')
@export var unit_size: float = 20.0
@export var height_units: int = 100
@export var width_units: int = 100

@export_category('Dungeon Models')

# FLOORS
@onready var floor_tile_scene: PackedScene = preload('res://scenes/model_scenes/Floor_Tiles.tscn')

# WALLS
@onready var wall_01_scene: PackedScene = preload('res://scenes/model_scenes/Wall_01.tscn')
@onready var wall_02_scene: PackedScene = preload('res://scenes/model_scenes/Wall_02.tscn')
@onready var wall_border_01_scene: PackedScene = preload('res://scenes/model_scenes/Wall_Border_01.tscn')
@onready var wall_border_02_scene: PackedScene = preload('res://scenes/model_scenes/Wall_Border_02.tscn')
@onready var wall_ruin_scene: PackedScene = preload('res://scenes/model_scenes/Wall_Ruin.tscn')
@onready var wall_windowed_01_scene: PackedScene = preload('res://scenes/model_scenes/Windowed_Wall_01.tscn')
@onready var wall_windowed_02_scene: PackedScene = preload('res://scenes/model_scenes/Windowed_Wall_02.tscn')
@onready var wall_skull_scene: PackedScene = preload('res://scenes/model_scenes/Skull_Wall.tscn')
@onready var all_walls = [wall_01_scene, wall_02_scene, wall_ruin_scene, wall_windowed_01_scene, wall_windowed_02_scene, wall_skull_scene]
@onready var all_non_window_walls = [wall_01_scene, wall_02_scene, wall_ruin_scene, wall_skull_scene]
@onready var all_window_walls = [wall_windowed_01_scene, wall_windowed_02_scene]
@onready var all_wall_borders = [wall_border_01_scene, wall_border_02_scene]

# WALL DECORATORS
@onready var wall_table_scene: PackedScene = preload('res://scenes/model_scenes/Wall_Table.tscn')

# DOORS
@onready var door_frame_01_scene: PackedScene = preload('res://scenes/model_scenes/Door_Frame_01.tscn')
@onready var door_frame_02_scene: PackedScene = preload('res://scenes/model_scenes/Door_Frame_02.tscn')
@onready var all_door_frames = [door_frame_01_scene, door_frame_02_scene]

# FLOOR DECORATORS
@onready var hexagon_scene: PackedScene = preload('res://scenes/model_scenes/Hexagon.tscn')
@onready var debris_scene: PackedScene = preload('res://scenes/model_scenes/Debris.tscn')
@onready var barrel_scene: PackedScene = preload('res://scenes/model_scenes/Barrel.tscn')
@onready var chest_scene: PackedScene = preload('res://scenes/model_scenes/Chest.tscn')
@onready var box_scene: PackedScene = preload('res://scenes/model_scenes/Box.tscn')
@onready var spike_scene: PackedScene = preload('res://scenes/model_scenes/Spikes.tscn')
@onready var skull_scene: PackedScene = preload('res://scenes/model_scenes/Skull.tscn')

# PILLARS
@onready var pillar_scene: PackedScene = preload('res://scenes/model_scenes/Pillar.tscn')
@onready var pillar_collapsed_1_scene: PackedScene = preload('res://scenes/model_scenes/Pillar_Collapsed_01.tscn')
@onready var pillar_collapsed_2_scene: PackedScene = preload('res://scenes/model_scenes/Pillar_Collapsed_02.tscn')
@onready var all_pillars = [pillar_scene, pillar_collapsed_1_scene, pillar_collapsed_2_scene]

# ROOF THINGS
@onready var arch_roof_scene: PackedScene = preload('res://scenes/model_scenes/Arch_Roof.tscn')
@onready var arch_scene: PackedScene = preload('res://scenes/model_scenes/Arch.tscn')
@onready var arch_fence_scene: PackedScene = preload('res://scenes/model_scenes/Arch_Fence.tscn')
@onready var block_arch_scene: PackedScene = preload('res://scenes/model_scenes/Block_Arch.tscn')
@onready var block_scene: PackedScene = preload('res://scenes/model_scenes/Block.tscn')
@onready var chandelier_scene: PackedScene = preload('res://scenes/model_scenes/Chandelier.tscn')

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	
	for x_unit in range(width_units):
		for z_unit in range(height_units):
			# every unit should have a floor tile and a roof tile with occasional chandelier
			place_floor_tile(x_unit, z_unit)
			place_block(x_unit, z_unit, 2.0)
			if randf() < 0.1:
				place_chandelier(x_unit, z_unit, 1.0)
			
			# add random amount of skulls in the unit square
			if randf() < 0.05:
				for i in randi_range(0, 4):
					place_skull(x_unit, z_unit)
				
			# make things a little more sparse
			if x_unit % 2 == 0 and z_unit % 2 == 0:
				if randf() < 0.1:
					place_hexagon(x_unit, z_unit)
				elif randf() < 0.3:
					if randf() < 0.5:
						place_pillar(x_unit, z_unit)
					elif randf() < 0.5:
						var thing = ['barrel', 'debris', 'chest', 'box'].pick_random()
						call('place_' + thing, x_unit, z_unit)
					elif randf() < 0.5:
						place_spike(x_unit, z_unit)
				else:
					if randf() < 0.5:
						if randf() < 0.5:
							if randf() < 0.5:
								place_x_wall(x_unit, z_unit, 0.5)
								place_x_wall(x_unit + 1, z_unit, 0.5)
								place_x_wall_border(x_unit, z_unit)
								place_x_wall_border(x_unit + 1, z_unit)
							else:
								place_x_window_wall(x_unit, z_unit, 0)
								place_x_window_wall(x_unit + 1, z_unit, 0)
								place_x_wall_border(x_unit, z_unit, 1.0)
								place_x_wall_border(x_unit + 1, z_unit, 1.0)
							place_x_arch(x_unit, z_unit, 1.5)
							place_x_arch(x_unit + 1, z_unit, 1.5)
							if randf() < 0.5:
								place_x_arch_fence(x_unit, z_unit, 1.5)
								place_x_arch_fence(x_unit + 1, z_unit, 1.5)
						else:
							place_x_door_frame(x_unit, z_unit)
							place_x_wall(x_unit, z_unit, 1)
					else:
						if randf() < 0.5:
							if randf() < 0.5:
								place_z_wall(x_unit, z_unit, 0.5)
								place_z_wall(x_unit, z_unit + 1, 0.5)
								place_z_wall_border(x_unit, z_unit)
								place_z_wall_border(x_unit, z_unit + 1)
							else:
								place_z_window_wall(x_unit, z_unit, 0)
								place_z_window_wall(x_unit, z_unit + 1, 0)
								place_z_wall_border(x_unit, z_unit, 1.0)
								place_z_wall_border(x_unit, z_unit + 1, 1.0)
							place_z_arch(x_unit, z_unit, 1.5)
							place_z_arch(x_unit, z_unit + 1, 1.5)
							if randf() < 0.5:
								place_z_arch_fence(x_unit, z_unit, 1.5)
								place_z_arch_fence(x_unit, z_unit + 1, 1.5)
						else:
							place_z_door_frame(x_unit, z_unit)
							place_z_wall(x_unit, z_unit, 1)
				
func place_floor_tile(x_unit, z_unit, y_unit = 0.0):
	var floor_instance = floor_tile_scene.instantiate()
	var x_offset = 10.0
	var z_offset = 10.0
	var y_offset = 0.0
	floor_instance.position = Vector3(x_unit * unit_size + x_offset, y_unit * unit_size + y_offset, z_unit * unit_size + z_offset)
	self.add_child(floor_instance)
	
func place_hexagon(x_unit, z_unit, y_unit = 0.0):
	var hexagon_instance = hexagon_scene.instantiate()
	var aabb_size = get_first_mesh_size(hexagon_instance)
	var x_offset = aabb_size.x / 2.0
	var z_offset = aabb_size.z / 2.0
	var y_offset = aabb_size.y / 2.0
	hexagon_instance.position = Vector3(x_unit * unit_size + x_offset, y_unit * unit_size + y_offset, z_unit * unit_size + z_offset)
	#hexagon_instance.rotation.y = randf_range(0, 2*PI)
	self.add_child(hexagon_instance)

func place_arch_roof(x_unit, z_unit, y_unit = 1.0):
	var arch_roof_instance = arch_roof_scene.instantiate()
	var aabb_size = get_first_mesh_size(arch_roof_instance)
	var x_offset = aabb_size.x / 2.0
	var z_offset = aabb_size.z / 2.0
	var y_offset = aabb_size.y / 2.0
	arch_roof_instance.position = Vector3(x_unit * unit_size + x_offset, y_unit * unit_size + y_offset, z_unit * unit_size + z_offset)
	self.add_child(arch_roof_instance)

func place_pillar(x_unit, z_unit, y_unit = 0.0):
	var selected_pillar = all_pillars.pick_random()
	#TODO: for collapsed pillars randomize their position and rotation in the floor tile
	var pillar_instance = selected_pillar.instantiate()
	var aabb_size = get_first_mesh_size(pillar_instance)
	var x_offset = aabb_size.x / 2.0
	var z_offset = aabb_size.z / 2.0
	var y_offset = aabb_size.y / 2.0
	pillar_instance.position = Vector3(x_unit * unit_size + x_offset, y_unit * unit_size + y_offset, z_unit * unit_size + z_offset)
	if selected_pillar == pillar_collapsed_2_scene:
		pillar_instance.rotation.y = randf_range(0, 2*PI)
	self.add_child(pillar_instance)
	
func place_spike(x_unit, z_unit, y_unit = 0.0):
	var spike_instance = spike_scene.instantiate()
	var aabb_size = get_first_mesh_size(spike_instance)
	var x_offset = aabb_size.x / 2.0
	var z_offset = aabb_size.z / 2.0
	var y_offset = aabb_size.y / 2.0
	spike_instance.position = Vector3(x_unit * unit_size + x_offset + 3, y_unit * unit_size + y_offset, z_unit * unit_size + z_offset + 1)
	self.add_child(spike_instance)
	
func place_debris(x_unit, z_unit, y_unit = 0.0):
	var debris_instance = debris_scene.instantiate()
	var aabb_size = get_first_mesh_size(debris_instance)
	var x_offset = aabb_size.x / 2.0
	var z_offset = aabb_size.z / 2.0
	var y_offset = aabb_size.y / 2.0
	debris_instance.position = Vector3(x_unit * unit_size + x_offset + randf_range(0, 20), y_unit * unit_size + y_offset, z_unit * unit_size + z_offset + randf_range(0, 20))
	debris_instance.rotation.y = randf_range(0, 2*PI)
	self.add_child(debris_instance)

func place_barrel(x_unit, z_unit, y_unit = 0.0):
	var barrel_instance = barrel_scene.instantiate()
	var aabb_size = get_first_mesh_size(barrel_instance)
	var x_offset = aabb_size.x / 2.0
	var z_offset = aabb_size.z / 2.0
	var y_offset = aabb_size.y / 2.0
	barrel_instance.position = Vector3(x_unit * unit_size + x_offset + randf_range(0, 20), y_unit * unit_size + y_offset, z_unit * unit_size + z_offset + randf_range(0, 20))
	barrel_instance.rotation.y = randf_range(0, 2*PI)
	self.add_child(barrel_instance)

func place_chest(x_unit, z_unit, y_unit = 0.0):
	var chest_instance = chest_scene.instantiate()
	var aabb_size = get_first_mesh_size(chest_instance)
	var x_offset = aabb_size.x / 2.0
	var z_offset = aabb_size.z / 2.0
	var y_offset = aabb_size.y / 2.0 * 2 # extra offset because there's two mesheswwwwww
	chest_instance.position = Vector3(x_unit * unit_size + x_offset + randf_range(0, 20), y_unit * unit_size + y_offset, z_unit * unit_size + z_offset + randf_range(0, 20))
	chest_instance.rotation.y = randf_range(0, 2*PI)
	self.add_child(chest_instance)
	
func place_box(x_unit, z_unit, y_unit = 0.0):
	var box_instance = box_scene.instantiate()
	var aabb_size = get_first_mesh_size(box_instance)
	var x_offset = aabb_size.x / 2.0
	var z_offset = aabb_size.z / 2.0
	var y_offset = aabb_size.y / 2.0
	box_instance.position = Vector3(x_unit * unit_size + x_offset + randf_range(0, 20), y_unit * unit_size + y_offset, z_unit * unit_size + z_offset + randf_range(0, 20))
	box_instance.rotation.y = randf_range(0, 2*PI)
	self.add_child(box_instance)
	
func place_skull(x_unit, z_unit, y_unit = 0.0):
	var skull_instance = skull_scene.instantiate()
	var aabb_size = get_first_mesh_size(skull_instance)
	var x_offset = aabb_size.x / 2.0
	var z_offset = aabb_size.z / 2.0
	var y_offset = aabb_size.y / 2.0
	skull_instance.position = Vector3(x_unit * unit_size + x_offset + randf_range(0, 20), y_unit * unit_size + y_offset + 5, z_unit * unit_size + z_offset + randf_range(0, 20))
	skull_instance.rotation.y = randf_range(0, 2*PI)
	skull_instance.rotation.x = randf_range(0, 2*PI)
	skull_instance.rotation.z = randf_range(0, 2*PI)
	self.add_child(skull_instance)
	
func place_x_arch(x_unit, z_unit, y_unit = 1.0):
	var arch_instance = arch_scene.instantiate()
	var aabb_size = get_first_mesh_size(arch_instance)
	var x_offset = aabb_size.x / 2.0
	var z_offset = aabb_size.z / 2.0
	var y_offset = aabb_size.y / 2.0
	arch_instance.position = Vector3(x_unit * unit_size + x_offset, y_unit * unit_size + y_offset, z_unit * unit_size + z_offset)
	self.add_child(arch_instance)

func place_x_arch_fence(x_unit, z_unit, y_unit = 1.0):
	var arch_fence_instance = arch_fence_scene.instantiate()
	var aabb_size = get_first_mesh_size(arch_fence_instance)
	var x_offset = aabb_size.x / 2.0
	var z_offset = aabb_size.z / 2.0
	var y_offset = aabb_size.y / 2.0
	arch_fence_instance.position = Vector3(x_unit * unit_size + x_offset + 2, y_unit * unit_size + y_offset, z_unit * unit_size + z_offset)
	self.add_child(arch_fence_instance)
	
func place_x_wall(x_unit, z_unit, y_unit = 0.0):
	var selected_wall = all_walls.pick_random()
	var wall_instance = selected_wall.instantiate()
	var aabb_size = get_first_mesh_size(wall_instance)
	var x_offset = aabb_size.x / 2.0
	var z_offset = aabb_size.z / 2.0
	var y_offset = aabb_size.y / 2.0
	wall_instance.position = Vector3(x_unit * unit_size + x_offset, y_unit * unit_size + y_offset, z_unit * unit_size + z_offset)
	self.add_child(wall_instance)

func place_x_window_wall(x_unit, z_unit, y_unit = 0.0):
	var selected_wall = all_window_walls.pick_random()
	var wall_instance = selected_wall.instantiate()
	var aabb_size = get_first_mesh_size(wall_instance)
	var x_offset = aabb_size.x / 2.0
	var z_offset = aabb_size.z / 2.0
	var y_offset = aabb_size.y / 2.0
	wall_instance.position = Vector3(x_unit * unit_size + x_offset, y_unit * unit_size + y_offset, z_unit * unit_size + z_offset)
	self.add_child(wall_instance)

func place_z_arch(x_unit, z_unit, y_unit = 1.0):
	var arch_instance = arch_scene.instantiate()
	var aabb_size = get_first_mesh_size(arch_instance)
	var x_offset = aabb_size.z / 2.0
	var z_offset = aabb_size.x / 2.0
	var y_offset = aabb_size.y / 2.0
	arch_instance.rotation.y = PI/2
	arch_instance.position = Vector3(x_unit * unit_size + x_offset, y_unit * unit_size + y_offset, z_unit * unit_size + z_offset)
	self.add_child(arch_instance)
	
func place_z_arch_fence(x_unit, z_unit, y_unit = 1.0):
	var arch_fence_instance = arch_fence_scene.instantiate()
	var aabb_size = get_first_mesh_size(arch_fence_instance)
	var x_offset = aabb_size.z / 2.0
	var z_offset = aabb_size.x / 2.0
	var y_offset = aabb_size.y / 2.0
	arch_fence_instance.rotation.y = PI/2
	arch_fence_instance.position = Vector3(x_unit * unit_size + x_offset, y_unit * unit_size + y_offset, z_unit * unit_size + z_offset + 2)
	self.add_child(arch_fence_instance)
	
func place_z_wall(x_unit, z_unit, y_unit = 0.0):
	var selected_wall = all_walls.pick_random()
	var wall_instance = selected_wall.instantiate()
	var aabb_size = get_first_mesh_size(wall_instance)
	var x_offset = aabb_size.z / 2.0
	var z_offset = aabb_size.x / 2.0
	var y_offset = aabb_size.y / 2.0
	wall_instance.rotation.y = PI/2
	wall_instance.position = Vector3(x_unit * unit_size + x_offset, y_unit * unit_size + y_offset, z_unit * unit_size + z_offset)
	self.add_child(wall_instance)

func place_z_window_wall(x_unit, z_unit, y_unit = 0.0):
	var selected_wall = all_window_walls.pick_random()
	var wall_instance = selected_wall.instantiate()
	var aabb_size = get_first_mesh_size(wall_instance)
	var x_offset = aabb_size.z / 2.0
	var z_offset = aabb_size.x / 2.0
	var y_offset = aabb_size.y / 2.0
	wall_instance.rotation.y = PI/2
	wall_instance.position = Vector3(x_unit * unit_size + x_offset, y_unit * unit_size + y_offset, z_unit * unit_size + z_offset)
	self.add_child(wall_instance)

func place_x_wall_border(x_unit, z_unit, y_unit = 0.0):
	var selected_wall_border = all_wall_borders.pick_random()
	var wall_border_instance = selected_wall_border.instantiate()
	var aabb_size = get_first_mesh_size(wall_border_instance)
	var x_offset = aabb_size.x / 2.0
	var z_offset = aabb_size.z / 2.0
	var y_offset = aabb_size.y / 2.0
	wall_border_instance.position = Vector3(x_unit * unit_size + x_offset, y_unit * unit_size + y_offset, z_unit * unit_size + z_offset)
	self.add_child(wall_border_instance)

func place_z_wall_border(x_unit, z_unit, y_unit = 0.0):
	var selected_wall_border = all_wall_borders.pick_random()
	var wall_border_instance = selected_wall_border.instantiate()
	var aabb_size = get_first_mesh_size(wall_border_instance)
	var x_offset = aabb_size.z / 2.0
	var z_offset = aabb_size.x / 2.0
	var y_offset = aabb_size.y / 2.0
	wall_border_instance.rotation.y = PI/2
	wall_border_instance.position = Vector3(x_unit * unit_size + x_offset, y_unit * unit_size + y_offset, z_unit * unit_size + z_offset)
	self.add_child(wall_border_instance)

func place_x_door_frame(x_unit, z_unit, y_unit = 0.0):
	var selected_wall = all_door_frames.pick_random()
	var wall_instance = selected_wall.instantiate()
	var aabb_size = get_first_mesh_size(wall_instance)
	var x_offset = aabb_size.x / 2.0
	var z_offset = aabb_size.z / 2.0
	var y_offset = aabb_size.y / 2.0
	wall_instance.position = Vector3(x_unit * unit_size + x_offset, y_unit * unit_size + y_offset, z_unit * unit_size + z_offset)
	self.add_child(wall_instance)

func place_z_door_frame(x_unit, z_unit, y_unit = 0.0):
	var selected_wall = all_door_frames.pick_random()
	var wall_instance = selected_wall.instantiate()
	var aabb_size = get_first_mesh_size(wall_instance)
	var x_offset = aabb_size.z / 2.0
	var z_offset = aabb_size.x / 2.0
	var y_offset = aabb_size.y / 2.0
	wall_instance.rotation.y = PI/2
	wall_instance.position = Vector3(x_unit * unit_size + x_offset, y_unit * unit_size + y_offset, z_unit * unit_size + z_offset)
	self.add_child(wall_instance)

func place_x_block_arch(x_unit, z_unit, y_unit = 1.0):
	var block_arch_instance = block_arch_scene.instantiate()
	var aabb_size = get_first_mesh_size(block_arch_instance)
	var x_offset = aabb_size.x / 2.0
	var z_offset = aabb_size.z / 2.0
	var y_offset = aabb_size.y / 2.0
	block_arch_instance.position = Vector3(x_unit * unit_size + x_offset, y_unit * unit_size + y_offset, z_unit * unit_size + z_offset)
	self.add_child(block_arch_instance)
	
func place_z_block_arch(x_unit, z_unit, y_unit = 1.0):
	var block_arch_instance = block_arch_scene.instantiate()
	var aabb_size = get_first_mesh_size(block_arch_instance)
	var x_offset = aabb_size.z / 2.0
	var z_offset = aabb_size.x / 2.0
	var y_offset = aabb_size.y / 2.0
	block_arch_instance.rotation.y = PI/2
	block_arch_instance.position = Vector3(x_unit * unit_size + x_offset, y_unit * unit_size + y_offset, z_unit * unit_size + z_offset)
	self.add_child(block_arch_instance)
	
func place_block(x_unit, z_unit, y_unit = 2.0):
	var block_instance = block_scene.instantiate()
	var aabb_size = get_first_mesh_size(block_instance)
	var x_offset = aabb_size.x / 2.0
	var z_offset = aabb_size.z / 2.0
	var y_offset = aabb_size.y / 2.0
	block_instance.position = Vector3(x_unit * unit_size + x_offset, y_unit * unit_size + y_offset, z_unit * unit_size + z_offset)
	self.add_child(block_instance)

func place_chandelier(x_unit, z_unit, y_unit = 2.0):
	var chandelier_instance = chandelier_scene.instantiate()
	var aabb_size = get_first_mesh_size(chandelier_instance)
	var x_offset = aabb_size.x / 2.0
	var z_offset = aabb_size.z / 2.0
	var y_offset = aabb_size.y / 2.0
	chandelier_instance.position = Vector3(x_unit * unit_size + x_offset + (unit_size - aabb_size.x)/2, y_unit * unit_size + y_offset + (unit_size - aabb_size.y), z_unit * unit_size + z_offset + (unit_size - aabb_size.z)/2)
	self.add_child(chandelier_instance)
	
## Searches for the first MeshInstance3D child and returns its AABB size.
## Returns Vector3.ZERO if no mesh is found.
func get_first_mesh_size(root_node: Node) -> Vector3:
	var mesh_instance = _find_first_mesh_instance(root_node)
	
	if mesh_instance and mesh_instance.mesh:
		# get_aabb() returns the bounding box in local space
		var aabb: AABB = mesh_instance.get_mesh().get_aabb()
		
		# We multiply by scale in case the node has been resized in the editor
		return aabb.size * root_node.scale
	
	print("No mesh found in: ", root_node.name)
	return Vector3.ZERO

## Helper function to recursively find the first MeshInstance3D
func _find_first_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	
	for child in node.get_children():
		var found = _find_first_mesh_instance(child)
		if found:
			return found
			
	return null

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass
