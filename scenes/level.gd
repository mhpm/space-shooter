extends Node2D

@export var meteor_scene: PackedScene = preload("res://scenes/meteor.tscn")
@export var boss_scene: PackedScene = preload("res://scenes/boss.tscn")
@export var boss_spawn_delay: float = 5.0 # Segundos de meteoros antes de la llegada del Jefe

@onready var player: Node2D = $Player
@onready var health_bar: ProgressBar = $HUD/MarginContainer/HBoxContainer/HealthBar
@onready var health_label: Label = $HUD/MarginContainer/HBoxContainer/HealthLabel
@onready var game_over_panel: Control = $HUD/GameOverPanel
@onready var victory_panel: Control = $HUD/VictoryPanel
@onready var boss_hud: Control = $HUD/BossHUD
@onready var boss_health_bar: ProgressBar = $HUD/BossHUD/BossHealthBar
@onready var boss_warning: Control = $HUD/BossWarning
@onready var spawn_timer: Timer = $SpawnTimer

var is_game_over: bool = false
var is_victory: bool = false
var boss_spawned: bool = false
var current_boss: Area2D = null

func _ready() -> void:
	# Configurar barra de vida del jugador
	if health_bar:
		health_bar.min_value = 0
		health_bar.max_value = 100
		health_bar.value = 100
	
	# Ocultar paneles de fin de partida y HUD de jefe al inicio
	if game_over_panel:
		game_over_panel.visible = false
	if victory_panel:
		victory_panel.visible = false
	if boss_hud:
		boss_hud.visible = false
	if boss_warning:
		boss_warning.visible = false
	
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
	
	# Programar la llegada del Jefe
	_schedule_boss_arrival()

func _unhandled_input(event: InputEvent) -> void:
	if (is_game_over or is_victory) and event is InputEventKey and event.pressed:
		if event.keycode == KEY_R or event.physical_keycode == KEY_R:
			get_tree().reload_current_scene()

func _schedule_boss_arrival() -> void:
	await get_tree().create_timer(boss_spawn_delay).timeout
	if is_game_over or boss_spawned:
		return
	_trigger_boss_sequence()

func _trigger_boss_sequence() -> void:
	boss_spawned = true
	
	# Mostrar anuncio de advertencia parpadeante
	if boss_warning:
		boss_warning.visible = true
		boss_warning.modulate.a = 0.0
		var warn_tween := create_tween()
		for i in 3:
			warn_tween.tween_property(boss_warning, "modulate:a", 1.0, 0.25)
			warn_tween.tween_property(boss_warning, "modulate:a", 0.1, 0.25)
		warn_tween.tween_property(boss_warning, "modulate:a", 0.0, 0.3)
		await warn_tween.finished
		boss_warning.visible = false
	
	if is_game_over:
		return
	
	# Instanciar el Jefe
	if boss_scene:
		current_boss = boss_scene.instantiate()
		current_boss.health_changed.connect(_on_boss_health_changed)
		current_boss.boss_died.connect(_on_boss_died)
		add_child(current_boss)
		
		# Mostrar barra de vida del Jefe en el HUD
		if boss_hud and boss_health_bar:
			boss_health_bar.max_value = current_boss.max_health
			boss_health_bar.value = 0.0
			boss_hud.visible = true
			boss_hud.modulate.a = 0.0
			
			var hud_tween := create_tween()
			hud_tween.set_parallel(true)
			hud_tween.tween_property(boss_hud, "modulate:a", 1.0, 0.8)
			hud_tween.tween_property(boss_health_bar, "value", current_boss.max_health, 1.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _start_next_spawn() -> void:
	if is_game_over or is_victory:
		return
	
	# Reducir frecuencia de meteoros si el jefe está activo
	if is_instance_valid(current_boss) and not current_boss.is_dead:
		spawn_timer.wait_time = randf_range(3.0, 5.0)
	else:
		spawn_timer.wait_time = randf_range(0.7, 1.4)
	
	spawn_timer.start()

func _spawn_meteor() -> void:
	if is_game_over or is_victory or not meteor_scene:
		return
	
	var meteor := meteor_scene.instantiate()
	meteor.position = Vector2(randf_range(60.0, 1220.0), -60.0)
	add_child(meteor)
	
	_start_next_spawn()

func _on_boss_health_changed(current: float, max_h: float) -> void:
	if not boss_health_bar:
		return
	
	boss_health_bar.max_value = max_h
	var tween := create_tween()
	tween.tween_property(boss_health_bar, "value", current, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	# Efecto de cambio de color al estar en fase crítica
	if (current / max_h) <= 0.5:
		boss_health_bar.modulate = Color(1.2, 0.4, 0.2, 1.0) # Rojo anaranjado crítico

func _on_boss_died() -> void:
	is_victory = true
	if spawn_timer:
		spawn_timer.stop()
	
	# Desvanecer HUD del jefe
	if boss_hud:
		var hud_tween := create_tween()
		hud_tween.tween_property(boss_hud, "modulate:a", 0.0, 0.8)
		hud_tween.finished.connect(func(): boss_hud.visible = false)
	
	# Mostrar pantalla de victoria tras la secuencia de explosiones
	if victory_panel:
		await get_tree().create_timer(1.8).timeout
		victory_panel.visible = true
		victory_panel.modulate.a = 0.0
		var win_tween := create_tween()
		win_tween.tween_property(victory_panel, "modulate:a", 1.0, 0.8)

func _on_player_health_changed(current: float, max_h: float) -> void:
	if not health_bar:
		return
	
	health_bar.max_value = max_h
	var tween := create_tween()
	tween.tween_property(health_bar, "value", current, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	var ratio := current / max_h
	if ratio > 0.5:
		health_bar.modulate = Color(0.2, 0.9, 1.0) # Cian
	elif ratio > 0.25:
		health_bar.modulate = Color(1.0, 0.8, 0.2) # Amarillo
	else:
		health_bar.modulate = Color(1.0, 0.25, 0.25) # Rojo

func _on_player_died() -> void:
	is_game_over = true
	if spawn_timer:
		spawn_timer.stop()
	
	if game_over_panel:
		game_over_panel.visible = true
		game_over_panel.modulate.a = 0.0
		var tween := create_tween()
		tween.tween_interval(0.6)
		tween.tween_property(game_over_panel, "modulate:a", 1.0, 0.8)
