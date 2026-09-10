extends Control

const PANEL := Color(0.97,0.964,0.944)
const TEXT := Color(0.025,0.025,0.026)
const MUTED := Color(0.34,0.34,0.33)
const ACCENT := Color(0.045,0.045,0.045)
const STRONG := Color(0.005,0.005,0.005)
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
					if session.started: session.begin()
					else: session.start_course()
			KEY_F2:
				session.sweep_practice()
			KEY_F3:
				debug_enabled = not debug_enabled
			KEY_F5:
				session.restart_active_run()
			KEY_F4: session.restart_run()
			KEY_F6: session.start_course()
			KEY_F7:
				player.wall_experiment=not player.wall_experiment
				session.notice="WALL LAB ON / SHIFT HOLD + SPACE LAUNCH" if player.wall_experiment else "WALL LAB OFF"
				session.notice_time=3.0
			KEY_F8: session.save_telemetry()
			KEY_F10:
				if debug_enabled and is_instance_valid(session.course): session.course.skip_station()
			KEY_1: session.set_movement_model(0)
			KEY_2: session.set_movement_model(1)
			KEY_3: session.set_movement_model(2)
			KEY_F11:
				var fullscreen := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if fullscreen else DisplayServer.WINDOW_MODE_FULLSCREEN)
	if session.menu_open and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if start_button.has_point(event.position):
			if session.started: session.begin()
			else: session.start_course()
		elif practice_button.has_point(event.position):
			session.sweep_practice()
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	aim_clock -= delta
	if aim_clock <= 0 and not get_tree().paused:
		aim = player.hooks[0].aim_result()
		aim_clock = 0.05
	queue_redraw()

func text_at(value: String, position: Vector2, size: int = 16, color: Color = TEXT) -> void:
	draw_string(font, position, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func panel(rect: Rect2, alpha: float = 0.88) -> void:
	draw_style_box(box_style(Color(PANEL, alpha)), rect)

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
	draw_rect(Rect2(30,30,3,62), ACCENT)
	text_at("R A V A G E", Vector2(46,57), 28)
	text_at("0.03   /   MOMENTUM + IMPACT", Vector2(46,81), 12, MUTED)
	panel(Rect2(w-292,30,262,68),0.78)
	text_at("DESTRUCTION",Vector2(w-275,53),11,MUTED)
	text_at("%06d" % manager.score,Vector2(w-275,83),28)
	text_at("%03d BREAKS" % manager.event_count,Vector2(w-145,83),15,STRONG)
	if session.menu_open:
		draw_menu(view)
		return
	var center := view * 0.5
	var can_grab := not aim.is_empty()
	var tint := ACCENT if can_grab else Color(TEXT,0.45)
	draw_arc(center, 8, 0, TAU, 24, Color(PANEL,0.85), 3.2, true)
	draw_arc(center, 8, 0, TAU, 24, tint, 1.2, true)
	draw_circle(center, 1.8, tint)
	for offset: Vector2 in [Vector2(-16,0),Vector2(16,0),Vector2(0,-16),Vector2(0,16)]:
		draw_line(center+offset*0.8,center+offset,tint,1.2,true)
	if can_grab:
		text_at("%.0f m" % player.global_position.distance_to(aim.position),center+Vector2(18,5),12,ACCENT)
		var camera:Camera3D=player.get_viewport().get_camera_3d()
		if not camera.is_position_behind(aim.position):
			var dot:=camera.unproject_position(aim.position)
			draw_circle(dot,5,Color(PANEL,0.9))
			draw_arc(dot,4,0,TAU,16,TEXT,1.5,true)
			if dot.distance_to(center)>10: draw_line(center,dot,Color(TEXT,0.3),1,true)
	for hook in player.hooks:
		if hook.status_time>0 and not hook.active:
			text_at(hook.status_text,center+Vector2(22,31),12,TEXT)
	var hint := "HOLD LMB / RMB TO ANCHOR    ·    RELEASE TO FLY"
	if session.practice_mode:
		hint = "SWEEP LAB   /   TAUT TENTACLE + SPEED = FRACTURE"
	text_at(hint,Vector2(w*0.5-225,45),12,ACCENT)
	if is_instance_valid(session.course): draw_course(view)
	if session.notice_time>0:
		panel(Rect2(w*0.5-250,h-206,500,35),0.95)
		text_at(session.notice,Vector2(w*0.5-233,h-183),13,TEXT)
	elif player.fall_grace:
		panel(Rect2(w*0.5-210,h-206,420,35),0.95)
		text_at("FALL GRACE / LOOK TOWARD A WALL AND GRAB",Vector2(w*0.5-198,h-183),12,TEXT)
	panel(Rect2(22,h-150,207,144),0.74)
	panel(Rect2(w-277,h-92,255,82),0.74)
	text_at("VELOCITY",Vector2(34,h-128),11,MUTED)
	text_at("%02d" % roundi(speed),Vector2(30,h-58),68)
	text_at("m/s",Vector2(131,h-59),16,MUTED)
	draw_rect(Rect2(34,h-42,180,3),Color(MUTED,0.25))
	draw_rect(Rect2(34,h-42,180*speed/player.profile.max_speed,3),STRONG if speed>=42 else ACCENT)
	text_at("RAM 26+   /   SLASH 20+ + TENSION",Vector2(34,h-22),10,MUTED)
	for i in player.hooks.size():
		draw_hook(player.hooks[i],Vector2(w*0.5-232+i*240,h-112),i)
	text_at("WASD  STEER     SPACE  JUMP     Q / E  REEL",Vector2(w*0.5-222,h-25),11,MUTED)
	text_at("R  RESPawn   /   F5  NEW RUN".to_upper(),Vector2(w-260,h-72),11,MUTED)
	text_at("F6  COURSE   /   F8  SAVE RUN",Vector2(w-260,h-49),11,MUTED)
	text_at("F3  DEBUG   /   ESC  PAUSE",Vector2(w-260,h-26),10,MUTED)
	if manager.last_hit_age < 1.5:
		var alpha := clampf(1.5-manager.last_hit_age,0,1)
		var kind:String=manager.last_context.get("kind","BREAK")
		text_at(("SEVER / " if kind=="SLASH" else "RAM / ")+manager.last_impact_name,Vector2(w*0.5-115,h*0.32),25,Color(STRONG,alpha))
	if debug_enabled:
		draw_debug()

func draw_hook(hook: GrappleController, point: Vector2, index: int) -> void:
	panel(Rect2(point,Vector2(224,67)),0.86)
	draw_rect(Rect2(point,Vector2(3,67)),TEXT)
	text_at("LMB / LEFT" if index==0 else "RMB / RIGHT",point+Vector2(15,21),11,MUTED)
	var state:="CHARGE %02d%%" % roundi(hook.charge*100) if hook.charge>0.25 and hook.active else ("SWING" if hook.active and hook.tension>6 else ("SLACK" if hook.active else "READY"))
	text_at(state,point+Vector2(15,45),17,TEXT)
	if hook.active:
		text_at("%.0f m" % hook.current_length,point+Vector2(158,44),16,TEXT)
	draw_rect(Rect2(point+Vector2(15,55),Vector2(194,2)),Color(MUTED,0.2))
	draw_rect(Rect2(point+Vector2(15,55),Vector2(194*hook.tension/hook.profile.maximum_hook_force,2)),TEXT)

func draw_debug() -> void:
	panel(Rect2(30,120,475,366),0.93)
	text_at("TELEMETRY / F3",Vector2(46,145),13,ACCENT)
	var data:Dictionary=session.get_node("Telemetry").summary()
	var lines: Array[String] = ["FPS %d | physics %d Hz | M%02d" % [Engine.get_frames_per_second(),Engine.physics_ticks_per_second,session.movement_model+1],
		"velocity " + str(player.velocity.snapped(Vector3.ONE*0.1)),
		"speed %.2f / peak %.2f" % [player.velocity.length(),player.peak_speed],
		"rigid %d / %d | peak %d" % [manager.active_debris.size(),manager.rigidbody_budget,manager.peak_rigidbodies],
		"breaks %d | sweeps %d" % [manager.event_count,player.get_node("TentacleSweep").sweep_event_count],
		"ink %d / %d" % [session.get_node("InkMarks").marks.size(),session.get_node("InkMarks").mark_budget]]
	for hook in player.hooks:
		lines.append("%s %s len %.1f rest %.1f T %.1f" % ["L" if hook.action==&"hook_left" else "R","ON" if hook.active else "OFF",hook.current_length,hook.rest_length,hook.tension])
	lines.append("target: "+player.hooks[0].targeting.reason)
	lines.append("grabs %d | miss %.0f%% | recovery %d" % [data.successful_grapples,data.miss_rate*100,data.fall_recoveries])
	lines.append("body %d | slash %d | avg loss %.1f" % [data.body_impacts,data.tentacle_sweeps,data.average_impact_speed_loss])
	lines.append("1 Spring / 2 Radial / 3 Hybrid / F8 Save")
	lines.append("F7 Wall lab / F10 Next course station")
	for i in lines.size():
		text_at(lines[i],Vector2(46,173+i*23),13,TEXT)

func draw_menu(view: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO,view),Color(PANEL,0.48))
	var origin := Vector2(72,view.y*0.23)
	text_at("03 / MOMENTUM + IMPACT",origin,13,ACCENT)
	text_at("GRAB HARD.",origin+Vector2(0,79),68)
	text_at("HIT HARD.",origin+Vector2(0,151),68)
	text_at("KEEP FLYING.",origin+Vector2(0,223),68,ACCENT)
	text_at("GRAB. SWING. RELEASE. SHATTER.",origin+Vector2(3,266),15)
	text_at("A burst of muscle. A moment of impact. Keep moving.",origin+Vector2(3,294),14,MUTED)
	start_button = Rect2(origin+Vector2(0,328),Vector2(236,53))
	draw_rect(start_button,ACCENT)
	text_at("RESUME  /  ENTER" if session.started else "ENTER TEST COURSE",start_button.position+Vector2(20,33),17,PANEL)
	practice_button = Rect2(origin+Vector2(252,328),Vector2(215,53))
	draw_rect(practice_button,Color(TEXT,0.09))
	draw_rect(practice_button,Color(TEXT,0.4),false,1)
	text_at("SWEEP LAB  /  F2",practice_button.position+Vector2(20,33),16,TEXT)
	var x := view.x - 387
	var y := view.y*0.35
	text_at("FIELD GUIDE",Vector2(x,y),13,ACCENT)
	var guide: Array[String] = ["01   TAP TO ZIP / HOLD TO SWING","02   Q REELS IN AND CHARGES A LAUNCH","03   RELEASE TO KEEP YOUR SPEED","04   RAM 26+ / TAUT TENTACLE CUT 20+","05   FALLING? LOOK UP AND GRAB AGAIN"]
	for i in guide.size():
		text_at(guide[i],Vector2(x,y+42+i*40),12,TEXT)
	text_at("1 Spring / 2 Radial / 3 Hybrid (default)",Vector2(x,y+271),12,MUTED)
	text_at("F4 Free canyon / F6 Restart course",Vector2(x,y+296),12,MUTED)
	text_at("R Checkpoint / F5 New run / F8 Save data",Vector2(x,y+321),12,MUTED)
	text_at("F3 Debug / F7 Wall lab / F11 Fullscreen",Vector2(x,y+346),12,MUTED)
	text_at("MOMENTUM / IMPACT / A THREE-MINUTE PLAYGROUND",Vector2(74,view.y-34),11,MUTED)

func draw_course(view: Vector2) -> void:
	var course:Node3D=session.course
	panel(Rect2(view.x*0.5-260,68,520,62),0.91)
	if course.completed:
		var result:="STATION CHECK COMPLETE" if course.assisted_run else "COURSE COMPLETE / %.1f s" % course.course_time
		text_at(result,Vector2(view.x*0.5-244,94),16,TEXT)
		text_at("Run data saved. F6 to replay; 1 / 2 / 3 to compare movement.",Vector2(view.x*0.5-244,116),11,MUTED)
		return
	text_at(course.stage_names[course.stage],Vector2(view.x*0.5-244,93),16,TEXT)
	text_at("%02d:%02d" % [int(course.course_time)/60,int(course.course_time)%60],Vector2(view.x*0.5+186,93),14,MUTED)
	text_at(course.hints[course.stage],Vector2(view.x*0.5-244,117),11,MUTED)
	var camera:Camera3D=player.get_viewport().get_camera_3d()
	var point:Vector3=course.waypoint()
	var screen:=camera.unproject_position(point)
	if camera.is_position_behind(point): screen=view-screen
	screen=screen.clamp(Vector2(55,160),view-Vector2(150,230))
	draw_arc(screen,13,0,TAU,24,Color(PANEL,0.9),4,true)
	draw_arc(screen,13,0,TAU,24,TEXT,1.5,true)
	text_at("NEXT %.0f m" % player.global_position.distance_to(point),screen+Vector2(18,-17),11,TEXT)
