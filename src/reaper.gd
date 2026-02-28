extends CharacterBody3D
class_name SmartNPC

@onready var main_game_node = get_tree().get_root().get_node('Game')

# --- NPC Settings ---
@export_group("NPC Settings")
@export var is_friendly: bool = false : set = set_is_friendly
@export var timeline_name: String = ""

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

@export_group("Combat & Slide Attack")
@export var slide_attack_enabled: bool = true
@export var slide_attack_cooldown: float = 0.5
@onready var slide_attack_cooldown_timer: float = 0.0

@export var attack_range: float = 10
@export var attack_cooldown: float = 1.5
@export var attack_damage: int = 15
var attack_timer: float = 0.0
var is_attacking: bool = false

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
	detection_area.body_entered.connect(_on_player_detected)
	detection_area.body_exited.connect(_on_player_lost_sight)
	
	change_state(State.IDLE)
	
	$HealthComponent.died.connect($CreatureSoundPlayer.play_death)
	$HealthComponent.damaged.connect($CreatureSoundPlayer.play_hurt)
	$HealthComponent.died.connect(_on_died)
	
	if not is_multiplayer_authority():
		detection_area.monitoring = false
		detection_area.monitorable = false

func set_is_friendly(value: bool):
	is_friendly = value
	if value:
		self.set_meta('interaction_message', 'Press E to talk')
		self.set_meta('interaction_function', 'start_talking')
	else:
		self.set_meta('interaction_message', null)
		self.set_meta('interaction_function', null)

# --- Physics & Logic Loop ---
func _physics_process(delta: float) -> void:
	if not multiplayer.multiplayer_peer: return
	if not multiplayer.is_server(): return 
	
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
	
	# 4. Attack Logic (Server Side Only)
	if target_player and not is_friendly:
		if attack_timer > 0:
			attack_timer -= delta
		
		# Proximity Attack (Animation Based)
		check_proximity_attack()
		
		# Slide Attack (Collision Based)
		if slide_attack_enabled:
			check_slide_attack(delta)

# --- Combat Functions ---

func check_proximity_attack():
	if is_attacking or attack_timer > 0 or current_state == State.DEAD:
		return
		
	var dist = global_position.distance_to(target_player.global_position)
	if dist <= attack_range:
		perform_attack()

func perform_attack():
	is_attacking = true
	attack_timer = attack_cooldown
	
	# Decelerate slightly during the swing for better feel
	velocity.x *= 0.2
	velocity.z *= 0.2
	
	safe_play("attack")
	
	# Listen for animation end to resume movement
	if not anim_player.animation_finished.is_connected(_on_attack_finished):
		anim_player.animation_finished.connect(_on_attack_finished, CONNECT_ONE_SHOT)

func _on_attack_finished(anim_name: String):
	if anim_name == "attack":
		is_attacking = false

## CALLED BY ANIMATION PLAYER METHOD TRACK
func deal_animation_damage():
	# Final check if player is still in range when hit lands
	if target_player and global_position.distance_to(target_player.global_position) <= (attack_range + 1.5):
		var damage_amount = randi_range(attack_damage - 2, attack_damage + 2)
		target_player.get_node('HealthComponent').take_damage_synced(damage_amount, false)

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

# --- Movement Logic ---

func process_aggro_logic(delta: float):
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
		
		# Only update velocity if not currently locked in an attack animation
		if not is_attacking:
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

func handle_animations():
	# If attacking, we don't want walk/run to override the current anim
	if is_attacking:
		return

	if not is_on_floor():
		safe_play("jump")
	elif velocity.length() > 0.1:
		var anim = "run" if current_state == State.AGGRO else "walk"
		safe_play(anim)
	else:
		safe_play("idle")

# --- Original State/Helper Functions ---

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
	if new_state == State.AGGRO and is_friendly: return
	if current_state == State.AGGRO and target_player != null and new_state != State.DEAD: return
	
	current_state = new_state
	state_timer = randf_range(2.0, 5.0)
	
	if new_state == State.RANDOM_WALK:
		var angle = randf() * TAU
		wander_direction = Vector3(cos(angle), 0, sin(angle))

func _on_died():
	current_state = State.DEAD
	is_attacking = false
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
			# Use shorter blend for attacks to make them feel responsive
			var blend = 0.1 if n == "attack" else 0.2
			anim_player.play(n, blend)

# --- Networking/Interactions ---

func start_talking(player_path: NodePath):
	if is_friendly and timeline_name != "":
		main_game_node.get_node('UI/raycast_center_message').text = ''
		self.set_meta('interaction_message', null)
		self.set_meta('interaction_function', null)
		var player = get_node(player_path)
		look_at(player.position, Vector3.UP)
		player.is_chatting = true
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
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

func apply_knockback_synced(force: Vector3):
	rpc_id(1, 'apply_knockback', force)

@rpc("any_peer","call_local","reliable")
func apply_knockback(force: Vector3):
	if not multiplayer.is_server(): return
	if current_state == State.DEAD: return
	knockback_velocity = force * base_knockback
	if current_state != State.AGGRO and not is_friendly:
		change_state(State.AGGRO)
