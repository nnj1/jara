extends Node3D

@onready var cylinder = $MeshInstance3D
@export var ray: RayCast3D

var is_active: bool = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass
	
func _physics_process(_delta: float) -> void:
	if is_active:
		if ray.is_colliding():
			var hit_point = ray.get_collision_point()
			strike_at(hit_point)
			# 2. Calculate the distance from the RayCast origin to that point
			var _distance = ray.global_position.distance_to(hit_point)
			# Optional: Get the actual object hit
			var _body = ray.get_collider()
		else:
			strike_at(ray.target_position)
		
func strike_at(target_pos: Vector3):
	var dist = (target_pos - self.global_position).length()
	cylinder.mesh.height = dist
	cylinder.position.z = -1 * dist/2.0
