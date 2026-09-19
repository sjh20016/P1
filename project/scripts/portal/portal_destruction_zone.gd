extends "res://scripts/open/open_zone.gd"

# Reuse the shipped macro admission, contact, damage and settling behaviour.
# The small playground keeps all four towers resident; no open-city streaming.
func _ready() -> void:
	loading = false

func _process(_delta: float) -> void:
	pass

func _physics_process(_delta: float) -> void:
	if not pending.is_empty() and active.size() < 3:
		var job: Dictionary = pending.pop_front()
		var tower = job.tower.get_ref()
		if is_instance_valid(tower) and not tower.state.detached:
			var macro = preload("res://scripts/open/open_macro.gd").new()
			add_child(macro); macro.configure(self, tower, job.event); active.append(macro)
