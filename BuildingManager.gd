extends Node3D

@export var inventory: Array[PackedScene] = []
@export var ghost_material: StandardMaterial3D
@export var ray_length: float = 20.0
@export var graph_editor: GraphEdit

var current_slot: int = 0
var ghost_block: MeshInstance3D

func _ready():
	ghost_block = MeshInstance3D.new()

	if ghost_material:
		ghost_block.material_override = ghost_material

	add_child(ghost_block)
	_update_ghost_mesh()


func _unhandled_input(event: InputEvent):
	if inventory.size() == 0:
		return

	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			current_slot = (current_slot + 1) % inventory.size()
			_update_ghost_mesh()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			current_slot = (current_slot - 1 + inventory.size()) % inventory.size()
			_update_ghost_mesh()


func _update_ghost_mesh():
	if inventory.size() == 0:
		return

	var temp_instance = inventory[current_slot].instantiate()
	var mesh_node := temp_instance.find_child("*", true, false)
	var found_mesh : Mesh = null

	if temp_instance is MeshInstance3D:
		found_mesh = temp_instance.mesh
	elif mesh_node and mesh_node is MeshInstance3D:
		found_mesh = mesh_node.mesh

	if found_mesh:
		ghost_block.mesh = found_mesh
		ghost_block.scale = Vector3.ONE * 1.01

	print("[BUILDER] Selected Block: ", inventory[current_slot].resource_path.get_file())
	temp_instance.queue_free()


func _process(_delta):
	var result = perform_raycast()
	if Input.is_action_just_pressed("delete"):
		delete_block(result)
	update_ghost(result)

	if Input.is_action_just_pressed("ui_accept"):
		place_block(result)


func perform_raycast() -> Dictionary:
	var cam = get_viewport().get_camera_3d()
	if not cam:
		return {}

	var space_state = get_world_3d().direct_space_state
	var mouse_pos = get_viewport().get_mouse_position()

	var origin = cam.project_ray_origin(mouse_pos)
	var end = origin + cam.project_ray_normal(mouse_pos) * ray_length

	var query = PhysicsRayQueryParameters3D.create(origin, end)
	query.collision_mask = 2
	var result = space_state.intersect_ray(query)

	if result and result.collider is BaseBlock:
		var body : BaseBlock = result.collider
		var shape_id : int = result.shape
		result["block"] = body.get_block_from_shape(shape_id)

	return result


func snap_to_axis(v: Vector3) -> Vector3:
	var abs_v = v.abs()
	if abs_v.x > abs_v.y and abs_v.x > abs_v.z:
		return Vector3(sign(v.x),0,0)
	elif abs_v.y > abs_v.x and abs_v.y > abs_v.z:
		return Vector3(0,sign(v.y),0)
	else:
		return Vector3(0,0,sign(v.z))


func build_grid_basis(target_block: BaseBlock, local_normal: Vector3) -> Basis:
	# Use the specific block's basis to find the world-space 'forward' (outward normal)
	var forward = (target_block.global_transform.basis * local_normal).normalized()
	
	# Use the specific block's 'up' to keep the ghost aligned with the cluster's tilt
	var up = target_block.global_transform.basis.y
	
	if abs(forward.dot(up)) > 0.9:
		up = target_block.global_transform.basis.z
		
	var right = up.cross(forward).normalized()
	up = forward.cross(right).normalized()
	
	return Basis(right, up, -forward)


func update_ghost(result):
	if result and result.has("block"):
		var target_block : BaseBlock = result.block
		var local_normal = snap_to_axis(target_block.global_transform.basis.inverse() * result.normal)
		
		# Find if this block is part of a motor cluster
		var motor : MotorBlock = null
		if target_block.get_parent() is MotorBlock:
			motor = target_block.get_parent()
		elif target_block is MotorBlock:
			motor = target_block

		if motor:
			# The Motor now dictates exactly where the ghost goes
			ghost_block.global_transform = motor.get_cluster_ghost_transform(target_block, local_normal)
		else:
			# Standard placement logic for non-motor blocks
			var local_hit_pos = target_block.to_local(result.position)
			var snapped_local_pos = (local_hit_pos + local_normal * 0.5).round()
			ghost_block.global_position = target_block.to_global(snapped_local_pos)
			
			var temp_block = inventory[current_slot].instantiate()
			if temp_block is DirectionalBlock:
				ghost_block.global_transform.basis = build_grid_basis(target_block, local_normal)
			else:
				ghost_block.global_transform.basis = target_block.global_transform.basis
			temp_block.queue_free()

		ghost_block.show()
	else:
		# Full Air Placement Logic
		var cam = get_viewport().get_camera_3d()
		if cam:
			var dir = cam.project_ray_normal(get_viewport().get_mouse_position())
			ghost_block.global_position = cam.global_position + dir * 5.0
			ghost_block.global_rotation = Vector3.ZERO
			ghost_block.show()

func place_block(result: Dictionary):
	if inventory.size() == 0:
		return

	var new_block = inventory[current_slot].instantiate()
	if new_block == null:
		return

	get_tree().root.add_child(new_block)

	# Use the ghost's transform exactly
	new_block.global_transform = ghost_block.global_transform

	if result and result.has("block"):
		var master_body : BaseBlock = result.collider
		var clicked_part : BaseBlock = result.block
		
		# Use the assembly's orientation to find the placement face
		var local_normal = snap_to_axis(master_body.global_transform.basis.inverse() * result.normal)

		if new_block is DirectionalBlock:
			new_block.setup_direction(local_normal)

		# The motor/cluster logic handles the parenting and welding
		master_body.absorb_block(new_block, local_normal, clicked_part)

	# Node Editor Logic
	if new_block is BaseBlock and new_block.node_data and graph_editor:
		var spawn_pos = Vector2(100, 100)
		var g_node = graph_editor.create_dynamic_node(new_block.node_data, spawn_pos)
		g_node.set_meta("physical_block", new_block)
		new_block.set_meta("logic_node", g_node)


func delete_block(result):
	if not result or not result.has("block"):
		return

	var block : BaseBlock = result.block

	if block.get_parent() is BaseBlock:
		block.disconnect_self()
	else:
		block.queue_free()
