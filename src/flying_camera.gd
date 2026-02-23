extends Camera3D

@onready var main_game_node = get_parent() if get_tree().get_root().get_node_or_null('Game') == null else get_tree().get_root().get_node('Game')

@export_group("Settings")
@export var active: bool = false
@export var mouse_sensitivity: float = 0.15
@export var move_speed: float = 200.0
@export var acceleration: float = 15.0

var velocity: Vector3 = Vector3.ZERO
var is_locked: bool = false 
var _rot_x: float = 0.0
var _rot_y: float = 0.0

func _ready():
	#active = false
	_rot_x = rotation.x
	_rot_y = rotation.y
	if active:
		make_current()
		_set_mouse_lock(true)

func _unhandled_input(event):
	if not active: return

	if event is InputEventMouseButton and event.pressed:
		if not is_locked: _set_mouse_lock(true)

	if event is InputEventMouseMotion and is_locked:
		_rot_y -= event.relative.x * deg_to_rad(mouse_sensitivity)
		_rot_x -= event.relative.y * deg_to_rad(mouse_sensitivity)
		_rot_x = clamp(_rot_x, deg_to_rad(-89), deg_to_rad(89))
		transform.basis = Basis.from_euler(Vector3(_rot_x, _rot_y, 0))

	if event.is_action_pressed("ui_cancel"):
		_set_mouse_lock(!is_locked)

func _set_mouse_lock(lock: bool):
	is_locked = lock
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if lock else Input.MOUSE_MODE_VISIBLE

func _process(delta):
	if active and is_locked:
		_handle_movement(delta)
		$SpotLight3D.show()
	
	if not active:
		$SpotLight3D.hide()
		if main_game_node:
			var player = main_game_node.get_node_or_null('players/' + str(multiplayer.get_unique_id()))
			if player:
				self.position = player.position
	

func _handle_movement(delta):
	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var y_axis = 0.0
	if Input.is_key_pressed(KEY_SPACE): y_axis += 1.0
	if Input.is_key_pressed(KEY_SHIFT): y_axis -= 1.0

	# Direction based on camera orientation
	var dir = (global_transform.basis.z * input_dir.y) + (global_transform.basis.x * input_dir.x) + (Vector3.UP * y_axis)
	
	if dir.length() > 0:
		dir = dir.normalized()

	velocity = velocity.lerp(dir * move_speed, acceleration * delta)
	global_position += velocity * delta
