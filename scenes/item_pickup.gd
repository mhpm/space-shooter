extends Area2D

enum ItemType {
	PURPLE_CRYSTAL,
	BLUE_CRYSTAL,
	YELLOW_CRYSTAL,
	GOLD_STAR,
	GOLD_COIN,
	RED_RUBY
}

const ITEM_TEXTURES := {
	ItemType.PURPLE_CRYSTAL: preload("res://graphics/assets_elements/items/assets_042.png"),
	ItemType.BLUE_CRYSTAL: preload("res://graphics/assets_elements/items/assets_043.png"),
	ItemType.YELLOW_CRYSTAL: preload("res://graphics/assets_elements/items/assets_044.png"),
	ItemType.GOLD_STAR: preload("res://graphics/assets_elements/items/assets_045.png"),
	ItemType.GOLD_COIN: preload("res://graphics/assets_elements/items/assets_046.png"),
	ItemType.RED_RUBY: preload("res://graphics/assets_elements/items/assets_047.png"),
}

@export var item_type: ItemType = ItemType.PURPLE_CRYSTAL
@export var speed_y: float = 140.0
@export var magnet_range: float = 240.0
@export var magnet_speed: float = 560.0

var points_value: int = 50
var xp_value: float = 15.0
var _target_player: Node2D = null
var _is_collected: bool = false
var _float_timer: float = 0.0
var _drift_x: float = 0.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	add_to_group("items")
	area_entered.connect(_on_area_entered)
	
	_drift_x = randf_range(-30.0, 30.0)
	_configure_type(item_type)
	
	# Buscar referencia inicial al jugador
	var players = get_tree().get_nodes_in_group("player_ship")
	if not players.is_empty():
		_target_player = players[0]
	
	# Efecto visual de escala suave al aparecer
	scale = Vector2(0.2, 0.2)
	var tw = create_tween()
	tw.tween_property(self, "scale", Vector2(0.45, 0.45), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func setup_random() -> void:
	var rand_val := randf()
	if rand_val < 0.25:
		item_type = ItemType.PURPLE_CRYSTAL
	elif rand_val < 0.50:
		item_type = ItemType.BLUE_CRYSTAL
	elif rand_val < 0.70:
		item_type = ItemType.GOLD_COIN
	elif rand_val < 0.85:
		item_type = ItemType.YELLOW_CRYSTAL
	elif rand_val < 0.95:
		item_type = ItemType.GOLD_STAR
	else:
		item_type = ItemType.RED_RUBY
	
	if is_inside_tree():
		_configure_type(item_type)

func _configure_type(type: ItemType) -> void:
	if sprite and ITEM_TEXTURES.has(type):
		sprite.texture = ITEM_TEXTURES[type]
	
	match type:
		ItemType.PURPLE_CRYSTAL, ItemType.BLUE_CRYSTAL:
			points_value = 50
			xp_value = 15.0
		ItemType.YELLOW_CRYSTAL:
			points_value = 75
			xp_value = 20.0
		ItemType.GOLD_COIN:
			points_value = 100
			xp_value = 25.0
		ItemType.GOLD_STAR:
			points_value = 150
			xp_value = 35.0
		ItemType.RED_RUBY:
			points_value = 300
			xp_value = 50.0

func _process(delta: float) -> void:
	if _is_collected:
		return
	
	_float_timer += delta * 3.0
	
	# Imán hacia el jugador si está en rango
	if is_instance_valid(_target_player) and not _target_player.is_dead:
		var dist: float = global_position.distance_to(_target_player.global_position)
		if dist < magnet_range:
			var dir = (_target_player.global_position - global_position).normalized()
			position += dir * magnet_speed * delta
		else:
			position.y += speed_y * delta
			position.x += (_drift_x + sin(_float_timer) * 20.0) * delta
	else:
		position.y += speed_y * delta
		position.x += (_drift_x + sin(_float_timer) * 20.0) * delta
	
	# Salir de pantalla vertical
	if position.y > 1360:
		queue_free()

func _on_area_entered(area: Area2D) -> void:
	if _is_collected:
		return
	var p = area if area.has_method("collect_item") else area.get_parent()
	if p and p.has_method("collect_item"):
		_collect(p)

func _collect(p: Node2D) -> void:
	_is_collected = true
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	if collision:
		collision.set_deferred("disabled", true)
	
	p.collect_item(points_value, xp_value)
	
	# Animación de recogida brillante
	var tw = create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "scale", scale * 1.5, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "modulate:a", 0.0, 0.18)
	tw.tween_property(self, "position:y", position.y - 30.0, 0.18)
	tw.finished.connect(queue_free)
