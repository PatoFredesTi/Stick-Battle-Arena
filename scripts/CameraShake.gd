extends Camera2D

@export var target_path: NodePath
@export var smooth_speed := 7.0

var target: Node2D

func _ready() -> void:
	if target_path != NodePath(""):
		target = get_node(target_path)

func _process(delta: float) -> void:
	if target:
		global_position = global_position.lerp(target.global_position + Vector2(0, -40), smooth_speed * delta)
