extends RigidBody3D

class_name EntityRigidBody

# This allows the server to tell clients who owns this object
# or for you to check if the local peer has the right to move it.
func is_authority() -> bool:
	return get_multiplayer_authority() == multiplayer.get_unique_id()

## The wrapper method you'll call in your game code
func apply_impulse_synced(impulse: Vector3):
	# Send the command to the server/authority
	rpc("remote_apply_impulse", impulse)

## The RPC that actually performs the physics work
@rpc("any_peer", "call_local", "reliable")
func remote_apply_impulse(impulse: Vector3):
	# Only the authority should process physics to avoid 'jitter'
	# from multiple sources fighting over the position.
	if is_authority():
		apply_central_impulse(impulse)
