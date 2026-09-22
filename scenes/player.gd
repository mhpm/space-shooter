extends Node2D

signal health_changed(current_health: float, max_health: float)
signal player_died
signal xp_changed(current_xp: float, max_xp: float, current_level: int)
signal score_changed(new_score: int)
signal shield_changed(has_shield: bool)
signal notification_triggered(text: String, color: Color)
signal weapon_level_changed(level: int)

@export var speed: float = 420.0
@export var laser_scene: PackedScene = preload("res://scenes/laser.tscn")
@export var explosion_scene: PackedScene = preload("res://scenes/explosion.tscn")
@export var shoot_cooldown: float = 0.18
@export var max_health: float = 100.0
@export var is_autofire: bool = false

# Texturas de armas láser
const TEX_LASER_CYAN := preload("res://graphics/assets_elements/lazers/assets_008.png")
const TEX_LASER_RED := preload("res://graphics/assets_elements/lazers/assets_009.png")
const TEX_LASER_PLASMA := preload("res://graphics/assets_elements/lazers/assets_017.png")
const TEX_LASER_HEAVY := preload("res://graphics/assets_elements/lazers/assets_032.png")

# Texturas de naves seleccionables
const SHIPS := {
	"purple": preload("res://graphics/assets_elements/ships/ship-purple.png"),
	"blue": preload("res://graphics/assets_elements/ships/ship-blue.png"),
	"red": preload("res://graphics/assets_elements/ships/ship-red.png"),
	"red2": preload("res://graphics/assets_elements/ships/ship-red2.png")
}

var health: float = 100.0
var is_dead: bool = false
var is_invulnerable: bool = false
var _shoot_timer: float = 0.0

# Sistema de Armas
var weapon_level: int = 1 # 1: Simple, 2: Doble, 3: Triple, 4: Max Power
var _max_power_timer: float = 0.0
var _base_speed: float = 420.0
var _speed_boost_timer: float = 0.0
var has_shield: bool = false

# Sistema de Experiencia y Puntuación
var score: int = 0
var xp: float = 0.0
var xp_required: float = 100.0
var player_level: int = 1

# Efecto visual de escudo
var _shield_rotation: float = 0.0

@onready var sprite: Sprite2D = $PlayerImage
@onready var hitbox: Area2D = $Hitbox

func _ready() -> void:
	add_to_group("player_ship")
	_base_speed = speed
	health = max_health
	emit_signal("health_changed", health, max_health)
	emit_signal("xp_changed", xp, xp_required, player_level)
	emit_signal("score_changed", score)
	emit_signal("shield_changed", has_shield)
	emit_signal("weapon_level_changed", weapon_level)
	
	if hitbox:
		hitbox.add_to_group("player")
		hitbox.area_entered.connect(_on_hitbox_area_entered)

func set_ship_type(type_name: String) -> void:
	if SHIPS.has(type_name) and sprite:
		sprite.texture = SHIPS[type_name]
		match type_name:
			"blue":
				_base_speed = 490.0
				shoot_cooldown = 0.15
				emit_signal("notification_triggered", "NAVE: INTERCEPTOR AZUL (+VEL)", Color(0.3, 0.8, 1.0))
			"red":
				_base_speed = 380.0
				max_health = 130.0
				health = max_health
				emit_signal("health_changed", health, max_health)
				emit_signal("notification_triggered", "NAVE: DESTRUCTOR ROJO (+BLINDAJE)", Color(1.0, 0.3, 0.3))
			"red2":
				_base_speed = 430.0
				weapon_level = 2
				shoot_cooldown = 0.16
				emit_signal("weapon_level_changed", weapon_level)
				emit_signal("notification_triggered", "NAVE: FÉNIX CARMESÍ (+DOBLE CAÑÓN)", Color(1.0, 0.5, 0.2))
			_:
				_base_speed = 420.0
				shoot_cooldown = 0.18
				emit_signal("notification_triggered", "NAVE: CAZA PÚRPURA (EQUILIBRADO)", Color(0.8, 0.4, 1.0))
		speed = _base_speed

func _process(delta: float) -> void:
	if is_dead:
		return
	
	# Timers de mejoras activas
	if _speed_boost_timer > 0.0:
		_speed_boost_timer -= delta
		if _speed_boost_timer <= 0.0:
			speed = _base_speed
	
	if _max_power_timer > 0.0:
		_max_power_timer -= delta
		if _max_power_timer <= 0.0:
			weapon_level = 3
			emit_signal("weapon_level_changed", weapon_level)
	
	# Rotación y animación del escudo de energía
	if has_shield:
		_shield_rotation += delta * 3.0
		queue_redraw()
	
	# Movimiento con flechas, WASD o joystick virtual
	var direction = Input.get_vector("left", "right", "up", "down")
	if direction == Vector2.ZERO:
		direction = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	position += direction * speed * delta
	
	# Limitar a los bordes de la pantalla vertical
	var vp_size := get_viewport_rect().size
	position.x = clampf(position.x, 35.0, vp_size.x - 35.0)
	position.y = clampf(position.y, 80.0, vp_size.y - 70.0)

	# Disparo manual o automático
	_shoot_timer -= delta
	var wants_to_shoot: bool = false
	if is_autofire and _shoot_timer <= 0.0:
		wants_to_shoot = true
	elif Input.is_action_just_pressed("shoot") or Input.is_action_just_pressed("ui_accept"):
		wants_to_shoot = true
	elif (Input.is_action_pressed("shoot") or Input.is_action_pressed("ui_accept")) and _shoot_timer <= 0.0:
		wants_to_shoot = true
	
	if wants_to_shoot:
		shoot()
		var cd := shoot_cooldown * (0.65 if weapon_level >= 4 else 1.0)
		_shoot_timer = cd

func set_autofire(enabled: bool) -> void:
	is_autofire = enabled

func shoot() -> void:
	if not laser_scene or is_dead:
		return
	
	var parent_node = get_parent() if get_parent() else get_tree().current_scene
	
	match weapon_level:
		1:
			# Disparo simple frontal
			_spawn_laser(parent_node, Vector2(0, -50), Vector2.UP, TEX_LASER_CYAN, 25.0)
		2:
			# Disparo doble paralelo
			_spawn_laser(parent_node, Vector2(-18, -45), Vector2.UP, TEX_LASER_CYAN, 24.0)
			_spawn_laser(parent_node, Vector2(18, -45), Vector2.UP, TEX_LASER_CYAN, 24.0)
		3:
			# Disparo triple en abanico
			_spawn_laser(parent_node, Vector2(0, -52), Vector2.UP, TEX_LASER_PLASMA, 28.0)
			_spawn_laser(parent_node, Vector2(-22, -42), Vector2(-0.25, -0.96), TEX_LASER_PLASMA, 26.0)
			_spawn_laser(parent_node, Vector2(22, -42), Vector2(0.25, -0.96), TEX_LASER_PLASMA, 26.0)
		_:
			# Max Power (Nivel 4): Cuádruple ráfaga con cañones pesados
			_spawn_laser(parent_node, Vector2(-12, -54), Vector2.UP, TEX_LASER_RED, 35.0)
			_spawn_laser(parent_node, Vector2(12, -54), Vector2.UP, TEX_LASER_RED, 35.0)
			_spawn_laser(parent_node, Vector2(-30, -38), Vector2(-0.35, -0.93), TEX_LASER_HEAVY, 42.0)
			_spawn_laser(parent_node, Vector2(30, -38), Vector2(0.35, -0.93), TEX_LASER_HEAVY, 42.0)

func _spawn_laser(parent_node: Node, offset: Vector2, dir: Vector2, tex: Texture2D, dmg: float) -> void:
	var l = laser_scene.instantiate()
	l.global_position = global_position + offset
	l.direction = dir
	l.custom_texture = tex
	l.damage = dmg
	parent_node.add_child(l)

# Recolección de Power-ups
func collect_powerup(type: int, name_text: String) -> void:
	match type:
		0: # SPEED
			_speed_boost_timer = 8.0
			speed = _base_speed * 1.45
			emit_signal("notification_triggered", "⚡ " + name_text, Color(0.2, 0.9, 1.0))
		1: # WEAPON_UPGRADE
			weapon_level = min(weapon_level + 1, 3)
			emit_signal("weapon_level_changed", weapon_level)
			var w_name := "¡DISPARO DOBLE!" if weapon_level == 2 else "¡DISPARO TRIPLE!"
			emit_signal("notification_triggered", "⚔ " + w_name, Color(1.0, 0.85, 0.2))
		2: # HEALTH
			health = min(max_health, health + 40.0)
			emit_signal("health_changed", health, max_health)
			emit_signal("notification_triggered", "❤ " + name_text, Color(0.3, 1.0, 0.4))
		3: # SHIELD
			has_shield = true
			emit_signal("shield_changed", true)
			emit_signal("notification_triggered", "🛡 " + name_text, Color(0.3, 0.8, 1.0))
			queue_redraw()
		4: # MAX_POWER
			weapon_level = 4
			_max_power_timer = 12.0
			emit_signal("weapon_level_changed", weapon_level)
			emit_signal("notification_triggered", "💥 " + name_text, Color(1.0, 0.2, 0.4))

# Recolección de Ítems, Puntos y Experiencia
func collect_item(points: int, xp_amount: float) -> void:
	add_score(points)
	add_xp(xp_amount)

func add_score(amount: int) -> void:
	score += amount
	emit_signal("score_changed", score)

func add_xp(amount: float) -> void:
	xp += amount
	if xp >= xp_required:
		level_up()
	else:
		emit_signal("xp_changed", xp, xp_required, player_level)

func level_up() -> void:
	player_level += 1
	xp -= xp_required
	xp_required = round(xp_required * 1.35)
	
	# Bonificación por subir de nivel
	health = min(max_health, health + 25.0)
	emit_signal("health_changed", health, max_health)
	
	if weapon_level < 3:
		weapon_level += 1
		emit_signal("weapon_level_changed", weapon_level)
	
	emit_signal("xp_changed", xp, xp_required, player_level)
	emit_signal("notification_triggered", "⭐ ¡¡ SUBIDA DE NIVEL %d !!" % player_level, Color(1.0, 0.9, 0.2))
	
	# Destello dorado en la nave
	var tw = create_tween()
	tw.tween_property(sprite, "modulate", Color(2.5, 2.3, 0.5, 1.0), 0.2)
	tw.tween_property(sprite, "modulate", Color.WHITE, 0.3)

func _on_hitbox_area_entered(area: Area2D) -> void:
	if is_dead:
		return
	if area.is_in_group("meteors"):
		take_damage(25.0)
		if area.has_method("explode"):
			area.explode()
	elif area.is_in_group("boss_projectiles") or area.is_in_group("enemy_projectiles"):
		var dmg: float = 15.0
		if "damage" in area:
			dmg = area.damage
		take_damage(dmg)
		if area.has_method("hit_player"):
			area.hit_player()
		elif area.has_method("explode"):
			area.explode()
		else:
			area.queue_free()
	elif area.is_in_group("boss"):
		take_damage(30.0)

func take_damage(amount: float) -> void:
	if is_dead or is_invulnerable:
		return
	
	# Si el escudo de energía está activo, absorbe completamente el daño
	if has_shield:
		has_shield = false
		emit_signal("shield_changed", false)
		emit_signal("notification_triggered", "🛡 ¡ESCUDO ABSORBIÓ EL IMPACTO!", Color(0.3, 0.8, 1.0))
		queue_redraw()
		_trigger_invulnerability()
		return
	
	health = max(0.0, health - amount)
	emit_signal("health_changed", health, max_health)
	
	if health <= 0.0:
		die()
	else:
		_trigger_invulnerability()

func _trigger_invulnerability() -> void:
	is_invulnerable = true
	var tween := create_tween()
	for i in 3:
		tween.tween_property(sprite, "modulate", Color(1.0, 0.2, 0.2, 0.4), 0.1)
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)
	
	await tween.finished
	is_invulnerable = false

func die() -> void:
	if is_dead:
		return
	is_dead = true
	emit_signal("player_died")
	
	if hitbox:
		hitbox.set_deferred("monitoring", false)
		hitbox.set_deferred("monitorable", false)
		var col = hitbox.get_node_or_null("CollisionShape2D")
		if col:
			col.set_deferred("disabled", true)
	
	if explosion_scene:
		var exp_node := explosion_scene.instantiate()
		exp_node.global_position = global_position
		exp_node.target_scale = Vector2(2.5, 2.5)
		exp_node.duration = 0.8
		if get_parent():
			get_parent().add_child(exp_node)
		else:
			get_tree().current_scene.add_child(exp_node)
	
	var fade_tween := create_tween()
	fade_tween.set_parallel(true)
	fade_tween.tween_property(sprite, "modulate:a", 0.0, 1.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	fade_tween.tween_property(sprite, "scale", sprite.scale * 1.3, 1.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _draw() -> void:
	# Dibujar campo de fuerza protector (escudo activo)
	if has_shield:
		var shield_radius: float = 52.0
		# Burbuja translúcida
		draw_circle(Vector2.ZERO, shield_radius, Color(0.1, 0.6, 1.0, 0.25))
		# Anillos de energía rotando
		draw_arc(Vector2.ZERO, shield_radius, _shield_rotation, _shield_rotation + PI, 32, Color(0.3, 0.9, 1.0, 0.9), 2.5, true)
		draw_arc(Vector2.ZERO, shield_radius, _shield_rotation + PI * 1.1, _shield_rotation + TAU * 1.05, 32, Color(0.3, 0.9, 1.0, 0.9), 2.5, true)
		# Halo exterior
		draw_arc(Vector2.ZERO, shield_radius * 1.12, -_shield_rotation * 0.7, -_shield_rotation * 0.7 + PI * 0.8, 24, Color(0.6, 1.0, 1.0, 0.5), 1.5, true)
