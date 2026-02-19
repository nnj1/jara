extends CharacterBody3D
class_name DumbEnemy

# Added DEAD to the enum
enum State { IDLE, RANDOM_WALK, AGGRO, DEAD }

@export_group("Movement")
@export var walk_speed: float = 10.0
@export var run_speed: float = 30.0
@export var jump_velocity: float = 12.0
@export var base_knockback: float = 1.0

@export_group("Smart Targeting")
@export var chase_persistence: float = 3.0
@export var max_chase_distance: float = 100.0

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
	if detection_area.body_entered.is_connected(_on_player_detected):
		detection_area.body_entered.disconnect(_on_player_detected)
	detection_area.body_entered.connect(_on_player_detected)
	detection_area.body_exited.connect(_on_player_lost_sight)
	change_state(State.IDLE)
	
	# Set up death sound
	$HealthComponent.died.connect($CreatureSoundPlayer.play_death)
	$HealthComponent.damaged.connect($CreatureSoundPlayer.play_hurt)
	
	# Connect HealthComponent to our local death function
	$HealthComponent.died.connect(_on_died)
	
func _physics_process(delta: float) -> void:
	# Stop all logic if dead
	if current_state == State.DEAD:
		# Still apply gravity and move_and_slide so they don't float if killed mid-air
		if not is_on_floor():
			velocity.y -= 14.8 * delta
			move_and_slide()
		return

	# 1. Apply Gravity
	if not is_on_floor():
		velocity.y -= 14.8 * delta
	else:
		# Reset jump only when on floor AND cooldown has reached zero
		if not can_jump and velocity.y <= 0 and jump_cooldown <= 0:
			can_jump = true
	
	# 2. Update Jump Cooldown
	if jump_cooldown > 0:
		jump_cooldown -= delta

	# 3. State Machine
	match current_state:
		State.AGGRO:
			process_aggro_logic(delta)
		State.RANDOM_WALK:
			process_wander_logic(delta)
		State.IDLE:
			process_idle_logic(delta)
	
	# 4. APPLY KNOCKBACK OVERRIDE
	if knockback_velocity.length() > 0.1:
		# We blend the knockback into the velocity
		velocity.x = knockback_velocity.x
		velocity.z = knockback_velocity.z
		# Decay the knockback so it doesn't slide forever
		knockback_velocity = knockback_velocity.move_toward(Vector3.ZERO, delta * 50.0)
		
	move_and_slide()

func process_aggro_logic(delta: float):
	if target_player:
		var dist = global_position.distance_to(target_player.global_position)
		
		if dist > max_chase_distance:
			lose_target()
			return

		if not is_player_in_area():
			persistence_timer -= delta
			if persistence_timer <= 0:
				lose_target()
				return

		var dir = (target_player.global_position - global_position)
		dir.y = 0
		
		if dir.length() > 1.0:
			dir = dir.normalized()
			look_at(global_position + dir, Vector3.UP)
			velocity.x = dir.x * run_speed
			velocity.z = dir.z * run_speed
			
			# JUMP LOGIC
			if is_on_floor() and is_on_wall() and can_jump:
				var is_hitting_player = false
				for i in get_slide_collision_count():
					var collision = get_slide_collision(i)
					if collision.get_collider() == target_player:
						is_hitting_player = true
						break
				
				if not is_hitting_player:
					velocity.y = jump_velocity
					jump_cooldown = 1.5 # Lock jumps for 1.5 seconds
					can_jump = false 
		else:
			velocity.x = 0
			velocity.z = 0
			
		if not is_on_floor():
			safe_play("jump")
		elif velocity.length() > 0.1:
			safe_play("run")
		else:
			safe_play("idle")
	else:
		change_state(State.IDLE)

func process_wander_logic(delta: float):
	velocity.x = wander_direction.x * walk_speed
	velocity.z = wander_direction.z * walk_speed
	if wander_direction != Vector3.ZERO:
		look_at(global_position + wander_direction, Vector3.UP)
	if not is_on_floor(): safe_play("jump")
	else: safe_play("walk")
	state_timer -= delta
	if state_timer <= 0: change_state(State.IDLE)

func process_idle_logic(delta: float):
	velocity.x = 0
	velocity.z = 0
	safe_play("idle")
	state_timer -= delta
	if state_timer <= 0: change_state(State.RANDOM_WALK)

func lose_target():
	target_player = null
	change_state(State.IDLE)

func _on_player_detected(body: Node3D):
	if current_state == State.DEAD: return
	if body is CharacterBody3D and body != self and body.is_in_group('players'):
		target_player = body
		persistence_timer = chase_persistence
		if current_state != State.AGGRO:
			current_state = State.AGGRO

func _on_player_lost_sight(body: Node3D):
	if body == target_player:
		persistence_timer = chase_persistence

func is_player_in_area() -> bool:
	return detection_area.get_overlapping_bodies().has(target_player)

func change_state(new_state: State):
	if current_state == State.DEAD: return # Can't change state if dead
	if current_state == State.AGGRO and target_player != null and new_state != State.DEAD: return
	
	current_state = new_state
	state_timer = randf_range(2.0, 5.0)
	
	if new_state == State.RANDOM_WALK:
		var angle = randf() * TAU
		wander_direction = Vector3(cos(angle), 0, sin(angle))

func _on_died():
	current_state = State.DEAD
	velocity = Vector3.ZERO
	# Disable collision so the player doesn't trip over a corpse
	collision_layer = 0
	collision_mask = 1 # Keep mask for ground floor only
	anim_player.speed_scale = 2 # death animation is a little slow so speed up the player
	safe_play("die")
	
	# Optional: Remove the enemy after some time
	var timer = get_tree().create_timer(20.0)
	timer.timeout.connect(queue_free)

func safe_play(anim_name: String):
	var n = "skeleton_stuff/rig_rig_" + anim_name
	if anim_player.has_animation(n):
		if anim_player.current_animation != n:
			anim_player.play(n)

func apply_knockback(force: Vector3):
	if current_state == State.DEAD: return
	knockback_velocity = force * base_knockback
	# Optional: If you want being hit to make them "mad"
	if current_state != State.AGGRO:
		change_state(State.AGGRO)
