extends Control

@export var contents_bb_code: String = 'Some shit would go here'
@export var window_title: String = 'Title would go here'
@export var contents_json: Array

# Dragging variables
var dragging: bool = false
var drag_offset: Vector2 = Vector2.ZERO

@onready var header = $Panel/VBoxContainer/HBoxContainer/window_title

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$Panel/VBoxContainer/HBoxContainer/window_title.text = window_title
	$Panel/VBoxContainer/RichTextLabel.text = contents_bb_code
	
	# Connect the gui_input signal of the header via code 
	# (or do it in the editor UI)
	header.gui_input.connect(_on_header_gui_input)

func _on_header_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			dragging = event.pressed
			# Calculate the distance between the mouse and the top-left of the window
			drag_offset = get_global_mouse_position() - global_position
			
	if event is InputEventMouseMotion and dragging:
		# Update window position based on mouse movement
		global_position = get_global_mouse_position() - drag_offset

func _on_button_pressed() -> void:
	queue_free()
		
func _input(event):
	if event is InputEventKey and event.is_pressed():
		print("Control caught key: ", event.as_text())
		# This stops the input from reaching other nodes or the UI
		get_viewport().set_input_as_handled()
		
	if event.is_action_pressed('ui_cancel'):
		queue_free()
		
		# This stops the input from reaching other nodes or the UI
		get_viewport().set_input_as_handled()

func setup_tree_view():
	# hide the richtext
	$Panel/VBoxContainer/RichTextLabel.hide()
	
	# 1. Create the Tree instance
	var tree = Tree.new()
	tree.mouse_filter = Control.MOUSE_FILTER_STOP
	$Panel/VBoxContainer.add_child(tree)

	# 3. Layout: Expand to fit parent
	tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	# 4. Tree Setup
	tree.columns = 2
	tree.set_column_title(0, "Property / Index")
	tree.set_column_title(1, "Value")
	tree.column_titles_visible = true
	tree.add_theme_font_size_override('font_size', 20)
	tree.add_theme_font_size_override('title_button_font_size', 20)
	
	var root = tree.create_item()
	tree.hide_root = true
	
	# 5. Populate
	populate_from_array(contents_json, root, tree)

func populate_from_array(data_array: Array, root_item: TreeItem, tree: Tree):
	for i in range(data_array.size()):
		# Create a parent node for each Dictionary in the array
		var entry_node = tree.create_item(root_item)
		entry_node.set_text(0, "Entry " + str(i))
		#entry_node.set_custom_bg_color(0, Color(1, 1, 1, 0.1)) # Subtle highlight for entries
		
		# Now parse the dictionary inside that entry
		var dict = data_array[i]
		if dict is Dictionary:
			_parse_recursive(dict, entry_node, tree)

func _parse_recursive(data, parent_item: TreeItem, tree: Tree):
	if data is Dictionary:
		for key in data.keys():
			var child = tree.create_item(parent_item)
			child.set_text(0, str(key))
			
			var val = data[key]
			if val is Dictionary or val is Array:
				_parse_recursive(val, child, tree)
			else:
				child.set_text(1, str(val))
				
	elif data is Array:
		for i in range(data.size()):
			var child = tree.create_item(parent_item)
			child.set_text(0, "[" + str(i) + "]")
			
			var val = data[i]
			if val is Dictionary or val is Array:
				_parse_recursive(val, child, tree)
			else:
				child.set_text(1, str(val))
