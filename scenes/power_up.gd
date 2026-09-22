extends Area2D

enum PowerUpType {
	SPEED,
	WEAPON_UPGRADE,
	HEALTH,
	SHIELD,
	MAX_POWER
}

const POWERUP_TEXTURES := {
	PowerUpType.SPEED: preload("res://graphics/assets_elements/powers up/assets_023.png"),
	PowerUpType.WEAPON_UPGRADE: preload("res://graphics/assets_elements/powers up/assets_024.png"),
	PowerUpType.HEALTH: preload("res://graphics/assets_elements/powers up/assets_025.png"),
	PowerUpType.SHIELD: preload("res://graphics/assets_elements/powers up/assets_026.png"),
	PowerUpType.MAX_POWER: preload("res://graphics/assets_elements/powers up/assets_041.png"),
}

const POWERUP_NAMES := {
	PowerUpType.SPEED: "¡VELOCIDAD AUMENTADA!",
	PowerUpType.WEAPON_UPGRADE: "¡MEJORA DE CAÑÓN!",
	PowerUpType.HEALTH: "+REPARACIÓN DE ESCUDO",
	PowerUpType.SHIELD: "¡ESCUDO DE ENERGÍA!",
	PowerUpType.MAX_POWER: "¡¡ MÁXIMA POTENCIA !!"
}

@export var powerup_type: PowerUpType = PowerUpType.WEAPON_UPGRADE
@export var speed_y: float = 130.0
@export var magnet_range: float = 200.0
@export var magnet_speed: float = 540.0

var _target_player: Node2D = null
var _is_collected: bool = false
var _float_timer: float = 0.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	add_to_group("powerups")
	area_entered.connect(_on_area_entered)
	_configure_type(powerup_type)
	
	var players = get_tree().get_nodes_in_group("player_ship")
	if not players.is_empty():
		_target_player = players[0]
	
	# Animación de pulso visual constante
	var tw = create_tween().set_loops()
	tw.tween_property(sprite, "scale", Vector2(0.58, 0.58), 0.5).set_trans(Tween.TRANS_SINE)
	tw.tween_property(sprite, "scale", Vector2(0.50, 0.50), 0.5).set_trans(Tween.TRANS_SINE)

func setup_random() -> void:
	# Ponderar probabilidades: upgrade y vida más comunes, max power más raro
	var r := randf()
	if r < 0.35:
		powerup_type = PowerUpType.WEAPON_UPGRADE
	elif r < 0.55:
		powerup_type = PowerUpType.HEALTH
	elif r < 0.75:
		powerup_type = PowerUpType.SPEED
	elif r < 0.90:
		powerup_type = PowerUpType.SHIELD
	else:
		powerup_type = PowerUpType.MAX_POWER
	
	if is_inside_tree():
		_configure_type(powerup_type)

func _configure_type(type: PowerUpType) -> void:
	if sprite and POWERUP_TEXTURES.has(type):
		sprite.texture = POWERUP_TEXTURES[type]

func _process(delta: float) -> void:
	if _is_collected:
		return
	
	_float_timer += delta * 2.5
	
	if is_instance_valid(_target_player) and not _target_player.is_dead:
		var dist: float = global_position.distance_to(_target_player.global_position)
		if dist < magnet_range:
			var dir = (_target_player.global_position - global_position).normalized()
			position += dir * magnet_speed * delta
		else:
			position.y += speed_y * delta
			position.x += sin(_float_timer) * 35.0 * delta
	else:
		position.y += speed_y * delta
		position.x += sin(_float_timer) * 35.0 * delta
	
	if position.y > 1360:
		queue_free()

func _on_area_entered(area: Area2D) -> void:
	if _is_collected:
		return
	var p = area if area.has_method("collect_powerup") else area.get_parent()
	if p and p.has_method("collect_powerup"):
		_collect(p)

func _collect(p: Node2D) -> void:
	_is_collected = true
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	if collision:
		collision.set_deferred("disabled", true)
	
	var name_text: String = POWERUP_NAMES.get(powerup_type, "¡POWER UP!")
	p.collect_powerup(powerup_type, name_text)
	
	# Desvanecimiento y explosión de brillo
	var tw = create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "scale", scale * 1.6, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "modulate:a", 0.0, 0.2)
	tw.finished.connect(queue_free)
