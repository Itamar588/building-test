extends GraphEdit

var is_syncing := false # Guard to prevent infinite feedback loops

func _ready():
	connection_request.connect(_on_connection_request)
	disconnection_request.connect(_on_disconnection_request)

func _on_connection_request(from_node: StringName, from_port: int, to_node: StringName, to_port: int):
	# ENFORCE ONE INPUT PER PORT: Disconnect existing before connecting new
	for c in get_connection_list():
		if c["to_node"] == to_node and c["to_port"] == to_port:
			disconnect_node(c["from_node"], c["from_port"], c["to_node"], c["to_port"])
	
	connect_node(from_node, from_port, to_node, to_port)
	sync()

func _on_disconnection_request(from_node: StringName, from_port: int, to_node: StringName, to_port: int):
	disconnect_node(from_node, from_port, to_node, to_port)
	sync()

# --- DRAG AND DROP HANDLERS ---

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is NodeDefinition

func _drop_data(at_position: Vector2, data: Variant):
	var spawn_pos = (at_position + scroll_offset) / zoom
	create_dynamic_node(data, spawn_pos)

# --- DYNAMIC UI GENERATION ---

func create_dynamic_node(def: NodeDefinition, pos: Vector2) -> GraphNode:
	var gn = GraphNode.new()
	gn.title = def.name
	gn.position_offset = pos
	gn.set_meta("code", def.code)
	gn.set_meta("last_result", 0.0)
	
	if def.has_data:
		var control = _create_control_for_type(def.data_type)
		gn.add_child(control)
		gn.set_meta("control", control)
	
	var max_ports = max(def.in_ports, def.out_ports)
	for i in range(max_ports):
		var row = HBoxContainer.new()
		row.custom_minimum_size.y = 25

		var in_label = Label.new()
		in_label.text = def.in_port_labels[i] if i < def.in_port_labels.size() else (">" if i < def.in_ports else "")
		in_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		in_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(in_label)

		var sep = Label.new()
		sep.text = "|"
		sep.modulate = Color(1, 1, 1, 0.3)
		row.add_child(sep)

		var out_label = Label.new()
		out_label.text = def.out_port_labels[i] if i < def.out_port_labels.size() else ("<" if i < def.out_ports else "")
		out_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		out_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(out_label)

		gn.add_child(row)
		gn.set_slot(gn.get_child_count() - 1,
			i < def.in_ports, 0, Color.GREEN,
			i < def.out_ports, 0, Color.BLUE)
	
	add_child(gn)
	return gn

func _create_control_for_type(type: int) -> Control:
	match type:
		0, 1: # Float/Int
			var sb = SpinBox.new()
			sb.min_value = -99999
			sb.max_value = 99999
			sb.step = 0.01 if type == 0 else 1.0
			sb.value_changed.connect(func(_v): sync())
			return sb
		3: # Bool
			var cb = CheckBox.new()
			cb.toggled.connect(func(_v): sync())
			return cb
	return Control.new()

# --- PROCESS LOOP ---

func _process(_delta):
	sync()

# --- EVALUATION ENGINE ---

func sync():
	if is_syncing: return
	is_syncing = true
	
	var max_passes = 5
	for i in range(max_passes):
		var changed = false
		for node in get_children():
			if node is GraphNode:
				var old_val = node.get_meta("last_result", 0.0)
				evaluate_node(node)
				var new_val = node.get_meta("last_result", 0.0)
				
				# Safe comparison for sync loop
				if typeof(old_val) != typeof(new_val) or str(old_val) != str(new_val):
					changed = true
		if not changed:
			break
	
	is_syncing = false

func evaluate_node(node: GraphNode):
	var inputs = []
	for i in range(10):
		inputs.append(null)
		
	# --- Gather input values ---
	for c in get_connection_list():
		if c["to_node"] == node.name:
			var port_idx = c["to_port"]
			var from_node = get_node_or_null(str(c["from_node"]))
			if from_node:
				inputs[port_idx] = from_node.get_meta("last_result", 0.0)
	
	# --- Math-safe inputs ---
	var math_inputs = []
	for val in inputs:
		math_inputs.append(0.0 if val == null else val)

	# --- Internal control value ---
	var internal_val: Variant = 0.0
	if node.has_meta("control"):
		var ctrl = node.get_meta("control")
		var ctrl_val: Variant
		if ctrl is SpinBox:
			ctrl_val = ctrl.value
		elif ctrl is CheckBox:
			ctrl_val = ctrl.button_pressed 
		else:
			ctrl_val = node.get_meta("last_result", 0.0)
		
		internal_val = ctrl_val
		# If it's a source node (like a Slider/Checkbox), update result from UI
		if node.get_meta("code", "") == "internal_value" or node.get_meta("code", "") == "":
			node.set_meta("last_result", ctrl_val)

	var current_meta_val = node.get_meta("last_result", 0.0)
	var expr = Expression.new()
	var code_string = node.get_meta("code", "0.0")

	# --- Expression evaluation with Time ---
	var err = expr.parse(code_string, ["inputs", "internal_value", "last_result", "time"])
	if err == OK:
		var res = expr.execute([math_inputs, internal_val, current_meta_val, Time], node)
		if not expr.has_execute_failed():
			if res is float or res is int:
				res = snappedf(float(res), 0.01)
			node.set_meta("last_result", res)

	# --- BRIDGE LOGIC TO PHYSICAL BLOCKS ---
	# This pushes the calculated 'last_result' to the actual 3D Block (Motor, Thruster, etc)
	if node.has_meta("physical_block"):
		var physical_block = node.get_meta("physical_block")
		if is_instance_valid(physical_block) and physical_block.has_method("apply_input"):
			physical_block.apply_input(node.get_meta("last_result", 0.0))

	# --- Printer node logic ---
	if node.title == "Printer":
		var val: Variant = null
		for c in get_connection_list():
			if c["to_node"] == node.name:
				var from_node = get_node_or_null(str(c["from_node"]))
				if from_node:
					val = from_node.get_meta("last_result", null)
					break
		
		if val == null: return

		if not node.has_meta("last_printed"):
			node.set_meta("last_printed", null)
		
		var last_printed = node.get_meta("last_printed")
		
		var changed := false
		if typeof(val) != typeof(last_printed):
			changed = true
		elif typeof(val) in [TYPE_FLOAT, TYPE_INT]:
			changed = not is_equal_approx(float(val), float(last_printed))
		else:
			changed = val != last_printed

		if changed:
			print(val)
			node.set_meta("last_printed", val)
