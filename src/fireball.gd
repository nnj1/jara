extends RigidBody3D

class_name SpellProjectile

@export var initial_mass: float = 1.0
@export var damage: int = 20
var current_scale: float = 1.0

func _ready() -> void:
	var generated_color = Color.from_hsv(randf(), 0.8, 1.0)
	$MeshInstance3D.mesh.material.emission = generated_color
	$OmniLight3D.light_color = generated_color
	
func _on_area_3d_body_entered(body: Node3D) -> void:
	if body.is_in_group("enemies"):
		if body is DumbNPC:
			var health_component = body.get_node_or_null('HealthComponent')
			if health_component:
				# TODO: Make weapons apply different damage types
				var damage_amount = randi_range(25,50)
				health_component.take_damage_synced(damage_amount, true if damage_amount > 20 else false)
				#print('Damaged enemy')
				queue_free() # Destroy fireball on impact

func _on_timer_timeout() -> void:
	queue_free() # Despawn after a few seconds if it hits nothing

func grow(delta):
	set_3d_scale(current_scale + 2 * delta)

func set_3d_scale(new_scale: float):
	current_scale = new_scale
	# 1. Scale the Visuals (MeshInstance3D)
	for child in get_children():
		if child is MeshInstance3D or child is CollisionShape3D:
			child.scale = Vector3.ONE * new_scale
	
	# 2. Update the Mass (Physics Tip: Volume scales by the cube)
	# If an object is 2x bigger in 3D, it's technically 8x heavier.
	self.mass = initial_mass * pow(new_scale, 3)
	
	# 3. Force the physics engine to recalculate center of mass/inertia
	# This prevents "wobbly" rotation after scaling.
	PhysicsServer3D.body_set_param(get_rid(), PhysicsServer3D.BODY_PARAM_CENTER_OF_MASS, Vector3.ZERO)
