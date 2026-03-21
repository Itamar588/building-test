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

		var real_block = body.get_block_from_shape(shape_id)

		result["block"] = real_block

	return result

# --- Snap any vector to the closest of the 6 grid directions ---
func snap_to_axis(v: Vector3) -> Vector3:

	var abs_v = v.abs()

	if abs_v.x > abs_v.y and abs_v.x > abs_v.z:
		return Vector3(sign(v.x),0,0)

	elif abs_v.y > abs_v.x and abs_v.y > abs_v.z:
		return Vector3(0,sign(v.y),0)

	else:
		return Vector3(0,0,sign(v.z))

# --- Build a perfectly aligned basis for grid rotation ---
func build_grid_basis(master: BaseBlock, local_normal: Vector3) -> Basis:

	var forward = (master.global_transform.basis * local_normal).normalized()

	var up = master.global_transform.basis.y

	# Prevent forward/up alignment
	if abs(forward.dot(up)) > 0.9:
		up = master.global_transform.basis.z

	var right = up.cross(forward).normalized()
	up = forward.cross(right).normalized()

	return Basis(right, up, -forward)

func update_ghost(result):

	if result and result.has("block"):
		var master_obj : BaseBlock = result.block

		var local_hit_pos = master_obj.to_local(result.position)

		var local_normal = snap_to_axis(
			master_obj.global_transform.basis.inverse() * result.normal
		)

		var snapped_local_pos = (local_hit_pos + local_normal * 0.5).round()

		ghost_block.global_position = master_obj.to_global(snapped_local_pos)

		ghost_block.global_transform.basis = master_obj.global_transform.basis

		var temp_block = inventory[current_slot].instantiate()

		if temp_block is DirectionalBlock:

			ghost_block.global_transform.basis = build_grid_basis(master_obj, local_normal)

		temp_block.queue_free()

		ghost_block.show()

	else:

		var cam = get_viewport().get_camera_3d()

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

	new_block.global_position = ghost_block.global_position
	new_block.global_rotation = ghost_block.global_rotation

	if result and result.collider is BaseBlock:

		var master_obj : BaseBlock = result.collider

		var local_normal = snap_to_axis(
			master_obj.global_transform.basis.inverse() * result.normal
		)

		if new_block is DirectionalBlock:

			new_block.global_transform.basis = build_grid_basis(master_obj, local_normal)

			new_block.setup_direction(local_normal)

		master_obj.absorb_block(new_block)

	# --- NODE EDITOR LINKING ---

	if new_block is BaseBlock and new_block.node_data and graph_editor:

		var spawn_pos = Vector2(100, 100)

		var g_node = graph_editor.create_dynamic_node(new_block.node_data, spawn_pos)

		g_node.set_meta("physical_block", new_block)

		new_block.set_meta("logic_node", g_node)
func delete_block(result):

	if not result or not result.has("block"):
		return

	var block : BaseBlock = result.block
	var master = block.get_master_body()

	# If it has a master, detach normally
	if master:
		block.disconnect_self()
	else:
		# This is the core block, delete the whole assembly
		block.queue_free()
