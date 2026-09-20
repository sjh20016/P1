class_name PortalPresentation
extends Node

# Animation/VFX consumers subscribe here. Presentation never delays, teleports
# or root-moves the physical player; the physics tick owns those decisions.
signal animation_cue(action: String, data: Dictionary)
var player: RavagePlayer
var portals: PortalManager
var state: String = "idle"
var history: Array[Dictionary] = []
var was_grounded: bool = false
var fall_speed: float = 0

func _ready() -> void:
	process_physics_priority = 10
	portals.action_cue.connect(receive)
	portals.impact.impact_event.connect(func(data):
		if data.source == player.get_instance_id(): receive("impact",data))
	player.reset_performed.connect(func(): receive("reset",{}))

func receive(action: String, data: Dictionary) -> void:
	if data.has("body_id") and data.body_id != player.get_instance_id(): return
	state = action
	history.append({"action":action,"data":data.duplicate()})
	if history.size() > 24: history.pop_front()
	animation_cue.emit(action,data)

func _physics_process(_delta: float) -> void:
	var grounded := player.is_on_floor()
	if grounded and not was_grounded and fall_speed > 4:
		receive("land",{"position":player.global_position,"speed":fall_speed})
	fall_speed = maxf(0,-player.velocity.y); was_grounded = grounded
