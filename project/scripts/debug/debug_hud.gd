extends CanvasLayer

var label: Label
var player: RavagePlayer

func _ready() -> void:
	player = get_tree().get_first_node_in_group("player")
	label = Label.new()
	label.position = Vector2(24, 20)
	label.add_theme_font_size_override("font_size", 20)
	add_child(label)

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("debug"):
		label.visible = not label.visible
	label.text = "RAVAGE / MOVEMENT LAB\nFPS  %d\nVelocity  %s\nSpeed  %.1f m/s\nLeft Hook  OFF\nRight Hook  OFF\nActive RigidBodies  0\n\nWASD move / Mouse look / SPACE jump\nR reset / F3 debug / ESC cursor" % [Engine.get_frames_per_second(), str(player.velocity.snapped(Vector3.ONE * 0.1)), player.velocity.length()]
