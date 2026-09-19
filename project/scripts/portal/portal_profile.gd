class_name PortalProfile
extends Resource

@export var placement_range: float = 150.0
@export var portal_size: float = 3.2 # Aperture radius, metres.
@export var exit_offset: float = 0.22
@export var momentum_multiplier: float = 1.0
@export var max_portal_velocity: float = 100.0
@export var portal_cooldown: float = 0.18
@export var object_mass_limit: float = 25.0
@export var spatial_cut_damage: float = 55.0
@export var spatial_cut_width: float = 1.2
@export var spatial_cut_cooldown: float = 2.0
@export var high_speed_impact_threshold: float = 26.0
@export var emergency_portal_enabled: bool = false
@export var camera_blend: float = 0.06
@export var fov_boost: float = 10.0
@export var high_speed_fov: float = 92.0
@export var exit_camera_stabilization: float = 0.12

@export_group("Space magic")
@export var magic_enabled: bool = true
@export var guide_speed: float = 115.0
@export var guide_range: float = 110.0
@export var guide_turn_rate: float = 18.0
@export var quick_cast_distance: float = 42.0
@export var dash_min_speed: float = 42.0
@export var dash_cooldown: float = 0.28
@export var impact_runup: float = 7.0
@export var boost_acceleration: float = 62.0
@export var boost_start_speed: float = 32.0
@export var space_hold_delay: float = 0.18
@export var edit_hover_duration: float = 1.2
@export var slow_fall_duration: float = 3.0
@export var slow_fall_speed: float = 2.5
@export var cut_min_radius: float = 2.4
@export var cut_max_radius: float = 14.0
@export var cut_charge_time: float = 1.4
@export var cut_separation: float = 2.8

func sanitize() -> void:
	placement_range = clampf(placement_range, 10, 220)
	portal_size = clampf(portal_size, 1.2, 5)
	exit_offset = clampf(exit_offset, 0.08, 1)
	momentum_multiplier = clampf(momentum_multiplier, 0.8, 1.2)
	max_portal_velocity = clampf(max_portal_velocity, 35, 140)
	portal_cooldown = clampf(portal_cooldown, 0.08, 0.6)
	object_mass_limit = clampf(object_mass_limit, 0.5, 50)
	spatial_cut_damage = clampf(spatial_cut_damage, 26, 100)
	spatial_cut_width = clampf(spatial_cut_width, 0.2, 4)
	spatial_cut_cooldown = clampf(spatial_cut_cooldown, 0.3, 5)
	high_speed_impact_threshold = clampf(high_speed_impact_threshold, 15, 55)
	guide_speed = clampf(guide_speed, 40, 220)
	guide_range = clampf(guide_range, 15, 180)
	guide_turn_rate = clampf(guide_turn_rate, 2, 40)
	quick_cast_distance = clampf(quick_cast_distance, 8, guide_range)
	dash_min_speed = clampf(dash_min_speed, 26, max_portal_velocity)
	dash_cooldown = clampf(dash_cooldown, 0.12, 1)
	impact_runup = clampf(impact_runup, 2, 15)
	boost_acceleration = clampf(boost_acceleration, 10, 120)
	boost_start_speed = clampf(boost_start_speed, 0, max_portal_velocity)
	space_hold_delay = clampf(space_hold_delay, 0.12, 0.4)
	edit_hover_duration = clampf(edit_hover_duration, 0.2, 2)
	slow_fall_duration = clampf(slow_fall_duration, 0.5, 5)
	slow_fall_speed = clampf(slow_fall_speed, 1, 8)
	cut_min_radius = clampf(cut_min_radius, 1, 6)
	cut_max_radius = clampf(cut_max_radius, cut_min_radius, 18)
	cut_charge_time = clampf(cut_charge_time, 0.3, 3)
	cut_separation = clampf(cut_separation, 0.5, 5)
