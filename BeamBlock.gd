extends DirectionalBlock
class_name BeamBlock

# Shared beam properties
var ray: RayCast3D
var beam_mesh: MeshInstance3D
var master_body_excluded: bool = false
var master_body: RigidBody3D = null

# Configuration (set these in _ready of child classes)
var beam_color := Color(1, 1, 1)
var beam_thickness := 0.05
var beam_max_range := 10.0

func _ready():
	super._ready()
	_setup_beam_system()

func _setup_beam_system():
	# 1. Setup Raycast
	ray = RayCast3D.new()
	ray.enabled = true
	ray.position = Vector3(0, 0, -0.6) # Offset from block center
	ray.target_position = Vector3(0, 0, -beam_max_range)
	ray.collision_mask = 1 | 2 # Adjust as needed
	add_child(ray)
	
	# 2. Setup Visual Mesh
	beam_mesh = MeshInstance3D.new()
	beam_mesh.mesh = BoxMesh.new()
	
	var mat = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED # Beams usually glow
	mat.albedo_color = beam_color
	beam_mesh.material_override = mat
	beam_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	
	add_child(beam_mesh)
	beam_mesh.hide()

func _physics_process(_delta: float):
	if not master_body_excluded:
		_find_and_exclude_master()
	
	# Child classes will use 'ray' and 'master_body' here via super
	process_beam_logic()

# OVERRIDE THIS in children
func process_beam_logic():
	pass

func update_beam_visual(current_length: float, active: bool):
	if not is_instance_valid(beam_mesh): return
	
	if not active or current_length <= 0.05:
		beam_mesh.hide()
		return
		
	beam_mesh.show()
	beam_mesh.scale = Vector3(beam_thickness, beam_thickness, current_length)
	# Math: offset the mesh so it starts at the ray origin and grows forward
	beam_mesh.position.z = ray.position.z - (current_length / 2.0)

func _find_and_exclude_master():
	var p = get_parent()
	while p:
		if p is RigidBody3D:
			master_body = p
			ray.add_exception(p)
			master_body_excluded = true
			return
		p = p.get_parent()
