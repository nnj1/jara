extends Node3D
class_name HealthComponent

# Signals for UI, VFX, and Logic
signal health_changed(current_health: float, max_health: float)
signal damaged(amount: float)
signal healed(amount: float)
signal parried
signal died

@export_group("Settings")
@export var max_health: float = 100.0

@export_group("Visuals")
@export var show_damage_numbers: bool = true
@export var damage_number_color: Color = Color.WHITE
@export var critical_hit_color: Color = Color.GOLD
@export var heal_color: Color = Color.GREEN

# Synchronized variable. The setter ensures signals fire on both Server and Clients.
@export var current_health: float:
	set(value):
		current_health = value
		health_changed.emit(current_health, max_health)

@export var is_dead: bool = false

func _ready() -> void:
	current_health = max_health

### Public Methods (Server-Only Logic)

## TODO: Called by the server when a hit is detected

func take_damage_synced(amount: float, is_critical: bool = false) -> void:
	# modify health amount based on if the player is blocking or parrying
	if get_parent() is Player:
		if get_parent().parry_timer > 0 and get_parent().parry_timer <= get_parent().parry_window_default and get_parent().is_moving_weapon:
				parried.emit()
				return
		if get_parent().is_blocking:
			amount = amount / 2.0
			is_critical = false
	
	rpc('take_damage', amount, is_critical)
	
@rpc("any_peer","call_local","reliable")
func take_damage(amount: float, is_critical: bool = false) -> void:
	if not is_multiplayer_authority() or is_dead or amount <= 0:
		return
	
	current_health = clamp(current_health - amount, 0, max_health)
	
	# Broadcast damage visuals to everyone
	_play_hit_vfx.rpc(amount, is_critical)
	
	if current_health <= 0:
		_broadcast_death.rpc()

## Called by the server when a heal occurs (potions, lifesteal)
func heal_synced(amount: float = 100.0) -> void:
	rpc('heal', amount)
	
@rpc("any_peer","call_local","reliable")
func heal(amount: float) -> void:
	if not is_multiplayer_authority() or is_dead or amount <= 0:
		return
		
	current_health = min(current_health + amount, max_health)
	
	# Broadcast healing visuals to everyone
	_play_heal_vfx.rpc(amount)

### Networked RPCs (Visual Events)

@rpc("any_peer", "call_local", "reliable")
func _play_hit_vfx(amount: float, is_critical: bool) -> void:
	if show_damage_numbers:
		spawn_damage_marker(amount, is_critical)
	damaged.emit(amount)

@rpc("any_peer", "call_local", "reliable")
func _play_heal_vfx(amount: float) -> void:
	if show_damage_numbers:
		# Pass heal_color as an override
		spawn_damage_marker(amount, false, heal_color)
	healed.emit(amount)

@rpc("any_peer", "call_local", "reliable")
func _broadcast_death() -> void:
	if is_dead: return
	is_dead = true
	died.emit()

### Damage/Heal Marker Logic (Local VFX)

func spawn_damage_marker(amount: float, is_critical: bool, override_color: Color = Color.TRANSPARENT) -> void:
	# Don't waste memory on headless dedicated servers
	if DisplayServer.get_name() == "headless": 
		return

	var label = Label3D.new()
	
	# Text Setup
	var prefix = "+" if override_color == heal_color else ""
	label.text = prefix + str(snapped(amount, 0.1))
	
	# Visual Setup
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.pixel_size = 0.05
	label.outline_modulate = Color(0, 0, 0, 0) # Transparent outline
	label.font_size = 48 if is_critical else 32
	
	# Determine Color
	if override_color != Color.TRANSPARENT:
		label.modulate = override_color
	else:
		label.modulate = critical_hit_color if is_critical else damage_number_color
	
	# Add to Scene Root so it stays alive if the enemy is queue_free'd
	get_tree().root.add_child(label)
	
	# Start at this component's world position
	label.global_position = global_position + Vector3(randf_range(-1.5, 1.5), randf_range(-1.5, 1.5), randf_range(-1.5, 1.5))
	
	# Animation Logic
	var tween = get_tree().create_tween().set_parallel(true)
	var random_x = randf_range(-0.7, 0.7)
	var target_pos = label.global_position + Vector3(random_x, 1.5, 0)
	
	tween.tween_property(label, "global_position", target_pos, 0.6)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_OUT)
	
	tween.tween_property(label, "modulate:a", 0.0, 0.4).set_delay(0.3)
	
	# Cleanup
	tween.chain().tween_callback(label.queue_free)

### Helpers

func get_health_percent() -> float:
	return current_health / max_health
