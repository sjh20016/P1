extends Node

var player: RavagePlayer
var voices:Dictionary={}
var tension_audio:=AudioStreamPlayer.new()
var sounds:Dictionary={}

func _ready() -> void:
	player=get_parent()
	add_child(tension_audio)
	for name in ["fire","attach","miss","release","tension"]:
		sounds[name]=load("res://assets/placeholders/grapple_"+name+".wav")
		var voice:=AudioStreamPlayer.new()
		voice.stream=sounds[name]
		voice.max_polyphony=2
		add_child(voice)
		voices[name]=voice
	var hum:AudioStreamWAV=sounds.tension.duplicate()
	hum.loop_mode=AudioStreamWAV.LOOP_FORWARD
	hum.loop_end=hum.data.size()/2
	tension_audio.stream=hum
	tension_audio.volume_db=-60
	call_deferred("connect_hooks")
	player.wall_launched.connect(func(): play("attach",-12))

func connect_hooks() -> void:
	for hook in player.hooks:
		hook.fired.connect(on_fire)
		hook.attached.connect(on_attach.bind(hook))
		hook.released.connect(on_release)

func play(name: String,volume: float) -> void:
	if DisplayServer.get_name()=="headless": return
	var voice:AudioStreamPlayer=voices[name]
	voice.volume_db=volume
	voice.play()

func on_fire(success: bool) -> void:
	# Attach has its own stronger transient; the fire layer stays quiet.
	play("fire" if success else "miss",-19 if success else -12)
	if player.has_node("InkBody"): player.get_node("InkBody").pressure=0.2

func on_attach(hook: GrappleController) -> void:
	play("attach",-10)
	if player.has_node("CameraShake"):
		player.get_node("CameraShake").directional_kick((hook.grapple_point-player.global_position).normalized(),0.11)
	player.camera_rig.impact_pulse=maxf(player.camera_rig.impact_pulse,1.2)

func on_release() -> void:
	play("release",-16)

func _process(_delta: float) -> void:
	var maximum:=0.0
	for hook in player.hooks:
		if hook.active: maximum=maxf(maximum,hook.tension/hook.profile.maximum_hook_force)
	if maximum>0.05 and DisplayServer.get_name()!="headless":
		if not tension_audio.playing: tension_audio.play()
		tension_audio.volume_db=lerpf(-38,-24,maximum)
		tension_audio.pitch_scale=lerpf(0.8,1.4,maximum)
	else: tension_audio.stop()
