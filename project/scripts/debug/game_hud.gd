extends Control

const INK := Color(0.032,0.051,0.063)
const PAPER := Color(0.88,0.93,0.91)
const MUTED := Color(0.52,0.64,0.65)
const MINT := Color(0.56,0.94,0.79)
const ORANGE := Color(1.0,0.56,0.36)
var font: Font
var session: Node3D
var player: RavagePlayer
var manager: DestructionManager
var debug_enabled: bool = false
var aim: Dictionary = {}
var aim_clock: float = 0.0
var start_button: Rect2
var practice_button: Rect2

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	font = ThemeDB.fallback_font
	session = get_tree().get_first_node_in_group("session")
	player = get_tree().get_first_node_in_group("player")
	manager = get_tree().get_first_node_in_group("destruction_manager")

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_ESCAPE:
				session.toggle_pause()
				get_viewport().set_input_as_handled()
			KEY_ENTER:
				if session.menu_open:
					session.begin()
			KEY_F2:
				session.sweep_practice()
			KEY_F3:
				debug_enabled = not debug_enabled
			KEY_F5:
				session.restart_run()
			KEY_F11:
				var fullscreen := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if fullscreen else DisplayServer.WINDOW_MODE_FULLSCREEN)
	if session.menu_open and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if start_button.has_point(event.position):
			session.begin()
		elif practice_button.has_point(event.position):
			session.sweep_practice()
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	aim_clock -= delta
	if aim_clock <= 0 and not get_tree().paused:
		aim = player.hooks[0].aim_result()
		aim_clock = 0.05
	queue_redraw()

func text_at(value: String, position: Vector2, size: int = 16, color: Color = PAPER) -> void:
	draw_string(font, position, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func panel(rect: Rect2, alpha: float = 0.88) -> void:
	draw_style_box(box_style(Color(INK, alpha)), rect)

func box_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 3
	return style

func _draw() -> void:
	var view := get_viewport_rect().size
	var w := view.x
	var h := view.y
	var speed := player.velocity.length()
	panel(Rect2(30,28,302,66),0.7)
	draw_rect(Rect2(30,30,3,62), MINT)
	text_at("R A V A G E", Vector2(46,57), 28)
	text_at("TOWERFALL   /   PROTOTYPE 0.01", Vector2(46,81), 12, MUTED)
	panel(Rect2(w-292,30,262,68),0.78)
	text_at("DESTRUCTION",Vector2(w-275,53),11,MUTED)
	text_at("%06d" % manager.score,Vector2(w-275,83),28)
	text_at("%02d / 14" % manager.event_count,Vector2(w-120,83),17,ORANGE)
	if session.menu_open:
		draw_menu(view)
		return
	var center := view * 0.5
	var can_grab := not aim.is_empty()
	var tint := MINT if can_grab else Color(PAPER,0.45)
	draw_arc(center, 8, 0, TAU, 24, tint, 1.2, true)
	draw_circle(center, 1.8, tint)
	for offset: Vector2 in [Vector2(-16,0),Vector2(16,0),Vector2(0,-16),Vector2(0,16)]:
		draw_line(center+offset*0.8,center+offset,tint,1.2,true)
	if can_grab:
		text_at("%.0f m" % player.global_position.distance_to(aim.position),center+Vector2(18,5),12,MINT)
	var hint := "HOLD LMB / RMB TO ANCHOR    ·    RELEASE TO FLY"
	if session.practice_mode:
		hint = "SWEEP LAB   /   TAUT TENTACLE + SPEED = FRACTURE"
	text_at(hint,Vector2(w*0.5-225,45),12,MINT)
	panel(Rect2(22,h-150,207,144),0.74)
	panel(Rect2(w-277,h-92,255,82),0.74)
	text_at("VELOCITY",Vector2(34,h-128),11,MUTED)
	text_at("%02d" % roundi(speed),Vector2(30,h-58),68)
	text_at("m/s",Vector2(131,h-59),16,MUTED)
	draw_rect(Rect2(34,h-42,180,3),Color(MUTED,0.25))
	draw_rect(Rect2(34,h-42,180*speed/player.profile.max_speed,3),ORANGE if speed>=42 else MINT)
	text_at("BREAK 19+    /    HEAVY 42+",Vector2(34,h-22),10,MUTED)
	for i in player.hooks.size():
		draw_hook(player.hooks[i],Vector2(w*0.5-232+i*240,h-112),i)
	text_at("WASD  STEER     SPACE  JUMP     Q / E  REEL",Vector2(w*0.5-222,h-25),11,MUTED)
	text_at("R  RESPawn   /   F5  NEW RUN".to_upper(),Vector2(w-260,h-72),11,MUTED)
	text_at("F2  SWEEP LAB   /   F3  DEBUG",Vector2(w-260,h-49),11,MUTED)
	text_at("ESC  PAUSE   /   F11  FULLSCREEN",Vector2(w-260,h-26),10,MUTED)
	if manager.last_hit_age < 1.5:
		var alpha := clampf(1.5-manager.last_hit_age,0,1)
		text_at(manager.last_impact_name + " / FRACTURE",Vector2(w*0.5-126,h*0.32),25,Color(ORANGE,alpha))
	if debug_enabled:
		draw_debug()

func draw_hook(hook: GrappleController, point: Vector2, index: int) -> void:
	panel(Rect2(point,Vector2(224,67)),0.86)
	draw_rect(Rect2(point,Vector2(3,67)),hook.tint)
	text_at("LMB / LEFT" if index==0 else "RMB / RIGHT",point+Vector2(15,21),11,MUTED)
	text_at("TENSION" if hook.active and hook.tension>6 else ("SLACK" if hook.active else "READY"),point+Vector2(15,45),17,hook.tint)
	if hook.active:
		text_at("%.0f m" % hook.current_length,point+Vector2(158,44),16,PAPER)
	draw_rect(Rect2(point+Vector2(15,55),Vector2(194,2)),Color(MUTED,0.2))
	draw_rect(Rect2(point+Vector2(15,55),Vector2(194*hook.tension/hook.profile.maximum_hook_force,2)),hook.tint)

func draw_debug() -> void:
	panel(Rect2(30,120,405,228),0.93)
	text_at("TELEMETRY / F3",Vector2(46,145),13,MINT)
	var lines: Array[String] = ["FPS %d  |  physics 120 Hz" % Engine.get_frames_per_second(),
		"velocity " + str(player.velocity.snapped(Vector3.ONE*0.1)),
		"speed %.2f / peak %.2f" % [player.velocity.length(),player.peak_speed],
		"rigid %d / %d | peak %d" % [manager.active_debris.size(),manager.rigidbody_budget,manager.peak_rigidbodies],
		"breaks %d | sweeps %d" % [manager.event_count,player.get_node("TentacleSweep").sweep_event_count]]
	for hook in player.hooks:
		lines.append("%s %s len %.1f rest %.1f T %.1f" % ["L" if hook.action==&"hook_left" else "R","ON" if hook.active else "OFF",hook.current_length,hook.rest_length,hook.tension])
	for i in lines.size():
		text_at(lines[i],Vector2(46,173+i*23),13,PAPER)

func draw_menu(view: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO,view),Color(0.018,0.031,0.04,0.6))
	var origin := Vector2(72,view.y*0.23)
	text_at("01 / KINETIC DESTRUCTION STUDY",origin,13,MINT)
	text_at("THE CITY",origin+Vector2(0,79),68)
	text_at("IS YOUR",origin+Vector2(0,151),68)
	text_at("SLINGSHOT.",origin+Vector2(0,223),68,MINT)
	text_at("GRAB. SWING. RELEASE. SHATTER.",origin+Vector2(3,266),15)
	text_at("A black core. Two tendrils. One finite canyon.",origin+Vector2(3,294),14,MUTED)
	start_button = Rect2(origin+Vector2(0,328),Vector2(236,53))
	draw_rect(start_button,MINT)
	text_at("RESUME  /  ENTER" if session.started else "ENTER THE CANYON",start_button.position+Vector2(20,33),17,INK)
	practice_button = Rect2(origin+Vector2(252,328),Vector2(215,53))
	draw_rect(practice_button,Color(PAPER,0.09))
	draw_rect(practice_button,Color(PAPER,0.4),false,1)
	text_at("SWEEP LAB  /  F2",practice_button.position+Vector2(20,33),16,PAPER)
	var x := view.x - 387
	var y := view.y*0.35
	text_at("FIELD GUIDE",Vector2(x,y),13,MINT)
	var guide: Array[String] = ["01   AIM AT A WALL OR CYAN SOCKET","02   HOLD EITHER MOUSE BUTTON","03   STEER WITH WASD WHILE FALLING","04   RELEASE TO KEEP YOUR SPEED","05   HIT OR SWEEP THE ORANGE PANELS"]
	for i in guide.size():
		text_at(guide[i],Vector2(x,y+42+i*40),12,PAPER)
	text_at("Q / E    Shorten / lengthen tendrils",Vector2(x,y+271),12,MUTED)
	text_at("SPACE    Jump from the launch deck",Vector2(x,y+296),12,MUTED)
	text_at("R    Respawn    ·    F5    Restore all targets",Vector2(x,y+321),12,MUTED)
	text_at("F3   Telemetry    ·    F11   Fullscreen",Vector2(x,y+346),12,MUTED)
	text_at("FIXED BLENDER MAP / 14 BREAKABLE SEGMENTS / 48 DEBRIS LIMIT",Vector2(74,view.y-34),11,MUTED)
