extends CanvasLayer

signal autofire_toggled(is_enabled: bool)

@onready var joystick: Control = $VirtualJoystick
@onready var shoot_button: Control = $ShootButton
@onready var auto_button: Button = $AutoFireButton

var is_autofire_enabled: bool = false

func _ready() -> void:
	if auto_button:
		auto_button.toggled.connect(_on_auto_button_toggled)
		_update_auto_button_visual()

func _on_auto_button_toggled(toggled_on: bool) -> void:
	is_autofire_enabled = toggled_on
	_update_auto_button_visual()
	emit_signal("autofire_toggled", is_autofire_enabled)

func _update_auto_button_visual() -> void:
	if not auto_button:
		return
	if is_autofire_enabled:
		auto_button.text = "⚡ AUTO: ON"
		auto_button.modulate = Color(1.0, 0.85, 0.2, 1.0)
	else:
		auto_button.text = "AUTO: OFF"
		auto_button.modulate = Color(0.7, 0.85, 1.0, 0.6)
