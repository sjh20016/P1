class_name SweepGeometry
extends RefCounted

## Separating-axis test for a swept line triangle and a predeclared target AABB.
## Only tests an event volume; never reads, cuts, or modifies render mesh geometry.
static func triangle_box(a: Vector3, b: Vector3, c: Vector3, bounds: AABB, radius: float = 0.22) -> bool:
	var box := bounds.grow(radius)
	var center := box.get_center()
	var half := box.size * 0.5
	var vertices: Array[Vector3] = [a - center, b - center, c - center]
	var edges: Array[Vector3] = [b - a, c - b, a - c]
	var axes: Array[Vector3] = [Vector3.RIGHT, Vector3.UP, Vector3.BACK, edges[0].cross(edges[1])]
	for edge in edges:
		axes.append(edge.cross(Vector3.RIGHT))
		axes.append(edge.cross(Vector3.UP))
		axes.append(edge.cross(Vector3.BACK))
	for axis in axes:
		if axis.length_squared() < 0.0000001:
			continue
		var p0 := vertices[0].dot(axis)
		var p1 := vertices[1].dot(axis)
		var p2 := vertices[2].dot(axis)
		var extent := half.dot(axis.abs())
		if minf(p0, minf(p1, p2)) > extent or maxf(p0, maxf(p1, p2)) < -extent:
			return false
	return true

static func swept_line_box(previous_start: Vector3, previous_end: Vector3, current_start: Vector3, current_end: Vector3, box: AABB, radius: float) -> bool:
	return triangle_box(previous_start, previous_end, current_end, box, radius) or triangle_box(previous_start, current_end, current_start, box, radius)
