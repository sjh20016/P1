extends Node3D

var started: bool = false
var menu_open: bool = true
var run_time: float = 0.0
var resets: int = 0
var practice_mode: bool = false
@onready var player: RavagePlayer = $Player
@onready var manager: DestructionManager = $DestructionManager

func _enter_tree() -> void:
	preload("res://scripts/debug/input_setup.gd").install()
	add_to_group("session")

func _ready() -> void:
	player.reset_performed.connect(on_player_reset)
	player.camera_rig.rotation = Vector3(-0.07, 0, 0)
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if OS.get_cmdline_user_args().has("--smoke-test"):
		call_deferred("run_export_smoke")

func _process(delta: float) -> void:
	run_time += delta
	$SweepSign.visible = not $D13.broken
	$LaunchSign.visible = not $LaunchDeck.broken

func on_player_reset() -> void:
	resets += 1
	if $LaunchDeck.broken:
		$LaunchDeck.restore()

func run_export_smoke() -> void:
	begin()
	await get_tree().physics_frame
	sweep_practice()
	await get_tree().create_timer(0.9).timeout
	var success: bool = $D13.broken and player.velocity.is_finite() and manager.active_debris.size() <= 48
	print("EXPORT SMOKE fracture=", $D13.broken, " sweeps=", player.get_node("TentacleSweep").sweep_event_count)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(OS.get_executable_path().get_base_dir().path_join("smoke.png"))
	player.controls_enabled = false
	for hook in player.hooks:
		hook.release()
	await get_tree().create_timer(5.5).timeout
	manager.prune()
	success = success and manager.active_debris.is_empty()
	print("EXPORT SMOKE RESULT ", "PASS" if success else "FAIL")
	get_tree().quit(0 if success else 1)

func begin() -> void:
	started = true
	menu_open = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func toggle_pause() -> void:
	menu_open = not menu_open
	get_tree().paused = menu_open
	Engine.time_scale = 1.0
	$ImpactVFX.stop_until = 0
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if menu_open else Input.MOUSE_MODE_CAPTURED
	if menu_open:
		for hook in player.hooks:
			hook.release()

func restart_run() -> void:
	Engine.time_scale = 1.0
	$ImpactVFX.stop_until = 0
	manager.clear_debris()
	manager.score = 0
	manager.event_count = 0
	manager.last_hit_age = 100
	for building: DestructibleBuilding in get_tree().get_nodes_in_group("buildings"):
		building.restore()
	for segment: DestructibleSegment in get_tree().get_nodes_in_group("destructible"):
		if not segment.managed_by_building and not segment is DestructibleBuilding:
			segment.restore()
	player.spawn_position = Vector3(0, 48, 12)
	player.reset_player()
	player.camera_rig.rotation = Vector3(-0.07, 0, 0)
	player.peak_speed = 0
	player.get_node("TentacleSweep").sweep_event_count = 0
	practice_mode = false
	run_time = 0
	resets = 0
	begin()

func sweep_practice() -> void:
	restart_run()
	practice_mode = true
	player.global_position = Vector3(-10, 28, -45)
	player.velocity = Vector3(35, 0, 0)
	player.camera_rig.rotation = Vector3(0.45, -0.65, 0)
	var hook: GrappleController = player.get_node("RightHook")
	hook.attach_to($PracticeAnchor.global_position, $PracticeAnchor)

func reset_position() -> void:
	player.reset_player()
	player.camera_rig.rotation = Vector3(-0.07, 0, 0)

func _exit_tree() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
