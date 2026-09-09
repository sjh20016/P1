extends Node3D

func _ready() -> void:
	var player := get_parent().get_node("Player")
	var shake := Node.new()
	shake.name = "CameraShake"
	shake.set_script(preload("res://scripts/camera/camera_shake.gd"))
	player.add_child(shake)
	var vfx := Node3D.new()
	vfx.set_script(preload("res://scripts/vfx/impact_vfx.gd"))
	add_child(vfx)
	var draw := MeshInstance3D.new()
	draw.set_script(preload("res://scripts/debug/debug_draw.gd"))
	add_child(draw)
	var overlay := CanvasLayer.new()
	add_child(overlay)
	var control := Control.new()
	control.set_script(preload("res://scripts/vfx/impact_overlay.gd"))
	overlay.add_child(control)
