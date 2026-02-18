extends RigidBody3D

@export var damage: int = 20

func _on_area_3d_body_entered(body: Node3D) -> void:
	if body.is_in_group("enemies"):
		# Handle damage logic here
		pass
	queue_free() # Destroy fireball on impact

func _on_timer_timeout() -> void:
	queue_free() # Despawn after a few seconds if it hits nothing
