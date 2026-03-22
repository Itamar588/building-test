extends DirectionalBlock
class_name FrontCluster

var cluster_blocks: Array[BaseBlock] = []
var blue_outline_material: StandardMaterial3D

func _ready():
	super._ready()
	_prepare_blue_material()

func _prepare_blue_material():
	blue_outline_material = StandardMaterial3D.new()
	blue_outline_material.albedo_color = Color(0.0, 0.6, 1.0)
	blue_outline_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	blue_outline_material.cull_mode = BaseMaterial3D.CULL_FRONT

## Called by Master Body
func _on_assembly_absorbed_block(incoming_node: BaseBlock, hit_normal: Vector3, target_sub_block: BaseBlock):
	
	# --- THE CRITICAL FIX ---
	# hit_normal is relative to the MASTER. 
	# We need to know what that normal is relative to THIS block's rotation.
	# We multiply the normal by the inverse of our local rotation matrix.
	var local_hit_normal = transform.basis.inverse() * hit_normal
	
	# Now we can safely compare it to Vector3.FORWARD (or whatever your 'front' is)
	# We round it to handle floating point errors from the rotation math
	var snapped_local_normal = local_hit_normal.round()

	# 1. Check if clicking on THIS block's front face
	var is_on_my_front = (target_sub_block == self and snapped_local_normal == Vector3.FORWARD)
	
	# 2. Check if clicking on an existing member of this cluster
	var is_on_cluster_member = cluster_blocks.has(target_sub_block)

	if is_on_my_front or is_on_cluster_member:
		add_to_cluster(incoming_node)

func add_to_cluster(block: BaseBlock):
	if not cluster_blocks.has(block):
		cluster_blocks.append(block)
		_apply_blue_outline(block)

func _apply_blue_outline(block: BaseBlock):
	await get_tree().process_frame
	
	if is_instance_valid(block) and block.owned_mesh:
		var blue = MeshInstance3D.new()
		blue.mesh = block.owned_mesh.mesh
		blue.scale = Vector3.ONE * 1.1 
		blue.material_override = blue_outline_material
		block.owned_mesh.add_child(blue)
