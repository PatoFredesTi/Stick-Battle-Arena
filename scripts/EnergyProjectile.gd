extends Area2D

var owner_player_id: int = 0
var damage: float = 5.0
var speed: float = 520.0
var direction: Vector2 = Vector2.RIGHT
var lifetime: float = 2.2
var projectile_type: String = "ball"
var target: Node2D = null
var hit_knockback: float = 380.0
var projectile_color: Color = Color(0.3, 0.75, 1.0, 1.0)

func _ready() -> void:
	monitoring = true
	monitorable = true

	var shape: CollisionShape2D = CollisionShape2D.new()
	var circle: CircleShape2D = CircleShape2D.new()
	if projectile_type == "barrage":
		circle.radius = 8.0
	elif projectile_type == "homing":
		circle.radius = 14.0
	else:
		circle.radius = 12.0
	shape.shape = circle
	add_child(shape)

	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()
		return

	if projectile_type == "homing" and target != null and is_instance_valid(target):
		var desired_direction: Vector2 = (target.global_position - global_position).normalized()
		direction = direction.lerp(desired_direction, 0.045).normalized()

	global_position += direction * speed * delta
	queue_redraw()

func _draw() -> void:
	var radius: float = 12.0
	if projectile_type == "barrage":
		radius = 7.0
	elif projectile_type == "homing":
		radius = 15.0

	draw_circle(Vector2.ZERO, radius + 7.0, Color(projectile_color.r, projectile_color.g, projectile_color.b, 0.22))
	draw_circle(Vector2.ZERO, radius, projectile_color)
	draw_circle(Vector2.ZERO, radius * 0.45, Color(1.0, 1.0, 1.0, 0.95))

func _on_area_entered(_area: Area2D) -> void:
	pass

func _on_body_entered(body: Node) -> void:
	if body == null:
		return
	if not body.has_method("take_hit"):
		return
	if body.has_method("get_player_id") and body.get_player_id() == owner_player_id:
		return

	var knock_direction: Vector2 = direction.normalized()
	body.take_hit(damage, 0.16, knock_direction * hit_knockback + Vector2(0, -45))
	queue_free()
