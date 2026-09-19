class_name GrappleProfile
extends Resource

@export_enum("M01 Pure Spring","M02 Radial Constraint","M03 Hybrid") var movement_model: int = 0
@export_enum("A Center Ray","B Screen Assist","C Sampled Cone") var targeting_model: int = 0
@export var assist_angle: float = 4.5
@export var emergency_angle: float = 8.0
@export var screen_assist_fraction: float = 0.045
@export var kick_speed: float = 0.0
@export var motor_acceleration: float = 0.0
@export var radial_correction: float = 0.0
@export var slingshot_boost: float = 0.0

@export var minimum_rope_length: float = 4.0
@export var maximum_rope_length: float = 150.0
@export var rest_ratio: float = 0.82
@export var spring_strength: float = 20.0
@export var damping: float = 5.5
@export var maximum_hook_force: float = 130.0
@export var maximum_combined_force: float = 180.0
@export var reel_speed: float = 18.0
@export var reattach_cooldown: float = 0.12
