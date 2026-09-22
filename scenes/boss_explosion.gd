extends Node2D

@export var initial_scale: Vector2 = Vector2(0.3, 0.3)
@export var target_scale: Vector2 = Vector2(1.4, 1.4)
@export var duration: float = 0.45

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	scale = initial_scale
	modulate = Color(1.8, 1.3, 0.8, 1.0) # Brillo inicial intenso
	rotation = randf_range(0, TAU)
	
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", target_scale, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.finished.connect(queue_free)
