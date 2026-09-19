extends Control

var player: RavagePlayer
var vfx: Node3D

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	player = get_tree().get_first_node_in_group("player")
	vfx = get_tree().get_first_node_in_group("impact_vfx")

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var view := get_viewport_rect().size
	var speed := player.velocity.length()
	if speed > 28:
		var alpha := clampf((speed - 28.0) / 150.0, 0.0, 0.3)
		for i in 22:
			var angle := float(i) * TAU / 22.0 + sin(float(i) * 13.0) * 0.09
			var direction := Vector2(cos(angle), sin(angle))
			var radius := 0.4 + fmod(Time.get_ticks_msec() * 0.0007 + i * 0.073, 0.15)
			var a := view * 0.5 + direction * view * radius
			var b := a + direction * (18 + speed * 0.65)
			draw_line(a, b, Color(0.035,0.035,0.035,alpha), 1.2, true)
	if is_instance_valid(vfx) and vfx.flash > 0:
		draw_rect(Rect2(Vector2.ZERO, view), Color(1,1,1,vfx.flash))
