extends AudioStreamPlayer3D
class_name CreatureSoundPlayer

@export_group("Idle Settings")
## Sounds played while the creature is wandering or standing still.
@export var idle_sounds: Array[AudioStream] = []
@export var min_idle_wait: float = 3.0
@export var max_idle_wait: float = 6.0

@export_group("Combat Sounds")
## Played when the creature sees the player or starts a chase.
@export var aggro_sounds: Array[AudioStream] = []
## Played when the creature takes damage.
@export var hurt_sounds: Array[AudioStream] = []
## Played once when health reaches zero.
@export var death_sounds: Array[AudioStream] = []
## Played during attacks.
@export var attack_sounds: Array[AudioStream] = []

@export_group("Variability")
## Randomizes pitch slightly each time a sound plays to avoid "machine-gun" effect.
@export_range(0.0, 0.5) var pitch_randomness: float = 0.1

var _is_dead: bool = false
var _base_pitch: float = 1.0

func _ready() -> void:
	_base_pitch = pitch_scale
	_start_idle_loop()

## Plays a random sound from a specific array. 
## Interrupts current sound for high-priority combat feedback.
func play_creature_sound(pool: Array[AudioStream], force: bool = true) -> void:
	if pool.is_empty() or _is_dead:
		return
		
	if force:
		stop()
		
	# Apply slight pitch variation for organic feel
	pitch_scale = _base_pitch + randf_range(-pitch_randomness, pitch_randomness)
	stream = pool.pick_random()
	play()

# --- Public API Methods ---

func play_hurt() -> void:
	play_creature_sound(hurt_sounds, true)

func play_aggro() -> void:
	play_creature_sound(aggro_sounds, true)

func play_attack() -> void:
	play_creature_sound(attack_sounds, true)

func play_death() -> void:
	_is_dead = true # Stop the idle loop
	play_creature_sound(death_sounds, true)

# --- Internal Idle Logic ---

func _start_idle_loop() -> void:
	while not _is_dead:
		var wait_time = randf_range(min_idle_wait, max_idle_wait)
		await get_tree().create_timer(wait_time).timeout
		
		# Only play idle if we aren't currently busy with a "priority" sound
		if not playing and not _is_dead and not idle_sounds.is_empty():
			stream = idle_sounds.pick_random()
			pitch_scale = _base_pitch + randf_range(-pitch_randomness, pitch_randomness)
			play()
