extends Control

signal button_pressed
signal button_released

@export var action_name: StringName = "shoot"
@export var button_radius: float = 48.0
@export var label_text: String = "FUEGO"

@export var normal_bg_color: Color = Color(0.12, 0.04, 0.07, 0.6)
@export var pressed_bg_color: Color = Color(0.8, 0.15, 0.28, 0.85)
@export var normal_border_color: Color = Color(1.0, 0.3, 0.45, 0.8)
@export var pressed_border_color: Color = Color(1.0, 0.85, 0.9, 1.0)
@export var normal_glow_color: Color = Color(1.0, 0.2, 0.35, 0.2)
@export var pressed_glow_color: Color = Color(1.0, 0.3, 0.5, 0.6)

var _touch_index: int = -1
var _is_pressed: bool = false
var _scale_factor: float = 1.0

func _ready() -> void:
	custom_minimum_size = Vector2(button_radius * 2.3, button_radius * 2.3)
	mouse_filter = Control.MOUSE_FILTER_STOP

func _process(delta: float) -> void:
	var target_scale: float = 0.92 if _is_pressed else 1.0
	if not is_equal_approx(_scale_factor, target_scale):
		_scale_factor = move_toward(_scale_factor, target_scale, 8.0 * delta)
		queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch_ev := event as InputEventScreenTouch
		if touch_ev.pressed and _touch_index == -1:
			var center: Vector2 = size / 2.0
			if touch_ev.position.distance_to(center) <= button_radius * 1.3:
				_press(touch_ev.index)
				accept_event()
		elif not touch_ev.pressed and touch_ev.index == _touch_index:
			_release()
			accept_event()
	
	elif event is InputEventScreenDrag:
		var drag_ev := event as InputEventScreenDrag
		if drag_ev.index == _touch_index:
			var center: Vector2 = size / 2.0
			# Si el dedo se aleja excesivamente, soltar
			if drag_ev.position.distance_to(center) > button_radius * 2.0:
				_release()
			accept_event()

func _press(index: int) -> void:
	_touch_index = index
	_is_pressed = true
	if not action_name.is_empty():
		Input.action_press(action_name)
	emit_signal("button_pressed")
	queue_redraw()

func _release() -> void:
	_touch_index = -1
	_is_pressed = false
	if not action_name.is_empty():
		Input.action_release(action_name)
	emit_signal("button_released")
	queue_redraw()

func _draw() -> void:
	var center: Vector2 = size / 2.0
	var r: float = button_radius * _scale_factor
	
	var bg_col := pressed_bg_color if _is_pressed else normal_bg_color
	var border_col := pressed_border_color if _is_pressed else normal_border_color
	var glow_col := pressed_glow_color if _is_pressed else normal_glow_color
	
	# Resplandor exterior
	draw_circle(center, r * 1.25, glow_col)
	# Fondo del botón
	draw_circle(center, r, bg_col)
	# Borde exterior
	draw_arc(center, r, 0.0, TAU, 48, border_col, 2.5, true)
	# Anillo interior concéntrico
	draw_arc(center, r * 0.72, 0.0, TAU, 36, Color(border_col.r, border_col.g, border_col.b, 0.4), 1.5, true)
	
	# Retícula de mira / láser en el centro
	var cross_len: float = 12.0 * _scale_factor
	var cross_col := Color(1.0, 1.0, 1.0, 0.9 if _is_pressed else 0.7)
	draw_line(center - Vector2(cross_len, 0), center - Vector2(4 * _scale_factor, 0), cross_col, 2.0)
	draw_line(center + Vector2(4 * _scale_factor, 0), center + Vector2(cross_len, 0), cross_col, 2.0)
	draw_line(center - Vector2(0, cross_len), center - Vector2(0, 4 * _scale_factor), cross_col, 2.0)
	draw_line(center + Vector2(0, 4 * _scale_factor), center + Vector2(0, cross_len), cross_col, 2.0)
	draw_circle(center, 2.5 * _scale_factor, cross_col)
