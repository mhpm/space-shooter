extends Node2D

signal health_changed(current_health: float, max_health: float)
signal player_died

@export var speed: float = 400.0
@export var laser_scene: PackedScene = preload("res://scenes/laser.tscn")
@export var explosion_scene: PackedScene = preload("res://scenes/explosion.tscn")
@export var shoot_cooldown: float = 0.2
@export var max_health: float = 100.0

var health: float = 100.0
var is_dead: bool = false
var is_invulnerable: bool = false
var _shoot_timer: float = 0.0

@onready var sprite: Sprite2D = $PlayerImage
@onready var hitbox: Area2D = $Hitbox

func _ready() -> void:
	health = max_health
	emit_signal("health_changed", health, max_health)
	
	if hitbox:
		hitbox.add_to_group("player")
		hitbox.area_entered.connect(_on_hitbox_area_entered)

func _process(delta: float) -> void:
	if is_dead:
		return
	
	# Movimiento con flechas del teclado
	var direction = Input.get_vector("left", "right", "up", "down")
	if direction == Vector2.ZERO:
		direction = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	position += direction * speed * delta
	
	# Limitar a los bordes de la pantalla (1280x720)
	position.x = clamp(position.x, 40.0, 1240.0)
	position.y = clamp(position.y, 50.0, 680.0)

	# Disparo con tecla Space
	_shoot_timer -= delta
	var wants_to_shoot: bool = false
	if Input.is_action_just_pressed("shoot") or Input.is_action_just_pressed("ui_accept"):
		wants_to_shoot = true
	elif (Input.is_action_pressed("shoot") or Input.is_action_pressed("ui_accept")) and _shoot_timer <= 0.0:
		wants_to_shoot = true
	
	if wants_to_shoot:
		shoot()
		_shoot_timer = shoot_cooldown

func shoot() -> void:
	if not laser_scene or is_dead:
		return
	var laser = laser_scene.instantiate()
	laser.global_position = global_position + Vector2(0, -50)
	
	if get_parent():
		get_parent().add_child(laser)
	else:
		get_tree().current_scene.add_child(laser)

func _on_hitbox_area_entered(area: Area2D) -> void:
	if is_dead:
		return
	if area.is_in_group("meteors"):
		take_damage(25.0)
		if area.has_method("explode"):
			area.explode()
	elif area.is_in_group("boss_projectiles"):
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
	
	health = max(0.0, health - amount)
	emit_signal("health_changed", health, max_health)
	
	if health <= 0.0:
		die()
	else:
		_trigger_invulnerability()

func _trigger_invulnerability() -> void:
	is_invulnerable = true
	# Efecto visual de parpadeo de daño
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
	
	# Desactivar colisiones
	if hitbox:
		hitbox.set_deferred("monitoring", false)
		hitbox.set_deferred("monitorable", false)
		var col = hitbox.get_node_or_null("CollisionShape2D")
		if col:
			col.set_deferred("disabled", true)
	
	# Instanciar gran explosión
	if explosion_scene:
		var exp_node := explosion_scene.instantiate()
		exp_node.global_position = global_position
		exp_node.target_scale = Vector2(2.5, 2.5) # Explosión más grande para la nave
		exp_node.duration = 0.8
		if get_parent():
			get_parent().add_child(exp_node)
		else:
			get_tree().current_scene.add_child(exp_node)
	
	# Desvanecimiento progresivo (fade-out) suave de la nave
	var fade_tween := create_tween()
	fade_tween.set_parallel(true)
	fade_tween.tween_property(sprite, "modulate:a", 0.0, 1.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	fade_tween.tween_property(sprite, "scale", sprite.scale * 1.3, 1.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
