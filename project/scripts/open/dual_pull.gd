extends Node

const CHARGE_SECONDS:float=0.85
const MIN_TENSION:float=28.0
var zone:Node3D
var player:CharacterBody3D
var charge:float=0
var cooldown:float=0
var hint:String="双钩抓住两座牵引核，按住 Q 拉断"
var targets:Array=[]
var ready_pair:bool=false
var cue_stage:int=0
var strain_audio:AudioStreamPlayer3D

func _ready() -> void:
	zone=get_parent();player=zone.session.player
	player.reset_performed.connect(cancel)
	strain_audio=AudioStreamPlayer3D.new()
	strain_audio.stream=preload("res://assets/placeholders/impact_crack.wav")
	strain_audio.max_polyphony=1;strain_audio.unit_size=12;strain_audio.max_distance=80
	add_child(strain_audio)

func hint_visible() -> bool:
	if ready_pair or charge>0 or cooldown>0: return true
	for hook in player.hooks:
		if hook.active and is_instance_valid(hook.target) and hook.target.has_method("can_pull") and hook.target.state.kind==4:
			return true
	return false

func _physics_process(delta:float) -> void:
	if zone.loading or not player.controls_enabled: return
	step(delta,Input.is_action_pressed("reel_in"))

func pair_error(left,right) -> String:
	if not left.active or not right.active: return "双钩抓住两座牵引核，按住 Q 拉断"
	var a=left.target;var b=right.target
	if not is_instance_valid(a) or not is_instance_valid(b): return "抓点已失效"
	if a==b: return "左右触手需要抓住两座不同的塔"
	if not a.has_method("can_pull") or not b.has_method("can_pull") or not a.can_pull() or not b.can_pull():
		return "寻找带黑环的牵引核"
	if not a.anchor_valid(left.grapple_point) or not b.anchor_valid(right.grapple_point): return "抓点已破坏，重新瞄准黑环"
	if a.to_local(left.grapple_point).y< -5 or b.to_local(right.grapple_point).y< -5: return "抓住弱缝上方的黑环"
	var span:Vector3=(b.global_position-a.global_position).slide(Vector3.UP)
	if span.length()<24 or span.length()>84 or absf(a.global_position.y-b.global_position.y)>12:
		return "选择彼此靠近的两座牵引核"
	var along:float=(player.global_position-a.global_position).dot(span)/span.length_squared()
	if along<0.12 or along>0.88: return "移动到两座塔之间再牵引"
	if not zone.has_macro_capacity(2): return "等待当前倒塌落稳，再发起双拉"
	return ""

func step(delta:float,pulling:bool) -> void:
	cooldown=maxf(0,cooldown-delta)
	if cooldown>0: return
	var left=player.hooks[0];var right=player.hooks[1]
	var reason:=pair_error(left,right)
	ready_pair=reason.is_empty()
	if not ready_pair:
		clear_preview();hint=reason;return
	if targets.size()!=2 or targets[0]!=left.target or targets[1]!=right.target:
		clear_preview();targets=[left.target,right.target]
	if not pulling:
		charge=maxf(0,charge-delta*2)
		hint="两侧已抓稳 · 按住 Q，扯断后飞离交汇处"
	elif minf(left.tension,right.tension)<MIN_TENSION:
		charge=maxf(0,charge-delta)
		hint="保持双钩，收绳建立两侧张力"
	else:
		charge=minf(1,charge+delta/CHARGE_SECONDS*clampf(minf(left.tension,right.tension)/65.0,0.6,1.25))
		hint="牵引蓄力 · 保持双钩与 Q，断裂后自动松钩"
	for tower in targets: tower.set_pull_charge(charge)
	var stage:int=2 if charge>=0.65 else (1 if charge>=0.2 else 0)
	if stage>cue_stage:
		cue_stage=stage
		strain_audio.global_position=(targets[0].global_position+targets[1].global_position)*0.5
		strain_audio.pitch_scale=0.6 if stage==1 else 0.82
		strain_audio.volume_db=-18 if stage==1 else -13
		if DisplayServer.get_name()!="headless": strain_audio.play()
	if charge==0: cue_stage=0
	if charge>=1:
		var launched:bool=zone.begin_dual_pull(targets[0],targets[1],left.grapple_point,right.grapple_point,minf(left.tension,right.tension))
		clear_preview()
		if launched:
			left.release();right.release();cooldown=1.4
			hint="牵引断裂！保持惯性，飞离交汇处"
		else:
			ready_pair=false;hint="牵引中断，重新选择两侧抓点"

func clear_preview() -> void:
	for tower in targets:
		if is_instance_valid(tower): tower.set_pull_charge(0)
	targets.clear();charge=0;cue_stage=0
	if is_instance_valid(strain_audio): strain_audio.stop()

func cancel() -> void:
	clear_preview();cooldown=0;ready_pair=false
	hint="双钩抓住两座牵引核，按住 Q 拉断"

func _exit_tree() -> void:
	clear_preview()
