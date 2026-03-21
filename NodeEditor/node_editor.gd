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
	
	# 1. Add Internal Data Control (SpinBox/CheckBox)
	if def.has_data:
		var control = _create_control_for_type(def.data_type)
		gn.add_child(control)
		gn.set_meta("control", control)
	
	# 2. Generate Balanced Port Rows with Labels and Separator
	var max_ports = max(def.in_ports, def.out_ports)
	
	for i in range(max_ports):
		var row = HBoxContainer.new()
		row.custom_minimum_size.y = 25 
		
		# --- INPUT LABEL (Left Side) ---
		var in_label = Label.new()
		if i < def.in_port_labels.size():
			in_label.text = def.in_port_labels[i]
		else:
			in_label.text = ">" if i < def.in_ports else ""
		in_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		in_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(in_label)

		# --- THE SEPARATOR (Middle) ---
		var sep = Label.new()
		sep.text = "|"
		sep.modulate = Color(1, 1, 1, 0.3) # Dimmed for cleaner UI
		row.add_child(sep)
		
		# --- OUTPUT LABEL (Right Side) ---
		var out_label = Label.new()
		if i < def.out_port_labels.size():
			out_label.text = def.out_port_labels[i]
		else:
			out_label.text = "<" if i < def.out_ports else ""
		out_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		out_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(out_label)
		
		gn.add_child(row)
		
		# 3. Enable Slots (Green = Input, Blue = Output)
		gn.set_slot(gn.get_child_count() - 1, 
			i < def.in_ports, 0, Color.GREEN, 
			i < def.out_ports, 0, Color.BLUE)
		
	add_child(gn)
	return gn

func _create_control_for_type(type: int) -> Control:
	match type:
		0, 1: # Float/Int
			var sb = SpinBox.new()
			sb.min_value = -99999; sb.max_value = 99999
			sb.step = 0.01 if type == 0 else 1.0
			sb.value_changed.connect(func(_v): sync())
			return sb
		3: # Bool
			var cb = CheckBox.new()
			cb.toggled.connect(func(_v): sync())
			return cb
	return Control.new()

# --- EVALUATION ENGINE ---

func sync():
	if is_syncing: return 
	is_syncing = true
	
	# Multi-pass ensures data flows through long chains in one frame
	var max_passes = 5 
	for i in range(max_passes):
		var changed = false
		for node in get_children():
			if node is GraphNode:
				var old_val = node.get_meta("last_result", 0.0)
				evaluate_node(node)
				var new_val = node.get_meta("last_result", 0.0)
				
				# Convert to string for reliable "changed" check on variants
				if str(old_val) != str(new_val):
					changed = true
		if not changed: break
	
	is_syncing = false

func evaluate_node(node: GraphNode):
	# Initialize inputs with null to allow blocks to detect empty ports
	var inputs = []
	for i in range(10): inputs.append(null)
		
	# Gather data from connected nodes
	for c in get_connection_list():
		if c["to_node"] == node.name:
			var port_idx = c["to_port"]
			var from_node = get_node_or_null(str(c["from_node"]))
			if from_node:
				inputs[port_idx] = from_node.get_meta("last_result", 0.0)
	
	# Create math-safe version (null becomes 0.0) for the Expression engine
	var math_inputs = []
	for val in inputs:
		math_inputs.append(0.0 if val == null else val)

	# Get internal value from the UI control (if any)
	var internal_val: Variant = 0.0
	if node.has_meta("control"):
		var ctrl = node.get_meta("control")
		if ctrl is SpinBox: internal_val = ctrl.value
		elif ctrl is CheckBox: internal_val = ctrl.button_pressed

	var current_meta_val = node.get_meta("last_result", 0.0)
	var expr = Expression.new()
	var code_string = node.get_meta("code", "0.0")
	
	# Logic execution
	var err = expr.parse(code_string, ["inputs", "internal_value", "last_result"])
	if err == OK:
		var res = expr.execute([math_inputs, internal_val, current_meta_val], node)
		
		if not expr.has_execute_failed():
			if res is float: res = snappedf(res, 0.01)
			node.set_meta("last_result", res)
			
			# Push data to the physical block in the 3D world
			if node.has_meta("physical_block"):
				var pb = node.get_meta("physical_block")
				if is_instance_valid(pb):
					pb.apply_input(inputs) 
	else:
		# Use a throttled print or meta-error if this gets too spammy
		pass
