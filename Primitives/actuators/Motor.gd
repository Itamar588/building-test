extends FrontCluster
class_name MotorBlock

@export var default_speed: float = 0.0
@export var default_active: bool = false

var speed_rpm: float = 0.0
var is_active: bool = false



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
	
	# Get the master body (The RigidBody3D at the top)
	var master = get_master_body()

	for block in cluster_blocks:
		if not is_instance_valid(block):
			continue

		var offset = cluster_local_offsets.get(block)
		if offset == null:
			continue

		# 1. Calculate the new local transform relative to the Master Body
		var new_local_pos = rot_basis * offset
		var original_rot = cluster_local_rotations.get(block, Basis.IDENTITY)
		var new_local_rot = rot_basis * original_rot

		# 2. Apply to the logic block
		block.position = new_local_pos
		block.basis = new_local_rot

		# 3. CRITICAL: Move the Shape and Mesh directly 
		# Since they are children of the Master Body, we set their local transforms
		if block.owned_mesh:
			block.owned_mesh.transform = block.transform
		if block.owned_shape:
			block.owned_shape.transform = block.transform
			
	# 4. "Ping" the Physics Engine
	# This forces the RigidBody to recalculate its internal collision bounds
	if master:
		# Setting a property to itself is a common trick to force a collision update
		master.mass = master.mass

func get_cluster_ghost_transform(target_block: BaseBlock, local_normal: Vector3) -> Transform3D:
	# If we are looking at the motor itself and hitting the front face
	if target_block == self:
		var pos = to_global(Vector3.FORWARD) # Assuming 1 unit size
		var rot = global_transform.basis * Basis(Vector3.FORWARD, rotation_angle)
		return Transform3D(rot, pos)

	# Get the target's 'resting' data (where it is when rotation is 0)
	var target_rest_off = cluster_local_offsets.get(target_block, Vector3.ZERO)
	var target_rest_rot = cluster_local_rotations.get(target_block, Basis.IDENTITY)
	
	# The new block's resting position is 1 unit offset in the local direction
	var new_rest_off = target_rest_off + (target_rest_rot * local_normal)
	
	# Current spin state
	var current_spin = Basis(Vector3.FORWARD, rotation_angle)
	
	# Combine: Motor World Basis * Current Spin * Target's Resting Orientation
	var final_basis = global_transform.basis * current_spin * target_rest_rot
	var final_pos = global_position + global_transform.basis * (current_spin * new_rest_off)
	
	return Transform3D(final_basis, final_pos)
