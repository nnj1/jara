extends EntityRigidBody

func _ready() -> void:
	var key = GlobalVars.lore_data.history.keys().pick_random()
	entity_data = {
		'title': key,
		'contents': GlobalVars.lore_data.history[key]
	}
	super._ready()
