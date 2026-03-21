extends RigidBody3D
class_name MachineCore

# A simple helper to store what/where every part is
var parts_registry = {} # { shape_idx: BaseBlock_Node }

func _ready():
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	collision_layer = 2
	collision_mask = 1 | 2

func attach_block(new_block: BaseBlock, hit_shape_idx: int, hit_normal: Vector3):
	# 1. Figure out WHO we actually hit
	var target_part = parts_registry.get(hit_shape_idx, self)
	
	# 2. Get the specific attachment point (Self or Hinge Joint)
	var attachment_point = target_part.get_attachment_node(hit_normal)
	
	# 3. Parenting
	var old_xf = new_block.global_transform
	new_block.reparent(attachment_point)
	new_block.global_transform = old_xf
	
	# 4. Physical Weld: Move the shape to the Core
	var shapes = []
	for child in new_block.get_children():
		if child is CollisionShape3D: shapes.append(child)
	
	for shape in shapes:
		var shape_xf = shape.global_transform
		shape.reparent(self)
		shape.global_transform = shape_xf
		
		# REGISTRATION: Link this specific shape index to the block node
		# We wait a frame for the physics server to update the index
		await get_tree().physics_frame
		var new_idx = shape.get_index() # Simplified for this version
		parts_registry[new_idx] = new_block

	# 5. Clean up the block's physics
	new_block.freeze = true
	new_block.collision_layer = 0
	
	recalculate_mass()

func recalculate_mass():
	# Standard mass math...
	pass
