extends Area2D

@export var speed: float = 580.0
@export var damage: float = 15.0
@export var direction: Vector2 = Vector2.DOWN

func _ready() -> void:
	add_to_group("boss_projectiles")
	rotation = direction.angle()
	area_entered.connect(_on_area_entered)

func _process(delta: float) -> void:
	position += direction.normalized() * speed * delta
	
	# Destruir si sale de la pantalla vertical
	if global_position.y > 1400 or global_position.y < -200 or global_position.x < -150 or global_position.x > 870:
		queue_free()

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("player"):
		var p = area.get_parent()
		if p and p.has_method("take_damage"):
			p.take_damage(damage)
		hit_player()

func hit_player() -> void:
	queue_free()
