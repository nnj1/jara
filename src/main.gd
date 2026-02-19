extends Node2D

# UI References
@onready var player_name_input = $CanvasLayer/VBoxContainer/HBoxContainer/PlayerName
@onready var server_item_list = $"CanvasLayer/VBoxContainer/TabContainer/Join Game/ServerList"
@onready var manual_ip_input = $CanvasLayer/VBoxContainer/HBoxContainer/HostName

@onready var host_server_name = $"CanvasLayer/VBoxContainer/TabContainer/Create Server/ServerName"

# To keep track of discovered servers and their IPs
var discovered_ips = []

func _ready():
	MultiplayerManager.start_listening()
	
	# Pre-fill defaults
	host_server_name.text = MultiplayerManager.server_name

# --- SERVER BROWSER LOGIC ---

func _on_refresh_list_timeout():
	# This timer runs every second to grab new UDP packets
	var servers = MultiplayerManager.get_discovered_servers()
	
	if servers.size() > 0:
		# Clear and rebuild list to remove old servers
		server_item_list.clear()
		discovered_ips.clear()
		
		for server in servers:
			var display_text = "%s | Players: %d | IP: %s" % [server.name, server.count, server.ip]
			server_item_list.add_item(display_text)
			discovered_ips.append(server.ip)

func _on_server_list_item_activated(index):
	# Triggered when double-clicking or pressing enter on a list item
	_connect_to_server(discovered_ips[index])

func _on_join_manual_pressed():
	_connect_to_server(manual_ip_input.text)

func _connect_to_server(ip: String):
	_update_local_identity()
	MultiplayerManager.join_game(ip)

# --- HOSTING LOGIC ---

func _on_host_button_pressed():
	_update_local_identity()
	
	# Apply Host-only settings
	MultiplayerManager.server_name = host_server_name.text
	MultiplayerManager.server_settings["some_setting"] = true
	
	MultiplayerManager.host_game()

func _update_local_identity():
	# Ensure the name is set before any network action
	var final_name = player_name_input.text
	if final_name.is_empty(): final_name = "Pilgrim_" + str(randi() % 1000)
	MultiplayerManager.player_name = final_name


func _on_button_pressed() -> void:
	var credits_scene = preload('res://scenes/main_scenes/popup_window.tscn').instantiate()
	credits_scene.contents_bb_code = 'Some shit would go here'
	credits_scene.window_title = 'Credits'
	$CanvasLayer.add_child(credits_scene)
