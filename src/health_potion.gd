extends EntityRigidBody

func consume(player_node):
	player_node.get_node('HealthComponent').heal_synced(25)
