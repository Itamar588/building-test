extends DirectionalBlock
class_name RepulserBlock

@export var default_strength: float = 1000.0
@export var default_on: bool = false
@export var max_interaction_range: float = 10.0 

var current_strength: float
var is_on: bool
var current_range: float

var ray: RayCast3D
var kinetic_beam: MeshInstance3D

var beam_thickness: float = 0.08
var master_body_excluded: bool = false


func _ready():
	super._ready()

	current_strength = default_strength
	is_on = default_on
	current_range = max_interaction_range

	# Ray
	ray = RayCast3D.new()
	ray.enabled = true
	ray.position = Vector3(0, 0, -0.6)
	ray.target_position = Vector3(0, 0, -current_range)
	ray.collision_mask = 1 | 2
	add_child(ray)

	# Beam visual
	kinetic_beam = MeshInstance3D.new()

	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE
	kinetic_beam.mesh = mesh

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1,1,0,0.6)
	mat.emission_enabled = true
	mat.emission = Color(10,10,0)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	kinetic_beam.material_override = mat
	kinetic_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	add_child(kinetic_beam)
	kinetic_beam.hide()


func apply_input(value: Variant):

	if value is Array and value.size() >= 3:

		# INPUT 0 → RANGE
		if value[0] != null:
			current_range = max(0.1, float(value[0]))
		else:
			current_range = max_interaction_range

		ray.target_position = Vector3(0,0,-current_range)

		# INPUT 1 → STRENGTH
		if value[1] != null:
			current_strength = float(value[1])
		else:
			current_strength = default_strength

		# INPUT 2 → ACTIVE
		if value[2] != null:
			is_on = bool(value[2])
		else:
			is_on = default_on


func _physics_process(_delta: float):

	if not master_body_excluded:
		_find_and_exclude_master()

	var visual_length: float = 0.0

	if is_on:

		ray.force_raycast_update()

		if ray.is_colliding():

			var hit_obj = ray.get_collider()
			var hit_point = ray.get_collision_point()

			visual_length = ray.global_position.distance_to(hit_point)

			if current_strength > 0:

				var master_body = _find_master_body()

				if master_body:

					var push_dir = get_forward_vector()

					var force_mag = (current_strength / max(visual_length, 0.1)) * 10.0
					var final_force = push_dir * force_mag

					if hit_obj is RigidBody3D:

						hit_obj.apply_force(
							final_force,
							hit_point - hit_obj.global_position
						)

					else:

						master_body.apply_force(
							-final_force,
							global_position - master_body.global_position
						)

		else:
			visual_length = current_range

	_update_beam_visuals(visual_length)


func _update_beam_visuals(length: float):

	if not is_instance_valid(kinetic_beam):
		return

	if not is_on or length <= 0.05:
		kinetic_beam.hide()
		return

	kinetic_beam.show()

	kinetic_beam.scale.x = beam_thickness
	kinetic_beam.scale.y = beam_thickness
	kinetic_beam.scale.z = length

	kinetic_beam.position = Vector3(
		0,
		0,
		ray.position.z - length * 0.5
	)


func _find_master_body() -> RigidBody3D:
	var p = get_parent()
	while p:
		if p is RigidBody3D:
			return p
		p = p.get_parent()
	return null


func _find_and_exclude_master():
	var p = get_parent()
	while p:
		if p is RigidBody3D:
			ray.add_exception(p)
			master_body_excluded = true
			break
		p = p.get_parent()
