extends MultiplayerSpawner

@export var player_scene: PackedScene = preload("res://scenes/main_scenes/player.tscn")

func _ready() -> void:
	# 1. Assign the custom spawn function
	self.spawn_function = _custom_spawn
	
	if multiplayer.is_server():
		multiplayer.peer_connected.connect(_on_peer_connected)
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
		
		# 2. WAIT one frame for the Game node to be ready
		_start_initial_spawning.call_deferred()

func _start_initial_spawning():
	# Spawn for host
	spawn(1)
	
	# Spawn for anyone who joined during the loading screen
	for id in multiplayer.get_peers():
		spawn(id)

func _on_peer_connected(id: int):
	spawn(id)

func _custom_spawn(data: Variant) -> Node:
	var id = data
	var p = player_scene.instantiate()
	p.name = str(id)
	
	# Set authority immediately
	p.set_multiplayer_authority(id)
	
	# Fix: Use local position instead of global_position here.
	# Or, even better, set the position in a way that doesn't require the tree.
	if get_parent().has_method("get_spawn_position"):
		var target_pos = get_parent().get_spawn_position()
		
		# Since the player will be a child of the Spawner's target path,
		# setting 'position' is safer if the parent is at (0,0,0).
		# To be 100% safe with global coordinates, we use a deferred call:
		p.set_deferred("global_position", target_pos)
	
	return p

func _on_peer_disconnected(id: int):
	if has_node(str(id)):
		get_node(str(id)).queue_free()
