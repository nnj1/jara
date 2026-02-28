extends Node3D

#TODO: make the damage continuous

@onready var damage_zone: Area3D = $Area3D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass

func _on_area_3d_body_entered(body: Node3D) -> void:
	if body is Player:
		body.get_node('HealthComponent').take_damage_synced(10, false)
