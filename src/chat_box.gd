extends Control

@onready var main_game_node = get_tree().get_root().get_node('Game')

@onready var chat_display: RichTextLabel = $PanelContainer/VBoxContainer/RichTextLabel
@onready var chat_input: LineEdit = $PanelContainer/VBoxContainer/LineEdit

var regex = RegEx.new()

func _ready():
	
	# Pattern Breakdown:
	# ^/add          -> Starts with /add
	# (?<type>\w+)   -> Captures the resource name (wood, stone, etc.)
	# \s+            -> One or more spaces
	# (?<amount>\d+) -> Captures the integer
	regex.compile("^/add(?<type>wood|stone|gold|food)\\s+(?<amount>\\d+)")
	
	# Ensure the input starts unfocused
	chat_input.release_focus()
	
	# Optional: styling the chat display to auto-scroll
	chat_display.scroll_following = true
	
	chat_input.text_submitted.connect(_on_text_submitted)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		if not chat_input.has_focus():
			chat_input.grab_focus()
			main_game_node.get_node('players/' + str(multiplayer.get_unique_id())).is_typing_chat = true
			# Consume the event so it doesn't trigger other things
			get_viewport().set_input_as_handled()
			
	if event.is_action_pressed("console"):
		if not chat_input.has_focus():
			chat_input.grab_focus()
			# Consume the event so it doesn't trigger other things
			get_viewport().set_input_as_handled()
			chat_input.text = '/'
			chat_input.caret_column = 1
			
	if event.is_action_pressed("ui_cancel"):
		if chat_input.has_focus():
			chat_input.text = ''
			chat_input.release_focus()
			main_game_node.get_node('players/' + str(multiplayer.get_unique_id())).is_typing_chat = false
			get_viewport().set_input_as_handled()
			
func _on_text_submitted(new_text: String):
	if new_text != "":
		# 1. Send the text to the chat
		rpc('update_chat_display', MultiplayerManager.player_name + ': ' + new_text)
	# 2. Clear the input field
	chat_input.clear()
	# 3. Release focus so the player can move/play again
	chat_input.release_focus()
	main_game_node.get_node('players/' + str(multiplayer.get_unique_id())).is_typing_chat = false

	
	# TODO: 4. Do some local stuff if the chat contains a command and god mode is active
	if MultiplayerManager.server_settings.god_mode:
		if new_text.begins_with('/'):
			handle_command(new_text)
	
@rpc("any_peer", "call_local", "reliable")
func update_chat_display(message: String):
	chat_display.append_text("\n" + message)
	$AudioStreamPlayer.play()

func handle_command(input: String):
	var result = regex.search(input)
	
	if result:
		var type = result.get_string("type")
		var amount = result.get_string("amount").to_int()
		
		apply_resource(type, amount)
	else:
		print("Invalid command or resource type!")

func apply_resource(type: String, amount: int):
	match type:
		"wood":
			main_game_node.add_wood(amount)
			print("Added ", amount, " wood.")
		"stone":
			main_game_node.add_stone(amount)
			print("Added ", amount, " stone.")
		"gold":
			main_game_node.add_gold(amount)
			print("Added ", amount, " gold.")
		"food":
			main_game_node.add_food(amount)
			print("Added ", amount, " food.")
