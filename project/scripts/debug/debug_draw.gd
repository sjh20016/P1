extends MeshInstance3D

var geometry := ImmediateMesh.new()
var line_material := StandardMaterial3D.new()
var enabled: bool = false
var player: RavagePlayer

func _ready() -> void:
	mesh = geometry
	line_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	line_material.vertex_color_use_as_albedo = true
	line_material.no_depth_test = true
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	player = get_tree().get_first_node_in_group("player")
	top_level = true
	global_transform = Transform3D.IDENTITY

func line(a: Vector3, b: Vector3, color: Color) -> void:
	geometry.surface_set_color(color)
	geometry.surface_add_vertex(a)
	geometry.surface_add_vertex(b)

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("debug"):
		enabled = not enabled
	geometry.clear_surfaces()
	if not enabled:
		return
	geometry.surface_begin(Mesh.PRIMITIVE_LINES, line_material)
	line(player.global_position, player.global_position + player.velocity * 0.3, Color.YELLOW)
	for h in player.hooks:
		if h.ray_flash > 0:
			line(h.camera.global_position, h.last_ray_end, Color.WHITE)
		if not h.active:
			continue
		var point := h.grapple_point
		line(point-Vector3.RIGHT, point+Vector3.RIGHT, h.tint)
		line(point-Vector3.UP, point+Vector3.UP, h.tint)
		line(h.debug_previous_start, h.debug_previous_end, Color.MAGENTA)
		line(h.debug_previous_start, player.global_position, Color.MAGENTA)
		line(h.debug_previous_start, point, Color(0.7,0.4,0.9))
		line(player.global_position, point, h.tint)
	var manager: DestructionManager = get_tree().get_first_node_in_group("destruction_manager")
	if is_instance_valid(manager) and manager.last_hit_age < 3:
		var hit := manager.last_hit_position
		line(hit-Vector3.ONE, hit+Vector3.ONE, Color.RED)
	geometry.surface_end()
