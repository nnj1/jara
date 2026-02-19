extends Node3D

@onready var cylinder = $MeshInstance3D
@export var ray: RayCast3D
@export var smoothing_speed: float = 20.0 

var is_active: bool = true
var current_strike_point: Vector3 = Vector3.ZERO

# Publicly accessible variables if other scripts need to know what we hit
var last_hit_body: Node3D = null
var current_strike_dist: float = 0.0

func _ready() -> void:
	# Start the strike point at the end of the ray so it doesn't "fly in" from (0,0,0)
	current_strike_point = ray.target_position

func _physics_process(delta: float) -> void:
	if is_active:
		var goal_pos: Vector3
		
		if ray.is_colliding():
			# 1. Update our collision data
			last_hit_body = ray.get_collider() as Node3D
			goal_pos = ray.get_collision_point()
			
			# (Optional) You can use last_hit_body here to trigger damage/effects
			# if last_hit_body.has_method("take_damage"):
			#     last_hit_body.take_damage(10 * delta)
		else:
			last_hit_body = null
			# If nothing is hit, aim for the tip of the ray in world space
			goal_pos = ray.target_position
		
		# 2. Smoothly interpolate the strike point
		current_strike_point = current_strike_point.lerp(goal_pos, smoothing_speed * delta)
		
		# 3. Calculate final distance for the shader/mesh
		current_strike_dist = global_position.distance_to(current_strike_point)
		
		# 4. Update the visuals
		strike_at(current_strike_point, current_strike_dist)

func strike_at(_target_pos: Vector3, dist: float):
	# Update Mesh Height
	cylinder.mesh.height = dist
	
	# Position the cylinder so the base stays at the origin
	# Assuming the Cylinder Mesh "Axis" is set to Y (default)
	# We move it "forward" (negative Z) by half the distance
	cylinder.position.z = -dist / 2.0
