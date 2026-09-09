extends RefCounted

static func install() -> void:
	var keys := {"forward": KEY_W, "back": KEY_S, "left": KEY_A, "right": KEY_D,
		"jump": KEY_SPACE, "reset": KEY_R, "debug": KEY_F3, "pause": KEY_ESCAPE,
		"reel_in": KEY_Q, "reel_out": KEY_E, "restart": KEY_F5}
	for action: String in keys:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		var event := InputEventKey.new()
		event.physical_keycode = keys[action]
		InputMap.action_add_event(action, event)
	for action: String in ["hook_left", "hook_right"]:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT if action == "hook_left" else MOUSE_BUTTON_RIGHT
		InputMap.action_add_event(action, event)
