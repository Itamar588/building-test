extends Node3D

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("NodeEditor"):
		# Toggle Visibility
		var is_open = !$NodeEditor.visible
		$NodeEditor.visible = is_open
		
		if is_open:
			# Free the mouse for UI work
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			# Lock the mouse for building/flying
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _ready():
	# Start with the mouse captured if the editor is hidden by default
	if !$NodeEditor.visible:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
