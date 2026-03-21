extends PanelContainer

@export var search_bar: LineEdit
@export var node_list: VBoxContainer

# Exported array of NodeDefinition resources
@export var node_definitions: Array[NodeDefinition] = []

var buttons := {}

func _ready():
	search_bar.text_changed.connect(_on_search_changed)
	
	# Clear old buttons
	for child in node_list.get_children():
		child.queue_free()
	
	# Create a button for each node definition
	for node_data in node_definitions:
		_create_button(node_data)

func _create_button(node_data: NodeDefinition):
	var btn = Button.new()
	btn.text = node_data.name if node_data.name != "" else "Unnamed Node"
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.mouse_filter = Control.MOUSE_FILTER_PASS
	node_list.add_child(btn)
	buttons[btn.text] = {"button": btn, "data": node_data}

func _get_drag_data(_at_position):
	for btn_name in buttons.keys():
		var btn = buttons[btn_name]["button"]
		var btn_rect = Rect2(btn.get_global_position(), btn.get_size())
		if btn_rect.has_point(get_global_mouse_position()):
			var preview = Label.new()
			preview.text = btn_name
			set_drag_preview(preview)
			return buttons[btn_name]["data"]  # Resource instance
	return null

func _on_search_changed(text: String):
	var query = text.to_lower()
	for btn_name in buttons:
		buttons[btn_name]["button"].visible = query == "" or btn_name.to_lower().contains(query)
