extends RigidBody3D
class_name BaseBlock

@export var block_mass: float = 1.0
@export var node_data: NodeDefinition # The logic template for this block

# Track the parts that 'belong' to this logic brain
var owned_mesh: MeshInstance3D
var owned_shape: CollisionShape3D

# Core outline
var core_outline: MeshInstance3D
var outline_material: StandardMaterial3D


func _ready():
	# Crucial for balance as we add parts
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	collision_layer = 2 

	# Identify our parts before they get reparented
	owned_mesh = get_node_or_null("MeshInstance3D")
	owned_shape = get_node_or_null("CollisionShape3D")

	if owned_shape:
		owned_shape.set_meta("owner_block", self)

	recalculate_physics()

	# Delay so welding can happen first
	call_deferred("update_core_outline")


# Specific blocks (Thrusters, Motors, etc.) will override this
func apply_input(_value: Variant):
	pass


## ---------- CORE OUTLINE SYSTEM ----------

func update_core_outline():

	var is_core = not (get_parent() is BaseBlock) and not freeze

	if not is_core:
		if core_outline:
			core_outline.queue_free()
			core_outline = null
		return

	if not owned_mesh:
		return

	if core_outline == null:

		core_outline = MeshInstance3D.new()
		core_outline.mesh = owned_mesh.mesh
		core_outline.scale = Vector3.ONE * 1.08

		outline_material = StandardMaterial3D.new()
		outline_material.albedo_color = Color(1.0, 0.5, 0.0)
		outline_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		outline_material.cull_mode = BaseMaterial3D.CULL_FRONT

		core_outline.material_override = outline_material

		owned_mesh.add_child(core_outline)




func absorb_block(incoming_node: BaseBlock, hit_normal: Vector3 = Vector3.ZERO, target_sub_block: BaseBlock = null):
	if incoming_node == self:
		return

	var shape = incoming_node.owned_shape
	var mesh = incoming_node.owned_mesh

	# Safety check for valid block parts 
	if not shape or not mesh:
		print("[WARN] Trying to absorb block without mesh/shape: ", incoming_node)
		return

	# Tag the shape so raycasts can identify this specific sub-block later 
	shape.set_meta("owner_block", incoming_node)

	# Store global transforms before reparenting to prevent "jumping" 
	var shape_global_xf = shape.global_transform
	var mesh_global_xf = mesh.global_transform
	var node_global_xf = incoming_node.global_transform

	# Strip physics from the incoming block so it doesn't fight the master body 
	incoming_node.freeze = true
	incoming_node.collision_layer = 0
	incoming_node.collision_mask = 0
	incoming_node.mass = 0.01 

	# --- WELDING: Move parts to the Master RigidBody ---
	shape.reparent(self)
	shape.global_transform = shape_global_xf

	mesh.reparent(self)
	mesh.global_transform = mesh_global_xf

	# Keep the logic script (BaseBlock) as a child for organizational purposes 
	incoming_node.reparent(self)
	incoming_node.global_transform = node_global_xf

	# --- NOTIFICATION SYSTEM ---
	# This is the "fix" for the cluster logic. 
	# It tells every child (like the Motor) that a new block was added.
	for child in get_children():
		if child.has_method("_on_assembly_absorbed_block"):
			child._on_assembly_absorbed_block(incoming_node, hit_normal, target_sub_block)

	# Refresh physics calculations and core outlines 
	call_deferred("recalculate_physics")
	call_deferred("update_core_outline")
	call_deferred("update_core_outline_for_child", incoming_node)


func update_core_outline_for_child(child):
	if child and child.has_method("update_core_outline"):
		child.update_core_outline()



## Safely removes this specific block from the master assembly
func disconnect_self():

	if is_instance_valid(owned_shape):
		owned_shape.remove_meta("owner_block")
		owned_shape.queue_free()

	if is_instance_valid(owned_mesh):
		owned_mesh.queue_free()

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

	for child in get_children():

		if child is MeshInstance3D:
			total_mass += block_mass
			weighted_pos += child.position * block_mass

		elif child is BaseBlock:
			total_mass += child.block_mass
			weighted_pos += child.position * child.block_mass

	mass = total_mass

	if total_mass > 0:
		center_of_mass = weighted_pos / total_mass



func get_block_from_shape(shape_id: int) -> BaseBlock:

	var owner_id = shape_find_owner(shape_id)
	var shape_node = shape_owner_get_owner(owner_id)

	if shape_node and shape_node.has_meta("owner_block"):

		var block = shape_node.get_meta("owner_block")

		if is_instance_valid(block):
			return block

	return self
