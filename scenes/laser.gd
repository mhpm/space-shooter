extends Area2D

@export var speed: float = 780.0
@export var damage: float = 25.0
@export var direction: Vector2 = Vector2.UP
@export var custom_texture: Texture2D = null

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	add_to_group("lasers")
	if custom_texture and sprite:
		sprite.texture = custom_texture
	
	# Rotar proyectil hacia su trayectoria
	rotation = direction.angle() + PI / 2.0

func _process(delta: float) -> void:
	position += direction.normalized() * speed * delta
	
	if global_position.y < -120 or global_position.y > 1400 or global_position.x < -100 or global_position.x > 820:
		queue_free()

func hit() -> void:
	queue_free()
