class_name PortalCutGeometry
extends RefCounted

# Intersect the box with the slab, then test its projected convex section.
static func contact(bounds: AABB, pose: Transform3D, center: Vector3, normal: Vector3, radius: float, width: float) -> Variant:
	var basis := PortalPhysics.frame(normal)
	var vertices: Array[Vector3] = []
	var depths: Array[float] = []
	var points := PackedVector2Array()
	for i in 8:
		var v := pose * bounds.get_endpoint(i) - center
		vertices.append(v); depths.append(v.dot(normal))
		if absf(depths[i]) <= width * 0.5: points.append(Vector2(v.dot(basis.x),v.dot(basis.y)))
	for i in 8:
		for bit in [1,2,4]:
			var j: int = i ^ bit
			if j <= i or is_equal_approx(depths[i],depths[j]): continue
			for plane in [-width * 0.5,width * 0.5]:
				var t: float = (plane - depths[i]) / (depths[j] - depths[i])
				if t < 0 or t > 1: continue
				var v := vertices[i].lerp(vertices[j],t)
				points.append(Vector2(v.dot(basis.x),v.dot(basis.y)))
	if points.is_empty(): return null
	var hull := Geometry2D.convex_hull(points)
	var nearest := points[0]
	if hull.size() >= 3 and Geometry2D.is_point_in_polygon(Vector2.ZERO,hull): nearest = Vector2.ZERO
	else:
		for i in hull.size():
			var p := Geometry2D.get_closest_point_to_segment(Vector2.ZERO,hull[i],hull[(i + 1) % hull.size()])
			if p.length_squared() < nearest.length_squared(): nearest = p
	if nearest.length_squared() > radius * radius: return null
	return center + basis.x * nearest.x + basis.y * nearest.y
