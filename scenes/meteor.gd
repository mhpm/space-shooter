extends Area2D

@export var explosion_scene: PackedScene = preload("res://scenes/explosion.tscn")
@export var item_scene: PackedScene = preload("res://scenes/item_pickup.tscn")
@export var powerup_scene: PackedScene = preload("res://scenes/power_up.tscn")

var speed_y: float = 250.0
var drift_x: float = 0.0
var rotation_speed: float = 1.0

# Texturas de asteroides reales en su nueva subcarpeta
const METEOR_TEXTURES := [
	preload("res://graphics/assets_elements/asteroids, meteors and bombs/assets_019.png"),
	preload("res://graphics/assets_elements/asteroids, meteors and bombs/assets_020.png"),
	preload("res://graphics/assets_elements/asteroids, meteors and bombs/assets_021.png"),
	preload("res://graphics/assets_elements/asteroids, meteors and bombs/assets_022.png"),
	preload("res://graphics/assets_elements/asteroids, meteors and bombs/assets_027.png"),
	preload("res://graphics/assets_elements/asteroids, meteors and bombs/assets_028.png"),
	preload("res://graphics/assets_elements/asteroids, meteors and bombs/assets_029.png")
]

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	add_to_group("meteors")
	area_entered.connect(_on_area_entered)
	
	if sprite and not METEOR_TEXTURES.is_empty():
		sprite.texture = METEOR_TEXTURES.pick_random()
	
	speed_y = randf_range(180.0, 360.0)
	drift_x = randf_range(-50.0, 50.0)
	rotation_speed = randf_range(-2.5, 2.5)
	
	var s := randf_range(0.48, 0.75)
	scale = Vector2(s, s)

func _process(delta: float) -> void:
	position.y += speed_y * delta
	position.x += drift_x * delta
	rotation += rotation_speed * delta
	
	if position.y > 1380 or position.x < -150 or position.x > 870:
		queue_free()

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("lasers"):
		if area.has_method("hit"):
			area.hit()
		else:
			area.queue_free()
		explode()
	elif area.is_in_group("player"):
		var player_node = area.get_parent()
		if player_node and player_node.has_method("take_damage"):
			player_node.take_damage(25.0)
		explode()

func explode() -> void:
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	if collision:
		collision.set_deferred("disabled", true)
	
	# Premiar al jugador con puntos directos
	var players = get_tree().get_nodes_in_group("player_ship")
	if not players.is_empty():
		var p = players[0]
		if p.has_method("add_score"):
			p.add_score(25)
	
	# Crear explosión
	if explosion_scene:
		var exp_node := explosion_scene.instantiate()
		exp_node.global_position = global_position
		exp_node.target_scale = scale * 1.8
		if get_parent():
			get_parent().add_child(exp_node)
		else:
			get_tree().current_scene.add_child(exp_node)
	
	# Soltar ítems coleccionables (60% probabilidad)
	var parent_node = get_parent() if get_parent() else get_tree().current_scene
	if parent_node and item_scene and randf() < 0.60:
		var item = item_scene.instantiate()
		item.global_position = global_position
		if item.has_method("setup_random"):
			item.setup_random()
		parent_node.call_deferred("add_child", item)
	
	# Pequeña probabilidad de soltar power-up (10%)
	if parent_node and powerup_scene and randf() < 0.10:
		var pu = powerup_scene.instantiate()
		pu.global_position = global_position
		if pu.has_method("setup_random"):
			pu.setup_random()
		parent_node.call_deferred("add_child", pu)
	
	queue_free()
