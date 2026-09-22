extends Area2D

signal health_changed(current_health: float, max_health: float)
signal boss_died
signal phase_changed(phase: int)

@export var max_health: float = 1200.0
@export var base_speed: float = 180.0
@export var dodge_speed: float = 380.0
@export var laser_scene: PackedScene = preload("res://scenes/boss_laser.tscn")
@export var missile_scene: PackedScene = preload("res://scenes/boss_missile.tscn")
@export var explosion_scene: PackedScene = preload("res://scenes/boss_explosion.tscn")

const TEXTURE_PHASE_1 := preload("res://graphics/boos_elements/boos_001.png")
const TEXTURE_PHASE_2 := preload("res://graphics/boos_elements/boos_002.png")

var health: float = 1200.0
var phase: int = 1
var is_active: bool = false
var is_dead: bool = false

# Movimiento y patrullaje
var patrol_direction: float = 1.0
var target_y: float = 195.0
var move_time: float = 0.0

# Sistema de esquiva (Dodge)
var dodge_velocity_x: float = 0.0
var dodge_cooldown_timer: float = 0.0

# Temporizadores de ataque
var laser_attack_timer: float = 1.5
var missile_attack_timer: float = 3.5

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionPolygon2D = $CollisionPolygon2D
@onready var cannon_left: Marker2D = $CannonLeft
@onready var cannon_right: Marker2D = $CannonRight
@onready var cannon_center: Marker2D = $CannonCenter
@onready var missile_left: Marker2D = $MissileLeft
@onready var missile_right: Marker2D = $MissileRight

func _ready() -> void:
	add_to_group("boss")
	health = max_health
	area_entered.connect(_on_area_entered)
	
	# Iniciar fuera de pantalla y entrar con animación fluida
	position = Vector2(640, -220)
	var intro_tween = create_tween()
	intro_tween.tween_property(self, "position:y", target_y, 2.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	intro_tween.finished.connect(_on_intro_finished)

func _on_intro_finished() -> void:
	is_active = true
	emit_signal("health_changed", health, max_health)

func _process(delta: float) -> void:
	if is_dead or not is_active:
		return
	
	move_time += delta
	_update_movement(delta)
	_update_dodge(delta)
	_update_attacks(delta)

func _update_movement(delta: float) -> void:
	var current_speed = base_speed * (1.35 if phase == 2 else 1.0)
	
	# Movimiento horizontal de patrullaje
	position.x += (patrol_direction * current_speed + dodge_velocity_x) * delta
	
	# Oscilación vertical flotante
	position.y = target_y + sin(move_time * 2.2) * 18.0
	
	# Rebotar en los márgenes de pantalla (resolución 1280x720)
	if position.x > 1060.0:
		position.x = 1060.0
		patrol_direction = -1.0
	elif position.x < 220.0:
		position.x = 220.0
		patrol_direction = 1.0
	
	# Desaceleración de la esquiva
	dodge_velocity_x = move_toward(dodge_velocity_x, 0.0, 900.0 * delta)

func _update_dodge(delta: float) -> void:
	if dodge_cooldown_timer > 0.0:
		dodge_cooldown_timer -= delta
		return
	
	# Buscar láseres del jugador que se aproximen en línea recta hacia el jefe
	var lasers = get_tree().get_nodes_in_group("lasers")
	for laser in lasers:
		if not is_instance_valid(laser):
			continue
		
		var lpos = laser.global_position
		# Láser por debajo del jefe y dentro de un rango de peligro (entre 120px y 380px)
		var dy = lpos.y - global_position.y
		if dy > 100.0 and dy < 380.0:
			var dx = lpos.x - global_position.x
			# Si el láser impactará el ancho de la nave (|dx| < 75)
			if abs(dx) < 75.0:
				_perform_dodge(dx)
				break

func _perform_dodge(laser_offset_x: float) -> void:
	# Esquivar en la dirección opuesta al láser o hacia el centro de la pantalla
	var dir := 1.0
	if abs(laser_offset_x) > 5.0:
		dir = -sign(laser_offset_x)
	else:
		# Si está perfectamente centrado, esquivar hacia el centro de la pantalla
		dir = 1.0 if position.x < 640.0 else -1.0
	
	# Evitar esquivar hacia la pared si ya estamos cerca del borde
	if position.x > 980.0:
		dir = -1.0
	elif position.x < 300.0:
		dir = 1.0
	
	dodge_velocity_x = dir * dodge_speed * (1.2 if phase == 2 else 1.0)
	dodge_cooldown_timer = 0.7 if phase == 2 else 1.1
	
	# Inclinación visual momentánea durante la esquiva
	var tilt_tween = create_tween()
	var tilt_angle = deg_to_rad(12.0 * dir)
	tilt_tween.tween_property(sprite, "rotation", deg_to_rad(180.0) + tilt_angle, 0.12)
	tilt_tween.tween_property(sprite, "rotation", deg_to_rad(180.0), 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _update_attacks(delta: float) -> void:
	laser_attack_timer -= delta
	missile_attack_timer -= delta
	
	# Ráfaga de láseres
	var laser_interval = 0.9 if phase == 2 else 1.5
	if laser_attack_timer <= 0.0:
		_fire_lasers()
		laser_attack_timer = laser_interval
	
	# Salva de misiles
	var missile_interval = 3.2 if phase == 2 else 4.5
	if missile_attack_timer <= 0.0:
		_fire_missiles()
		missile_attack_timer = missile_interval

func _fire_lasers() -> void:
	if not laser_scene:
		return
	
	if phase == 1:
		# Disparo alterno o doble cañón
		_spawn_laser(cannon_left.global_position, Vector2.DOWN)
		_spawn_laser(cannon_right.global_position, Vector2.DOWN)
	else:
		# Fase 2: Disparo triple en abanico con cañón central apuntando al jugador
		_spawn_laser(cannon_left.global_position, Vector2(-0.25, 1.0).normalized())
		_spawn_laser(cannon_right.global_position, Vector2(0.25, 1.0).normalized())
		
		# Cañón central apunta a la nave del jugador
		var player_dir = Vector2.DOWN
		var players = get_tree().get_nodes_in_group("player")
		if not players.is_empty() and is_instance_valid(players[0]):
			player_dir = (players[0].global_position - cannon_center.global_position).normalized()
		_spawn_laser(cannon_center.global_position, player_dir)

func _spawn_laser(spawn_pos: Vector2, dir: Vector2) -> void:
	var l = laser_scene.instantiate()
	l.global_position = spawn_pos
	l.direction = dir
	if get_parent():
		get_parent().add_child(l)
	else:
		get_tree().current_scene.add_child(l)

func _fire_missiles() -> void:
	if not missile_scene:
		return
	
	_spawn_missile(missile_left.global_position, Vector2(-0.5, 0.8).normalized())
	_spawn_missile(missile_right.global_position, Vector2(0.5, 0.8).normalized())

func _spawn_missile(spawn_pos: Vector2, initial_dir: Vector2) -> void:
	var m = missile_scene.instantiate()
	m.global_position = spawn_pos
	m.direction = initial_dir
	if get_parent():
		get_parent().add_child(m)
	else:
		get_tree().current_scene.add_child(m)

func _on_area_entered(area: Area2D) -> void:
	if is_dead or not is_active:
		return
	
	# Si un láser del jugador impacta al jefe
	if area.is_in_group("lasers"):
		var dmg: float = 25.0
		if "damage" in area:
			dmg = area.damage
		
		if area.has_method("hit"):
			area.hit()
		else:
			area.queue_free()
		
		take_damage(dmg)

func take_damage(amount: float) -> void:
	if is_dead or not is_active:
		return
	
	health = max(0.0, health - amount)
	emit_signal("health_changed", health, max_health)
	
	_flash_hit()
	
	# Verificar transición a Fase 2 (al 50% de vida)
	if phase == 1 and health <= (max_health * 0.5):
		_enter_phase_2()
	
	if health <= 0.0:
		die()

func _flash_hit() -> void:
	var tw = create_tween()
	tw.tween_property(sprite, "modulate", Color(2.5, 0.5, 0.5, 1.0), 0.05)
	var normal_color = Color(1.15, 0.85, 0.85, 1.0) if phase == 2 else Color.WHITE
	tw.tween_property(sprite, "modulate", normal_color, 0.05)

func _enter_phase_2() -> void:
	phase = 2
	emit_signal("phase_changed", 2)
	
	# Cambiar textura a nave dañada / modo agresivo
	if sprite:
		sprite.texture = TEXTURE_PHASE_2
		sprite.modulate = Color(1.15, 0.85, 0.85, 1.0)
	
	# Efecto visual de explosiones menores de cambio de fase
	for i in 4:
		var exp_node = explosion_scene.instantiate()
		exp_node.global_position = global_position + Vector2(randf_range(-80, 80), randf_range(-50, 50))
		exp_node.target_scale = Vector2(0.8, 0.8)
		get_tree().current_scene.add_child(exp_node)

func die() -> void:
	if is_dead:
		return
	is_dead = true
	is_active = false
	emit_signal("boss_died")
	
	# Desactivar colisiones
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	if collision_shape:
		collision_shape.set_deferred("disabled", true)
	
	# Secuencia de destrucción épica: explosiones múltiples
	for i in 9:
		await get_tree().create_timer(0.18).timeout
		if not is_instance_valid(self):
			return
		if explosion_scene:
			var exp_node = explosion_scene.instantiate()
			exp_node.global_position = global_position + Vector2(randf_range(-100, 100), randf_range(-60, 60))
			exp_node.target_scale = Vector2(randf_range(1.2, 1.8), randf_range(1.2, 1.8))
			if get_parent():
				get_parent().add_child(exp_node)
			else:
				get_tree().current_scene.add_child(exp_node)
	
	# Gran explosión final
	if explosion_scene:
		var final_exp = explosion_scene.instantiate()
		final_exp.global_position = global_position
		final_exp.target_scale = Vector2(3.0, 3.0)
		if get_parent():
			get_parent().add_child(final_exp)
		else:
			get_tree().current_scene.add_child(final_exp)
	
	# Desvanecer y liberar
	var fade_tw = create_tween()
	fade_tw.tween_property(sprite, "modulate:a", 0.0, 0.4)
	await fade_tw.finished
	queue_free()
