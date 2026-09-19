extends Node3D

func _enter_tree() -> void:
	preload("res://scripts/debug/input_setup.gd").install()
