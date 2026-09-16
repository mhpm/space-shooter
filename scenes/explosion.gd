extends Node2D

@export var initial_scale: Vector2 = Vector2(0.5, 0.5)
@export var target_scale: Vector2 = Vector2(1.2, 1.2)
@export var duration: float = 0.4

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	scale = target_scale * 0.4
	modulate = Color(1.5, 1.3, 1.0, 1.0) # Ligero brillo inicial
	rotation = randf_range(0, TAU) # Rotación aleatoria para variedad visual
	
	var tween := create_tween()
	tween.set_parallel(true)
	# Expansión rápida
	tween.tween_property(self, "scale", target_scale, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# Desvanecimiento progresivo
	tween.tween_property(self, "modulate:a", 0.0, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	# Al finalizar, destruye el nodo
	tween.finished.connect(queue_free)
