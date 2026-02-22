extends RigidBody3D
class_name EntityRigidBody

@onready var main_game_node = get_tree().get_root().get_node('Game')

@export var is_pickable: bool = false
@export var throw_power: float = 5.0 # How hard the object is tossed forward

@export var is_held: bool = false : set = set_is_held
var _hold_target: Marker3D = null

func _ready() -> void:
	is_held = false

func set_is_held(value):
	is_held = value # Ensure the variable actually updates
	if value == false:
		if not is_pickable:
			set_meta('interaction_message', null)
			set_meta('interaction_function', null)
		else:
			set_meta('interaction_message', 'Press E to pick up')
			set_meta('interaction_function', 'pick_up_synced')
			# Re-enable collision detection with Layer 2 (Players)
			set_collision_mask_value(2, true)
			set_collision_layer_value(3, true)
	else:
		remove_meta('interaction_message')
		remove_meta('interaction_function')
		# Disable collision detection with Layer 2 (Players) so it doesn't jitter or push the player
		set_collision_mask_value(2, false)
		set_collision_layer_value(3, false)


func _physics_process(_delta):
	# If we are being held, snap to the player's hand every frame
	# Since we aren't reparenting, this keeps the Spawner hierarchy stable.
	if _hold_target:
		global_transform = _hold_target.global_transform

func is_authority() -> bool:
	return get_multiplayer_authority() == multiplayer.get_unique_id()

# --- PICK UP LOGIC ---

func pick_up_synced(player_path):
	# If the object isn't pickable forget this entire thing
	if not is_pickable: return
	# If the player is already holding an object, prevent them from picking up the new object
	if get_node(player_path).held_object:
		#TODO: DO SOMETHING HERE
		pass
	else:
		# Request the server to handle the pickup
		rpc_id(1, "request_pick_up")

@rpc("any_peer", "call_local", "reliable")
func request_pick_up():
	if not multiplayer.is_server(): return
	var sender_id = multiplayer.get_remote_sender_id()
	
	# Server validates ownership and syncs to all clients
	set_multiplayer_authority(sender_id)
	rpc("remote_pick_up", sender_id)

@rpc("authority", "call_local", "reliable")
func remote_pick_up(player_id: int):
	var player = main_game_node.get_node("players/" + str(player_id))
	_hold_target = player.get_node("left_arm/hold_point")
	is_held = true
	# Freeze physics so it doesn't fight the manual transform updates
	freeze = true
	# Let the player who is the one who picked up know they successfully picked up
	if multiplayer.get_unique_id() == player_id:
		main_game_node.get_node('players/' + str(player_id)).held_object = self

# --- DROP LOGIC ---

func drop_synced():
	rpc_id(1, "request_drop")

@rpc("any_peer", "call_local", "reliable")
func request_drop():
	if not multiplayer.is_server(): return
	
	# Hand authority back to the server for world physics
	set_multiplayer_authority(1)
	rpc("remote_drop")

@rpc("authority", "call_local", "reliable")
func remote_drop():
	var release_vel = Vector3.ZERO
	var throw_dir = Vector3.ZERO
	
	if _hold_target:
		# Climb the tree: hold_point -> left_arm -> player
		var player = _hold_target.get_parent().get_parent() 
		
		# 1. Inherit player's current movement
		if "velocity" in player:
			release_vel = player.velocity
		
		# 2. Calculate forward thrust (Basis.z is backward, so -z is forward)
		# We add a tiny bit of Vector3.UP (0.1) so it doesn't hit the floor instantly
		throw_dir = (-player.global_transform.basis.z + (Vector3.UP * 0.1)).normalized()
	
	# 3. Release the lock and re-enable physics
	_hold_target = null
	is_held = false
	freeze = false
	
	# 4. Set the final velocity (Current Movement + The Throw)
	linear_velocity = release_vel + (throw_dir * throw_power)
	
	# 5. Add a little "tumble" for realism
	angular_velocity = Vector3(randf(), randf(), randf()).normalized() * 2.0

# - IMPULSE FUNCTIONS

## The wrapper method you'll call in your game code
func apply_impulse_synced(impulse: Vector3):
	# Send the command to the server/authority
	rpc("remote_apply_impulse", impulse)

## The RPC that actually performs the physics work
@rpc("any_peer", "call_local", "reliable")
func remote_apply_impulse(impulse: Vector3):
	# Only the authority should process physics to avoid 'jitter'
	# from multiple sources fighting over the position.
	if is_authority():
		apply_central_impulse(impulse)
