extends RigidBody3D
class_name BaseBlock

@export var block_mass: float = 1.0
@export var node_data: NodeDefinition # The logic template for this block

func _ready():
	# Crucial for balance as we add parts
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	collision_layer = 2 
	recalculate_physics()

# Specific blocks (Thrusters, etc.) will override this
func apply_input(value: Variant):
	pass

func absorb_block(incoming_node: RigidBody3D):
	if incoming_node == self: return

	var shape = incoming_node.get_node_or_null("CollisionShape3D")
	var mesh = incoming_node.get_node_or_null("MeshInstance3D")
	
	if shape and mesh:
		var shape_global_xf = shape.global_transform
		var node_global_xf = incoming_node.global_transform
		
		incoming_node.freeze = true
		incoming_node.collision_layer = 0
		
		# Move the physical shape to the master
		shape.reparent(self)
		shape.global_transform = shape_global_xf
		
		# Move the node (scripts/visuals) to the master
		incoming_node.reparent(self)
		incoming_node.global_transform = node_global_xf
		
		call_deferred("recalculate_physics")

func recalculate_physics():
	var total_mass = 0.0
	var weighted_pos = Vector3.ZERO
	
	for child in get_children():
		if child is MeshInstance3D or child is BaseBlock:
			total_mass += block_mass
			weighted_pos += child.position * block_mass
			
	mass = total_mass
	if total_mass > 0:
		center_of_mass = weighted_pos / total_mass
