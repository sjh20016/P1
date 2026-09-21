extends CanvasLayer

var game: Node3D
var readout: Label
var debug_panel: PanelContainer
var status: Label
var instructions: Label

func _ready() -> void:
	var root := Control.new(); root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); root.mouse_filter = Control.MOUSE_FILTER_IGNORE; add_child(root)
	var heading := Label.new(); heading.position = Vector2(26,20); heading.text = "RAVAGE / 空间破坏 · 魔法操作"; heading.add_theme_font_size_override("font_size", 26); root.add_child(heading)
	readout = Label.new(); readout.position = Vector2(26,60); root.add_child(readout)
	status = Label.new(); status.position = Vector2(26,690); status.add_theme_font_size_override("font_size",18); root.add_child(status)
	instructions = Label.new(); instructions.position = Vector2(26,750)
	instructions.text = "WASD 移动 · 空格 跳跃 · 左 / 右键 A / B · Q 切割 · E 紧急入口 · T 投块\n1–8 测试区 · F6 高差试跳 · L 循环实验 · R 回起点 · F5 全重置 · X 清门 · F3 参数 · Esc 鼠标"
	root.add_child(instructions)
	var cross := Label.new(); cross.text = "+"; cross.set_anchors_and_offsets_preset(Control.PRESET_CENTER); cross.position -= Vector2(7,15); cross.add_theme_font_size_override("font_size",24); root.add_child(cross)
	for item in [heading, readout, status, instructions, cross]:
		item.add_theme_font_override("font", preload("res://assets/placeholders/ui_zh.tres"))
		item.add_theme_color_override("font_color", Color(0.02,0.025,0.03))
		item.add_theme_color_override("font_outline_color", Color(0.95,0.95,0.92,0.8))
		item.add_theme_constant_override("outline_size", 4)
	debug_panel = PanelContainer.new(); debug_panel.position = Vector2(970,20); debug_panel.size = Vector2(440,640); root.add_child(debug_panel)
	var scroll := ScrollContainer.new(); scroll.custom_minimum_size = Vector2(440,640); debug_panel.add_child(scroll)
	var rows := VBoxContainer.new(); scroll.add_child(rows)
	var title := Label.new(); title.text = "LIVE PARAMETERS (F3)"; rows.add_child(title)
	var fields := {
		"placement_range": [10,220,1], "portal_size": [1.2,5,0.1], "exit_offset": [0.08,1,0.02],
		"momentum_multiplier": [0.8,1.2,0.02], "max_portal_velocity": [35,140,1], "portal_cooldown": [0.08,0.6,0.02],
		"object_mass_limit": [0.5,50,0.5], "spatial_cut_damage": [26,100,1], "spatial_cut_width": [0.2,4,0.1],
		"spatial_cut_cooldown": [0.3,5,0.1], "high_speed_impact_threshold": [15,55,1],
		"camera_blend": [0.001,0.2,0.005], "fov_boost": [0,18,1], "high_speed_fov": [76,105,1], "exit_camera_stabilization": [0,0.3,0.01],
		"guide_speed": [40,220,5], "guide_range": [15,180,5], "dash_min_speed": [26,100,1],
		"quick_cast_distance": [8,110,1], "dash_cooldown": [0.12,1,0.02], "impact_runup": [2,15,0.5],
		"boost_acceleration": [10,120,2], "boost_start_speed": [0,100,1],
		"space_hold_delay": [0.12,0.4,0.02], "edit_hover_duration": [0.2,2,0.1],
		"slow_fall_duration": [0.5,5,0.1], "slow_fall_speed": [1,8,0.5],
		"cut_min_radius": [1,6,0.2], "cut_max_radius": [6,18,0.5], "cut_charge_time": [0.3,3,0.1],
		"link_dive_range": [8,45,1], "link_dive_speed": [35,100,1],
		"portal_view_resolution": [128,1024,128], "portal_view_fps": [10,60,5], "portal_view_distance": [20,160,5]}
	for key: String in fields:
		var row := HBoxContainer.new(); rows.add_child(row)
		var label := Label.new(); label.text = key; label.custom_minimum_size.x = 260; row.add_child(label)
		var spin := SpinBox.new(); spin.min_value = fields[key][0]; spin.max_value = fields[key][1]; spin.step = fields[key][2]; spin.value = game.profile.get(key); row.add_child(spin)
		spin.value_changed.connect(func(value):
			game.profile.set(key,value); game.profile.sanitize()
			if key == "portal_size": game.portals.clear())
	var check := CheckButton.new(); check.text = "Emergency Portal (auto / experimental)"; rows.add_child(check)
	check.toggled.connect(func(value): game.profile.emergency_portal_enabled = value)
	var views := CheckButton.new(); views.text = "Live portal windows"; views.button_pressed = game.profile.portal_view_enabled; rows.add_child(views)
	views.toggled.connect(func(value): game.profile.portal_view_enabled = value)
	debug_panel.hide()

func toggle_debug() -> void:
	debug_panel.visible = not debug_panel.visible
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if debug_panel.visible else Input.MOUSE_MODE_CAPTURED
	game.player.controls_enabled = not debug_panel.visible

func _process(_delta: float) -> void:
	readout.text = "%s\n速度  %05.1f m/s    穿越 %d / 物体 %d    破坏 %d\n碎块 %d / 48    宏块 %d / 3    切割冷却 %.1f s\nFPS %d    物理 %.2f ms    出口受阻 %d" % [game.STATIONS[game.station], game.player.velocity.length(), game.portals.traversal_count, game.portals.object_traversals, game.manager.damage_events, game.manager.active_debris.size(), game.zone.active.size(), game.cut.cooldown, Engine.get_frames_per_second(), Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000, game.portals.blocked_count]
	status.text = game.portals.status + "\n" + game.ability.preview_text
	readout.text += "\n建筑碎块：运动 %d / 24 · 悬空 %d · 待分离 %d" % [game.fracture_field.active_count(),game.fracture_field.pieces.size()-game.fracture_field.active_count(),game.fracture_field.pending.size()]
	readout.text += "\n布置/切割门 %d / 2 · 移动残留门 %d / 2 · 门内视野 %d / 2" % [int(game.portals.gates[0] != null) + int(game.portals.gates[1] != null),game.portals.dash_gates.size(),game.windows.active_views]
	if game.forest_enabled:
		readout.text = readout.text.replace(game.STATIONS[game.station],"开放塔林 · 81 座可破坏塔")
		if is_instance_valid(game.canyon): readout.text = readout.text.replace("开放塔林 · 81 座可破坏塔","垂直峡谷 · 132 座可破坏塔 / 370 个场景物件")
	if game.profile.magic_enabled:
		instructions.text = "左 / 右键选出口，松开穿门（双门保留）· Shift 蓄速 / 再按穿门\n长按空格选点 → 松开 → 鼠标旋转 / 右键蓄力切割 · V 移动残留门 / 滚轮远近\nQ + 左 / 右键放 A / B · F 冲门 · G 改 B · C 收门 · WASD 移动 · X 取消 · R 复位 · F5 重建"
	else:
		instructions.text = "WASD 移动 · 空格 跳跃 · 左 / 右键 A / B · Q 切割 · E 紧急入口 · T 投块\n1–8 测试区 · F6 高差试跳 · L 循环实验 · R 回起点 · F5 全重置 · X 清门 · F4 魔法操作 · F3 参数"
