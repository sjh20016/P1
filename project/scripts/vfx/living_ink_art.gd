class_name LivingInkArt
extends Node

const PAPER = preload("res://assets/placeholders/paper.tres")
const CUT = preload("res://assets/placeholders/cut_ink.tres")

static func paper_mesh(visual: MeshInstance3D) -> void:
	if visual.mesh == null:
		return
	visual.material_override = null
	for surface in visual.mesh.get_surface_count():
		var material := visual.mesh.surface_get_material(surface)
		var is_cut := material != null and (material.resource_name.contains("INK_CUT") or material.resource_name.contains("Fracture interior"))
		visual.set_surface_override_material(surface,CUT if is_cut else PAPER)
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

static func apply(node: Node) -> void:
	if node is MeshInstance3D:
		paper_mesh(node)
	for child in node.get_children():
		apply(child)
