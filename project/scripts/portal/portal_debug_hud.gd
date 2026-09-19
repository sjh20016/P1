extends CanvasLayer

var game: Node3D
var readout: Label
var debug_panel: PanelContainer
var status: Label

func _ready() -> void:
	var root := Control.new(); root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); root.mouse_filter = Control.MOUSE_FILTER_IGNORE; add_child(root)
	var heading := Label.new(); heading.position = Vector2(26,20); heading.text = "RAVAGE / 空间破坏实验  0.01"; heading.add_theme_font_size_override("font_size", 26); root.add_child(heading)
	readout = Label.new(); readout.position = Vector2(26,60); root.add_child(readout)
	status = Label.new(); status.position = Vector2(26,730); status.add_theme_font_size_override("font_size",18); root.add_child(status)
	var instructions := Label.new(); instructions.position = Vector2(26,780)
	instructions.text = "WASD 移动 · 空格 跳跃 · 左 / 右键 A / B · Q 切割 · E 紧急入口 · T 投块\n1–8 测试区 · F6 高差试跳 · L 循环实验 · R 回起点 · F5 全重置 · X 清门 · F3 参数 · Esc 鼠标"
	root.add_child(instructions)
	var cross := Label.new(); cross.text = "+"; cross.set_anchors_and_offsets_preset(Control.PRESET_CENTER); cross.position -= Vector2(7,15); cross.add_theme_font_size_override("font_size",24); root.add_child(cross)
	for item in [heading, readout, status, instructions, cross]:
		item.add_theme_font_override("font", preload("res://assets/placeholders/ui_zh.tres"))
		item.add_theme_color_override("font_color", Color(0.02,0.025,0.03))
		item.add_theme_color_override("font_outline_color", Color(0.95,0.95,0.92,0.8))
		item.add_theme_constant_override("outline_size", 4)
	debug_panel = PanelContainer.new(); debug_panel.position = Vector2(970,20); debug_panel.size = Vector2(440,640); root.add_child(debug_panel)
	var rows := VBoxContainer.new(); debug_panel.add_child(rows)
	var title := Label.new(); title.text = "LIVE PARAMETERS (F3)"; rows.add_child(title)
	var fields := {
		"placement_range": [10,220,1], "portal_size": [1.2,5,0.1], "exit_offset": [0.08,1,0.02],
		"momentum_multiplier": [0.8,1.2,0.02], "max_portal_velocity": [35,140,1], "portal_cooldown": [0.08,0.6,0.02],
		"object_mass_limit": [0.5,50,0.5], "spatial_cut_damage": [26,100,1], "spatial_cut_width": [0.2,4,0.1],
		"spatial_cut_cooldown": [0.3,5,0.1], "high_speed_impact_threshold": [15,55,1],
		"camera_blend": [0.001,0.2,0.005], "fov_boost": [0,18,1], "high_speed_fov": [76,105,1], "exit_camera_stabilization": [0,0.3,0.01]}
	for key: String in fields:
		var row := HBoxContainer.new(); rows.add_child(row)
		var label := Label.new(); label.text = key; label.custom_minimum_size.x = 260; row.add_child(label)
		var spin := SpinBox.new(); spin.min_value = fields[key][0]; spin.max_value = fields[key][1]; spin.step = fields[key][2]; spin.value = game.profile.get(key); row.add_child(spin)
		spin.value_changed.connect(func(value):
			game.profile.set(key,value); game.profile.sanitize()
			if key == "portal_size": game.portals.clear())
	var check := CheckButton.new(); check.text = "Emergency Portal (auto / experimental)"; rows.add_child(check)
	check.toggled.connect(func(value): game.profile.emergency_portal_enabled = value)
	debug_panel.hide()

func toggle_debug() -> void:
	debug_panel.visible = not debug_panel.visible
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if debug_panel.visible else Input.MOUSE_MODE_CAPTURED
	game.player.controls_enabled = not debug_panel.visible

func _process(_delta: float) -> void:
	readout.text = "%s\n速度  %05.1f m/s    穿越 %d / 物体 %d    破坏 %d\n碎块 %d / 48    宏块 %d / 3    切割冷却 %.1f s\nFPS %d    物理 %.2f ms    出口受阻 %d" % [game.STATIONS[game.station], game.player.velocity.length(), game.portals.traversal_count, game.portals.object_traversals, game.manager.damage_events, game.manager.active_debris.size(), game.zone.active.size(), game.cut.cooldown, Engine.get_frames_per_second(), Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000, game.portals.blocked_count]
	status.text = game.portals.status + "\n" + game.ability.preview_text
