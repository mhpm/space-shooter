extends Area2D

@export var initial_speed: float = 180.0
@export var max_speed: float = 380.0
@export var acceleration: float = 140.0
@export var turn_speed: float = 2.2
@export var damage: float = 25.0
@export var health: float = 20.0
@export var explosion_scene: PackedScene = preload("res://scenes/boss_explosion.tscn")

var speed: float = 180.0
var direction: Vector2 = Vector2.DOWN
var is_exploding: bool = false
var target_player: Node2D = null

@onready var collision: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	add_to_group("boss_projectiles")
	speed = initial_speed
	rotation = direction.angle()
	area_entered.connect(_on_area_entered)
	
	# Buscar referencia al jugador en la escena
	var players = get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		target_player = players[0]

func _process(delta: float) -> void:
	if is_exploding:
		return
	
	# Guiado suave hacia la posición del jugador
	if is_instance_valid(target_player):
		var target_pos = target_player.global_position
		# Si el jugador está por debajo del misil, corregir trayectoria
		if target_pos.y > global_position.y - 20:
			var desired_dir = (target_pos - global_position).normalized()
			direction = direction.slerp(desired_dir, turn_speed * delta).normalized()
	
	# Aceleración progresiva
	speed = min(speed + acceleration * delta, max_speed)
	position += direction * speed * delta
	rotation = direction.angle()
	
	# Destruir si sale de los límites de pantalla vertical
	if global_position.y > 1400 or global_position.y < -200 or global_position.x < -150 or global_position.x > 870:
		queue_free()

func _on_area_entered(area: Area2D) -> void:
	if is_exploding:
		return
	
	# Si un láser del jugador impacta el misil
	if area.is_in_group("lasers"):
		var laser_dmg: float = 25.0
		if "damage" in area:
			laser_dmg = area.damage
		
		if area.has_method("hit"):
			area.hit()
		else:
			area.queue_free()
		
		health -= laser_dmg
		if health <= 0:
			explode()
		else:
			_flash_hit()
	
	# Si impacta contra el jugador
	elif area.is_in_group("player"):
		var p = area.get_parent()
		if p and p.has_method("take_damage"):
			p.take_damage(damage)
		explode()

func _flash_hit() -> void:
	var sprite = get_node_or_null("Sprite2D")
	if sprite:
		var tw = create_tween()
		tw.tween_property(sprite, "modulate", Color(2.0, 2.0, 2.0, 1.0), 0.05)
		tw.tween_property(sprite, "modulate", Color.WHITE, 0.05)

func hit_player() -> void:
	explode()

func explode() -> void:
	if is_exploding:
		return
	is_exploding = true
	
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	if collision:
		collision.set_deferred("disabled", true)
	
	if explosion_scene:
		var exp_node = explosion_scene.instantiate()
		exp_node.global_position = global_position
		exp_node.target_scale = Vector2(0.9, 0.9)
		if get_parent():
			get_parent().add_child(exp_node)
		else:
			get_tree().current_scene.add_child(exp_node)
	
	queue_free()
