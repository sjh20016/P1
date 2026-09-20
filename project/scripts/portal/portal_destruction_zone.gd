extends "res://scripts/open/open_zone.gd"

# Reuse the shipped macro admission, contact, damage and settling behaviour.
# Persist compact damage states; only nearby tower collision proxies stay live.
var interest_clock: float = 0
func _ready() -> void:
	loading = false

func _process(_delta: float) -> void:
	pass

func _physics_process(_delta: float) -> void:
	interest_clock -= _delta
	if interest_clock <= 0 and session.forest_enabled:
		interest_clock = 0.1; refresh_interest()
	if not pending.is_empty() and active.size() < 3:
		var job: Dictionary = pending.pop_front()
		var tower = job.tower.get_ref()
		if is_instance_valid(tower) and not tower.state.detached:
			var macro = preload("res://scripts/open/open_macro.gd").new()
			add_child(macro); macro.configure(self, tower, job.event); active.append(macro)

func refresh_interest() -> void:
	if not is_instance_valid(session.player): return
	var focus: Array[Vector3] = [session.player.global_position,session.player.global_position + session.player.velocity * 0.8]
	for gate in session.portals.gates:
		if is_instance_valid(gate): focus.append(gate.global_position)
	if is_instance_valid(session.magic) and session.magic.guide.active: focus.append(session.magic.guide.point)
	for macro in active:
		if is_instance_valid(macro): focus.append(macro.global_position)
	for tower in towers + ruins:
		var nearby := false
		var reach := 170.0 if tower.near else 150.0
		for point in focus:
			if tower.global_position.distance_squared_to(point) < reach * reach: nearby = true; break
		tower.set_near(nearby)
