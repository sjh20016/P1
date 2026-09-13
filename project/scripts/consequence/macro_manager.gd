extends Node3D

@export var budget:int=6
var active:Array=[]
var ruins:Array=[]
var peak:int=0
var collision_count:int=0
var activation_us:Array[int]=[]
var last_detach_type:int=-1

func _ready() -> void: add_to_group("macro_manager")

func detach_component(tower,component:Array,event) -> void:
	var started:=Time.get_ticks_usec()
	while active.size()>=budget: active[0].settle("budget")
	var macro=preload("res://scripts/consequence/macro_chunk.gd").new()
	add_child(macro)
	macro.configure(self,tower,component,event)
	last_detach_type=event.type
	active.append(macro);peak=maxi(peak,active.size())
	activation_us.append(Time.get_ticks_usec()-started)

func became_ruin(macro,visual:Node3D,reason:String) -> void:
	active.erase(macro)
	visual.reparent(self,true)
	visual.name="StaticRuin"
	visual.set_meta("settle_reason",reason)
	ruins.append(visual)
	for panel in visual.get_children():
		if panel.has_method("set_macro_moving"): panel.set_macro_moving(false)
		elif panel is DestructibleSegment and not panel.broken: panel.collision_layer=2;panel.collision_mask=4

func clear() -> void:
	for macro in active:
		macro.set_physics_process(false);macro.collision_layer=0;macro.collision_mask=0;macro.queue_free()
	for ruin in ruins:
		if is_instance_valid(ruin): ruin.queue_free()
	active.clear();ruins.clear();collision_count=0;peak=0;activation_us.clear()
