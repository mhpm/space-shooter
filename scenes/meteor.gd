extends Area2D

@export var explosion_scene: PackedScene = preload("res://scenes/explosion.tscn")

var speed_y: float = 250.0
var drift_x: float = 0.0
var rotation_speed: float = 1.0

# Lista de texturas de meteoros disponibles
const METEOR_TEXTURES := [
	preload("res://graphics/assets_elements/assets_020.png"),
	preload("res://graphics/assets_elements/assets_021.png"),
	preload("res://graphics/assets_elements/assets_022.png"),
	preload("res://graphics/assets_elements/assets_023.png"),
	preload("res://graphics/assets_elements/assets_024.png"),
	preload("res://graphics/assets_elements/assets_025.png")
]

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	add_to_group("meteors")
	area_entered.connect(_on_area_entered)
	
	# Seleccionar textura aleatoria para variedad
	if sprite and not METEOR_TEXTURES.is_empty():
		sprite.texture = METEOR_TEXTURES.pick_random()
	
	# Configurar parámetros aleatorios de movimiento de meteoro
	speed_y = randf_range(180.0, 360.0)
	drift_x = randf_range(-60.0, 60.0)
	rotation_speed = randf_range(-2.5, 2.5)
	
	# Variación aleatoria de escala (entre 0.5 y 0.75)
	var s := randf_range(0.5, 0.75)
	scale = Vector2(s, s)

func _process(delta: float) -> void:
	position.y += speed_y * delta
	position.x += drift_x * delta
	rotation += rotation_speed * delta
	
	# Destruir si sale completamente de la pantalla
	if position.y > 800 or position.x < -150 or position.x > 1430:
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
	# Desactivar colisiones inmediatamente para evitar colisiones múltiples
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	if collision:
		collision.set_deferred("disabled", true)
	
	# Crear explosión
	if explosion_scene:
		var exp_node := explosion_scene.instantiate()
		exp_node.global_position = global_position
		# Adaptar escala de la explosión al tamaño del meteoro
		exp_node.target_scale = scale * 1.8
		if get_parent():
			get_parent().add_child(exp_node)
		else:
			get_tree().current_scene.add_child(exp_node)
	
	queue_free()
