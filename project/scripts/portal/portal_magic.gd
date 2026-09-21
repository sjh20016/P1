class_name PortalMagic
extends Node

enum Mode { FREE, AIMING, BOOSTING, BOOST_AIM, EDITING, MARKED, CUT_CHARGE, TRANSIT }
var right_aim := false
var mode: Mode = Mode.FREE
var player: RavagePlayer
var portals: PortalManager
var legacy: SpatialCutAbility
var links: PortalLinkAbility
var guide: PortalGuide
var volume: PortalVolumeCut
var boost_speed: float = 0
var boost_time: float = 0
var boost_velocity := Vector3.ZERO
var loop_visuals: Array[PortalComponent] = []
var dash_left: float = 0
var slow_left: float = 0
var hover_left: float = 0
var charge: float = 0
var space_down: bool = false
var space_age: float = 0
var space_consumed: bool = false
var commands: Array[String] = []
var cut_point := Vector3.ZERO
var cut_normal := Vector3.UP
var pending_rotation := Vector2.ZERO
var loop_actor: PortalLoopActor
var cut_radius: float = 2.4
var last_launch_speed: float = 0
var last_cast_point := Vector3.ZERO

func _ready() -> void:
	process_physics_priority = -5
	guide = PortalGuide.new(); guide.portals = portals; guide.player = player; portals.add_child(guide)
	volume = PortalVolumeCut.new(); volume.portals = portals; volume.legacy = legacy; portals.add_child(volume)
	player.reset_performed.connect(reset)
	loop_actor = PortalLoopActor.new(); loop_actor.player = player; add_child(loop_actor)

func _unhandled_input(event: InputEvent) -> void:
	if not portals.profile.magic_enabled: return
	if event is InputEventKey and event.pressed and event.physical_keycode in [KEY_ESCAPE,KEY_F3]:
		cancel()
		if is_instance_valid(links): links.cancel_edit()
		return
	if not player.controls_enabled or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED: return
	if is_instance_valid(links) and links.handle_input(event):
		if links.editing and mode != Mode.FREE: cancel()
		return
	if is_instance_valid(links) and links.editing: return
	if event is InputEventMouseMotion and mode in [Mode.MARKED,Mode.CUT_CHARGE]:
		pending_rotation += event.relative
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT: queue_command("aim" if event.pressed else "fire")
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				right_aim = mode not in [Mode.EDITING,Mode.MARKED,Mode.CUT_CHARGE]
				queue_command("aim" if right_aim else "charge")
			else:
				queue_command("fire" if right_aim else "cut"); right_aim = false
	if event is InputEventKey and not event.echo:
		if event.physical_keycode == KEY_SPACE:
			queue_command("space_down" if event.pressed else "space_up")
		if event.pressed and event.physical_keycode == KEY_SHIFT: queue_command("boost")
		if event.pressed and event.physical_keycode == KEY_X: queue_command("cancel")
		if event.pressed and event.physical_keycode == KEY_F: queue_command("dive")

func queue_command(command: String) -> void:
	# Mutations and world queries are executed on the physics tick, not in input.
	if commands.size() < 16: commands.append(command)

func _physics_process(delta: float) -> void:
	dash_left = maxf(0,dash_left - delta)
	if mode == Mode.TRANSIT and portals.pending_dash.is_empty():
		mode = Mode.FREE; dash_left = portals.profile.dash_cooldown
	if not portals.profile.magic_enabled or not player.controls_enabled:
		if mode != Mode.FREE or not commands.is_empty(): cancel()
		return
	if is_instance_valid(links) and links.editing:
		if mode != Mode.FREE or not commands.is_empty(): cancel()
		return
	var queued := commands.duplicate(); commands.clear()
	for command in queued: handle(command)
	if mode in [Mode.MARKED,Mode.CUT_CHARGE] and not pending_rotation.is_zero_approx():
		rotate_cut(pending_rotation); pending_rotation = Vector2.ZERO
	slow_left = maxf(0,slow_left - delta)
	if space_down and not space_consumed:
		space_age += delta
		if space_age >= portals.profile.space_hold_delay:
			space_consumed = true; begin_edit()
	if mode in [Mode.AIMING,Mode.BOOST_AIM,Mode.EDITING]: guide.advance(delta)
	if mode == Mode.EDITING:
		hover_left = maxf(0,hover_left - delta)
		if guide.stopped or hover_left <= 0: lock_cut()
	if mode in [Mode.BOOSTING,Mode.BOOST_AIM]:
		boost_time += delta
		boost_speed = minf(portals.profile.max_portal_velocity,boost_speed + portals.profile.boost_acceleration * delta)
		update_loop()
		loop_actor.advance(delta,boost_speed / portals.profile.max_portal_velocity)
	if mode == Mode.CUT_CHARGE:
		charge = minf(portals.profile.cut_charge_time,charge + delta)
		cut_radius = lerpf(portals.profile.cut_min_radius,portals.profile.cut_max_radius,charge / portals.profile.cut_charge_time)
		guide.update_visual(cut_radius)

func handle(command: String) -> void:
	if mode == Mode.TRANSIT and command != "cancel": return
	match command:
		"aim":
			if mode == Mode.EDITING or mode == Mode.CUT_CHARGE: return
			mode = Mode.BOOST_AIM if mode in [Mode.BOOSTING,Mode.BOOST_AIM] else Mode.AIMING
			guide.begin(false)
			portals.cue("dash_aim")
		"fire":
			if mode in [Mode.AIMING,Mode.BOOST_AIM]: launch(guide.snapshot())
		"boost":
			if mode in [Mode.BOOSTING,Mode.BOOST_AIM]: launch(guide.snapshot() if mode == Mode.BOOST_AIM else guide.quick_target())
			else: begin_boost()
		"dive":
			if dash_left > 0 or not is_instance_valid(links): return
			var speed := boost_speed if mode in [Mode.BOOSTING,Mode.BOOST_AIM] else player.velocity.length()
			if links.dive(speed):
				mode = Mode.FREE; slow_left = 0; hover_left = 0; boost_speed = 0
				space_down = false; guide.cancel(); clear_loop(); dash_left = portals.profile.dash_cooldown
		"space_down":
			space_down = true; space_age = 0; space_consumed = false
		"space_up":
			space_down = false
			if mode == Mode.EDITING: lock_cut()
		"charge":
			if mode == Mode.EDITING: lock_cut()
			if mode != Mode.MARKED: return
			if legacy.cooldown > 0:
				portals.status = "空间切割冷却中"; return
			mode = Mode.CUT_CHARGE; charge = 0; cut_radius = portals.profile.cut_min_radius
			portals.cue("cut_charge",{"point":cut_point})
		"cut":
			if mode == Mode.CUT_CHARGE:
				if volume.request(cut_point,cut_radius,cut_normal):
					last_cast_point = cut_point; mode = Mode.FREE; guide.cancel()
				else: mode = Mode.MARKED
		"cancel": cancel()

func begin_boost() -> void:
	guide.cancel(); clear_loop(); slow_left = 0
	boost_velocity = player.velocity
	boost_speed = clampf(maxf(player.velocity.length(),portals.profile.boost_start_speed),0,portals.profile.max_portal_velocity)
	boost_time = 0; mode = Mode.BOOSTING
	loop_actor.begin()
	portals.cue("boost_start",{"speed":boost_speed})
	for i in 2:
		var gate := PortalComponent.new(); gate.radius = 1.35; gate.slot = i; gate.show_label = false
		portals.add_child(gate); gate.build_visual(); loop_visuals.append(gate)
	update_loop(); portals.status = "头脚空间回路 · 再按 Shift 发射 / 左键选出口"

func update_loop() -> void:
	for i in loop_visuals.size():
		var gate: PortalComponent = loop_visuals[i]
		gate.global_transform = Transform3D(PortalPhysics.frame(Vector3.UP),player.global_position + Vector3.UP * (-0.78 if i == 0 else 1.9))
		gate.scale = Vector3.ONE * (1.0 + sin(boost_time * (14 + boost_speed * 0.1)) * 0.08)

func clear_loop() -> void:
	if is_instance_valid(loop_actor): loop_actor.finish()
	for gate in loop_visuals:
		if is_instance_valid(gate): gate.queue_free()
	loop_visuals.clear()

func launch(target: Dictionary) -> void:
	var boosting := mode in [Mode.BOOSTING,Mode.BOOST_AIM]
	if dash_left > 0:
		portals.status = "突进恢复中"
		mode = Mode.BOOSTING if boosting else Mode.FREE; guide.cancel(); return
	var speed := boost_speed if boosting else maxf(player.velocity.length(),portals.profile.dash_min_speed)
	if not portals.magic_dash(player,target,speed):
		# A failed placement spends neither stored energy nor the current velocity.
		mode = Mode.BOOSTING if boosting else Mode.FREE
		guide.cancel(); return
	last_launch_speed = speed; dash_left = portals.profile.dash_cooldown
	mode = Mode.TRANSIT; slow_left = 0; hover_left = 0
	guide.cancel(); clear_loop(); boost_speed = 0

func begin_edit() -> void:
	if mode in [Mode.BOOSTING,Mode.BOOST_AIM]: clear_loop(); boost_speed = 0
	mode = Mode.EDITING; hover_left = portals.profile.edit_hover_duration
	slow_left = portals.profile.slow_fall_duration; guide.begin(true)
	portals.cue("cut_edit")
	portals.status = "悬浮选点 · 鼠标引导 · 松空格锁点"

func lock_cut() -> void:
	guide.lock(); cut_point = guide.point
	cut_normal = Vector3.UP; guide.cut_normal = cut_normal; pending_rotation = Vector2.ZERO
	cut_radius = portals.profile.cut_min_radius; mode = Mode.MARKED
	hover_left = 0; slow_left = portals.profile.slow_fall_duration
	portals.cue("cut_lock",{"point":cut_point})
	portals.status = "切割点已锁定 · 鼠标旋转切面 · 右键蓄力扩大，松开切断"

func rotate_cut(motion: Vector2) -> void:
	var right := player.camera_rig.global_basis.x.normalized()
	var forward := -player.camera_rig.global_basis.z.normalized()
	cut_normal = (Basis(forward,-motion.x * 0.006) * Basis(right,-motion.y * 0.006) * cut_normal).normalized()
	guide.cut_normal = cut_normal; guide.update_visual(cut_radius)

func filter_motion(delta: float) -> void:
	if not portals.profile.magic_enabled: return
	# Manager releases velocity before the player's motion signal. Do not let the
	# still-pending animation mode erase that velocity before our own next tick.
	if mode == Mode.TRANSIT and portals.pending_dash.is_empty():
		mode = Mode.FREE; dash_left = portals.profile.dash_cooldown
	if mode in [Mode.BOOSTING,Mode.BOOST_AIM,Mode.TRANSIT]:
		# Store bounded kinetic speed in the spatial loop instead of repeatedly
		# teleporting the camera between two coincident colliders every frame.
		player.velocity = Vector3.ZERO
	elif mode == Mode.EDITING or slow_left > 0:
		player.velocity.x *= exp(-7 * delta); player.velocity.z *= exp(-7 * delta)
		if mode == Mode.EDITING: player.velocity.y = 0
		else: player.velocity.y = maxf(player.velocity.y,-portals.profile.slow_fall_speed)

func hint() -> String:
	match mode:
		Mode.AIMING: return "出口飞行 %.0f m · 松键生成入口并穿门 · 双门保留" % guide.distance
		Mode.TRANSIT: return "入口展开 → 穿门 → 出口弹射 · X 可取消"
		Mode.BOOSTING,Mode.BOOST_AIM: return "回路蓄速 %03.0f / %.0f m/s · Shift 发射 / 左键定向" % [boost_speed,portals.profile.max_portal_velocity]
		Mode.EDITING: return "悬浮 %.1f s · 鼠标引导标记 · 松空格锁定" % hover_left
		Mode.MARKED: return "鼠标旋转切面 · 按住右键蓄力 / 左键转为移动"
		Mode.CUT_CHARGE: return "切割直径 %.1f m · 鼠标旋转 · 松右键展开双门" % (cut_radius * 2)
	return "左 / 右键选出口，松开穿门 · Shift 蓄速 · 长按空格选切割点"

func cancel() -> void:
	portals.cancel_dash()
	if mode != Mode.FREE: portals.cue("cancel")
	if mode in [Mode.BOOSTING,Mode.BOOST_AIM]: player.velocity = boost_velocity
	mode = Mode.FREE; space_down = false; space_consumed = false; space_age = 0
	slow_left = 0; hover_left = 0; charge = 0; boost_speed = 0; commands.clear()
	pending_rotation = Vector2.ZERO
	guide.cancel(); clear_loop()

func reset() -> void:
	# Reset owns the motion state: never restore pre-loop velocity on an R reset.
	portals.cancel_dash(false)
	mode = Mode.FREE; cancel(); dash_left = 0; volume.cancel()
	if is_instance_valid(links): links.cancel_edit()
