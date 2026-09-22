extends Area2D

@export var speed: float = 480.0
@export var damage: float = 15.0
@export var direction: Vector2 = Vector2.DOWN

func _ready() -> void:
	add_to_group("enemy_projectiles")
	rotation = direction.angle() - PI / 2.0
	area_entered.connect(_on_area_entered)

func _process(delta: float) -> void:
	position += direction.normalized() * speed * delta
	
	if global_position.y > 1380 or global_position.y < -150 or global_position.x < -100 or global_position.x > 820:
		queue_free()

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("player"):
		var p = area.get_parent()
		if p and p.has_method("take_damage"):
			p.take_damage(damage)
		queue_free()
