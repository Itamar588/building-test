extends RigidBody3D
class_name BaseBlock

@export var block_mass: float = 1.0
@export var node_data: NodeDefinition # The logic template for this block

# Track the parts that 'belong' to this logic brain
var owned_mesh: MeshInstance3D
var owned_shape: CollisionShape3D

func _ready():
	# Crucial for balance as we add parts
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	collision_layer = 2 

	# Identify our parts before they get reparented
	owned_mesh = get_node_or_null("MeshInstance3D")
	owned_shape = get_node_or_null("CollisionShape3D")

	recalculate_physics()

# Specific blocks (Thrusters, Motors, etc.) will override this
func apply_input(_value: Variant):
	pass

## The core logic for welding one block into another's physics body
func absorb_block(incoming_node: BaseBlock):
	if incoming_node == self: return

	# We use the references stored in the incoming block
	var shape = incoming_node.owned_shape
	var mesh = incoming_node.owned_mesh

	if shape and mesh:
		shape.set_meta("owner_block", incoming_node)

	# 1. Capture Global State
	var shape_global_xf = shape.global_transform
	var mesh_global_xf = mesh.global_transform
	var node_global_xf = incoming_node.global_transform

	# 2. STRIP PHYSICS from the incoming block
	# It becomes a 'Logic Container' child
	incoming_node.freeze = true
	incoming_node.collision_layer = 0
	incoming_node.collision_mask = 0
	incoming_node.mass = 0.01 

	# 3. WELD TO MASTER
	# The current body (self) now 'owns' the physical presence of the incoming block
	shape.reparent(self)
	shape.global_transform = shape_global_xf

	mesh.reparent(self)
	mesh.global_transform = mesh_global_xf

	# 4. REPARENT THE BRAIN
	# Keeps the scripts running as a child of the physical body
	incoming_node.reparent(self)
	incoming_node.global_transform = node_global_xf

	# 5. Update physics to reflect new weight/balance
	call_deferred("recalculate_physics")

## Safely removes this specific block from the master assembly
func disconnect_self():
	if is_instance_valid(owned_shape): owned_shape.queue_free()
	if is_instance_valid(owned_mesh): owned_mesh.queue_free()

	var master_body = get_master_body()

	queue_free()

	if master_body and master_body.has_method("recalculate_physics"):
		master_body.call_deferred("recalculate_physics")

## Finds the RigidBody3D at the top of the chain (The Vehicle or Motor Assembly)
func get_master_body() -> RigidBody3D:
	var p = get_parent()

	while p:
		if p is RigidBody3D and not p is BaseBlock: 
			return p
		p = p.get_parent()

	return null

func recalculate_physics():
	var total_mass = 0.0
	var weighted_pos = Vector3.ZERO

	# We calculate based on the parts we physically own right now
	for child in get_children():

		if child is MeshInstance3D:
			# If it's a mesh, find the block that owns it to get its specific mass
			total_mass += block_mass 
			weighted_pos += child.position * block_mass

		elif child is BaseBlock:
			# Account for child logic blocks
			total_mass += child.block_mass
			weighted_pos += child.position * child.block_mass

	mass = total_mass

	if total_mass > 0: 
		center_of_mass = weighted_pos / total_mass
func get_block_from_shape(shape_id: int) -> BaseBlock:
	var owner_id = shape_find_owner(shape_id)
	var shape_node = shape_owner_get_owner(owner_id)

	if shape_node and shape_node.has_meta("owner_block"):
		return shape_node.get_meta("owner_block")

	return self
