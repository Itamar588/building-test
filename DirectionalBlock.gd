extends BaseBlock
class_name DirectionalBlock

# We use a dedicated property to store the "intended" direction
# relative to the grid, which helps if the mesh is rotated internally.
var placement_normal: Vector3 = Vector3.FORWARD

func get_forward_vector() -> Vector3:
	# Returns the world-space direction the block is pointing.
	# In Godot, -basis.z is standard "Forward".
	return -global_transform.basis.z.normalized()

func setup_direction(local_normal: Vector3):
	# Store the normal it was placed on in case logic needs it later
	placement_normal = local_normal
	
	# If you want the block to do something specific when placed 
	# (like change an animation or light color), do it here.
	print("[BLOCK] Direction set to: ", local_normal)
