class_name PortalLoopActor
extends Node3D

# Presentation only: the body, collision sphere and camera never teleport.
var player: RavagePlayer
var character: PortalCharacter
var core: MeshInstance3D
var echo: MeshInstance3D
var original_pose: Transform3D
var original_material: Material
var original_shadow: int
var material: ShaderMaterial
var phase: float = 0
var cycles: int = 0
var running := false

func _ready() -> void:
	core = player.get_node("Core")
	original_pose = core.transform; original_material = core.material_override
	original_shadow = core.cast_shadow
	echo = MeshInstance3D.new(); echo.mesh = core.mesh; player.add_child(echo); echo.hide()
	echo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	material = ShaderMaterial.new()
	material.shader = preload("res://shaders/portal_loop.gdshader")

func begin() -> void:
	phase = 0; cycles = 0; running = true
	core.material_override = material; echo.material_override = material; echo.show()
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if is_instance_valid(character):
		echo.hide(); character.set_loop(phase,0)

func advance(delta: float, speed_fraction: float) -> void:
	if not running: return
	var step := delta * lerpf(0.8,3.8,clampf(speed_fraction,0,1))
	cycles += int(floor(phase + step)); phase = fposmod(phase + step,1.0)
	material.set_shader_parameter("bottom",player.global_position.y - 0.78)
	material.set_shader_parameter("top",player.global_position.y + 1.9)
	core.position = Vector3(0,1.9 - phase * 2.68,0)
	core.scale = Vector3(0.82,lerpf(1.05,1.5,speed_fraction),0.82)
	echo.transform = core.transform
	echo.position.y += -2.68 if phase < 0.5 else 2.68
	if is_instance_valid(character):
		echo.hide(); character.set_loop(phase,speed_fraction)

func finish() -> void:
	running = false
	if is_instance_valid(character): character.finish_loop()
	if is_instance_valid(core): core.transform = original_pose; core.material_override = original_material; core.cast_shadow = original_shadow
	if is_instance_valid(echo): echo.hide()

func _exit_tree() -> void:
	finish()
	if is_instance_valid(echo): echo.queue_free()
