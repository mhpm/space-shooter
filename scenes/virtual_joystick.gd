extends Control

signal direction_changed(vector: Vector2)

@export var max_distance: float = 65.0
@export var deadzone: float = 8.0
@export var base_radius: float = 60.0
@export var knob_radius: float = 24.0
@export var return_speed: float = 25.0

@export var base_color: Color = Color(0.05, 0.09, 0.16, 0.55)
@export var border_color: Color = Color(0.18, 0.82, 0.98, 0.75)
@export var knob_color: Color = Color(0.25, 0.9, 1.0, 0.85)
@export var knob_glow: Color = Color(0.1, 0.6, 0.9, 0.35)

var _touch_index: int = -1
var _knob_position: Vector2 = Vector2.ZERO
var _output_vector: Vector2 = Vector2.ZERO
var _is_active: bool = false

func _ready() -> void:
	custom_minimum_size = Vector2(base_radius * 2.4, base_radius * 2.4)
	mouse_filter = Control.MOUSE_FILTER_STOP

func _process(delta: float) -> void:
	if not _is_active and _knob_position != Vector2.ZERO:
		_knob_position = _knob_position.lerp(Vector2.ZERO, return_speed * delta)
		if _knob_position.length_squared() < 0.5:
			_knob_position = Vector2.ZERO
		queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch_ev := event as InputEventScreenTouch
		if touch_ev.pressed and _touch_index == -1:
			var center: Vector2 = size / 2.0
			var dist: float = touch_ev.position.distance_to(center)
			if dist <= base_radius * 1.6:
				_touch_index = touch_ev.index
				_is_active = true
				_update_knob(touch_ev.position)
				accept_event()
		elif not touch_ev.pressed and touch_ev.index == _touch_index:
			_release()
			accept_event()
	
	elif event is InputEventScreenDrag:
		var drag_ev := event as InputEventScreenDrag
		if drag_ev.index == _touch_index:
			_update_knob(drag_ev.position)
			accept_event()

func _update_knob(touch_pos: Vector2) -> void:
	var center: Vector2 = size / 2.0
	var delta: Vector2 = touch_pos - center
	var dist: float = delta.length()
	var dir: Vector2 = delta.normalized() if dist > 0.0 else Vector2.ZERO
	
	var clamped_dist: float = minf(dist, max_distance)
	_knob_position = dir * clamped_dist
	
	if dist > deadzone:
		var normalized_dist: float = (clamped_dist - deadzone) / (max_distance - deadzone)
		_output_vector = dir * clampf(normalized_dist, 0.0, 1.0)
	else:
		_output_vector = Vector2.ZERO
	
	_apply_input_actions(_output_vector)
	emit_signal("direction_changed", _output_vector)
	queue_redraw()

func _release() -> void:
	_touch_index = -1
	_is_active = false
	_output_vector = Vector2.ZERO
	_apply_input_actions(Vector2.ZERO)
	emit_signal("direction_changed", Vector2.ZERO)
	queue_redraw()

func _apply_input_actions(vec: Vector2) -> void:
	if vec.x > 0.08:
		Input.action_press("right", vec.x)
		Input.action_release("left")
	elif vec.x < -0.08:
		Input.action_press("left", -vec.x)
		Input.action_release("right")
	else:
		Input.action_release("left")
		Input.action_release("right")
	
	if vec.y > 0.08:
		Input.action_press("down", vec.y)
		Input.action_release("up")
	elif vec.y < -0.08:
		Input.action_press("up", -vec.y)
		Input.action_release("down")
	else:
		Input.action_release("up")
		Input.action_release("down")

func get_direction() -> Vector2:
	return _output_vector

func _draw() -> void:
	var center: Vector2 = size / 2.0
	
	# Base circular exterior con efecto translucido
	draw_circle(center, base_radius, base_color)
	draw_arc(center, base_radius, 0.0, TAU, 48, border_color, 2.5, true)
	
	# Marcas tácticas en los 4 puntos cardinales
	var tick_length: float = 6.0
	var tick_col := Color(border_color.r, border_color.g, border_color.b, 0.45)
	draw_line(center + Vector2(0, -base_radius + 2), center + Vector2(0, -base_radius + 2 + tick_length), tick_col, 2.0)
	draw_line(center + Vector2(0, base_radius - 2), center + Vector2(0, base_radius - 2 - tick_length), tick_col, 2.0)
	draw_line(center + Vector2(-base_radius + 2, 0), center + Vector2(-base_radius + 2 + tick_length, 0), tick_col, 2.0)
	draw_line(center + Vector2(base_radius - 2, 0), center + Vector2(base_radius - 2 - tick_length, 0), tick_col, 2.0)
	
	# Pomo central (Knob)
	var knob_center: Vector2 = center + _knob_position
	# Resplandor exterior del pomo
	draw_circle(knob_center, knob_radius * 1.35, knob_glow)
	# Núcleo del pomo
	draw_circle(knob_center, knob_radius, knob_color)
	# Anillo interior decorativo
	draw_arc(knob_center, knob_radius * 0.7, 0.0, TAU, 32, Color(1.0, 1.0, 1.0, 0.5), 1.5, true)
