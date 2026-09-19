class_name PortalPhysics
extends RefCounted

static func frame(normal: Vector3) -> Basis:
	var up := Vector3.UP if absf(normal.dot(Vector3.UP)) < 0.95 else Vector3.FORWARD
	var right := up.cross(normal).normalized()
	return Basis(right, normal.cross(right).normalized(), normal.normalized())

static func rotation_between(entry: Basis, exit: Basis) -> Basis:
	return exit * Basis(Vector3.UP, PI) * entry.transposed()

static func velocity_out(velocity: Vector3, rotation: Basis, multiplier: float, maximum: float) -> Vector3:
	return (rotation * velocity * multiplier).limit_length(maximum)

# Sweep the traveller's leading sphere against the aperture, before the supporting
# solid wall can stop it. Off-centre entries must fit the entire bounding sphere.
static func crossing(gate: Transform3D, start: Vector3, motion: Vector3, radius: float, aperture: float) -> float:
	var p := gate.affine_inverse() * start
	var d := gate.basis.transposed() * motion
	if d.z >= -0.00001 or p.z < radius - 0.18:
		return -1.0
	var t := (radius + 0.035 - p.z) / d.z
	if t < -0.05 or t > 1.0:
		return -1.0
	var at := p + d * clampf(t, 0, 1)
	return clampf(t, 0, 1) if Vector2(at.x, at.y).length() <= aperture - radius else -1.0
