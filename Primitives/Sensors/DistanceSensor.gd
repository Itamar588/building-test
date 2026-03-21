extends DirectionalBlock
class_name DistanceSensorBlock

@export var default_max_range: float = 10.0 
var current_max_range: float = 10.0
var ray: RayCast3D
var laser_mesh: MeshInstance3D
var master_body_excluded: bool = false

func _ready():
	super._ready()
	current_max_range = default_max_range
	
	ray = RayCast3D.new()
	ray.enabled = true
	ray.position = Vector3(0, 0, -0.6) 
	ray.target_position = Vector3(0, 0, -current_max_range)
	ray.collision_mask = 0xFFFF 
	add_child(ray)
	
	laser_mesh = MeshInstance3D.new()
	var b_mesh = BoxMesh.new()
	b_mesh.size = Vector3(1, 1, 1)
	laser_mesh.mesh = b_mesh
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(1, 0, 0, 0.5)
	mat.emission_enabled = true
	mat.emission = Color(10, 0, 0)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	laser_mesh.material_override = mat
	
	add_child(laser_mesh)
	laser_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func apply_input(value: Variant):
	if value is Array and value.size() > 0:
		var port_0 = value[0]
		# PERSISTENCE: If port is empty/null, snap back to default
		if port_0 == null:
			current_max_range = default_max_range
		else:
			current_max_range = float(port_0)
	else:
		current_max_range = float(value)
		
	if is_instance_valid(ray):
		ray.target_position = Vector3(0, 0, -current_max_range)

func _physics_process(_delta: float):
	if not master_body_excluded:
		_find_and_exclude_master()
	
	var result_dist: float = 0.0
	var visual_length = current_max_range
	
	if current_max_range > 0:
		ray.force_raycast_update()
		if ray.is_colliding():
			var hit_point = ray.get_collision_point()
			var dist = global_position.distance_to(hit_point)
			
			if dist <= current_max_range + 0.1:
				result_dist = dist
				visual_length = dist
	
	# Update Visual Laser
	if is_instance_valid(laser_mesh):
		if current_max_range <= 0.05:
			laser_mesh.hide()
		else:
			laser_mesh.show()
			laser_mesh.scale = Vector3(0.02, 0.02, visual_length)
			var z_offset = ray.position.z - (visual_length / 2.0)
			laser_mesh.position.z = z_offset

	# Sync to Logic Node
	if has_meta("logic_node"):
		var g_node = get_meta("logic_node")
		if is_instance_valid(g_node):
			var final_val = snappedf(result_dist, 0.01)
			if abs(g_node.get_meta("last_result", 0.0) - final_val) > 0.001:
				g_node.set_meta("last_result", final_val)
				var editor = g_node.get_parent()
				if editor and editor.has_method("sync"):
					editor.sync()

func _find_and_exclude_master():
	var p = get_parent()
	while p:
		if p is RigidBody3D:
			ray.add_exception(p)
			master_body_excluded = true
			break
		p = p.get_parent()
