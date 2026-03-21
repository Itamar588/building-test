extends BeamBlock
class_name DistanceSensorBlock

func _ready():
	beam_color = Color(1, 0, 0, 0.5) # Red for sensor
	beam_thickness = 0.02
	super._ready() # Calls setup in parent

func apply_input(value: Variant):
	# If input is provided, change range, otherwise use default
	var new_range = beam_max_range
	if value is Array and value[0] != null:
		new_range = float(value[0])
	elif value is float or value is int:
		new_range = float(value)
	
	ray.target_position.z = -new_range

func process_beam_logic():
	var dist = abs(ray.target_position.z) # Default to max
	ray.force_raycast_update()
	
	if ray.is_colliding():
		dist = global_position.distance_to(ray.get_collision_point())
	
	update_beam_visual(dist, true)
	_sync_to_logic(dist)

func _sync_to_logic(val: float):
	if has_meta("logic_node"):
		var g_node = get_meta("logic_node")
		if is_instance_valid(g_node):
			var final_val = snappedf(val, 0.01)
			if abs(g_node.get_meta("last_result", 0.0) - final_val) > 0.001:
				g_node.set_meta("last_result", final_val)
				if g_node.get_parent().has_method("sync"):
					g_node.get_parent().sync()
