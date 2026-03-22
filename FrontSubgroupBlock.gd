extends DirectionalBlock
class_name FrontCluster

var cluster_blocks: Array[BaseBlock] = []
var rotation_angle := 0.0
# Stores local position & rotation relative to motor (original)
var cluster_local_offsets := {}
var cluster_local_rotations := {}

var blue_outline_material: StandardMaterial3D


func _ready():
	super._ready()
	_prepare_blue_material()


func _prepare_blue_material():
	blue_outline_material = StandardMaterial3D.new()
	blue_outline_material.albedo_color = Color(0.0, 0.6, 1.0)
	blue_outline_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	blue_outline_material.cull_mode = BaseMaterial3D.CULL_FRONT


func _on_assembly_absorbed_block(incoming_node: BaseBlock, hit_normal: Vector3, target_sub_block: BaseBlock):
	var local_hit_normal = transform.basis.inverse() * hit_normal
	var snapped_local_normal = local_hit_normal.round()

	var is_on_my_front = (target_sub_block == self and snapped_local_normal == Vector3.FORWARD)
	var is_on_cluster_member = cluster_blocks.has(target_sub_block)

	if is_on_my_front or is_on_cluster_member:
		add_to_cluster(incoming_node)


## FrontCluster.gd

## FrontCluster.gd

func add_to_cluster(block: BaseBlock):
	if cluster_blocks.has(block):
		return

	cluster_blocks.append(block)

	# 1. Create a basis for the CURRENT spin state
	var current_spin_basis = Basis(Vector3.FORWARD, rotation_angle)
	var inv_spin = current_spin_basis.inverse()

	# 2. Store position relative to motor body, then un-spin it
	var motor_relative_pos = to_local(block.global_position)
	cluster_local_offsets[block] = inv_spin * motor_relative_pos

	# 3. Store rotation relative to motor body, then un-spin it
	# This ensures if the motor is at 45 deg, we store it at 0 deg
	var motor_relative_rot = global_transform.basis.inverse() * block.global_transform.basis
	cluster_local_rotations[block] = inv_spin * motor_relative_rot

	_apply_blue_outline(block)

func _apply_blue_outline(block: BaseBlock):
	await get_tree().process_frame

	if not is_instance_valid(block):
		return
	if not block.owned_mesh:
		return
	if block.owned_mesh.get_node_or_null("ClusterOutline"):
		return

	var blue := MeshInstance3D.new()
	blue.name = "ClusterOutline"
	blue.mesh = block.owned_mesh.mesh
	blue.scale = Vector3.ONE * 1.1
	blue.material_override = blue_outline_material

	block.owned_mesh.add_child(blue)
