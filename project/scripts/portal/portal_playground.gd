extends Node3D

@export var forest_enabled: bool = true
@export var canyon_enabled: bool = true
var canyon: PortalCanyon

const STATIONS := ["A · 高差弹射", "B · 水平穿越", "C · 90° 转向", "D · 高速撞墙", "E · 碎块循环", "F · 空间切割", "G · 连续组合", "H · 可破坏塔"]
const BASES := [Vector3(0,0,0), Vector3(65,0,0), Vector3(125,0,0), Vector3(0,0,100), Vector3(65,0,100), Vector3(125,0,100), Vector3(0,0,180), Vector3(65,0,180)]
var player: RavagePlayer
var manager: DestructionManager
var portals: PortalManager
var ability: PortalAbility
var cut: SpatialCutAbility
var zone: Node3D
var profile := PortalProfile.new()
var station: int = 0
var projectiles: Array = []
var impact_vfx: Node3D
var hud: CanvasLayer
var magic: PortalMagic
var links: PortalLinkAbility
var windows: PortalWindowRenderer
var presentation: PortalPresentation
var character: PortalCharacter
var skill_vfx: PortalSkillVFX
var fracture_field: PortalFractureField
var frame_ms: Array[float] = []
var last_frame_us: int = 0

func _ready() -> void:
	if get_tree().has_meta("portal_reload_canyon"):
		canyon_enabled = get_tree().get_meta("portal_reload_canyon")
		get_tree().remove_meta("portal_reload_canyon")
	if get_tree().has_meta("portal_reload_forest"):
		forest_enabled = get_tree().get_meta("portal_reload_forest")
		get_tree().remove_meta("portal_reload_forest")
	if get_tree().has_meta("portal_reload_magic"):
		profile.magic_enabled = get_tree().get_meta("portal_reload_magic")
		get_tree().remove_meta("portal_reload_magic")
	preload("res://scripts/debug/input_setup.gd").install()
	manager = DestructionManager.new(); add_child(manager)
	fracture_field = PortalFractureField.new(); add_child(fracture_field)
	var kinetic := KineticImpact.new(); kinetic.manager = manager; add_child(kinetic)
	portals = PortalManager.new(); portals.profile = profile; portals.impact = kinetic; add_child(portals)
	zone = preload("res://scripts/portal/portal_destruction_zone.gd").new(); zone.session = self; add_child(zone)
	build_world()
	player = preload("res://scenes/player/player.tscn").instantiate()
	# Compose a separate ability loadout before entering the scene tree.
	player.get_node("LeftHook").free(); player.get_node("RightHook").free()
	player.profile = player.profile.duplicate(); player.profile.reset_depth = -80
	if forest_enabled and canyon_enabled: player.profile.reset_depth = -65
	player.profile.max_speed = profile.max_portal_velocity
	player.spawn_position = Vector3(0,49,10); add_child(player)
	player.collision_mask = 3 | 16
	var shake := preload("res://scripts/camera/camera_shake.gd").new(); shake.name = "CameraShake"; player.add_child(shake)
	cut = SpatialCutAbility.new(); cut.portals = portals; cut.manager = manager; add_child(cut)
	ability = PortalAbility.new(); ability.player = player; ability.portals = portals; ability.cut = cut; add_child(ability)
	magic = PortalMagic.new(); magic.player = player; magic.portals = portals; magic.legacy = cut; add_child(magic)
	links = PortalLinkAbility.new(); links.player = player; links.portals = portals; add_child(links); magic.links = links
	ability.magic = magic
	var feedback := preload("res://scripts/portal/portal_feedback.gd").new(); feedback.player = player; feedback.portals = portals; add_child(feedback)
	impact_vfx = preload("res://scripts/vfx/impact_vfx.gd").new(); add_child(impact_vfx)
	windows = PortalWindowRenderer.new(); windows.portals = portals; windows.viewer = player.camera_rig.camera; add_child(windows)
	presentation = PortalPresentation.new(); presentation.portals = portals; presentation.player = player; add_child(presentation)
	character = PortalCharacter.new(); character.name = "PortalCharacter"
	character.player = player; character.magic = magic; character.presentation = presentation
	character.position.y = -0.72; player.add_child(character)
	player.camera_rig.position.y = 0.6
	player.get_node("Core").hide()
	magic.loop_actor.character = character
	skill_vfx = PortalSkillVFX.new(); skill_vfx.player = player; skill_vfx.character = character
	skill_vfx.magic = magic; skill_vfx.presentation = presentation; add_child(skill_vfx)
	hud = preload("res://scripts/portal/portal_debug_hud.gd").new(); hud.game = self; add_child(hud)
	if profile.magic_enabled: call_deferred("start_magic")
	else: call_deferred("select_station", 0)

func build_world() -> void:
	var world := WorldEnvironment.new(); var env := Environment.new()
	env.background_mode = Environment.BG_COLOR; env.background_color = Color(0.73,0.75,0.77)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.ambient_light_color = Color.WHITE; env.ambient_light_energy = 0.7
	world.environment = env; add_child(world)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-50,-30,0); sun.light_energy = 1.5; sun.shadow_enabled = true; add_child(sun)
	if forest_enabled:
		if canyon_enabled:
			env.ambient_light_energy = 0.5; sun.light_energy = 0.8
			canyon = PortalCanyon.new(); canyon.game = self; add_child(canyon); return
		build_forest(); return
	for i in 8:
		var p: Vector3 = BASES[i]
		box(p + Vector3(0,-0.5,0), Vector3(38,1,44))
		label(STATIONS[i], p + Vector3(-15,2,19))
	for i in [0,3]:
		var p: Vector3 = BASES[i]
		box(p + Vector3(0,10,-17), Vector3(16,20,1))
		box(p + Vector3(0,47.5 if i == 0 else 25.5,10), Vector3(10,1,8))
		box(p + Vector3(0,-0.5,29), Vector3(30,1,48))
		tower(p + Vector3(0,18,28), 0)
	box(BASES[1] + Vector3(0,7,-12), Vector3(16,14,1))
	box(BASES[1] + Vector3(0,7,12), Vector3(16,14,1))
	box(BASES[2] + Vector3(0,7,-12), Vector3(16,14,1))
	box(BASES[2] + Vector3(13,7,0), Vector3(1,14,16))
	box(BASES[4] + Vector3(0,32.5,0), Vector3(12,1,12))
	label("L：投放循环块 / 修改高处出口释放动能", BASES[4] + Vector3(0,5,12))
	tower(BASES[5] + Vector3(0,18,0), 3)
	box(BASES[5] + Vector3(-16,12,0), Vector3(1,18,16))
	box(BASES[5] + Vector3(16,12,0), Vector3(1,18,16))
	box(BASES[6] + Vector3(0,16,-16), Vector3(16,32,1))
	box(BASES[6] + Vector3(-16,16,0), Vector3(1,32,16))
	box(BASES[6] + Vector3(10,20,0), Vector3(10,1,10))
	tower(BASES[7] + Vector3(0,18,0), 3)
	box(BASES[7] + Vector3(0,12,-19), Vector3(16,24,1))

func build_forest() -> void:
	box(Vector3(0,-0.5,-145),Vector3(410,1,410))
	for row in 9:
		for column in 9:
			var kind := 3 if row % 3 == 0 and column % 3 == 1 else (2 if (row + column) % 7 == 0 else 0)
			tower(Vector3((column - 4) * 38,18,-row * 38),kind)

func forest_spawn(index: int) -> Vector3:
	return Vector3(((index % 3) - 1) * 114,2,-int(index / 3) * 114 + 30) if index > 0 else Vector3(0,2,34)

func box(where: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new(); body.position = where; body.collision_layer = 1; body.collision_mask = 0
	var shape := CollisionShape3D.new(); var geometry := BoxShape3D.new(); geometry.size = size; shape.shape = geometry; body.add_child(shape)
	var visual := MeshInstance3D.new(); var mesh := BoxMesh.new(); mesh.size = size
	var material := StandardMaterial3D.new(); material.albedo_color = Color(0.87,0.87,0.84); material.roughness = 0.95
	mesh.material = material; visual.mesh = mesh; body.add_child(visual); add_child(body)
	return body

func tower(where: Vector3, kind: int) -> void:
	var building = preload("res://scripts/open/open_tower.gd").new()
	building.state = OpenDamageState.new(); building.state.kind = kind; building.state.id = zone.towers.size()
	building.zone = zone; building.position = where; zone.add_child(building)
	building.set_near(not forest_enabled or where.distance_to(Vector3(0,2,34)) < 150)
	zone.towers.append(building); zone.states.append(building.state)

func label(text: String, where: Vector3) -> void:
	var sign := Label3D.new(); sign.text = text; sign.position = where
	sign.font = preload("res://assets/placeholders/ui_zh.tres"); sign.font_size = 48; sign.pixel_size = 0.024
	sign.modulate = Color(0.03,0.03,0.035); sign.outline_size = 0; sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(sign)

func select_station(index: int) -> void:
	station = index; portals.clear(); cut.cancel()
	if is_instance_valid(canyon):
		player.spawn_position = canyon.spawn_point(index); player.reset_player("vertical_canyon")
		canyon.refresh_interest(player.global_position)
		player.camera_rig.rotation = Vector3(-0.16,-0.23,0)
		portals.status = "垂直峡谷 · 原始资产场景 · 132 座塔均支持局部破坏 · V 移动切割门"
		return
	if forest_enabled:
		player.spawn_position = forest_spawn(index); player.reset_player("forest_sector")
		zone.refresh_interest()
		player.camera_rig.rotation = Vector3(0.22,0,0)
		portals.status = "塔林区域 %d / 8 · 81 座可破坏塔 · 鼠标旋转切面 · V 移动切割门" % (index + 1)
		return
	var p: Vector3 = BASES[index]
	var spawn := p + Vector3(0,2,7)
	match index:
		0,3:
			portals.place(p + Vector3(0,8,0), Vector3.DOWN, 0)
			portals.place(p + Vector3(0,10,-10), Vector3.FORWARD, 1)
			spawn = p + Vector3(0,49 if index == 0 else 27,10)
		1:
			portals.place(p + Vector3(0,4,0), Vector3.FORWARD, 0)
			portals.place(p + Vector3(0,4,0), Vector3.BACK, 1)
		2:
			portals.place(p + Vector3(0,4,0), Vector3.FORWARD, 0)
			portals.place(p + Vector3(0,4,0), Vector3.RIGHT, 1)
		4:
			# In the action loadout B remains the replaceable output, including
			# the gravity loop. Keep classic station ordering for old controls.
			portals.place(p + Vector3(0,28,0), Vector3.UP, 1 if profile.magic_enabled else 0)
			portals.place(p + Vector3(0,5,0), Vector3.DOWN, 0 if profile.magic_enabled else 1)
			spawn = p + Vector3(10,2,10)
		5:
			portals.place(p + Vector3(-12,12,0), Vector3.LEFT, 0)
			portals.place(p + Vector3(12,12,0), Vector3.RIGHT, 1)
			spawn = p + Vector3(0,2,19)
		6:
			portals.place(p + Vector3(0,5,0), Vector3.DOWN, 0)
			portals.place(p + Vector3(0,24,-10), Vector3.FORWARD, 1)
			spawn = p + Vector3(10,22,0)
		7:
			portals.place(p + Vector3(0,12,-13), Vector3.FORWARD, 1)
			spawn = p + Vector3(0,2,19)
	player.spawn_position = spawn; player.reset_player("station")
	player.camera_rig.rotation = Vector3(-0.95 if index in [0,3] else -0.08, 0, 0)
	portals.status = STATIONS[index] + "  /  可重新放置两门；F6 高差落下演示"
	if profile.magic_enabled: portals.status = STATIONS[index] + " · 左键突进 / Shift 蓄速 / 长按空格切割"

func start_magic() -> void:
	select_station(0); portals.clear()
	if forest_enabled: return
	player.spawn_position = Vector3(0,2,48); player.reset_player("magic_yard")
	player.camera_rig.rotation = Vector3(0.30,0,0)
	portals.status = "瞄准前方建筑 · Shift 蓄速，再按发射 · 长按空格选切割点"

func toggle_magic() -> void:
	magic.reset(); cut.cancel()
	profile.magic_enabled = not profile.magic_enabled
	if profile.magic_enabled: start_magic()
	else: select_station(station)

func drop_trial() -> void:
	select_station(0)
	if is_instance_valid(canyon):
		player.global_position += Vector3.UP * 35; player.camera_rig.rotation = Vector3(-1.15,0,0); return
	if forest_enabled:
		player.global_position = Vector3(19,48,20); player.camera_rig.rotation = Vector3(-1.15,0,0); return
	player.global_position = Vector3(0,48,0); player.velocity = Vector3.ZERO
	player.camera_rig.rotation = Vector3(-1.15, 0, 0)

func link_trial() -> void:
	select_station(1)
	if is_instance_valid(canyon):
		portals.install_cut_pair(canyon.markers.ROUTE_01,Vector3.BACK,3.2)
		portals.gates[0].global_position = canyon.markers.ROUTE_01
		portals.gates[1].global_position = canyon.markers.ROUTE_05
		for gate in portals.gates: gate.traversal_enabled = true
		player.global_position = canyon.markers.ROUTE_01 + Vector3.BACK * 10
		player.camera_rig.rotation = Vector3.ZERO; canyon.refresh_interest(player.global_position); return
	if forest_enabled:
		portals.place(Vector3(0,12,20),Vector3.FORWARD,0)
		portals.place(Vector3(38,12,-90),Vector3.FORWARD,1)
		player.spawn_position = Vector3(0,7,25); player.reset_player("forest_links")
		player.camera_rig.rotation = Vector3(0.22,0,0); zone.refresh_interest(); return
	portals.place(Vector3(65,7,0),Vector3.FORWARD,0)
	portals.place(Vector3(69,18,168),Vector3.FORWARD,1)
	player.spawn_position = Vector3(65,5,-4); player.reset_player("link_trial")
	player.camera_rig.rotation = Vector3(0.10,0,0)
	portals.status = "实体投送 · 门内看远方塔 · F 冲门 / T 投块 / G 改出口 · Shift 可先蓄速"

func spawn_projectile(loop: bool = false) -> RigidBody3D:
	projectiles = projectiles.filter(func(body): return is_instance_valid(body) and not body.is_queued_for_deletion())
	if projectiles.size() >= 8:
		var old: RigidBody3D = projectiles.pop_front(); old.freeze = true; old.collision_layer = 0; old.queue_free()
	var body := preload("res://scripts/portal/portal_projectile.gd").new(); body.portals = portals
	var shape := CollisionShape3D.new(); var sphere := SphereShape3D.new(); sphere.radius = 0.45; shape.shape = sphere; body.add_child(shape)
	var visual := MeshInstance3D.new(); var mesh := SphereMesh.new(); mesh.radius = 0.45; mesh.height = 0.9
	var material := StandardMaterial3D.new(); material.albedo_color = Color(0.10,0.11,0.13); mesh.material = material
	visual.mesh = mesh; body.add_child(visual); add_child(body)
	if loop and not forest_enabled:
		body.global_position = BASES[4] + Vector3(0,25,0); body.linear_velocity = Vector3.DOWN * 3
	else:
		var camera: Camera3D = player.camera_rig.camera
		var direction: Vector3 = -camera.global_basis.z
		body.global_position = player.global_position + Vector3.UP + direction * 1.5
		body.linear_velocity = direction * 28 + player.velocity
		if profile.magic_enabled: body.linear_velocity = links.throw_velocity(body.global_position,28) + player.velocity
	body.angular_velocity = Vector3(1,2,3); projectiles.append(body); return body

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	if event.physical_keycode == KEY_F5:
		reload_playground(); return
	if event.physical_keycode == KEY_F3:
		hud.toggle_debug(); return
	if event.physical_keycode == KEY_F4:
		toggle_magic(); return
	if event.physical_keycode == KEY_ESCAPE:
		player.controls_enabled = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
		return
	if not player.controls_enabled: return
	if event.physical_keycode >= KEY_1 and event.physical_keycode <= KEY_8: select_station(event.physical_keycode - KEY_1)
	if event.physical_keycode == KEY_F6: drop_trial()
	if event.physical_keycode == KEY_F7: link_trial()
	if event.physical_keycode == KEY_T: spawn_projectile()
	if event.physical_keycode == KEY_L:
		select_station(4); spawn_projectile(true)

func reload_playground() -> void:
	get_tree().set_meta("portal_reload_canyon",canyon_enabled)
	get_tree().set_meta("portal_reload_forest",forest_enabled)
	get_tree().set_meta("portal_reload_magic",profile.magic_enabled)
	Engine.time_scale = 1; get_tree().reload_current_scene()

func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	if last_frame_us > 0 and frame_ms.size() < 36000: frame_ms.append((now - last_frame_us) / 1000.0)
	last_frame_us = now

func _exit_tree() -> void:
	Engine.time_scale = 1.0
