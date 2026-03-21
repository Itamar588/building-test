extends Resource
class_name NodeDefinition

enum DataType { FLOAT, INT, STRING, BOOL }

@export var name: String = "Block"
@export var in_ports: int = 0
@export var out_ports: int = 0
@export var in_port_labels: Array[String] = []
@export var out_port_labels: Array[String] = []
@export var code: String = "" # e.g. "inputs[0] * internal_value"
@export var has_data: bool = false
@export var data_type: DataType = DataType.FLOAT
