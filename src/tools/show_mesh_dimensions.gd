@tool # This allows the script to run while in the editor
extends MeshInstance3D

# This creates a clickable button in the Inspector
@export var get_dimensions: bool = false:
	set(value):
		_print_dimensions()

func _print_dimensions():
	if mesh:
		var aabb: AABB = mesh.get_aabb()
		var size = aabb.size * scale
		print("--- Mesh Dimensions ---")
		print("Width (X): ", size.x)
		print("Height (Y): ", size.y)
		print("Depth (Z): ", size.z)
	else:
		print("No mesh assigned to this node!")
