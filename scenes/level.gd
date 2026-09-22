extends Node2D

@export var meteor_scene: PackedScene = preload("res://scenes/meteor.tscn")
@export var enemy_scene: PackedScene = preload("res://scenes/enemy.tscn")
@export var boss_scene: PackedScene = preload("res://scenes/boss.tscn")
@export var boss_spawn_delay: float = 24.0 # Segundos de oleadas antes del Jefe Titán

@onready var bg: Sprite2D = $BG
@onready var player: Node2D = $Player
@onready var touch_controls: CanvasLayer = get_node_or_null("TouchControls")
@onready var spawn_timer: Timer = $SpawnTimer

# HUD Elements
@onready var health_bar: ProgressBar = $HUD/MarginContainer/VBoxContainer/TopRow/HealthBar
@onready var health_label: Label = $HUD/MarginContainer/VBoxContainer/TopRow/HealthLabel
@onready var shield_badge: Label = $HUD/MarginContainer/VBoxContainer/TopRow/ShieldBadge
@onready var pause_button: Button = $HUD/MarginContainer/VBoxContainer/TopRow/PauseButton

@onready var level_badge: Label = $HUD/MarginContainer/VBoxContainer/SecondRow/LevelBadge
@onready var xp_bar: ProgressBar = $HUD/MarginContainer/VBoxContainer/SecondRow/XPBar
@onready var score_label: Label = $HUD/MarginContainer/VBoxContainer/SecondRow/ScoreLabel
@onready var notification_banner: Label = $HUD/NotificationBanner

@onready var boss_hud: Control = $HUD/BossHUD
@onready var boss_health_bar: ProgressBar = $HUD/BossHUD/BossHealthBar
@onready var boss_warning: Control = $HUD/BossWarning

@onready var game_over_panel: Control = $HUD/GameOverPanel
@onready var game_over_restart_btn: Button = $HUD/GameOverPanel/VBoxContainer/RestartButton
@onready var final_score_label: Label = $HUD/GameOverPanel/VBoxContainer/FinalScoreLabel

@onready var victory_panel: Control = $HUD/VictoryPanel
@onready var victory_restart_btn: Button = $HUD/VictoryPanel/VBoxContainer/RestartButton
@onready var victory_score_label: Label = $HUD/VictoryPanel/VBoxContainer/VictoryScoreLabel

@onready var pause_menu: Control = $HUD/PauseMenu
@onready var pause_resume_btn: Button = $HUD/PauseMenu/CenterContainer/VBoxContainer/ResumeButton
@onready var pause_restart_btn: Button = $HUD/PauseMenu/CenterContainer/VBoxContainer/RestartButton

# Botones de naves en pausa
@onready var ship_purple_btn: Button = $HUD/PauseMenu/CenterContainer/VBoxContainer/ShipButtons/ShipPurpleBtn
@onready var ship_blue_btn: Button = $HUD/PauseMenu/CenterContainer/VBoxContainer/ShipButtons/ShipBlueBtn
@onready var ship_red_btn: Button = $HUD/PauseMenu/CenterContainer/VBoxContainer/ShipButtons/ShipRedBtn
@onready var ship_red2_btn: Button = $HUD/PauseMenu/CenterContainer/VBoxContainer/ShipButtons/ShipRed2Btn

var is_game_over: bool = false
var is_victory: bool = false
var boss_spawned: bool = false
var current_boss: Area2D = null
var _notification_tween: Tween = null
var _current_score: int = 0

func _ready() -> void:
	# Forzar orientación vertical (Portrait) estricta en móviles
	DisplayServer.screen_set_orientation(DisplayServer.SCREEN_PORTRAIT)
	
	process_mode = Node.PROCESS_MODE_ALWAYS
	_adjust_background()
	get_viewport().size_changed.connect(_adjust_background)
	
	# Configurar paneles iniciales
	if game_over_panel:
		game_over_panel.visible = false
	if victory_panel:
		victory_panel.visible = false
	if boss_hud:
		boss_hud.visible = false
	if boss_warning:
		boss_warning.visible = false
	if pause_menu:
		pause_menu.visible = false
	if notification_banner:
		notification_banner.visible = false
	if shield_badge:
		shield_badge.visible = false
	
	# Conectar botones de reinicio y pausa
	if game_over_restart_btn:
		game_over_restart_btn.pressed.connect(_restart_game)
	if victory_restart_btn:
		victory_restart_btn.pressed.connect(_restart_game)
	if pause_button:
		pause_button.pressed.connect(_on_pause_pressed)
	if pause_resume_btn:
		pause_resume_btn.pressed.connect(_on_resume_pressed)
	if pause_restart_btn:
		pause_restart_btn.pressed.connect(_restart_game)
	
	# Conectar selector de naves
	if ship_purple_btn:
		ship_purple_btn.pressed.connect(func(): _select_ship("purple"))
	if ship_blue_btn:
		ship_blue_btn.pressed.connect(func(): _select_ship("blue"))
	if ship_red_btn:
		ship_red_btn.pressed.connect(func(): _select_ship("red"))
	if ship_red2_btn:
		ship_red2_btn.pressed.connect(func(): _select_ship("red2"))
	
	# Conectar controles táctiles
	if touch_controls and player and player.has_method("set_autofire"):
		touch_controls.autofire_toggled.connect(player.set_autofire)
	
	# Conectar señales del jugador
	if player:
		if player.has_signal("health_changed"):
			player.health_changed.connect(_on_player_health_changed)
			_on_player_health_changed(player.health, player.max_health)
		if player.has_signal("player_died"):
			player.player_died.connect(_on_player_died)
		if player.has_signal("xp_changed"):
			player.xp_changed.connect(_on_player_xp_changed)
		if player.has_signal("score_changed"):
			player.score_changed.connect(_on_player_score_changed)
		if player.has_signal("shield_changed"):
			player.shield_changed.connect(_on_player_shield_changed)
		if player.has_signal("notification_triggered"):
			player.notification_triggered.connect(_show_notification)
	
	# Iniciar temporizador de generación de oleadas
	if spawn_timer:
		spawn_timer.timeout.connect(_on_spawn_timer_timeout)
		_start_next_spawn()
	
	_schedule_boss_arrival()

func _select_ship(type_name: String) -> void:
	if player and player.has_method("set_ship_type"):
		player.set_ship_type(type_name)

func _adjust_background() -> void:
	if not bg or not bg.texture:
		return
	var vp_size := get_viewport_rect().size
	bg.position = vp_size / 2.0
	var tex_size := bg.texture.get_size()
	var s := maxf(vp_size.x / tex_size.x, vp_size.y / tex_size.y)
	bg.scale = Vector2(s, s)

func _unhandled_input(event: InputEvent) -> void:
	if is_game_over or is_victory:
		if event is InputEventKey and event.pressed:
			if event.keycode == KEY_R or event.physical_keycode == KEY_R:
				_restart_game()
		elif (event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.pressed):
			_restart_game()
	elif event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and (event.keycode == KEY_P or event.physical_keycode == KEY_P or event.keycode == KEY_ESCAPE or event.physical_keycode == KEY_ESCAPE)):
			if get_tree().paused:
				_on_resume_pressed()
			else:
				_on_pause_pressed()

func _on_pause_pressed() -> void:
	get_tree().paused = true
	if touch_controls:
		touch_controls.visible = false
	if pause_menu:
		pause_menu.visible = true

func _on_resume_pressed() -> void:
	get_tree().paused = false
	if touch_controls:
		touch_controls.visible = true
	if pause_menu:
		pause_menu.visible = false

func _restart_game() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func _schedule_boss_arrival() -> void:
	await get_tree().create_timer(boss_spawn_delay).timeout
	if is_game_over or boss_spawned:
		return
	_trigger_boss_sequence()

func _trigger_boss_sequence() -> void:
	boss_spawned = true
	
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
	
	if boss_scene:
		current_boss = boss_scene.instantiate()
		current_boss.health_changed.connect(_on_boss_health_changed)
		current_boss.boss_died.connect(_on_boss_died)
		add_child(current_boss)
		
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
	
	if is_instance_valid(current_boss) and not current_boss.is_dead:
		spawn_timer.wait_time = randf_range(2.8, 4.5)
	else:
		spawn_timer.wait_time = randf_range(0.75, 1.4)
	
	spawn_timer.start()

func _on_spawn_timer_timeout() -> void:
	if is_game_over or is_victory:
		return
	
	var vp_w := get_viewport_rect().size.x
	var r := randf()
	
	# Generación variada: 45% meteoros, 55% enemigos de diversas clases
	if r < 0.45 and meteor_scene:
		var meteor = meteor_scene.instantiate()
		meteor.position = Vector2(randf_range(45.0, vp_w - 45.0), -60.0)
		add_child(meteor)
	elif enemy_scene:
		var enemy = enemy_scene.instantiate()
		enemy.position = Vector2(randf_range(50.0, vp_w - 50.0), -60.0)
		
		# Determinar tipo de enemigo según probabilidad
		var sub_r := randf()
		if sub_r < 0.40:
			enemy.setup(0) # SCOUT (Esquivador)
		elif sub_r < 0.72:
			enemy.setup(1) # SHOOTER (Tirador)
		elif sub_r < 0.92:
			enemy.setup(2) # HEAVY (Acorazado)
		else:
			enemy.setup(3) # DREADNOUGHT (Élite)
		
		add_child(enemy)
	
	_start_next_spawn()

func _on_player_xp_changed(current_xp: float, max_xp: float, current_level: int) -> void:
	if xp_bar:
		xp_bar.max_value = max_xp
		var tw = create_tween()
		tw.tween_property(xp_bar, "value", current_xp, 0.2).set_trans(Tween.TRANS_QUAD)
	if level_badge:
		level_badge.text = "NVL %d" % current_level

func _on_player_score_changed(new_score: int) -> void:
	_current_score = new_score
	if score_label:
		score_label.text = "PUNTOS: %d" % new_score

func _on_player_shield_changed(active: bool) -> void:
	if shield_badge:
		shield_badge.visible = active

func _show_notification(text: String, color: Color) -> void:
	if not notification_banner:
		return
	
	if _notification_tween and _notification_tween.is_valid():
		_notification_tween.kill()
	
	notification_banner.text = text
	notification_banner.modulate = color
	notification_banner.visible = true
	notification_banner.scale = Vector2(0.8, 0.8)
	notification_banner.pivot_offset = notification_banner.size / 2.0
	
	_notification_tween = create_tween()
	_notification_tween.set_parallel(true)
	_notification_tween.tween_property(notification_banner, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK)
	_notification_tween.tween_property(notification_banner, "modulate:a", 1.0, 0.15)
	
	_notification_tween.chain().tween_interval(1.4)
	_notification_tween.chain().tween_property(notification_banner, "modulate:a", 0.0, 0.4)
	_notification_tween.finished.connect(func(): notification_banner.visible = false)

func _on_boss_health_changed(current: float, max_h: float) -> void:
	if not boss_health_bar:
		return
	boss_health_bar.max_value = max_h
	var tween := create_tween()
	tween.tween_property(boss_health_bar, "value", current, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if (current / max_h) <= 0.5:
		boss_health_bar.modulate = Color(1.2, 0.4, 0.2, 1.0)

func _on_boss_died() -> void:
	is_victory = true
	if touch_controls:
		touch_controls.visible = false
	if spawn_timer:
		spawn_timer.stop()
	
	if boss_hud:
		var hud_tween := create_tween()
		hud_tween.tween_property(boss_hud, "modulate:a", 0.0, 0.8)
		hud_tween.finished.connect(func(): boss_hud.visible = false)
	
	if victory_panel:
		if victory_score_label:
			victory_score_label.text = "PUNTUACIÓN FINAL: %d" % _current_score
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
		health_bar.modulate = Color(0.2, 0.9, 1.0)
	elif ratio > 0.25:
		health_bar.modulate = Color(1.0, 0.8, 0.2)
	else:
		health_bar.modulate = Color(1.0, 0.25, 0.25)

func _on_player_died() -> void:
	is_game_over = true
	if touch_controls:
		touch_controls.visible = false
	if spawn_timer:
		spawn_timer.stop()
	
	if game_over_panel:
		if final_score_label:
			final_score_label.text = "PUNTUACIÓN FINAL: %d" % _current_score
		game_over_panel.visible = true
		game_over_panel.modulate.a = 0.0
		var tween := create_tween()
		tween.tween_interval(0.6)
		tween.tween_property(game_over_panel, "modulate:a", 1.0, 0.8)
