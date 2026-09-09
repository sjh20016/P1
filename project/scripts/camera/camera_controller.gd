extends Node3D

@export var sensitivity: float = 0.0022
@export var base_fov: float = 76.0
@onready var player: RavagePlayer = get_parent()
@onready var camera: Camera3D = $SpringArm3D/Camera3D

func _ready() -> void:
	rotation.x = -0.16
	$SpringArm3D.add_excluded_object(player.get_rid())
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and player.controls_enabled:
		rotation.y -= event.relative.x * sensitivity
		rotation.x = clampf(rotation.x - event.relative.y * sensitivity, -1.3, 1.25)
	if event.is_action_pressed("pause"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED

func _process(delta: float) -> void:
	camera.fov = lerpf(camera.fov, base_fov + minf(player.velocity.length() * 0.18, 12.0), 1.0 - exp(-5.0 * delta))
