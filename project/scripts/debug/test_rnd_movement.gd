extends SceneTree

var rows: Array[Dictionary] = []
var failures: int = 0
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	preload("res://scripts/debug/input_setup.gd").install()
	var world := Node3D.new()
	root.add_child(world)
	var p: RavagePlayer = load("res://scenes/player/player.tscn").instantiate()
	p.controls_enabled=false
	world.add_child(p)
	var anchor := StaticBody3D.new()
	anchor.position=Vector3(0,38,-45)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size=Vector3(10,12,4)
	collision.shape=shape
	anchor.add_child(collision)
	world.add_child(anchor)
	await physics_frame
	await physics_frame
	var h: GrappleController=p.hooks[0]
	for rate in [60,90,120]:
		Engine.physics_ticks_per_second=rate
		for model in 3:
			h.release()
			p.reset_player("experiment")
			p.global_position=Vector3(0,10,16)
			p.velocity=Vector3(9,-4,-3)
			p.profile=p.profile.duplicate()
			h.profile=load("res://assets/placeholders/grapple_m%02d.tres" % (model+1))
			var before:=p.velocity
			h.attach_to(Vector3(0,38,-43),anchor)
			var initial_change:=p.velocity.distance_to(before)
			var t1:=0.0 if initial_change>=5.0 else -1.0
			var t20:=0.0 if p.velocity.length()>=20 else -1.0
			var t25:=0.0 if p.velocity.length()>=25 else -1.0
			var t30:=0.0 if p.velocity.length()>=30 else -1.0
			var peak:=p.velocity.length()
			var release_speed:=0.0
			var release_after:=0.0
			var v100:=0.0
			var elapsed:=0.0
			p.controls_enabled=true
			for step in int(rate*2.2):
				await physics_frame
				elapsed+=1.0/rate
				var speed:=p.velocity.length()
				peak=maxf(peak,speed)
				if t1<0 and p.velocity.distance_to(before)>=5: t1=elapsed
				if t20<0 and speed>=20: t20=elapsed
				if t25<0 and speed>=25: t25=elapsed
				if t30<0 and speed>=30: t30=elapsed
				if step==int(rate*0.1): v100=speed
				if step==int(rate*1.2):
					release_speed=speed
					h.release()
				if step==int(rate*1.32): release_after=speed
				if not p.velocity.is_finite() or speed>82.01: failures+=1
			p.controls_enabled=false
			var row: Dictionary={"model":model+1,"physics_hz":rate,"initial_kick_delta":initial_change,"t1_seconds":t1,"time_to_20":t20,"time_to_25":t25,"time_to_30":t30,"speed_at_100ms":v100,"release_speed":release_speed,"release_after_120ms":release_after,"release_retention":release_after/maxf(release_speed,0.01),"peak":peak}
			rows.append(row)
			print("RACE ",JSON.stringify(row))
	Engine.physics_ticks_per_second=120
	var file:=FileAccess.open("res://../build/rnd003/movement_race.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(rows,"\t"))
	file.close()
	world.queue_free()
	await process_frame
	print("RND MOVEMENT RESULT failures=",failures)
	quit(failures)
