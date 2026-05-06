extends CharacterBody2D

signal energy_changed(current: float, maximum: float)
signal life_changed(current: float, maximum: float)
signal flight_changed(is_flying: bool)

const SPEED := 360.0
const AIR_SPEED := 420.0
const JUMP_VELOCITY := -620.0
const GRAVITY := 1500.0
const MAX_ENERGY := 100.0
const ENERGY_DRAIN_FLY := 18.0
const ENERGY_RECOVERY_GROUND := 9.0
const ENERGY_CHARGE_RATE := 36.0
const DOUBLE_TAP_WINDOW := 0.28

var life := 100.0
var energy := MAX_ENERGY
var is_flying := false
var last_jump_pressed_at := -10.0
var time_alive := 0.0
var facing := 1
var charging := false

func _ready() -> void:
	energy_changed.emit(energy, MAX_ENERGY)
	life_changed.emit(life, 100.0)
	flight_changed.emit(is_flying)

func _physics_process(delta: float) -> void:
	time_alive += delta
	_handle_flight_toggle()
	_handle_movement(delta)
	_handle_energy(delta)
	move_and_slide()
	queue_redraw()

func _handle_flight_toggle() -> void:
	if Input.is_action_just_pressed("jump_fly"):
		if is_on_floor() and not is_flying:
			velocity.y = JUMP_VELOCITY
		elif time_alive - last_jump_pressed_at <= DOUBLE_TAP_WINDOW and energy > 5.0:
			_set_flying(not is_flying)
		last_jump_pressed_at = time_alive

func _handle_movement(delta: float) -> void:
	var direction := Input.get_axis("move_left", "move_right")
	charging = Input.is_action_pressed("charge_energy")
	if abs(direction) > 0.05:
		facing = sign(direction)
	
	if is_flying:
		velocity.x = move_toward(velocity.x, direction * AIR_SPEED, AIR_SPEED * 6.0 * delta)
		if Input.is_action_pressed("jump_fly"):
			velocity.y = move_toward(velocity.y, -AIR_SPEED * 0.65, AIR_SPEED * 5.0 * delta)
		else:
			velocity.y = move_toward(velocity.y, 0.0, AIR_SPEED * 3.5 * delta)
	else:
		velocity.x = move_toward(velocity.x, direction * SPEED, SPEED * 8.0 * delta)
		if not is_on_floor():
			velocity.y += GRAVITY * delta
	
	if is_on_floor() and is_flying:
		_set_flying(false)

func _handle_energy(delta: float) -> void:
	var previous := energy
	if is_flying:
		energy -= ENERGY_DRAIN_FLY * delta
		if energy <= 0.0:
			energy = 0.0
			_set_flying(false)
	elif charging:
		energy += ENERGY_CHARGE_RATE * delta
	elif is_on_floor():
		energy += ENERGY_RECOVERY_GROUND * delta
	energy = clamp(energy, 0.0, MAX_ENERGY)
	if not is_equal_approx(previous, energy):
		energy_changed.emit(energy, MAX_ENERGY)

func _set_flying(value: bool) -> void:
	if is_flying == value:
		return
	is_flying = value
	flight_changed.emit(is_flying)
	if is_flying:
		velocity.y = min(velocity.y, -120.0)

func _draw() -> void:
	var body_color := Color(1, 0.9, 0.25) if is_flying else Color.WHITE
	if charging:
		body_color = Color(0.25, 0.85, 1.0)
		_draw_aura(Color(0.25, 0.85, 1.0, 0.35), 52 + sin(time_alive * 12.0) * 5.0)
	elif is_flying:
		_draw_aura(Color(1, 0.9, 0.25, 0.22), 48 + sin(time_alive * 10.0) * 4.0)
	
	# Stickman
	draw_circle(Vector2(0, -58), 16, body_color)
	draw_line(Vector2(0, -42), Vector2(0, 18), body_color, 6, true)
	draw_line(Vector2(0, -22), Vector2(28 * facing, -2), body_color, 5, true)
	draw_line(Vector2(0, -20), Vector2(-25 * facing, -3), body_color, 5, true)
	draw_line(Vector2(0, 18), Vector2(22, 58), body_color, 6, true)
	draw_line(Vector2(0, 18), Vector2(-22, 58), body_color, 6, true)
	
	# Energy flame when flying
	if is_flying:
		draw_line(Vector2(-10, 60), Vector2(-22, 92 + randf() * 8.0), Color(1, 0.75, 0.1), 5, true)
		draw_line(Vector2(10, 60), Vector2(22, 92 + randf() * 8.0), Color(1, 0.75, 0.1), 5, true)

func _draw_aura(color: Color, radius: float) -> void:
	draw_arc(Vector2(0, 0), radius, 0, TAU, 64, color, 5, true)
	draw_arc(Vector2(0, 0), radius * 0.72, 0, TAU, 64, color.lightened(0.35), 3, true)
