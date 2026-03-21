extends Camera3D

@export var speed: float = 10.0
@export var sensitivity: float = 0.1

var rotation_x: float = 0.0
var rotation_y: float = 0.0

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _input(event):
	if event is InputEventMouseMotion:
		# Modify rotations based on mouse movement
		rotation_x -= event.relative.y * sensitivity
		rotation_y -= event.relative.x * sensitivity
		rotation_x = clamp(rotation_x, -89, 89)
		
		transform.basis = Basis.from_euler(Vector3(deg_to_rad(rotation_x), deg_to_rad(rotation_y), 0))

func _process(delta):
	var input_dir = Input.get_vector("A", "D", "W", "S")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if direction:
		global_position += direction * speed * delta
