class_name PortalLinkAbility
extends Node3D

# Physical routes remain available inside the action loadout. Q modifies only
# placement; it never switches the whole character to a different game mode.
var player: RavagePlayer
var portals: PortalManager
var editing: bool = false
var held_buttons: Dictionary = {}
var commands: Array[int] = []
var preview: MeshInstance3D
var preview_clock: float = 0
var preview_text: String = ""
var dives: int = 0

func _ready() -> void:
	process_physics_priority = -6
	preview = MeshInstance3D.new(); add_child(preview)
	var torus := TorusMesh.new(); torus.inner_radius = 0.96; torus.outer_radius = 1
	var material := StandardMaterial3D.new(); material.albedo_color = Color(0.06,0.06,0.07)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	torus.material = material; preview.mesh = torus; preview.hide()
	player.reset_performed.connect(cancel_edit)

func handle_input(event: InputEvent) -> bool:
	if event is InputEventKey and not event.echo:
		if event.physical_keycode == KEY_Q:
			editing = event.pressed
			if editing: portals.cue("link_aim")
			return true
		if event.pressed and event.physical_keycode == KEY_G:
			if portals.gates[0] != null and portals.gates[1] != null: queue_place(1)
			else: portals.status = "先用 Q + 左 / 右键布置一对实体门"
			return true
		if event.pressed and event.physical_keycode == KEY_C:
			portals.clear(); portals.status = "实体连接已收回"; return true
	if event is InputEventMouseButton:
		var button: int = event.button_index
		if not event.pressed and held_buttons.has(button):
			held_buttons.erase(button); return true
		if editing and button in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT]:
			if event.pressed:
				held_buttons[button] = true; queue_place(0 if button == MOUSE_BUTTON_LEFT else 1)
			return true
	return false

func queue_place(slot: int) -> void:
	if commands.size() < 4: commands.append(slot)

func _physics_process(delta: float) -> void:
	if not portals.profile.magic_enabled or not player.controls_enabled:
		cancel_edit(); return
	var queued := commands.duplicate(); commands.clear()
	for slot in queued:
		var camera: Camera3D = player.camera_rig.camera
		if portals.place(camera.global_position,-camera.global_basis.z,slot):
			portals.cue("link_place",{"slot":slot,"pose":portals.gates[slot].global_transform})
	preview.visible = false
	if not editing: return
	preview_clock -= delta
	if preview_clock <= 0:
		preview_clock = 0.05
		var camera: Camera3D = player.camera_rig.camera
		var hit := portals.placement(camera.global_position,-camera.global_basis.z,0)
		# A may be too close to B while B can validly be moved here. Preview the
		# feasible slot, and still validate the chosen button when committing.
		if not hit.ok: hit = portals.placement(camera.global_position,-camera.global_basis.z,1)
		preview_text = "左键放 A / 右键放 B · 松 Q 返回技能" if hit.ok else hit.reason
		preview.set_meta("valid",hit.ok)
		if hit.ok:
			preview.global_transform = Transform3D(hit.basis * Basis(Vector3.RIGHT,PI/2),hit.point + hit.basis.z * 0.06)
			preview.scale = Vector3.ONE * portals.profile.portal_size
	preview.visible = preview.get_meta("valid",false)

func aimed_gate(min_alignment: float = 0.65) -> PortalComponent:
	if portals.gates[0] == null or portals.gates[1] == null: return null
	var gate: PortalComponent = null
	var best: float = -1
	var aim: Vector3 = -player.camera_rig.global_basis.z
	for candidate: PortalComponent in portals.gates:
		var offset: Vector3 = candidate.global_position - player.global_position
		if offset.length() > portals.profile.link_dive_range or offset.length() < 1.0: continue
		if candidate.to_local(player.global_position).z < 0.75 or not candidate.valid_surface(): continue
		var alignment := aim.dot(offset.normalized())
		if alignment > min_alignment and alignment > best: gate = candidate; best = alignment
	return gate

func throw_velocity(origin: Vector3, speed: float) -> Vector3:
	var gate := aimed_gate(0.96)
	if gate == null: return -player.camera_rig.global_basis.z * speed
	var delta := gate.global_position - origin
	var time := maxf(0.02,delta.length() / speed)
	return (delta / time + Vector3.UP * 25.0 * time * 0.5).limit_length(portals.profile.max_portal_velocity)

func dive(speed: float) -> bool:
	var gate := aimed_gate()
	if gate == null:
		portals.status = "瞄准 %.0f m 内已连接实体门的正面，再按 F 冲入" % portals.profile.link_dive_range; return false
	var delta := gate.global_position - player.global_position
	var launch_speed := clampf(maxf(speed,portals.profile.link_dive_speed),0,portals.profile.max_portal_velocity)
	var time := delta.length() / maxf(launch_speed,1)
	# Ballistic lead helps an ordinary lunge reach the opening. World collisions
	# still run for the entire route; F never teleports through intervening walls.
	player.velocity = (delta / time + Vector3.UP * player.profile.gravity * time * 0.5).limit_length(portals.profile.max_portal_velocity)
	dives += 1
	portals.cue("dive",{"target":gate.global_position,"velocity":player.velocity,"slot":gate.slot})
	portals.status = "实体冲门 · 出口方向决定弹射路线"
	return true

func cancel_edit() -> void:
	editing = false; held_buttons.clear(); commands.clear(); preview_clock = 0
	if is_instance_valid(preview): preview.hide()
