extends Control

@export var bar_name: String = "ENERGÍA"
@export var fill_color: Color = Color(0.1, 0.65, 1.0)

var value: float = 100.0
var max_value: float = 100.0

func _ready() -> void:
	custom_minimum_size = Vector2(360, 28)

func set_value(current: float, maximum: float = 100.0) -> void:
	value = clamp(current, 0.0, maximum)
	max_value = maximum
	queue_redraw()

func _draw() -> void:
	var size := Vector2(360, 28)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.6), true)
	draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.25), false, 2)
	var percent := value / max_value if max_value > 0 else 0.0
	draw_rect(Rect2(Vector2(3, 3), Vector2((size.x - 6) * percent, size.y - 6)), fill_color, true)
	draw_string(ThemeDB.fallback_font, Vector2(8, 20), "%s: %d%%" % [bar_name, int(value)], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
