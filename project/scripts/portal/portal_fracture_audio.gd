class_name PortalFractureAudio
extends Node3D

const CUES := {
	"ram":preload("res://assets/audio/destruction/ram_body.wav"),
	"stone":preload("res://assets/audio/destruction/stone_tail.wav"),
	"shear":preload("res://assets/audio/destruction/cut_shear.wav"),
	"air":preload("res://assets/audio/destruction/cut_air.wav"),
	"concrete_a":preload("res://assets/audio/destruction/concrete_a.wav"),
	"concrete_b":preload("res://assets/audio/destruction/concrete_b.wav")}
var voices: Array[AudioStreamPlayer3D] = []
var cursor := 0
var last_beat := -1000
var last_settle := -1000
var last_family := ""
var played := 0
var beat_index := 0

func _ready() -> void:
	for i in 8:
		var voice := AudioStreamPlayer3D.new(); voice.unit_size = 22; voice.max_distance = 180
		voice.max_db = 0; add_child(voice); voices.append(voice)

func cue(name: String, point: Vector3, db: float, pitch: float = 1) -> void:
	var voice := voices[cursor%voices.size()]; cursor += 1
	voice.stop(); voice.stream = CUES[name]; voice.global_position = point
	voice.volume_db = db; voice.pitch_scale = pitch; played += 1
	if DisplayServer.get_name() != "headless": voice.play()

func feedback(context: Dictionary) -> void:
	if not context.get("asset_fracture",false): return
	var now := Time.get_ticks_msec()
	if now-last_beat < 95: return
	last_beat = now; last_family = context.get("kind","BODY")
	beat_index += 1
	var point: Vector3 = context.position
	var variation := .94+float(beat_index%4)*.035
	if last_family == "SLASH":
		cue("air",point,-11,variation); cue("shear",point,-10,variation)
	else:
		cue("concrete_a" if beat_index%2==0 else "concrete_b",point,-9,variation)
		cue("ram" if last_family == "BODY" else "stone",point,-7 if last_family == "BODY" else -14,.94)

func settle(point: Vector3) -> void:
	var now := Time.get_ticks_msec()
	if now-last_settle < 300: return
	last_settle = now; cue("stone",point,-22,.84)
