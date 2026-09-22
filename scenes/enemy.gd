extends Area2D

enum EnemyType {
	SCOUT,
	SHOOTER,
	HEAVY,
	DREADNOUGHT
}

const ENEMY_TEXTURES := {
	EnemyType.SCOUT: preload("res://graphics/assets_elements/enemies/enemy-1.png"),
	EnemyType.SHOOTER: preload("res://graphics/assets_elements/enemies/enemy-2.png"),
	EnemyType.HEAVY: preload("res://graphics/assets_elements/enemies/enemy-3.png"),
	EnemyType.DREADNOUGHT: preload("res://graphics/assets_elements/enemies/assets_000.png"),
}

@export var enemy_type: EnemyType = EnemyType.SCOUT
@export var speed_y: float = 220.0
@export var max_health: float = 30.0

@export var enemy_laser_scene: PackedScene = preload("res://scenes/enemy_laser.tscn")
@export var explosion_scene: PackedScene = preload("res://scenes/explosion.tscn")
@export var item_scene: PackedScene = preload("res://scenes/item_pickup.tscn")
@export var powerup_scene: PackedScene = preload("res://scenes/power_up.tscn")

var health: float = 30.0
var is_dead: bool = false
var points_value: int = 100
var xp_value: float = 25.0

# Esquiva
var dodge_velocity_x: float = 0.0
var dodge_cooldown: float = 0.0
var _sine_time: float = 0.0
var _drift_freq: float = 2.0
var _drift_amp: float = 60.0

# Disparo
var _shoot_timer: float = 1.2
var _shoot_interval: float = 1.8

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var thruster: Sprite2D = $Thruster

func _ready() -> void:
	add_to_group("enemies")
	area_entered.connect(_on_area_entered)
	_sine_time = randf_range(0.0, TAU)
	_configure_type(enemy_type)
	health = max_health

func setup(type: EnemyType) -> void:
	enemy_type = type
	_configure_type(enemy_type)

func _configure_type(type: EnemyType) -> void:
	if sprite and ENEMY_TEXTURES.has(type):
		sprite.texture = ENEMY_TEXTURES[type]
	
	match type:
		EnemyType.SCOUT:
			max_health = 25.0
			speed_y = randf_range(240.0, 320.0)
			points_value = 100
			xp_value = 25.0
			_drift_amp = 80.0
			_drift_freq = 3.0
			scale = Vector2(0.52, 0.52)
		EnemyType.SHOOTER:
			max_health = 45.0
			speed_y = randf_range(160.0, 220.0)
			points_value = 200
			xp_value = 45.0
			_drift_amp = 45.0
			_drift_freq = 1.8
			_shoot_interval = randf_range(1.5, 2.2)
			_shoot_timer = randf_range(0.6, 1.4)
			scale = Vector2(0.55, 0.55)
		EnemyType.HEAVY:
			max_health = 90.0
			speed_y = randf_range(110.0, 150.0)
			points_value = 400
			xp_value = 80.0
			_drift_amp = 30.0
			_drift_freq = 1.2
			_shoot_interval = randf_range(1.8, 2.6)
			_shoot_timer = randf_range(0.8, 1.5)
			scale = Vector2(0.62, 0.62)
		EnemyType.DREADNOUGHT:
			max_health = 260.0
			speed_y = 80.0
			points_value = 1000
			xp_value = 200.0
			_drift_amp = 50.0
			_drift_freq = 1.0
			_shoot_interval = 1.2
			_shoot_timer = 1.0
			scale = Vector2(0.48, 0.48)

func _process(delta: float) -> void:
	if is_dead:
		return
	
	_sine_time += delta * _drift_freq
	
	# Actualizar esquiva (especialmente activa en Scouts)
	_update_dodge(delta)
	
	# Movimiento compuesto
	var move_x := (sin(_sine_time) * _drift_amp + dodge_velocity_x) * delta
	position.x += move_x
	position.y += speed_y * delta
	
	# Confinar dentro de los bordes laterales del viewport
	var vp_w := get_viewport_rect().size.x
	position.x = clampf(position.x, 45.0, vp_w - 45.0)
	
	# Desaceleración suave de la esquiva
	dodge_velocity_x = move_toward(dodge_velocity_x, 0.0, 800.0 * delta)
	
	# Lógica de disparo para SHOOTER, HEAVY y DREADNOUGHT
	if enemy_type != EnemyType.SCOUT:
		_shoot_timer -= delta
		if _shoot_timer <= 0.0:
			_fire_laser()
			_shoot_timer = _shoot_interval
	
	# Destruir si sale de la pantalla por debajo
	if position.y > 1380:
		queue_free()

func _update_dodge(delta: float) -> void:
	if dodge_cooldown > 0.0:
		dodge_cooldown -= delta
		return
	
	# Los Scouts son expertos en esquivar
	var danger_dist: float = 240.0 if enemy_type == EnemyType.SCOUT else 140.0
	var lasers = get_tree().get_nodes_in_group("lasers")
	
	for laser in lasers:
		if not is_instance_valid(laser):
			continue
		var lpos: Vector2 = laser.global_position
		# Si el láser viene por debajo y está en camino
		var dy: float = lpos.y - global_position.y
		if dy > 0.0 and dy < danger_dist:
			var dx: float = lpos.x - global_position.x
			if absf(dx) < 60.0:
				# Esquivar hacia el lado contrario al láser
				var dir: float = -signf(dx) if absf(dx) > 2.0 else (1.0 if randf() > 0.5 else -1.0)
				# Evitar esquivar hacia la pared
				var vp_w := get_viewport_rect().size.x
				if position.x > vp_w - 100.0:
					dir = -1.0
				elif position.x < 100.0:
					dir = 1.0
				
				dodge_velocity_x = dir * (420.0 if enemy_type == EnemyType.SCOUT else 260.0)
				dodge_cooldown = 0.8 if enemy_type == EnemyType.SCOUT else 1.5
				
				# Inclinación visual del enemigo
				var tw = create_tween()
				tw.tween_property(sprite, "rotation", deg_to_rad(15.0 * dir), 0.1)
				tw.tween_property(sprite, "rotation", 0.0, 0.25)
				break

func _fire_laser() -> void:
	if not enemy_laser_scene or is_dead:
		return
	
	if enemy_type == EnemyType.HEAVY:
		# Disparo doble
		for offset_x in [-22.0, 22.0]:
			var l = enemy_laser_scene.instantiate()
			l.global_position = global_position + Vector2(offset_x, 35.0)
			get_parent().add_child(l)
	elif enemy_type == EnemyType.DREADNOUGHT:
		# Disparo triple en abanico
		for ang in [-0.25, 0.0, 0.25]:
			var l = enemy_laser_scene.instantiate()
			l.global_position = global_position + Vector2(0, 45.0)
			l.direction = Vector2(sin(ang), cos(ang))
			get_parent().add_child(l)
	else:
		# Disparo simple hacia abajo
		var l = enemy_laser_scene.instantiate()
		l.global_position = global_position + Vector2(0, 30.0)
		get_parent().add_child(l)

func _on_area_entered(area: Area2D) -> void:
	if is_dead:
		return
	
	if area.is_in_group("lasers"):
		var dmg: float = 25.0
		if "damage" in area:
			dmg = area.damage
		if area.has_method("hit"):
			area.hit()
		else:
			area.queue_free()
		
		take_damage(dmg)
	
	elif area.is_in_group("player"):
		var p = area.get_parent()
		if p and p.has_method("take_damage"):
			p.take_damage(20.0)
		take_damage(health)

func take_damage(amount: float) -> void:
	if is_dead:
		return
	
	health -= amount
	# Destello blanco al ser golpeado
	var tw = create_tween()
	tw.tween_property(sprite, "modulate", Color(2.5, 2.0, 2.0, 1.0), 0.06)
	tw.tween_property(sprite, "modulate", Color.WHITE, 0.06)
	
	if health <= 0:
		die()

func die() -> void:
	if is_dead:
		return
	is_dead = true
	
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	if collision:
		collision.set_deferred("disabled", true)
	
	# Premiar al jugador con puntos y experiencia
	var players = get_tree().get_nodes_in_group("player_ship")
	if not players.is_empty():
		var p = players[0]
		if p.has_method("add_score"):
			p.add_score(points_value)
		if p.has_method("add_xp"):
			p.add_xp(xp_value)
	
	# Crear explosión
	if explosion_scene:
		var exp_node = explosion_scene.instantiate()
		exp_node.global_position = global_position
		exp_node.target_scale = Vector2(1.2, 1.2) if enemy_type != EnemyType.DREADNOUGHT else Vector2(2.2, 2.2)
		if get_parent():
			get_parent().add_child(exp_node)
		else:
			get_tree().current_scene.add_child(exp_node)
	
	# Soltar botín (ítems / gemas y posibles power-ups)
	_drop_loot()
	queue_free()

func _drop_loot() -> void:
	var parent_node = get_parent() if get_parent() else get_tree().current_scene
	if not parent_node:
		return
	
	# Cantidad de ítems según el enemigo
	var item_count: int = 1
	if enemy_type == EnemyType.HEAVY:
		item_count = 2
	elif enemy_type == EnemyType.DREADNOUGHT:
		item_count = 4
	
	if item_scene:
		for i in item_count:
			var item = item_scene.instantiate()
			item.global_position = global_position + Vector2(randf_range(-30, 30), randf_range(-20, 20))
			if item.has_method("setup_random"):
				item.setup_random()
			parent_node.call_deferred("add_child", item)
	
	# Probabilidad de soltar Power-Up
	var powerup_chance: float = 0.20
	if enemy_type == EnemyType.HEAVY:
		powerup_chance = 0.60
	elif enemy_type == EnemyType.DREADNOUGHT:
		powerup_chance = 1.0 # Garantizado en Dreadnought
	
	if powerup_scene and randf() < powerup_chance:
		var pu = powerup_scene.instantiate()
		pu.global_position = global_position
		if pu.has_method("setup_random"):
			pu.setup_random()
		parent_node.call_deferred("add_child", pu)
