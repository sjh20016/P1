extends DestructibleSegment
var tower_ref:WeakRef
var face_normal:=Vector3.BACK
func receive_damage(event) -> Dictionary:
	var tower=tower_ref.get_ref()
	return tower.receive_damage(event) if is_instance_valid(tower) else {"changed":false}
func grapple_anchor() -> StaticBody3D:
	return tower_ref.get_ref()
