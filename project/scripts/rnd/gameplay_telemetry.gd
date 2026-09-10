class_name GameplayTelemetry
extends Node

var player: RavagePlayer
var manager: DestructionManager
var elapsed: float=0.0
var speed_integral: float=0.0
var peak: float=0.0
var above_30: float=0.0
var first_grapple: float=-1.0
var t20: float=-1.0
var t30: float=-1.0
var shots: int=0
var misses: int=0
var attaches: int=0
var distance_sum: float=0.0
var recoveries: int=0
var resets: int=0
var body_impacts: int=0
var slashes: int=0
var impact_speed_sum: float=0.0
var impact_loss_sum: float=0.0
var releases: Array[float]=[]
var events: Array[Dictionary]=[]
var last_saved_path: String=""

func _ready() -> void:
	add_to_group("telemetry")
	player=get_tree().get_first_node_in_group("player")
	manager=get_tree().get_first_node_in_group("destruction_manager")
	player.motion_completed.connect(sample)
	player.reset_performed.connect(on_reset)
	player.fall_recovered.connect(func(): recoveries+=1; event("recovery"))
	player.wall_launched.connect(func(): event("wall_launch",{"speed":player.velocity.length()}))
	for hook in player.hooks:
		hook.fired.connect(on_fire)
		hook.attached.connect(on_attach.bind(hook))
		hook.released.connect(on_release.bind(hook))
	manager.impact_reported.connect(on_impact)

func event(kind: String, data: Dictionary={}) -> void:
	if events.size()>=5000: events.pop_front()
	var row:=data.duplicate()
	row["event"]=kind
	row["seconds"]=elapsed
	row["position"]=[player.global_position.x,player.global_position.y,player.global_position.z]
	events.append(row)

func sample(delta: float) -> void:
	elapsed+=delta
	var speed:=player.velocity.length()
	speed_integral+=speed*delta
	peak=maxf(peak,speed)
	if speed>=30: above_30+=delta
	if first_grapple>=0:
		if t20<0 and speed>=20: t20=elapsed-first_grapple
		if t30<0 and speed>=30: t30=elapsed-first_grapple

func on_fire(success: bool) -> void:
	shots+=1
	if not success: misses+=1
	event("fire",{"success":success})

func on_attach(hook: GrappleController) -> void:
	attaches+=1
	if first_grapple<0: first_grapple=elapsed
	var distance:=player.global_position.distance_to(hook.grapple_point)
	distance_sum+=distance
	event("attach",{"distance":distance,"speed":player.velocity.length(),"selection":hook.targeting.reason})

func on_release(hook: GrappleController) -> void:
	releases.append(player.velocity.length())
	if releases.size()>2000: releases.pop_front()
	event("release",{"speed":player.velocity.length(),"action":hook.status_text,"charge":hook.charge})

func on_reset() -> void:
	if player.reset_reason in ["initial","new_run","experiment"]: return
	resets+=1
	event("reset",{"reason":player.reset_reason})

func on_impact(context: Dictionary) -> void:
	var kind:String=context.get("kind","BREAK")
	if kind=="BODY":
		body_impacts+=1
		impact_speed_sum+=float(context.get("before",0.0))
		impact_loss_sum+=float(context.get("before",0.0))-float(context.get("after",0.0))
	elif kind=="SLASH": slashes+=1
	event(kind.to_lower(),{"before":context.get("before",0.0),"after":context.get("after",0.0),"normal_speed":context.get("normal_speed",0.0)})

func summary() -> Dictionary:
	return {"version":"0.03","model":player.hooks[0].profile.movement_model+1,"physics_hz":Engine.physics_ticks_per_second,"seconds":elapsed,"first_grapple_time":first_grapple,"shots":shots,"miss_rate":float(misses)/maxi(shots,1),"successful_grapples":attaches,"average_grapple_distance":distance_sum/maxi(attaches,1),"time_to_20_after_first_grapple":t20,"time_to_30_after_first_grapple":t30,"average_speed":speed_integral/maxf(elapsed,0.001),"peak_speed":peak,"time_above_30":above_30,"release_speeds":releases,"fall_recoveries":recoveries,"resets":resets,"body_impacts":body_impacts,"tentacle_sweeps":slashes,"average_impact_speed":impact_speed_sum/maxi(body_impacts,1),"average_impact_speed_loss":impact_loss_sum/maxi(body_impacts,1)}

func save_run(path: String="") -> String:
	if path.is_empty():
		DirAccess.make_dir_recursive_absolute("user://telemetry003")
		path="user://telemetry003/run-"+Time.get_datetime_string_from_system().replace(":","-")+"-"+str(Time.get_ticks_msec())+".json"
	var file:=FileAccess.open(path,FileAccess.WRITE)
	if file==null: return ""
	file.store_string(JSON.stringify({"summary":summary(),"events":events},"\t"))
	file.close()
	last_saved_path=ProjectSettings.globalize_path(path)
	print("TELEMETRY ",last_saved_path)
	return last_saved_path

func clear_run() -> void:
	elapsed=0; speed_integral=0; peak=0; above_30=0
	first_grapple=-1; t20=-1; t30=-1
	shots=0; misses=0; attaches=0; distance_sum=0
	recoveries=0; resets=0; body_impacts=0; slashes=0
	impact_speed_sum=0; impact_loss_sum=0
	releases.clear(); events.clear()
