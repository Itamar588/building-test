extends FrontCluster
class_name MotorBlock

@export var default_speed: float = 0.0
@export var default_active: bool = false

var speed_rpm: float = 0.0
var is_active: bool = false

var rotation_angle := 0.0


func _ready():

	# Motors sometimes have different mesh names
	owned_mesh = find_child("MeshInstance3D*", false, false)
	owned_shape = find_child("CollisionShape3D*", false, false)

	if owned_shape:
		owned_shape.set_meta("owner_block", self)

	super._ready()

	speed_rpm = default_speed
	is_active = default_active

	set_physics_process(true)


## GraphEditor input
func apply_input(value: Variant):

	if value is Array and value.size() >= 2:

		if value[0] != null:
			speed_rpm = float(value[0])
		else:
			speed_rpm = default_speed

		if value[1] != null:
			is_active = bool(value[1])
		else:
			is_active = default_active


func _physics_process(delta):

	if not is_active:
		return

	if cluster_blocks.is_empty():
		return

	var degrees_per_second = (speed_rpm * 360.0) / 60.0
	rotation_angle += deg_to_rad(degrees_per_second) * delta

	_apply_cluster_rotation()


func _apply_cluster_rotation():

	var axis = Vector3.FORWARD
	var rot_basis = Basis(axis, rotation_angle)

	for block in cluster_blocks:

		if not is_instance_valid(block):
			continue

		var offset = cluster_local_offsets.get(block)
		if offset == null:
			continue

		var rotated_offset = rot_basis * offset

		var new_pos = global_position + global_transform.basis * rotated_offset

		block.global_position = new_pos

		var original_rot = cluster_local_rotations.get(block)
		if original_rot == null:
			continue

		var new_basis = global_transform.basis * rot_basis * original_rot

		block.global_basis = new_basis

		# Move visuals and collisions with the logic block
		if block.owned_mesh:
			block.owned_mesh.global_transform = block.global_transform

		if block.owned_shape:
			block.owned_shape.global_transform = block.global_transform
