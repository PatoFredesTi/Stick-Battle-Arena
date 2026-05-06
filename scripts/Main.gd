extends Node2D

@onready var player := $Player
@onready var energy_bar := $CanvasLayer/HUD/EnergyBar
@onready var life_bar := $CanvasLayer/HUD/LifeBar
@onready var state_label := $CanvasLayer/HUD/StateLabel

func _ready() -> void:
	player.energy_changed.connect(_on_energy_changed)
	player.life_changed.connect(_on_life_changed)
	player.flight_changed.connect(_on_flight_changed)
	_on_energy_changed(player.energy, player.MAX_ENERGY)
	_on_life_changed(player.life, 100.0)
	_on_flight_changed(player.is_flying)

func _on_energy_changed(current: float, maximum: float) -> void:
	energy_bar.set_value(current, maximum)

func _on_life_changed(current: float, maximum: float) -> void:
	life_bar.set_value(current, maximum)

func _on_flight_changed(is_flying: bool) -> void:
	state_label.text = "ESTADO: VOLANDO" if is_flying else "ESTADO: TIERRA"
