extends CharacterBody3D

class_name Player

@onready var main_game_node = get_tree().get_root().get_node('Game')

## Movement parameters (Quake-style)
@export_group("Movement Physics")
@export var walk_speed: float = 40.0
@export var run_acceleration: float = 14.0
@export var air_acceleration: float = 120.0 
@export var air_cap: float = 1.0            
@export var friction: float = 6.0
@export var jump_velocity: float = 20.0
@export var gravity: float = 32.0

## Interaction with RigidBodies
@export_group("Physics Interaction")
@export var push_force: float = 1.5
@export var attack_impulse: float = 50.0 # Force applied during start_attack()

## Look and State
@export_group("Look Settings")
@export var sensitivity: float = 0.002
@export var is_active: bool = true 

## Bob and Tilt Settings
@export_group("Juice")
@export var bob_freq: float = 1.0
@export var bob_amp: float = 0.0 # Set to 0.3 or similar to enable
@export var tilt_amount: float = 0.05
@export var tilt_speed: float = 5.0

## Spell Settings
@onready var fireball_scene: PackedScene = preload('res://scenes/model_scenes/entities/Fireball.tscn')
@export var lob_strength: float = 30.0
@export var upward_bias: float = 0.3 # Adds the "lob" arch
@onready var muzzle = $Camera3D/Muzzle

## Animation Parameters
@onready var body_animation_tree: AnimationTree = $rig/AnimationTree
@onready var right_arm_animation_player: AnimationPlayer = $right_arm/AnimationPlayer
@onready var block_timer: float = 0.0 # how long block key was held

# Internal variables
var is_mouse_captured: bool = true
var _bob_time: float = 0.0
var _camera_rotation := Vector2.ZERO 
var _current_weapon_index: int = 0 : set = change_weapon
var is_attacking: bool = false # Tracked for AnimationPlayer
var is_blocking: bool = false
var is_parrying: bool = false
var parry_timer: float = 0.0
@export var parry_window_default: float = 0.1
var held_object: EntityRigidBody = null
var held_object_rotation_speed: float = 5.0

@onready var camera: Camera3D = $Camera3D
@onready var _default_cam_height: float = camera.position.y
@onready var interaction_ray: RayCast3D = $Camera3D/RayCast3D
@onready var attack_ray: RayCast3D = $Camera3D/RayCast3D2

func _ready() -> void:
	
	# Turn off all flying camera
	if is_multiplayer_authority():
		camera.make_current()
		capture_mouse(true)
		_camera_rotation.y = rotation.y
		_camera_rotation.x = camera.rotation.x
	else:
		is_active = false
		camera.current = false
		# make it's player model visible to the other players
		$rig/Skeleton3D/Knight.set_layer_mask_value(1, true)
	
	# set the default weapon
	change_weapon(0)
	
	# Configure the health component
	$HealthComponent.max_health = 100.0
	$HealthComponent.damaged.connect(on_taking_damage)
	$HealthComponent.parried.connect(on_successful_parry)
	if is_multiplayer_authority():
		$HealthComponent.health_changed.connect(update_ui)
	
# SIGNALS THAT JACK INTO THE UI	
func update_ui(current_health, max_health):
	var hp_label = main_game_node.get_node_or_null('UI/player_stats/VBoxContainer/HP_label')
	if hp_label:
		hp_label.text = 'HP: ' + str(int(current_health)) + '/' + str(int(max_health))

# --- ANIMATION FOR SUCCESSFUL PARRY ---
func on_successful_parry():
	pass
	
# --- ANIMATION FOR TAKING DAMAGE ---
func on_taking_damage(amount):
	if not is_blocking:
		$CreatureSoundPlayer.play_hurt()
		main_game_node.flash_damage_animation()
		tilt_camera_3d(0.05 * amount)
	elif is_blocking:
		tilt_camera_3d(0.025 * amount)
		
func tilt_camera_3d(intensity: float = 0.05, duration: float = 0.1):
	var tween = create_tween()
	# Rotate on the Z axis (Roll)
	# Vector3(0, 0, intensity) tilts left/right
	var direction = 1 if randf() > 0.5 else -1
	tween.tween_property(camera, "rotation:z", intensity * direction, duration).set_trans(Tween.TRANS_SINE)	
	# Return to zero
	tween.tween_property(camera, "rotation:z", 0, duration).set_trans(Tween.TRANS_SINE)
	
# --- NEW ATTACK and BLOCK METHODS FOR ANIMATION PLAYER ---
func start_attack():
	$CreatureSoundPlayer.play_attack()
	is_attacking = true

func stop_attack():
	is_attacking = false

func start_blocking():
	is_blocking = true

func stop_blocking():
	is_blocking = false

func apply_attack_impulse():
	if attack_ray.is_colliding():
		var target = attack_ray.get_collider()
		# Push direction is based on where the camera is looking
		var push_dir = -camera.global_transform.basis.z
		
		if target is EntityRigidBody:
			target.apply_impulse_synced(push_dir * attack_impulse)
			print('Pushed entity')
			is_attacking = false # Prevent multiple hits in one frame
		elif target is CharacterBody3D:
			if target is Player:
				# TODO: only do if PVP friendly fire is turned on
				pass
			if target is DumbEnemy:
				var health_component = target.get_node_or_null('HealthComponent')
				if health_component:
					# TODO: Make weapons apply different damage types
					var damage_amount = randi_range(1,25)
					health_component.take_damage_synced(damage_amount, true if damage_amount > 20 else false)
					print('Damaged enemy')
			if target.has_method("apply_knockback"):
				target.apply_knockback_synced(push_dir * attack_impulse)
				print('Pushed enemy')
			is_attacking = false
# -----------------------------------------------

func change_weapon(index):
	_current_weapon_index = index
	var weapon_container = $right_arm/weapons
	var i = 0
	for weapon in weapon_container.get_children():
		weapon.hide()
		if i == index:
			weapon.show()
		i += 1
		
func next_weapon():
	if _current_weapon_index + 1 == len($right_arm/weapons.get_children()):
		_current_weapon_index = 0
	else:
		_current_weapon_index += 1

func prev_weapon():
	if _current_weapon_index - 1 < 0:
		_current_weapon_index = len($right_arm/weapons.get_children()) - 1
	else:
		_current_weapon_index -= 1

func _unhandled_input(event: InputEvent) -> void:
	# Only handle mouse look and UI for the local player
	if not is_multiplayer_authority() or not is_active: 
		return
		
	if event.is_action_pressed("scroll_up"):
		next_weapon()
	if event.is_action_pressed("scroll_down"):
		prev_weapon()
	if event.is_action_pressed("ui_cancel") and not main_game_node.settings_menu:
		capture_mouse(!is_mouse_captured)
		
	if event is InputEventMouseButton and event.pressed:
		if not is_mouse_captured:
			capture_mouse(true)
	if is_mouse_captured and event is InputEventMouseMotion:
		_camera_rotation.y -= event.relative.x * sensitivity
		_camera_rotation.x -= event.relative.y * sensitivity
		_camera_rotation.x = clamp(_camera_rotation.x, -deg_to_rad(85), deg_to_rad(85))
		rotation.y = _camera_rotation.y
		camera.rotation.x = _camera_rotation.x

func capture_mouse(capture: bool) -> void:
	is_mouse_captured = capture
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if capture else Input.MOUSE_MODE_VISIBLE

func _physics_process(delta: float) -> void:
	# Only the owner handles input and calculates movement
	if not is_multiplayer_authority() or not is_active: 
		return
		
	# Handle spellcasting (Server-side spawn via RPC)
	if Input.is_action_just_pressed("spell_1"):
		rpc_id(1, "server_lob_fireball")
	if Input.is_action_pressed("spell_2"):
		$aoe_spells/Holy.is_active = true
	if Input.is_action_just_released("spell_2"):
		$aoe_spells/Holy.is_active = false
	if Input.is_action_pressed("spell_q"):
		$left_arm/spells/Lightning.is_active = true
		$left_arm/spells/Lightning.show()
	else:
		$left_arm/spells/Lightning.is_active = false
		$left_arm/spells/Lightning.hide()
		
	# Handle rotation of any held object
	if Input.is_action_pressed('spell_r'):
		$left_arm/hold_point.rotate_y(held_object_rotation_speed * delta)
		
	# Handle Attack Logic
	if is_attacking:
		apply_attack_impulse()
		
	# attack and parry animations
	if Input.is_action_just_pressed('left_click'):
		if not right_arm_animation_player.is_playing():
			right_arm_animation_player.play("stab")
	elif Input.is_action_just_pressed('right_click'):
		if not right_arm_animation_player.is_playing():
			right_arm_animation_player.play("block")
	
	if Input.is_action_just_released('right_click'):
		if len(right_arm_animation_player.get_queue()) == 0:
			right_arm_animation_player.queue('return_from_block')
	
	if is_blocking:
		parry_timer = 0.0
		block_timer += delta
	else:
		parry_timer = block_timer
		block_timer = 0.0
	
	# check to see if parrying
	if parry_timer <= parry_window_default and parry_timer != 0.0:
		is_parrying = true
	else:
		is_parrying = false
	
	# Interaction logic
	if interaction_ray.is_colliding():
		var collider = interaction_ray.get_collider()
		if collider:
			main_game_node.get_node('UI/raycast_target').text = str(collider.name)
			if collider.has_meta('interaction_message'):
				main_game_node.get_node('UI/raycast_center_message').text = collider.get_meta('interaction_message')
			if Input.is_action_just_pressed("interact"):
				if collider.has_meta('interaction_function'):
					collider.call(collider.get_meta('interaction_function'), self.get_path())
	else:
		# Drop any held object
		if held_object and Input.is_action_just_pressed('interact'):
			held_object.drop_synced()
			held_object = null
		main_game_node.get_node('UI/raycast_center_message').text = ''

	# Movement logic
	var input_dir := Vector2.ZERO
	if is_mouse_captured:
		input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	
	var wish_dir := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	# --- FLYING LOGIC START ---
	if Input.is_action_pressed("fly"):
		# Move up at jump_velocity speed (or create a new fly_speed variable)
		velocity.y = jump_velocity 
		# While flying, we use air physics for horizontal movement so it feels floaty
		handle_air_physics(wish_dir, delta)
	# --- FLYING LOGIC END ---
	
	elif is_on_floor():
		handle_ground_physics(wish_dir, delta)
	else:
		handle_air_physics(wish_dir, delta)
		
	if is_on_floor() and Input.is_action_just_pressed("jump"):
		if not $jumpSound.playing:
			$jumpSound.play()
			
	move_and_slide()
	_handle_view_effects(delta, input_dir)
	
	if is_on_floor() and velocity.length() > 0.1 and input_dir != Vector2.ZERO:
		var horizontal_vel = Vector3(velocity.x, 0, velocity.z).length()
		$footstepsSound.pitch_scale = (horizontal_vel / walk_speed) * 0.25 + 0.25
		if not $footstepsSound.playing:
			$footstepsSound.play()
	elif $footstepsSound.playing:
		$footstepsSound.stop()
		
	# play walking and idle animations 
	var progress = Vector3(velocity.x, 0, velocity.z).length() / walk_speed
	body_animation_tree.set('parameters/blend_position', progress)
	
	# handle any rigidbodies the player bumps into
	handle_rigidbody_push()

func _handle_view_effects(delta: float, input_dir: Vector2) -> void:
	if is_on_floor() and velocity.length() > 0.1:
		_bob_time += delta * velocity.length() * 0.5
		camera.position.y = _default_cam_height + sin(_bob_time * bob_freq) * bob_amp
		camera.position.x = cos(_bob_time * bob_freq * 0.5) * bob_amp
	else:
		camera.position.y = lerp(camera.position.y, _default_cam_height, delta * 10.0)
		camera.position.x = lerp(camera.position.x, 0.0, delta * 10.0)
		_bob_time = 0.0

	var target_tilt = -input_dir.x * tilt_amount
	camera.rotation.z = lerp(camera.rotation.z, target_tilt, delta * tilt_speed)

func handle_ground_physics(wish_dir: Vector3, delta: float) -> void:
	var speed = velocity.length()
	if speed != 0:
		var drop = speed * friction * delta
		velocity *= max(speed - drop, 0) / speed
	accelerate(wish_dir, walk_speed, run_acceleration, delta)
	if is_mouse_captured and Input.is_action_just_pressed("jump"):
		velocity.y = jump_velocity

func handle_air_physics(wish_dir: Vector3, delta: float) -> void:
	velocity.y -= gravity * delta
	accelerate(wish_dir, air_cap, air_acceleration, delta)

func accelerate(wish_dir: Vector3, max_speed: float, accel: float, delta: float) -> void:
	var current_speed = velocity.dot(wish_dir)
	var add_speed = max_speed - current_speed
	if add_speed <= 0: return
	var accel_speed = min(accel * delta * max_speed, add_speed)
	velocity += wish_dir * accel_speed

# for pushing rigidbodies you bump into
func handle_rigidbody_push() -> void:
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		if collider is EntityRigidBody:
			var push_dir = -collision.get_normal()
			push_dir.y = 0 
			var impact_strength = velocity.length() * push_force
			collider.apply_impulse_synced(push_dir * impact_strength)

@rpc("any_peer", "call_local", "reliable")
func server_lob_fireball():
	# Only the server should instantiate the fireball to keep it synced
	if not multiplayer.is_server():
		return
		
	var fireball = fireball_scene.instantiate()
	# Add fireball to the root scene so it doesn't move with the player
	main_game_node.get_node('entities').add_child(fireball, true)
	# Position it at the wizard's hand/staff
	fireball.global_position = muzzle.global_position
	# 1. Get the direction from the RayCast (Server uses camera rotation synced from client)
	var target_dir = -camera.global_transform.basis.z 
	# 2. Add the "Lob" (Angle it up slightly)
	var launch_velocity = (target_dir + Vector3.UP * upward_bias).normalized() * lob_strength
	# 3. Apply the force
	fireball.linear_velocity = launch_velocity
