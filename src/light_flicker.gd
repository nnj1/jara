extends OmniLight3D

## The normal brightness of the light
@export var base_energy: float = 2.0
## How much the light "drops" during a flicker (0.0 to 1.0)
@export var flicker_depth: float = 0.2
## How fast the jitter happens (higher = more frantic)
@export var jitter_speed: float = 0.05

var time_passed: float = 0.0

func _process(delta: float) -> void:
	time_passed += delta
	
	# Only change the brightness every "jitter_speed" seconds
	if time_passed >= jitter_speed:
		time_passed = 0.0
		
		# Pick a random strength between (base - depth) and (base)
		var jitter = randf_range(base_energy - flicker_depth, base_energy)
		
		# Apply to energy (fast) instead of range (slow)
		light_energy = jitter
		
		# Optional: Occasionally "black out" for a frame
		#if randf() > 0.98: 
		#	light_energy = 0.05
