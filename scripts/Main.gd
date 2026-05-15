extends Node2D

const PlayerScript: Script = preload("res://scripts/Player.gd")
const EnergyBarScript: Script = preload("res://scripts/EnergyBar.gd")

var player_1: CharacterBody2D
var player_2: CharacterBody2D
var camera: Camera2D
var p1_life_bar: Control
var p1_energy_bar: Control
var p2_life_bar: Control
var p2_energy_bar: Control
var info_label: Label
var shake_timer: float = 0.0
var shake_power: float = 0.0

func _ready() -> void:
	_create_world()
	_create_players()
	_create_camera()
	_create_hud()
	_connect_players()
	_update_all_bars()

func _create_world() -> void:
	var background: ColorRect = ColorRect.new()
	background.color = Color(0.08, 0.09, 0.13, 1.0)
	background.size = Vector2(4000, 2200)
	background.position = Vector2(-2000, -1300)
	add_child(background)

	var ground: ColorRect = ColorRect.new()
	ground.color = Color(0.22, 0.22, 0.26, 1.0)
	ground.size = Vector2(4000, 24)
	ground.position = Vector2(-2000, 180)
	add_child(ground)

	var line: ColorRect = ColorRect.new()
	line.color = Color(0.48, 0.48, 0.56, 1.0)
	line.size = Vector2(4000, 4)
	line.position = Vector2(-2000, 176)
	add_child(line)

func _create_players() -> void:
	player_1 = CharacterBody2D.new()
	player_1.name = "Player1"
	player_1.set_script(PlayerScript)
	player_1.player_id = 1
	player_1.body_color = Color(0.35, 0.78, 1.0, 1.0)
	player_1.global_position = Vector2(-220, 80)
	add_child(player_1)

	player_2 = CharacterBody2D.new()
	player_2.name = "Player2"
	player_2.set_script(PlayerScript)
	player_2.player_id = 2
	player_2.body_color = Color(1.0, 0.42, 0.42, 1.0)
	player_2.global_position = Vector2(220, 80)
	add_child(player_2)

	player_1.opponent = player_2
	player_2.opponent = player_1

func _create_camera() -> void:
	camera = Camera2D.new()
	camera.name = "DynamicCamera"
	camera.enabled = true
	camera.zoom = Vector2(0.95, 0.95)
	add_child(camera)

func _create_hud() -> void:
	var canvas: CanvasLayer = CanvasLayer.new()
	canvas.name = "HUD"
	add_child(canvas)

	p1_life_bar = EnergyBarScript.new()
	p1_life_bar.position = Vector2(24, 24)
	p1_life_bar.bar_name = "P1 LIFE"
	p1_life_bar.fill_color = Color(0.2, 0.95, 0.35, 1.0)
	canvas.add_child(p1_life_bar)

	p1_energy_bar = EnergyBarScript.new()
	p1_energy_bar.position = Vector2(24, 52)
	p1_energy_bar.bar_name = "P1 ENERGY"
	p1_energy_bar.fill_color = Color(0.2, 0.65, 1.0, 1.0)
	canvas.add_child(p1_energy_bar)

	p2_life_bar = EnergyBarScript.new()
	p2_life_bar.position = Vector2(1030, 24)
	p2_life_bar.bar_name = "P2 LIFE"
	p2_life_bar.fill_color = Color(0.2, 0.95, 0.35, 1.0)
	canvas.add_child(p2_life_bar)

	p2_energy_bar = EnergyBarScript.new()
	p2_energy_bar.position = Vector2(1030, 52)
	p2_energy_bar.bar_name = "P2 ENERGY"
	p2_energy_bar.fill_color = Color(1.0, 0.78, 0.18, 1.0)
	canvas.add_child(p2_energy_bar)

	info_label = Label.new()
	info_label.position = Vector2(24, 625)
	info_label.text = "v0.5 Fixed | Aura Boost + knockback control | Fix: no more infinite slide after hits/projectiles"
	info_label.add_theme_font_size_override("font_size", 16)
	canvas.add_child(info_label)

func _connect_players() -> void:
	player_1.energy_changed.connect(_on_energy_changed)
	player_1.life_changed.connect(_on_life_changed)
	player_1.attack_landed.connect(_on_attack_landed)
	player_1.energy_attack_used.connect(_on_energy_attack_used)
	player_1.dash_started.connect(_on_dash_started)

	player_2.energy_changed.connect(_on_energy_changed)
	player_2.life_changed.connect(_on_life_changed)
	player_2.attack_landed.connect(_on_attack_landed)
	player_2.energy_attack_used.connect(_on_energy_attack_used)
	player_2.dash_started.connect(_on_dash_started)

func _process(delta: float) -> void:
	var center: Vector2 = (player_1.global_position + player_2.global_position) * 0.5 + Vector2(0, -60)
	camera.global_position = camera.global_position.lerp(center, 0.08)

	var distance: float = player_1.global_position.distance_to(player_2.global_position)
	var zoom_value: float = clamp(1.18 - distance / 1500.0, 0.70, 1.05)
	camera.zoom = camera.zoom.lerp(Vector2(zoom_value, zoom_value), 0.05)

	if shake_timer > 0.0:
		shake_timer -= delta
		var offset: Vector2 = Vector2(randf_range(-shake_power, shake_power), randf_range(-shake_power, shake_power))
		camera.offset = offset
	else:
		camera.offset = Vector2.ZERO

func _on_energy_changed(player_id: int, current: float, maximum: float) -> void:
	if player_id == 1:
		p1_energy_bar.set_value(current, maximum)
	else:
		p2_energy_bar.set_value(current, maximum)

func _on_life_changed(player_id: int, current: float, maximum: float) -> void:
	if player_id == 1:
		p1_life_bar.set_value(current, maximum)
	else:
		p2_life_bar.set_value(current, maximum)

func _on_attack_landed(_player_id: int) -> void:
	_start_shake(0.12, 5.0)

func _on_energy_attack_used(_player_id: int, projectile_type: String) -> void:
	if projectile_type == "homing":
		_start_shake(0.10, 3.0)

func _on_dash_started(_player_id: int) -> void:
	_start_shake(0.05, 1.4)

func _start_shake(duration: float, power: float) -> void:
	shake_timer = duration
	shake_power = power

func _update_all_bars() -> void:
	p1_life_bar.set_value(player_1.life, player_1.MAX_LIFE)
	p1_energy_bar.set_value(player_1.energy, player_1.MAX_ENERGY)
	p2_life_bar.set_value(player_2.life, player_2.MAX_LIFE)
	p2_energy_bar.set_value(player_2.energy, player_2.MAX_ENERGY)
