extends AnimatableBody3D

@export var TOMBSTONE_TYPE: bool = false

# Audio
var open_sound: AudioStreamPlayer3D
var close_sound: AudioStreamPlayer3D

# State Management
var open_state: bool = false
var is_tweening: bool = false
var last_target_angle: float = 0.0

# Transform Anchors
var current_start_trans: Transform3D
var current_start_pivot: Vector3
var hinge: Marker3D

@onready var door_height: float = $CollisionShape3D.shape.size.y

func _ready() -> void:
	# Interaction Setup
	self.set_meta('interaction_message', 'Press E to open')
	self.set_meta('interaction_function', 'toggle_door')
	
	# Node References
	open_sound = get_node_or_null('openSound')
	close_sound = get_node_or_null('closeSound')
	hinge = get_node_or_null('hinge')
	
	# Delay capture to ensure procedural placement is finished 
	# and the node is fully inside the SceneTree.
	call_deferred("initialize_anchor")

func initialize_anchor() -> void:
	if hinge:
		current_start_trans = global_transform
		current_start_pivot = hinge.global_position
	else:
		push_warning("Hinge Marker3D not found on: ", name)

func toggle_door(player_path: NodePath) -> void:
	rpc('toggle_door_sync', player_path)

@rpc("any_peer", "call_local","reliable")
func toggle_door_sync(player_path: NodePath) -> void:
	var player = get_node(player_path)
	if is_tweening:
		return
		
	if open_state:
		close_door(player)
	else:
		open_door(player)

func open_door(player: Node3D) -> void:
	open_state = true
	is_tweening = true
	self.set_meta('interaction_message', 'Press E to close')
	
	if not TOMBSTONE_TYPE:
		# Dynamic Swing Logic
		# Vector from door to player
		var to_player = (player.global_position - global_position).normalized()
		# Assuming -Z is forward
		var door_forward = -global_transform.basis.z 
		var dot = door_forward.dot(to_player)
		
		# If dot > 0, player is in front, swing away (negative angle)
		last_target_angle = -PI/2 if dot > 0 else PI/2
		
		var tween = create_tween()
		tween.tween_method(
			func(angle): rotate_door(angle, current_start_trans, current_start_pivot),
			0.0, last_target_angle, 1.0
		).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		
		tween.finished.connect(func(): is_tweening = false)
	else:
		# Tombstone sliding logic
		var tween = move_along_y(-1 * (door_height - 1))
		tween.finished.connect(func(): is_tweening = false)

	if open_sound:
		open_sound.play()
	
func close_door(_player: Node3D) -> void:
	open_state = false
	is_tweening = true
	self.set_meta('interaction_message', 'Press E to open')
	
	if not TOMBSTONE_TYPE:
		var tween = create_tween()
		# Return from the last target angle back to 0
		tween.tween_method(
			func(angle): rotate_door(angle, current_start_trans, current_start_pivot),
			last_target_angle, 0.0, 1.0
		).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		
		tween.finished.connect(func(): is_tweening = false)
	else:
		var tween = move_along_y(door_height - 1)
		tween.finished.connect(func(): is_tweening = false)

	if close_sound:
		close_sound.play()

func rotate_door(angle: float, start_trans: Transform3D, start_pivot: Vector3) -> void:
	if not hinge: return
	
	# 1. Get world axis (Hinge Y)
	var rotation_axis = (start_trans.basis * hinge.transform.basis.y).normalized()
	var rotation_basis = Basis(rotation_axis, angle)
	
	# 2. Calculate offset (Arm) from pivot to door center
	var pivot_to_center = start_trans.origin - start_pivot
	
	# 3. Rotate the arm
	var rotated_offset = rotation_basis * pivot_to_center
	
	# 4. Update transform
	var final_trans = start_trans
	final_trans.origin = start_pivot + rotated_offset
	final_trans.basis = rotation_basis * start_trans.basis
	
	global_transform = final_trans

func move_along_y(change_in_y: float) -> Tween:
	var tween = create_tween()
	var target_pos = global_position + Vector3(0, change_in_y, 0) 
	tween.tween_property(self, "global_position", target_pos, 2.0) \
		.set_trans(Tween.TRANS_SINE) \
		.set_ease(Tween.EASE_OUT)
	return tween
