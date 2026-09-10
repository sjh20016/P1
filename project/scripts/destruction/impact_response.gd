class_name ImpactResponse
extends RefCounted

static func penetrate(velocity: Vector3, normal: Vector3, structure: int) -> Vector3:
	var retention := [0.90,0.82,0.68][clampi(structure,0,2)] as float
	var radial := normal*velocity.dot(normal)
	var tangent := velocity-radial
	return tangent*0.99+radial*retention
