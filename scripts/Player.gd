extends CharacterBody2D

signal energy_changed(player_id: int, current: float, maximum: float)
signal life_changed(player_id: int, current: float, maximum: float)
signal attack_landed(player_id: int)
signal energy_attack_used(player_id: int, projectile_type: String)
signal dash_started(player_id: int)

const ProjectileScript: Script = preload("res://scripts/EnergyProjectile.gd")

const MAX_LIFE: float = 100.0
const MAX_ENERGY: float = 100.0
const GROUND_Y: float = 120.0
const LEFT_LIMIT: float = -1050.0
const RIGHT_LIMIT: float = 1050.0

const GRAVITY: float = 1350.0
const MOVE_SPEED: float = 280.0
const AIR_SPEED: float = 330.0
const JUMP_FORCE: float = -520.0
const FLY_SPEED: float = 255.0

const GROUND_ACCELERATION: float = 1350.0
const AIR_ACCELERATION: float = 1050.0
const GROUND_FRICTION: float = 1900.0
const AIR_FRICTION: float = 850.0
const STUN_KNOCKBACK_FRICTION: float = 1450.0
const MAX_HORIZONTAL_SPEED: float = 900.0
const MAX_VERTICAL_SPEED: float = 900.0

const ENERGY_FLY_DRAIN: float = 16.0
const ENERGY_CHARGE_RATE: float = 34.0
const PASSIVE_ENERGY_RATE: float = 3.0

const DASH_COST: float = 9.0
const DASH_SPEED: float = 720.0
const DASH_TIME: float = 0.16
const DASH_COOLDOWN: float = 0.42

const AURA_DAMAGE_MULTIPLIER: float = 1.5
const AURA_SPEED_MULTIPLIER: float = 1.5
const AURA_ENERGY_ATTACK_MULTIPLIER: float = 1.5
const AURA_DRAIN_RATE: float = 22.0
const AURA_MIN_ENERGY: float = 10.0

var player_id: int = 1
var opponent: CharacterBody2D = null
var body_color: Color = Color(0.35, 0.78, 1.0, 1.0)

var life: float = MAX_LIFE
var energy: float = MAX_ENERGY
var facing: int = 1
var is_flying: bool = false
var is_charging: bool = false
var is_blocking: bool = false
var is_dashing: bool = false
var is_aura_active: bool = false

var jump_press_timer: float = 0.0
var stun_timer: float = 0.0
var attack_cooldown: float = 0.0
var hit_flash_timer: float = 0.0
var projectile_cooldown: float = 0.0
var dash_timer: float = 0.0
var dash_cooldown_timer: float = 0.0
var trail_timer: float = 0.0
var afterimage_positions: Array[Vector2] = []

func _ready() -> void:
	add_to_group("fighters")

	var collision: CollisionShape2D = CollisionShape2D.new()
	var capsule: CapsuleShape2D = CapsuleShape2D.new()
	capsule.radius = 18.0
	capsule.height = 78.0
	collision.shape = capsule
	collision.position = Vector2(0, -34)
	add_child(collision)

	energy_changed.emit(player_id, energy, MAX_ENERGY)
	life_changed.emit(player_id, life, MAX_LIFE)

func get_player_id() -> int:
	return player_id

func _physics_process(delta: float) -> void:
	_update_timers(delta)
	_update_facing()

	if stun_timer > 0.0:
		_update_stun_movement(delta)
		_apply_world_limits()
		move_and_slide()
		queue_redraw()
		return

	_handle_input(delta)
	_apply_world_limits()
	move_and_slide()
	queue_redraw()

func _update_timers(delta: float) -> void:
	if jump_press_timer > 0.0:
		jump_press_timer -= delta
	if attack_cooldown > 0.0:
		attack_cooldown -= delta
	if hit_flash_timer > 0.0:
		hit_flash_timer -= delta
	if projectile_cooldown > 0.0:
		projectile_cooldown -= delta
	if dash_cooldown_timer > 0.0:
		dash_cooldown_timer -= delta
	if dash_timer > 0.0:
		dash_timer -= delta
		if dash_timer <= 0.0:
			is_dashing = false
	if trail_timer > 0.0:
		trail_timer -= delta

	if is_dashing and trail_timer <= 0.0:
		afterimage_positions.push_front(global_position)
		if afterimage_positions.size() > 5:
			afterimage_positions.pop_back()
		trail_timer = 0.035

	if not is_dashing and afterimage_positions.size() > 0:
		afterimage_positions.pop_back()

	if is_aura_active:
		energy = max(0.0, energy - AURA_DRAIN_RATE * delta)
		energy_changed.emit(player_id, energy, MAX_ENERGY)
		if energy <= 0.0:
			is_aura_active = false

	if energy < MAX_ENERGY and not is_charging and not is_aura_active:
		energy = min(MAX_ENERGY, energy + PASSIVE_ENERGY_RATE * delta)
		energy_changed.emit(player_id, energy, MAX_ENERGY)

func _update_facing() -> void:
	if opponent != null and is_instance_valid(opponent) and not is_dashing and stun_timer <= 0.0:
		if opponent.global_position.x > global_position.x:
			facing = 1
		else:
			facing = -1

func _update_stun_movement(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, STUN_KNOCKBACK_FRICTION * delta)
	velocity.y += GRAVITY * delta
	velocity.x = clamp(velocity.x, -MAX_HORIZONTAL_SPEED, MAX_HORIZONTAL_SPEED)
	velocity.y = clamp(velocity.y, -MAX_VERTICAL_SPEED, MAX_VERTICAL_SPEED)

func _handle_input(delta: float) -> void:
	var left_action: String = _action("left")
	var right_action: String = _action("right")
	var down_action: String = _action("down")
	var jump_action: String = _action("jump")
	var charge_action: String = _action("charge")
	var block_action: String = _action("block")
	var aura_action: String = _action("aura")
	var dash_action: String = _action("dash")
	var light_action: String = _action("light_attack")
	var heavy_action: String = _action("heavy_attack")
	var ball_action: String = _action("energy_ball")
	var barrage_action: String = _action("energy_barrage")
	var homing_action: String = _action("homing_energy")

	var move_axis: float = Input.get_action_strength(right_action) - Input.get_action_strength(left_action)

	if Input.is_action_just_pressed(aura_action):
		_toggle_aura()

	is_charging = Input.is_action_pressed(charge_action) and not is_dashing and not is_aura_active
	is_blocking = Input.is_action_pressed(block_action) and not is_charging and not is_dashing

	if Input.is_action_just_pressed(dash_action):
		_try_dash(move_axis)

	if is_dashing:
		if is_flying:
			velocity.y = move_toward(velocity.y, 0.0, 900.0 * delta)
		else:
			velocity.y += GRAVITY * delta * 0.35
		velocity.x = clamp(velocity.x, -MAX_HORIZONTAL_SPEED, MAX_HORIZONTAL_SPEED)
		velocity.y = clamp(velocity.y, -MAX_VERTICAL_SPEED, MAX_VERTICAL_SPEED)
		return

	if is_charging:
		velocity.x = move_toward(velocity.x, 0.0, GROUND_FRICTION * delta)
		energy = min(MAX_ENERGY, energy + ENERGY_CHARGE_RATE * delta)
		energy_changed.emit(player_id, energy, MAX_ENERGY)
	else:
		var current_speed_multiplier: float = 1.0
		if is_aura_active:
			current_speed_multiplier = AURA_SPEED_MULTIPLIER

		var target_speed: float = move_axis * MOVE_SPEED * current_speed_multiplier
		var acceleration: float = GROUND_ACCELERATION
		var friction: float = GROUND_FRICTION

		if is_flying:
			target_speed = move_axis * AIR_SPEED * current_speed_multiplier
			acceleration = AIR_ACCELERATION
			friction = AIR_FRICTION

		if abs(move_axis) > 0.1:
			velocity.x = move_toward(velocity.x, target_speed, acceleration * delta)
		else:
			velocity.x = move_toward(velocity.x, 0.0, friction * delta)

	if abs(move_axis) > 0.1:
		facing = 1 if move_axis > 0.0 else -1

	if Input.is_action_just_pressed(jump_action):
		if _is_on_custom_floor():
			velocity.y = JUMP_FORCE
			jump_press_timer = 0.25
		else:
			if jump_press_timer > 0.0:
				is_flying = not is_flying
				jump_press_timer = 0.0
			else:
				jump_press_timer = 0.25

	if is_flying and energy > 0.0:
		var aura_speed_bonus: float = AURA_SPEED_MULTIPLIER if is_aura_active else 1.0
		if Input.is_action_pressed(jump_action):
			velocity.y = -FLY_SPEED * aura_speed_bonus
		elif Input.is_action_pressed(down_action):
			velocity.y = FLY_SPEED * aura_speed_bonus
		else:
			velocity.y = move_toward(velocity.y, 0.0, 730.0 * delta)

		energy = max(0.0, energy - ENERGY_FLY_DRAIN * delta)
		energy_changed.emit(player_id, energy, MAX_ENERGY)
		if energy <= 0.0:
			is_flying = false
	else:
		velocity.y += GRAVITY * delta

	velocity.x = clamp(velocity.x, -MAX_HORIZONTAL_SPEED, MAX_HORIZONTAL_SPEED)
	velocity.y = clamp(velocity.y, -MAX_VERTICAL_SPEED, MAX_VERTICAL_SPEED)

	if Input.is_action_just_pressed(light_action):
		_try_melee_attack(6.0, 0.15, 62.0, 185.0)
	if Input.is_action_just_pressed(heavy_action):
		_try_melee_attack(11.0, 0.22, 82.0, 285.0)

	if Input.is_action_just_pressed(ball_action):
		_try_spawn_projectile("ball")
	if Input.is_action_just_pressed(barrage_action):
		_try_spawn_barrage()
	if Input.is_action_just_pressed(homing_action):
		_try_spawn_projectile("homing")

func _try_dash(move_axis: float) -> void:
	if dash_cooldown_timer > 0.0 or is_charging or energy < DASH_COST:
		return

	var dash_direction: Vector2 = Vector2(float(facing), 0.0)
	if abs(move_axis) > 0.1:
		dash_direction.x = 1.0 if move_axis > 0.0 else -1.0
		facing = int(dash_direction.x)

	if is_flying:
		dash_direction = Vector2(float(facing), 0.0)
		if Input.is_action_pressed(_action("jump")):
			dash_direction.y = -0.45
		elif Input.is_action_pressed(_action("down")):
			dash_direction.y = 0.45
		dash_direction = dash_direction.normalized()

	energy -= DASH_COST
	energy_changed.emit(player_id, energy, MAX_ENERGY)
	is_dashing = true
	is_blocking = false
	is_charging = false
	dash_timer = DASH_TIME
	dash_cooldown_timer = DASH_COOLDOWN
	velocity = dash_direction * DASH_SPEED * (AURA_SPEED_MULTIPLIER if is_aura_active else 1.0)
	velocity.x = clamp(velocity.x, -MAX_HORIZONTAL_SPEED, MAX_HORIZONTAL_SPEED)
	velocity.y = clamp(velocity.y, -MAX_VERTICAL_SPEED, MAX_VERTICAL_SPEED)
	afterimage_positions.clear()
	dash_started.emit(player_id)

func _toggle_aura() -> void:
	if is_aura_active:
		is_aura_active = false
		return
	if energy >= AURA_MIN_ENERGY:
		is_aura_active = true
		is_charging = false
		is_blocking = false

func _apply_world_limits() -> void:
	if global_position.y > GROUND_Y:
		global_position.y = GROUND_Y
		if velocity.y > 0.0:
			velocity.y = 0.0
		is_flying = false

	if global_position.x < LEFT_LIMIT:
		global_position.x = LEFT_LIMIT
		if velocity.x < 0.0:
			velocity.x = 0.0

	if global_position.x > RIGHT_LIMIT:
		global_position.x = RIGHT_LIMIT
		if velocity.x > 0.0:
			velocity.x = 0.0

func _is_on_custom_floor() -> bool:
	return global_position.y >= GROUND_Y - 0.5

func _try_melee_attack(damage: float, stun_time: float, attack_range: float, knockback_force: float) -> void:
	if attack_cooldown > 0.0 or is_charging:
		return
	attack_cooldown = 0.20

	if opponent == null or not is_instance_valid(opponent):
		return

	var to_opponent: Vector2 = opponent.global_position - global_position
	var is_in_front: bool = sign(to_opponent.x) == facing or abs(to_opponent.x) < 18.0
	var vertical_ok: bool = abs(to_opponent.y) < 125.0

	if is_in_front and vertical_ok and to_opponent.length() <= attack_range:
		if opponent.has_method("take_hit"):
			var dash_bonus: float = 1.0
			if is_dashing:
				dash_bonus = 1.25

			var aura_bonus: float = 1.0
			if is_aura_active:
				aura_bonus = AURA_DAMAGE_MULTIPLIER

			var knockback_bonus: float = min(aura_bonus, 1.25)
			var final_knockback: Vector2 = Vector2(facing * knockback_force * dash_bonus * knockback_bonus, -135.0)
			opponent.take_hit(damage * dash_bonus * aura_bonus, stun_time, final_knockback)
			attack_landed.emit(player_id)

func _try_spawn_projectile(projectile_type: String) -> void:
	if projectile_cooldown > 0.0 or is_charging:
		return

	var cost: float = 8.0
	var damage: float = 5.0
	var speed: float = 620.0
	var cooldown: float = 0.31
	var knockback_amount: float = 155.0

	if projectile_type == "homing":
		cost = 14.0
		damage = 7.0
		speed = 450.0
		cooldown = 0.66
		knockback_amount = 210.0

	if energy < cost:
		return

	if is_aura_active:
		damage *= AURA_ENERGY_ATTACK_MULTIPLIER
		speed *= 1.18
		knockback_amount *= 1.25

	energy -= cost
	energy_changed.emit(player_id, energy, MAX_ENERGY)
	projectile_cooldown = cooldown

	var projectile: Area2D = ProjectileScript.new()
	projectile.owner_player_id = player_id
	projectile.projectile_type = projectile_type
	projectile.damage = damage
	projectile.speed = speed
	projectile.hit_knockback = knockback_amount
	projectile.direction = Vector2(facing, 0.0)
	projectile.global_position = global_position + Vector2(facing * 42, -34)
	projectile.target = opponent
	projectile.projectile_color = body_color
	get_parent().add_child(projectile)
	energy_attack_used.emit(player_id, projectile_type)

func _try_spawn_barrage() -> void:
	if projectile_cooldown > 0.0 or is_charging:
		return

	var cost: float = 15.0
	if energy < cost:
		return

	energy -= cost
	energy_changed.emit(player_id, energy, MAX_ENERGY)
	projectile_cooldown = 0.76

	var barrage_damage: float = 2.0
	var barrage_speed: float = 710.0
	var barrage_knockback: float = 95.0

	if is_aura_active:
		barrage_damage *= AURA_ENERGY_ATTACK_MULTIPLIER
		barrage_speed *= 1.18
		barrage_knockback *= 1.25

	for index in range(3):
		var projectile: Area2D = ProjectileScript.new()
		projectile.owner_player_id = player_id
		projectile.projectile_type = "barrage"
		projectile.damage = barrage_damage
		projectile.speed = barrage_speed
		projectile.hit_knockback = barrage_knockback
		projectile.direction = Vector2(facing, (float(index) - 1.0) * 0.08).normalized()
		projectile.global_position = global_position + Vector2(facing * 42, -44 + float(index) * 12.0)
		projectile.target = opponent
		projectile.projectile_color = body_color
		get_parent().add_child(projectile)

	energy_attack_used.emit(player_id, "barrage")

func take_hit(damage: float, stun_time: float, knockback: Vector2) -> void:
	var final_damage: float = damage
	var final_knockback: Vector2 = knockback

	if is_blocking:
		final_damage *= 0.35
		final_knockback *= 0.35
		stun_time *= 0.45

	final_knockback.x = clamp(final_knockback.x, -MAX_HORIZONTAL_SPEED, MAX_HORIZONTAL_SPEED)
	final_knockback.y = clamp(final_knockback.y, -MAX_VERTICAL_SPEED, MAX_VERTICAL_SPEED)

	is_dashing = false
	is_charging = false
	life = clamp(life - final_damage, 0.0, MAX_LIFE)
	stun_timer = stun_time
	hit_flash_timer = 0.12
	velocity = final_knockback
	life_changed.emit(player_id, life, MAX_LIFE)

func _action(action_name: String) -> String:
	return "p%d_%s" % [player_id, action_name]

func _draw() -> void:
	for index in range(afterimage_positions.size()):
		var old_position: Vector2 = afterimage_positions[index]
		var local_offset: Vector2 = old_position - global_position
		var alpha_value: float = 0.18 - float(index) * 0.025
		_draw_stickman(local_offset, Color(body_color.r, body_color.g, body_color.b, alpha_value), 3.0)

	var draw_color: Color = body_color
	if hit_flash_timer > 0.0:
		draw_color = Color(1.0, 1.0, 1.0, 1.0)

	if is_aura_active:
		draw_circle(Vector2(0, -38), 58.0, Color(draw_color.r, draw_color.g, draw_color.b, 0.14))
		draw_arc(Vector2(0, -38), 62.0, 0.0, TAU, 64, Color(draw_color.r, draw_color.g, draw_color.b, 0.92), 3.5)
		draw_line(Vector2(-28, -98), Vector2(-12, -128), Color(draw_color.r, draw_color.g, draw_color.b, 0.65), 3.0)
		draw_line(Vector2(22, -100), Vector2(8, -134), Color(draw_color.r, draw_color.g, draw_color.b, 0.65), 3.0)
		draw_line(Vector2(-40, -34), Vector2(-60, -68), Color(draw_color.r, draw_color.g, draw_color.b, 0.55), 2.5)
		draw_line(Vector2(42, -28), Vector2(62, -64), Color(draw_color.r, draw_color.g, draw_color.b, 0.55), 2.5)

	if is_blocking:
		draw_circle(Vector2(0, -38), 38.0, Color(0.3, 0.8, 1.0, 0.12))
		draw_arc(Vector2(0, -38), 40.0, -1.4, 1.4, 32, Color(0.45, 0.9, 1.0, 0.85), 3.0)

	if is_charging:
		draw_circle(Vector2(0, -38), 45.0, Color(draw_color.r, draw_color.g, draw_color.b, 0.16))
		draw_arc(Vector2(0, -38), 48.0, 0.0, TAU, 48, Color(draw_color.r, draw_color.g, draw_color.b, 0.85), 2.5)

	if is_dashing:
		draw_line(Vector2(-facing * 60, -42), Vector2(-facing * 18, -42), Color(draw_color.r, draw_color.g, draw_color.b, 0.42), 4.0)
		draw_line(Vector2(-facing * 74, -28), Vector2(-facing * 22, -28), Color(draw_color.r, draw_color.g, draw_color.b, 0.30), 3.0)

	if is_flying:
		draw_line(Vector2(-16, 10), Vector2(-28, 36), Color(0.8, 0.95, 1.0, 0.75), 3.0)
		draw_line(Vector2(16, 10), Vector2(28, 36), Color(0.8, 0.95, 1.0, 0.75), 3.0)

	_draw_stickman(Vector2.ZERO, draw_color, 5.0)

func _draw_stickman(origin: Vector2, draw_color: Color, thickness: float) -> void:
	draw_circle(origin + Vector2(0, -74), 14.0, draw_color)
	draw_line(origin + Vector2(0, -60), origin + Vector2(0, -24), draw_color, thickness)
	draw_line(origin + Vector2(0, -50), origin + Vector2(facing * 23, -38), draw_color, thickness - 1.0)
	draw_line(origin + Vector2(0, -47), origin + Vector2(-facing * 17, -35), draw_color, thickness - 1.0)
	draw_line(origin + Vector2(0, -24), origin + Vector2(facing * 16, 6), draw_color, thickness - 1.0)
	draw_line(origin + Vector2(0, -24), origin + Vector2(-facing * 16, 6), draw_color, thickness - 1.0)
