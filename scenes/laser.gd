extends Area2D

@export var speed: float = 700.0

func _ready() -> void:
	add_to_group("lasers")

func _process(delta: float) -> void:
	position.y -= speed * delta
	# Si sale de la pantalla por arriba, se destruye para liberar memoria
	if global_position.y < -100:
		queue_free()

func hit() -> void:
	queue_free()
