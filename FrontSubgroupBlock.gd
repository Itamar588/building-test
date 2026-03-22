extends DirectionalBlock
class_name FrontCluster

var cluster_blocks: Array[BaseBlock] = []

# Stores transforms relative to the motor
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


## Called by the Master Body when a block gets welded
func _on_assembly_absorbed_block(incoming_node: BaseBlock, hit_normal: Vector3, target_sub_block: BaseBlock):

	var local_hit_normal = transform.basis.inverse() * hit_normal
	var snapped_local_normal = local_hit_normal.round()

	var is_on_my_front = (target_sub_block == self and snapped_local_normal == Vector3.FORWARD)
	var is_on_cluster_member = cluster_blocks.has(target_sub_block)

	if is_on_my_front or is_on_cluster_member:
		add_to_cluster(incoming_node)


func add_to_cluster(block: BaseBlock):

	if cluster_blocks.has(block):
		return

	cluster_blocks.append(block)

	# Store local position relative to motor
	var local_pos = to_local(block.global_position)
	cluster_local_offsets[block] = local_pos

	# Store local rotation relative to motor
	var local_rot = global_transform.basis.inverse() * block.global_transform.basis
	cluster_local_rotations[block] = local_rot

	_apply_blue_outline(block)


func _apply_blue_outline(block: BaseBlock):

	await get_tree().process_frame

	if not is_instance_valid(block):
		return

	if not block.owned_mesh:
		return

	# Prevent duplicate outlines
	if block.owned_mesh.get_node_or_null("ClusterOutline"):
		return

	var blue := MeshInstance3D.new()
	blue.name = "ClusterOutline"

	blue.mesh = block.owned_mesh.mesh
	blue.scale = Vector3.ONE * 1.1
	blue.material_override = blue_outline_material

	block.owned_mesh.add_child(blue)
