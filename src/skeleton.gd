extends CharacterBody3D
class_name DumbNPC

@onready var main_game_node = get_tree().get_root().get_node('Game')

# --- NPC Settings ---
@export_group("NPC Settings")
@export var is_friendly: bool = false : set = set_is_friendly
@export var timeline_name: String = "" # The Dialogic timeline to play

enum State { IDLE, RANDOM_WALK, AGGRO, DEAD, CHATTING }

@export_group("Movement")
@export var walk_speed: float = 10.0
@export var run_speed: float = 30.0
@export var jump_velocity: float = 12.0
@export var base_knockback: float = 1.0
@export var rotation_speed: float = 10.0
var current_look_direction: Vector3 = Vector3.FORWARD

@export_group("Smart Targeting")
@export var chase_persistence: float = 3.0
@export var max_chase_distance: float = 100.0

@export_group("Slide Attack Variables")
@export var slide_attack_cooldown: float = 0.5
@onready var slide_attack_cooldown_timer: float = 0.0

# --- Internal Variables ---
var current_state: State = State.IDLE
var target_player: CharacterBody3D = null
var wander_direction: Vector3 = Vector3.ZERO
var state_timer: float = 0.0
var persistence_timer: float = 0.0
var jump_cooldown: float = 0.0 
var can_jump: bool = true 
var knockback_velocity = Vector3.ZERO

@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var detection_area: Area3D = $DetectionArea

func _ready() -> void:
	# Only connect detection if we aren't friendly
	detection_area.body_entered.connect(_on_player_detected)
	detection_area.body_exited.connect(_on_player_lost_sight)
	
	change_state(State.IDLE)
	
	# Set up sounds/health
	$HealthComponent.died.connect($CreatureSoundPlayer.play_death)
	$HealthComponent.damaged.connect($CreatureSoundPlayer.play_hurt)
	$HealthComponent.died.connect(_on_died)
	
	# Turn off detection area, if you're not the server
	if not is_multiplayer_authority():
		detection_area.monitoring = false
		detection_area.monitorable = false

func set_is_friendly(value: bool):
	is_friendly = value
	if value:
		self.set_meta('interaction_message', 'Press E to talk')
		self.set_meta('interaction_function', 'start_talking')
	else:
		# disable chat compoenent here
		self.set_meta('interaction_message', null)
		self.set_meta('interaction_function', null)
		
## Chat interaction functions
func start_talking(player_path: NodePath):
	if is_friendly and timeline_name != "":
		# Erase "press E to chat message"
		main_game_node.get_node('UI/raycast_center_message').text = ''
		self.set_meta('interaction_message', null)
		self.set_meta('interaction_function', null)
		# MAKE NPC LOOK AT PLAYER
		var player = get_node(player_path)
		look_at(player.position, Vector3.UP)
		# MAKE player freeze
		player.is_chatting = true
		# Free mouse to use
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		# MAKE NPC move into chatting state (REQUEST THE SERVER TO DO THIS)
		rpc_id(1, 'change_state_sync', State.CHATTING)
		Dialogic.start(timeline_name)
		for connection in Dialogic.timeline_ended.get_connections():
			Dialogic.timeline_ended.disconnect(connection.callable)
		Dialogic.timeline_ended.connect(stop_talking.bind(player.get_path()))
	
@rpc("any_peer","call_local","reliable")	
func change_state_sync(given_state: State):
	if multiplayer.is_server():
		change_state(given_state)
	
func stop_talking(player_path: NodePath):
	if is_friendly and timeline_name != "":
		var player = get_node(player_path)
		player.is_chatting = false
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		rpc_id(1, 'change_state_sync', State.RANDOM_WALK)
		self.set_meta('interaction_message', 'Press E to talk')
		self.set_meta('interaction_function', 'start_talking')

func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority(): return # physics only runs on server
	
	if current_state == State.DEAD:
		if not is_on_floor():
			velocity.y -= 14.8 * delta
			move_and_slide()
		return

	# 1. Apply Gravity
	if not is_on_floor():
		velocity.y -= 14.8 * delta
	else:
		if not can_jump and velocity.y <= 0 and jump_cooldown <= 0:
			can_jump = true
	
	if jump_cooldown > 0:
		jump_cooldown -= delta

	# 2. State Machine
	match current_state:
		State.AGGRO:
			process_aggro_logic(delta)
		State.RANDOM_WALK:
			process_wander_logic(delta)
		State.IDLE:
			process_idle_logic(delta)
		State.CHATTING:
			process_chatting_logic(delta)
	
	# 3. Apply Knockback
	if knockback_velocity.length() > 0.1:
		velocity.x = knockback_velocity.x
		velocity.z = knockback_velocity.z
		knockback_velocity = knockback_velocity.move_toward(Vector3.ZERO, delta * 50.0)
	
	if velocity.length_squared() > 0.001 or not is_on_floor():	
		move_and_slide()
	
	# 4. Attack Logic (Disabled if friendly)
	if target_player and not is_friendly:
		check_slide_attack(delta)

func check_slide_attack(delta):
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		
		if collider == target_player:
			if slide_attack_cooldown_timer > 0:
				slide_attack_cooldown_timer -= delta
			else:
				var damage_amount = randi_range(1,5)
				collider.get_node('HealthComponent').take_damage_synced(damage_amount, false)
				slide_attack_cooldown_timer = slide_attack_cooldown

func process_aggro_logic(delta: float):
	# Friendly NPCs should never stay in AGGRO state
	if is_friendly or not target_player:
		change_state(State.IDLE)
		return

	var dist = global_position.distance_to(target_player.global_position)
	
	if dist > max_chase_distance:
		lose_target()
		return

	if not is_player_in_area():
		persistence_timer -= delta
		if persistence_timer <= 0:
			lose_target()
			return

	var target_dir = (target_player.global_position - global_position)
	target_dir.y = 0 
	
	if target_dir.length() > 0.1:
		target_dir = target_dir.normalized()
		current_look_direction = current_look_direction.slerp(target_dir, rotation_speed * delta).normalized()
		look_at(global_position + current_look_direction, Vector3.UP)
		
		velocity.x = target_dir.x * run_speed
		velocity.z = target_dir.z * run_speed
		
		if is_on_floor() and is_on_wall() and can_jump:
			velocity.y = jump_velocity
			jump_cooldown = 1.5 
			can_jump = false 
	else:
		velocity.x = 0
		velocity.z = 0
		
	handle_animations()

func process_wander_logic(delta: float):
	velocity.x = wander_direction.x * walk_speed
	velocity.z = wander_direction.z * walk_speed
	if wander_direction != Vector3.ZERO:
		current_look_direction = current_look_direction.slerp(wander_direction.normalized(), rotation_speed * delta).normalized()
		look_at(global_position + current_look_direction, Vector3.UP)
	
	handle_animations()
	state_timer -= delta
	if state_timer <= 0: change_state(State.IDLE)

func process_idle_logic(delta: float):
	velocity.x = 0
	velocity.z = 0
	safe_play("idle")
	state_timer -= delta
	if state_timer <= 0: change_state(State.RANDOM_WALK)

func process_chatting_logic(_delta: float):
	velocity.x = 0
	velocity.z = 0
	safe_play("chatting")
	# CAN ONLY LEAVE THIS STATE IF CHAT IS COMPLETE
	#state_timer -= delta
	#if state_timer <= 0: change_state(State.RANDOM_WALK)

func handle_animations():
	if not is_on_floor():
		safe_play("jump")
	elif velocity.length() > 0.1:
		var anim = "run" if current_state == State.AGGRO else "walk"
		safe_play(anim)
	else:
		safe_play("idle")

func lose_target():
	target_player = null
	change_state(State.IDLE)

func _on_player_detected(body: Node3D):
	if current_state == State.DEAD or is_friendly: return
	if body is CharacterBody3D and body != self and body.is_in_group('players'):
		target_player = body
		persistence_timer = chase_persistence
		if current_state != State.AGGRO:
			change_state(State.AGGRO)

func _on_player_lost_sight(body: Node3D):
	if body == target_player:
		persistence_timer = chase_persistence

func is_player_in_area() -> bool:
	return detection_area.get_overlapping_bodies().has(target_player)

func change_state(new_state: State):
	if current_state == State.DEAD: return 
	# Only allow aggro transition if NOT friendly
	if new_state == State.AGGRO and is_friendly: return
	
	if current_state == State.AGGRO and target_player != null and new_state != State.DEAD: return
	
	current_state = new_state
	state_timer = randf_range(2.0, 5.0)
	
	if new_state == State.RANDOM_WALK:
		var angle = randf() * TAU
		wander_direction = Vector3(cos(angle), 0, sin(angle))

func _on_died():
	current_state = State.DEAD
	velocity = Vector3.ZERO
	collision_layer = 0
	collision_mask = 1 
	safe_play("die")
	var timer = get_tree().create_timer(20.0)
	timer.timeout.connect(queue_free)

func safe_play(anim_name: String):
	if anim_name == 'die':
		anim_player.speed_scale = 2 
	if anim_name == 'chatting':
		if not anim_player.has_animation('chatting'):
			anim_name = 'idle'
	var n = anim_name
	if anim_player.has_animation(n):
		if anim_player.current_animation != n:
			anim_player.play(n, 0.2)
			
func apply_knockback_synced(force: Vector3):
	rpc_id(1, 'apply_knockback', force)

@rpc("any_peer","call_local","reliable")
func apply_knockback(force: Vector3):
	if not multiplayer.is_server(): return
	if current_state == State.DEAD: return
	knockback_velocity = force * base_knockback
	# Only get aggressive from being hit if not friendly!
	if current_state != State.AGGRO and not is_friendly:
		change_state(State.AGGRO)
