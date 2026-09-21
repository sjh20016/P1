class_name PortalCanyon
extends Node3D

var game: Node3D
var structures: Array[PortalAssetStructure] = []
var towers: Array[PortalAssetStructure] = []
var markers: Dictionary = {}
var interest_clock := 0.0
var load_ms: float

func _ready() -> void:
	var started := Time.get_ticks_usec()
	var layout = JSON.parse_string(FileAccess.get_file_as_string("res://assets/canyon/layout.json"))
	for key: String in layout.markers:
		var value: Array = layout.markers[key]; markers[key] = Vector3(value[0],value[1],value[2])
	var file := FileAccess.open("res://assets/canyon/vertical_canyon.bin",FileAccess.READ)
	assert(file.get_32() == 0x43414E33,"Re-export the canyon with tools/export_portal_canyon.py")
	var count := file.get_32()
	var material := StandardMaterial3D.new(); material.vertex_color_use_as_albedo = true; material.roughness = 0.9
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	for i in count:
		var body := PortalAssetStructure.new(); body.name = file.get_pascal_string()
		body.position = Vector3(file.get_float(),file.get_float(),file.get_float())
		body.original_arrays = PortalAssetStructure.read_arrays(file,file.get_32())
		body.decoded_size = file.get_32(); body.encoded = file.get_buffer(file.get_32())
		body.material = material; add_child(body); structures.append(body)
		if str(body.name).begins_with("Tower_") or str(body.name).begins_with("Backdrop_"): towers.append(body)
	file.close(); refresh_interest(markers.PLAYER_SPAWN)
	load_ms = (Time.get_ticks_usec() - started) / 1000.0

func _physics_process(delta: float) -> void:
	interest_clock -= delta
	if interest_clock <= 0 and is_instance_valid(game.player):
		interest_clock = 0.1; refresh_interest(game.player.global_position)

func refresh_interest(point: Vector3) -> void:
	var focus: Array[Vector3] = [point]
	if is_instance_valid(game.player): focus.append(point + game.player.velocity * 0.8)
	if is_instance_valid(game.portals):
		for gate in game.portals.all_gates():
			if is_instance_valid(gate): focus.append(gate.global_position)
	if is_instance_valid(game.fracture_field):
		for piece in game.fracture_field.pieces:
			if is_instance_valid(piece) and not piece.settled: focus.append(piece.global_position)
	for body in structures:
		var wanted := false
		var reach := 170.0 if body.near else 150.0
		for p in focus:
			if body.bounds_distance(p) < reach: wanted = true; break
		body.set_near(wanted)

func spawn_point(index: int) -> Vector3:
	return markers.get("PLAYER_SPAWN",Vector3(-21,36,0)) + Vector3.UP * 1.2 if index == 0 else markers.get("ROUTE_%02d" % index,markers.PLAYER_SPAWN)
