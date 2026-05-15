extends Control

var value: float = 100.0
var max_value: float = 100.0
var fill_color: Color = Color(0.2, 0.65, 1.0, 1.0)
var bar_name: String = "ENERGY"

func _ready() -> void:
	custom_minimum_size = Vector2(230, 30)

func set_value(current: float, maximum: float = 100.0) -> void:
	value = clamp(current, 0.0, maximum)
	max_value = maximum
	queue_redraw()

func _draw() -> void:
	var bar_dimensions: Vector2 = Vector2(220, 18)
	var percent: float = 0.0
	if max_value > 0.0:
		percent = clamp(value / max_value, 0.0, 1.0)

	draw_rect(Rect2(Vector2.ZERO, bar_dimensions), Color(0, 0, 0, 0.6), true)
	draw_rect(Rect2(Vector2.ZERO, bar_dimensions), Color(1, 1, 1, 0.25), false, 2)
	draw_rect(Rect2(Vector2(3, 3), Vector2((bar_dimensions.x - 6.0) * percent, bar_dimensions.y - 6.0)), fill_color, true)
	draw_string(ThemeDB.fallback_font, Vector2(8, 32), "%s: %d%%" % [bar_name, int(value)], HORIZONTAL_ALIGNMENT_LEFT)
