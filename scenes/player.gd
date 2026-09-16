extends Node2D

@export var speed: float = 400.0

func _ready() -> void:
	position = Vector2(400, 600)
	
func _process(delta: float) -> void:
	var direction = Input.get_vector("left", "right", "up", "down")
	if direction == Vector2.ZERO:
		direction = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	position += direction * speed * delta
