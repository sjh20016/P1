class_name TentacleSweep
extends Node

@export var cut_speed_threshold: float = 22.0
@export var tension_threshold: float = 6.0
@export var sweep_speed_threshold: float = 12.0
@export var sweep_radius: float = 0.22
@export var target_cooldown: float = 0.18
var sweep_event_count: int = 0
var sweep_speed: float = 0.0
var cooldowns: Dictionary = {}
@onready var player: RavagePlayer = get_parent()

func _ready() -> void:
	player.motion_completed.connect(check_sweeps)
	player.reset_performed.connect(func(): cooldowns.clear())

func check_sweeps(delta: float) -> void:
	for key in cooldowns.keys():
		cooldowns[key] -= delta
		if cooldowns[key] <= 0:
			cooldowns.erase(key)
	for hook in player.hooks:
		check_hook(hook, delta)
		hook.remember_segment()

func check_hook(hook: GrappleController, delta: float) -> void:
	if not hook.active or not hook.history_valid or delta <= 0:
		return
	sweep_speed = maxf(player.global_position.distance_to(hook.previous_start), hook.grapple_point.distance_to(hook.previous_end)) / delta
	if player.velocity.length() < cut_speed_threshold or hook.tension < tension_threshold or sweep_speed < sweep_speed_threshold:
		return
	# Swept quad = two triangles. Target boxes are authored alongside collision shapes.
	for segment: DestructibleSegment in get_tree().get_nodes_in_group("destructible"):
		if segment.broken or segment == hook.target or cooldowns.has(segment.get_instance_id()):
			continue
		var inverse := segment.global_transform.affine_inverse()
		var a := inverse * hook.previous_start
		var b := inverse * hook.previous_end
		var c := inverse * player.global_position
		var d := inverse * hook.grapple_point
		if SweepGeometry.swept_line_box(a, b, c, d, segment.local_bounds, sweep_radius):
			var center := segment.global_transform * segment.local_bounds.get_center()
			if segment.has_method("sweep_hit"):
				var hit: Variant = segment.sweep_hit(hook.previous_start,hook.previous_end,player.global_position,hook.grapple_point,sweep_radius)
				if hit == null:
					continue
				center = hit
			if segment.break_segment(center, player.velocity.normalized(), player.velocity.length()):
				cooldowns[segment.get_instance_id()] = target_cooldown
				sweep_event_count += 1
