extends SceneTree
var failures:int=0
func _initialize() -> void: call_deferred("run")
func check(ok:bool,label:String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok: failures+=1
func run() -> void:
	var game=load("res://scenes/maps/main.tscn").instantiate();root.add_child(game)
	game.start_consequence();game.player.controls_enabled=false
	var tower=game.consequence.towers[0]
	var event:=RavageDamageEvent.new();event.energy=55;event.direction=Vector3.RIGHT;event.type=RavageDamageEvent.Type.SLASH
	for i in 8:
		event.position=tower.to_global(Vector3(-5+(i%4)*3,-6+(i/4)*10,8.4))
		game.manager.apply_damage(tower,event)
	check(game.manager.damage_events>1 and game.manager.feedback_count==1,"many real cuts share one audiovisual beat")
	check(is_equal_approx(Engine.time_scale,1.0),"continuous slash never globally slows movement")
	check(game.get_node("InkMarks").pending_impacts.is_empty(),"local panel scars bypass legacy projection rays")
	var before:int=game.manager.score
	event.type=RavageDamageEvent.Type.PULL
	event.position=tower.to_global(Vector3(0,0,8.4))
	var result:Dictionary=game.manager.apply_damage(tower,event)
	check(not result.changed and game.manager.score==before,"pull without structural change cannot farm score")
	game.restart_run()
	check(game.manager.combo==0 and game.manager.feedback_count==0 and game.manager.last_reward==0,"session reset clears reward and feedback clocks")
	game.queue_free()
	for i in 12: await process_frame
	print("FEEDBACK005 RESULT failures=",failures);quit(failures)
