extends Node2D

@export var meteor_scene: PackedScene = preload("res://scenes/meteor.tscn")

@onready var player: Node2D = $Player
@onready var health_bar: ProgressBar = $HUD/MarginContainer/HBoxContainer/HealthBar
@onready var health_label: Label = $HUD/MarginContainer/HBoxContainer/HealthLabel
@onready var game_over_panel: Control = $HUD/GameOverPanel
@onready var spawn_timer: Timer = $SpawnTimer

var is_game_over: bool = false

func _ready() -> void:
	# Configurar barra de vida
	if health_bar:
		health_bar.min_value = 0
		health_bar.max_value = 100
		health_bar.value = 100
	
	# Conectar señales del jugador
	if player:
		if player.has_signal("health_changed"):
			player.health_changed.connect(_on_player_health_changed)
			_on_player_health_changed(player.health, player.max_health)
		if player.has_signal("player_died"):
			player.player_died.connect(_on_player_died)
	
	# Iniciar temporizador de meteoros
	if spawn_timer:
		spawn_timer.timeout.connect(_spawn_meteor)
		_start_next_spawn()

func _unhandled_input(event: InputEvent) -> void:
	if is_game_over and event is InputEventKey and event.pressed:
		if event.keycode == KEY_R or event.physical_keycode == KEY_R:
			get_tree().reload_current_scene()

func _start_next_spawn() -> void:
	if is_game_over:
		return
	spawn_timer.wait_time = randf_range(0.7, 1.4)
	spawn_timer.start()

func _spawn_meteor() -> void:
	if is_game_over or not meteor_scene:
		return
	
	var meteor := meteor_scene.instantiate()
	# Posición aleatoria arriba de la pantalla (resolución 1280x720)
	meteor.position = Vector2(randf_range(60.0, 1220.0), -60.0)
	add_child(meteor)
	
	_start_next_spawn()

func _on_player_health_changed(current: float, max_h: float) -> void:
	if not health_bar:
		return
	
	health_bar.max_value = max_h
	# Animación suave de reducción de barra
	var tween := create_tween()
	tween.tween_property(health_bar, "value", current, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	# Cambiar color según la salud restante
	var ratio := current / max_h
	if ratio > 0.5:
		health_bar.modulate = Color(0.2, 0.9, 1.0) # Cian / Escudo lleno
	elif ratio > 0.25:
		health_bar.modulate = Color(1.0, 0.8, 0.2) # Amarillo / Advertencia
	else:
		health_bar.modulate = Color(1.0, 0.25, 0.25) # Rojo / Peligro crítico

func _on_player_died() -> void:
	is_game_over = true
	if spawn_timer:
		spawn_timer.stop()
	
	# Mostrar panel de Game Over tras un instante
	if game_over_panel:
		game_over_panel.visible = true
		game_over_panel.modulate.a = 0.0
		var tween := create_tween()
		tween.tween_interval(0.6) # Esperar a que la explosión se desarrolle
		tween.tween_property(game_over_panel, "modulate:a", 1.0, 0.8)
