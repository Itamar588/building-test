extends BeamBlock
class_name RepulserBlock

var is_on := false
var strength := 1000.0
@export var stabilization_authority := 0.5 # How hard it tries to stay upright (0.0 to 1.0+)

func _ready():
	beam_color = Color(1, 1, 0, 0.6) # Yellow for repulser
	beam_thickness = 0.08
	super._ready()

func apply_input(value: Variant):
	if value is Array and value.size() >= 3:
		if value[0] != null: ray.target_position.z = -max(0.1, float(value[0]))
		if value[1] != null: strength = float(value[1])
		if value[2] != null: is_on = bool(value[2])

func process_beam_logic():
	var visual_len = abs(ray.target_position.z)
	
	if is_on:
		ray.force_raycast_update()
		if ray.is_colliding():
			var hit_obj = ray.get_collider()
			var hit_point = ray.get_collision_point()
			visual_len = global_position.distance_to(hit_point)
			
			if master_body and strength != 0:
				var push_dir = get_forward_vector() # Usually -basis.z
				var force_mag = (strength / max(visual_len, 0.1)) * 10.0
				var force_vec = push_dir * force_mag
				
				# 1. APPLY THE PRIMARY FORCE (Lifting/Pushing)
				if hit_obj is RigidBody3D:
					hit_obj.apply_force(force_vec, hit_point - hit_obj.global_position)
				else:
					# Push the master body away from the ground
					master_body.apply_force(-force_vec, global_position - master_body.global_position)
				
				# 2. GYRO-STABILIZATION (The Fix)
				# Calculates the difference between current 'Up' and World 'Up'
				var current_up = master_body.global_transform.basis.y
				var upright_torque = current_up.cross(Vector3.UP)
				
				# Apply a corrective torque to counteract the tilting
				# We scale it by strength so heavier lifts get more stability
				var stabilizer_force = upright_torque * strength * stabilization_authority
				master_body.apply_torque(stabilizer_force)
				
				# Optional: Dampen existing angular velocity to prevent "pendulum" swinging
				master_body.angular_velocity *= 0.95 

	update_beam_visual(visual_len, is_on)
