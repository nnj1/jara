extends Node

# --- Signals for UI Updating ---
signal connection_failed
signal connection_success
signal player_list_changed
signal server_settings_updated

# --- Constants ---
const DEFAULT_PORT = 7000
const BROADCAST_PORT = 7001
const BROADCAST_INTERVAL = 2.0

# --- State Variables ---
var local_username: String = "Guest"

# The "Source of Truth" for the game world
var server_settings = {
	"game_name": "Procedural World",
	"host_name": "Player 1",
	"max_players": 4,
	"current_players": 0,
	"map_type": "procedural",
	"map_seed": 0
}

# The dictionary of all connected players: { id: { "name": "str" } }
var players = {} :
	set(val):
		players = val
		player_list_changed.emit()

# --- Internal Networking ---
var udp_broadcast: PacketPeerUDP
var broadcast_timer: Timer

func _ready():
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connection_success)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

# --- Public API ---

func host_game(username: String, game_name: String, max_p: int):
	local_username = username
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(DEFAULT_PORT, max_p)
	
	if error != OK:
		return error
		
	multiplayer.multiplayer_peer = peer
	
	# Setup Host Data
	server_settings.host_name = username
	server_settings.game_name = game_name
	server_settings.max_players = max_p
	server_settings.map_seed = randi() # Generate unique world seed
	
	# Add the host (ID 1) to the player list
	_add_player(1, username)
	_setup_broadcast()
	return OK

func join_game(address: String, username: String):
	local_username = username
	if address == "": address = "127.0.0.1"
	
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(address, DEFAULT_PORT)
	
	if error != OK:
		return error
		
	multiplayer.multiplayer_peer = peer
	return OK

# --- RPC Sync Functions ---

@rpc("authority", "call_local", "reliable")
func sync_server_settings(new_settings: Dictionary):
	server_settings = new_settings
	server_settings_updated.emit()

@rpc("authority", "call_local", "reliable")
func sync_player_list(new_player_dict: Dictionary):
	players = new_player_dict

@rpc("any_peer", "reliable")
func _register_player(username: String):
	if not multiplayer.is_server(): return
	var id = multiplayer.get_remote_sender_id()
	_add_player(id, username)

func _add_player(id: int, username: String):
	players[id] = {"name": username}
	server_settings.current_players = players.size()
	
	# Push updates to everyone
	sync_player_list.rpc(players)
	sync_server_settings.rpc(server_settings)

# --- UDP Broadcasting (LAN Discovery) ---

func _setup_broadcast():
	udp_broadcast = PacketPeerUDP.new()
	udp_broadcast.set_broadcast_enabled(true)
	udp_broadcast.dest_address = "255.255.255.255"
	udp_broadcast.dest_port = BROADCAST_PORT
	
	broadcast_timer = Timer.new()
	broadcast_timer.wait_time = BROADCAST_INTERVAL
	broadcast_timer.autostart = true
	broadcast_timer.timeout.connect(_on_broadcast_timeout)
	add_child(broadcast_timer)

func _on_broadcast_timeout():
	var data = JSON.stringify(server_settings)
	udp_broadcast.put_packet(data.to_utf8_buffer())

# --- Connection Callbacks ---

@warning_ignore("unused_parameter")
func _on_peer_connected(id):
	# If we are a client, we tell the server who we are
	if not multiplayer.is_server():
		_register_player.rpc(local_username)

func _on_peer_disconnected(id):
	if multiplayer.is_server():
		players.erase(id)
		server_settings.current_players = players.size()
		sync_player_list.rpc(players)
		sync_server_settings.rpc(server_settings)

func _on_connection_success():
	connection_success.emit()

func _on_connection_failed():
	multiplayer.multiplayer_peer = null
	connection_failed.emit()

func _on_server_disconnected():
	multiplayer.multiplayer_peer = null
	players.clear()
	# Stop broadcasting if we were the host
	if is_instance_valid(broadcast_timer):
		broadcast_timer.queue_free()
