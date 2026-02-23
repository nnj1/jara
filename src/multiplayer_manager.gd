extends Node

# --- Constants ---
const PORT = 9999              
const LAN_PORT = 9991          
const DEFAULT_IP = "localhost" 
const BROADCAST_ADDRESS = "127.255.255.255"

# --- Local Player State ---
var player_name: String = "Pilgrim " 
var server_name: String = "Generic Match"

# --- Global Match State ---
var players = {}  # { "peer_id": {"name": "str"} }

# --- SERVER SETTINGS ---
var server_settings = {
	"god_mode": true,
	"map_seed": 0
}

signal settings_received

# --- Networking Tools ---
var udp_socket := PacketPeerUDP.new()
var broadcast_timer: Timer

func _ready():
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connection_success)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	
	broadcast_timer = Timer.new()
	broadcast_timer.wait_time = 2.0 
	broadcast_timer.timeout.connect(_broadcast_presence)
	add_child(broadcast_timer)
	
	generate_new_seed()

func generate_new_seed():
	# Only the host decides the seed
	if multiplayer.is_server() or multiplayer.multiplayer_peer == null:
		randomize() 
		server_settings["map_seed"] = randi() 
		print("New seed generated: ", server_settings["map_seed"])

# --- HOSTING & JOINING ---

func host_game():
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(PORT, 10) 
	if error != OK:
		print("Failed to host: ", error)
		return
	
	multiplayer.multiplayer_peer = peer
	players["1"] = {"name": player_name}
	
	udp_socket.set_broadcast_enabled(true)
	udp_socket.set_dest_address(BROADCAST_ADDRESS, LAN_PORT)
	broadcast_timer.start()
	
	load_game()

func join_game(address: String):
	stop_listening() 
	if address.is_empty(): address = DEFAULT_IP
	
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(address, PORT)
	if error != OK:
		print("Failed to join: ", error)
		return
		
	multiplayer.multiplayer_peer = peer

# --- HANDSHAKE & SYNC ---

func _on_connection_success():
	register_player.rpc_id(1, player_name)
	load_game()

@rpc("any_peer", "call_remote", "reliable")
func register_player(chosen_name: String):
	if multiplayer.is_server():
		var id = multiplayer.get_remote_sender_id()
		players[str(id)] = {"name": chosen_name}
		_sync_global_state()

func _on_peer_connected(id: int):
	if multiplayer.is_server():
		# Send current god_mode and map_seed to the joining player
		sync_settings.rpc_id(id, JSON.stringify(server_settings))
			
func _sync_global_state():
	update_all_clients.rpc(JSON.stringify(players))

@rpc("authority", "call_local", "reliable")
func update_all_clients(p_json: String):
	players = JSON.parse_string(p_json)

@rpc("authority", "call_remote", "reliable")
func sync_settings(s_json: String):
	server_settings = JSON.parse_string(s_json)
	settings_received.emit()

# --- DISCONNECTION HANDLING ---

func _on_peer_disconnected(id: int):
	if multiplayer.is_server():
		players.erase(str(id))
		_sync_global_state()

func _on_server_disconnected():
	_cleanup_and_exit()

func _on_connection_failed():
	print('Connection failed.')
	_cleanup_and_exit()

# --- DISCONNECTION HANDLING ---

## Public function to leave the game or stop the server
func leave_game():
	if multiplayer.multiplayer_peer is ENetMultiplayerPeer:
		multiplayer.multiplayer_peer.close()
	
	# Manually trigger cleanup since close() doesn't always 
	# trigger signals for the local player immediately
	_cleanup_and_exit()

# Modify your existing cleanup to be slightly more robust
func _cleanup_and_exit():
	# Stop UDP broadcasting if we were hosting
	broadcast_timer.stop()
	udp_socket.close()
	
	# Reset networking and data
	multiplayer.multiplayer_peer = null
	players.clear()
	
	# Navigate back to the main menu
	# Note: Use deferred call if you run into "Locked Header" errors during scene changes
	get_tree().change_scene_to_file.call_deferred("res://scenes/main_scenes/main.tscn")
	print("Disconnected and returned to menu.")

# --- LAN DISCOVERY ---

func _broadcast_presence():
	var info = {"name": server_name, "port": PORT, "count": players.size()}
	var packet = JSON.stringify(info).to_utf8_buffer()
	
	udp_socket.set_dest_address(BROADCAST_ADDRESS, LAN_PORT)
	udp_socket.put_packet(packet)
	
	udp_socket.set_dest_address("127.0.0.1", LAN_PORT)
	udp_socket.put_packet(packet)

func start_listening():
	if not udp_socket.is_bound():
		udp_socket.bind(LAN_PORT)

func stop_listening():
	udp_socket.close()

func get_discovered_servers() -> Array:
	var servers = []
	while udp_socket.get_available_packet_count() > 0:
		var packet_ip = udp_socket.get_packet_ip()
		var data = JSON.parse_string(udp_socket.get_packet().get_string_from_utf8())
		if data:
			data["ip"] = packet_ip
			servers.append(data)
	return servers

# --- HELPERS ---

func load_game():
	get_tree().change_scene_to_file("res://scenes/main_scenes/game.tscn")

func get_player_name(peer_id: int) -> String:
	var id_string = str(peer_id)
	if players.has(id_string):
		return players[id_string]["name"]
	return "Unknown"
