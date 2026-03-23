extends DirectionalBlock
class_name AeroBlock

@export var aero_mesh: MeshInstance3D

@export_group("Aerodynamic Faces")
@export var face_top: bool = false
@export var face_bottom: bool = false
@export var face_front: bool = false
@export var face_back: bool = false
@export var face_left: bool = false
@export var face_right: bool = false

@export_group("Aero Physics")
@export var aero_color: Color = Color(0.0, 0.6, 1.0)
## Drag coefficient (1.0 is a flat plate, 0.05 is a teardrop)
@export var drag_coeff: float = 1.0 
## The effective size of each face in meters squared
@export var face_area: float = 1.0

var last_global_pos: Vector3

func _ready():
	super._ready()
	last_global_pos = global_position
	
	if not aero_mesh:
		aero_mesh = find_child("MeshInstance3D*", false, false)
	
	_setup_visuals()

func _setup_visuals():
	if not aero_mesh: return

	var shader = Shader.new()
	shader.code = """
		shader_type spatial;
		uniform vec4 aero_color : source_color;
		uniform float top; uniform float bottom;
		uniform float front; uniform float back;
		uniform float l; uniform float r;

		void fragment() {
			vec3 n = NORMAL;
			float is_aero = 0.0;
			if (top > 0.5 && n.y > 0.5) is_aero = 1.0;
			if (bottom > 0.5 && n.y < -0.5) is_aero = 1.0;
			if (front > 0.5 && n.z > 0.5) is_aero = 1.0;
			if (back > 0.5 && n.z < -0.5) is_aero = 1.0;
			if (l > 0.5 && n.x < -0.5) is_aero = 1.0;
			if (r > 0.5 && n.x > 0.5) is_aero = 1.0;
			
			if (is_aero > 0.5) {
				ALBEDO = aero_color.rgb;
				EMISSION = aero_color.rgb * 0.3;
			} else {
				ALBEDO = vec3(0.5);
			}
		}
	"""
	
	var mat = ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("aero_color", aero_color)
	mat.set_shader_parameter("top", 1.0 if face_top else 0.0)
	mat.set_shader_parameter("bottom", 1.0 if face_bottom else 0.0)
	mat.set_shader_parameter("front", 1.0 if face_front else 0.0)
	mat.set_shader_parameter("back", 1.0 if face_back else 0.0)
	mat.set_shader_parameter("l", 1.0 if face_left else 0.0)
	mat.set_shader_parameter("r", 1.0 if face_right else 0.0)
	
	aero_mesh.material_override = mat

func _physics_process(delta):
	var master_body = get_master_body()
	if not master_body or delta <= 0: return

	# 1. Calculate Velocity
	var velocity = (global_position - last_global_pos) / delta
	last_global_pos = global_position

	var speed = velocity.length()
	if speed < 0.01: return 

	var velocity_dir = velocity.normalized()
	var total_force = Vector3.ZERO

	# 2. Air Density (Standard is 1.225. Higher = thicker air/water)
	var air_density = 1.225

	# 3. Physics Check
	var faces = {
		Vector3.UP: face_top, Vector3.DOWN: face_bottom,
		Vector3.FORWARD: face_front, Vector3.BACK: face_back,
		Vector3.LEFT: face_left, Vector3.RIGHT: face_right
	}

	for local_norm in faces:
		if not faces[local_norm]: continue
		
		var world_norm = global_transform.basis * local_norm
		var exposure = world_norm.dot(velocity_dir)
		
		if exposure > 0:
			# A more stable drag equation: 
			# F = 0.5 * rho * v^2 * Cd * Area
			var force_mag = 0.5 * air_density * (speed * speed) * drag_coeff * (face_area * exposure)
			
			# Safety Clamp: Prevent force from exceeding the body's momentum 
			# This prevents the "Yeet" by making sure the block can't 
			# push harder than gravity/inertia can handle in one frame.
			var max_safe_force = (master_body.mass * speed) / delta
			force_mag = min(force_mag, max_safe_force * 0.5)

			total_force -= velocity_dir * force_mag

	# 4. Apply Force
	master_body.apply_force(total_force, global_position - master_body.global_position)
