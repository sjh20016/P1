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
