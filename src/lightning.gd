extends Node3D

@onready var cylinder = $MeshInstance3D
@export var ray: RayCast3D

@onready var lightning_sound: AudioStreamPlayer3D = $AudioStreamPlayer3D

var is_active: bool = false
var attack_timeout: float = 0.5
var attack_timer: float = attack_timeout


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass
	
func _physics_process(delta: float) -> void:
	if is_active:
		if not lightning_sound.playing:
			lightning_sound.play()
		if ray.is_colliding():
			var hit_point = ray.get_collision_point()
			strike_at(hit_point)
			# 2. Calculate the distance from the RayCast origin to that point
			var _distance = ray.global_position.distance_to(hit_point)
			# apply_damage
			var target = ray.get_collider()
			if target is Player:
				# TODO: only do if PVP friendly fire is turned on
				pass
			if target is SpellProjectile:
				# TODO: only do if PVP friendly fire is turned on
				if target.has_method('grow'):
					target.grow(delta)
			if target is DumbEnemy:
				var health_component = target.get_node_or_null('HealthComponent')
				if health_component:
					attack_timer -= delta
					if attack_timer < 0:
						var damage_amount = randi_range(1,5)
						health_component.take_damage(damage_amount, true if damage_amount > 3 else false)
						attack_timer = attack_timeout
		else:
			strike_at(ray.target_position)
	else:
		lightning_sound.stop()
		
func strike_at(target_pos: Vector3):
	var dist = (target_pos - self.global_position).length()
	cylinder.mesh.height = dist
	cylinder.position.z = -1 * dist/2.0
