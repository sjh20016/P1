extends Node3D

var stage: int=0
var completed: bool=false
var assisted_run: bool=false
var course_time: float=0.0
var rescue_count_at_start: int=0
var wall_launches: int=0
var structure_triggered: bool=false
var proxy: MeshInstance3D
var reaction_time: float=0.0
var proxy_start:=Transform3D.IDENTITY
var checkpoint:=Vector3(0,48,12)
var stage_names:Array[String]=["01 / SNAP INTO SPEED","02 / RAM A SHORTCUT","03 / CHAIN YOUR GRAPPLES","04 / SWEEP THE CROSSBEAM","05 / OPEN THE INNER ROUTE","06 / DIVE AND RECOVER","07 / WALL LAUNCH LAB","08 / FINAL HEAVY IMPACT"]
var hints:Array[String]=["Aim at the first ring. Tap to zip; hold to swing.","Release and hit the wall at 26+ m/s. Keep flying.","Alternate left and right hooks. Q reels and charges.","Grab the upper-right ring, then drop past the beam at 20+.","Break the front wall. An anchor is hidden inside.","Dive below the warning line. Grab to turn your fall around.","Optional: Shift holds briefly; Space kicks off the wall.","Charge with Q, release a hook, then ram the heavy gate."]
@onready var game:Node3D=get_parent()
@onready var player:RavagePlayer=game.player
@onready var telemetry:GameplayTelemetry=game.get_node("Telemetry")

func start() -> void:
	player.controls_enabled=true
	player.spawn_position=checkpoint
	player.reset_player("new_run")
	player.camera_rig.look_at($AnchorStart.global_position,Vector3.UP)
	player.wall_launched.connect(func(): wall_launches+=1)
	rescue_count_at_start=telemetry.recoveries
	telemetry.event("course_start")

func waypoint() -> Vector3:
	var points:Array[Vector3]=[$AnchorStart.global_position,$GateA.global_position,$AnchorChainR.global_position,$GateB.global_position,$ShellFront.global_position,Vector3(0,-115,-205),$WallLab.global_position,$FinalGate.global_position]
	return points[mini(stage,7)]

func _process(delta: float) -> void:
	update_reaction(delta)
	if completed: return
	course_time+=delta
	var p:=player.global_position
	var advance:=false
	match stage:
		0: advance=p.z < -36
		1: advance=$GateA.broken and p.z < -73
		2: advance=p.z < -118
		3: advance=$GateB.broken and p.z < -139
		4: advance=$ShellFront.broken and p.z < -182
		5: advance=telemetry.recoveries>rescue_count_at_start
		6: advance=wall_launches>0 or p.z < -234
		7: advance=$FinalGate.broken and p.z < -250
	if $GateB.broken and not structure_triggered:
		start_reaction()
	if advance: advance_stage()

func advance_stage() -> void:
	telemetry.event("course_stage",{"stage":stage+1,"time":course_time})
	stage+=1
	if stage==2: checkpoint=Vector3(0,41,-83)
	if stage==5:
		checkpoint=Vector3(0,40,-184)
		rescue_count_at_start=telemetry.recoveries
	if stage==6:
		checkpoint=Vector3(0,-66,-222)
		player.wall_experiment=true
	player.spawn_position=checkpoint
	if stage>=stage_names.size():
		completed=true
		telemetry.event("course_complete",{"course_seconds":course_time,"assisted":assisted_run})
		telemetry.save_run()

func start_reaction() -> void:
	structure_triggered=true
	var canopy:DestructibleSegment=$CanopyB
	if canopy.broken: return
	# One authored canopy reacts visually; its collision is removed at the same time.
	proxy=MeshInstance3D.new()
	proxy.mesh=canopy.get_node("IntactVisual").mesh
	add_child(proxy)
	proxy.global_transform=canopy.get_node("IntactVisual").global_transform
	proxy_start=proxy.global_transform
	canopy.broken=true
	canopy.collision_layer=0
	canopy.collision_mask=0
	canopy.get_node("IntactVisual").hide()
	canopy.get_node("Collision").set_deferred("disabled",true)
	telemetry.event("fake_structure",{"count":1})

func update_reaction(delta: float) -> void:
	if not is_instance_valid(proxy): return
	reaction_time+=delta
	var fall:=maxf(reaction_time-0.25,0.0)
	proxy.global_position=proxy_start.origin+Vector3(0,-8.0*fall*fall,0)
	proxy.rotation.z=sin(minf(reaction_time,1.4))*0.5
	if reaction_time>2.5:
		proxy.queue_free()

func skip_station() -> void:
	# Developer-only station selection is explicitly labelled in telemetry.
	if completed: return
	assisted_run=true
	telemetry.event("debug_station_skip",{"from":stage})
	advance_stage()
	if not completed:
		player.global_position=waypoint()+Vector3(0,-3,18)
		player.velocity=Vector3.ZERO
		player.camera_rig.look_at(waypoint(),Vector3.UP)
