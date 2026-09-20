extends SceneTree

var actor: PortalCharacter
var camera: Camera3D
const OUTPUT := "res://../docs/portal-character/"

func _initialize() -> void:
	call_deferred("run")

func capture(name: String) -> void:
	for i in 4: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUTPUT + name + ".png")

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var scene := Node3D.new(); root.add_child(scene); current_scene = scene
	var environment := WorldEnvironment.new(); var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR; settings.background_color = Color(0.34,0.39,0.46)
	environment.environment = settings; scene.add_child(environment)
	actor = PortalCharacter.new(); scene.add_child(actor)
	actor.animation.pause(); actor.animation.seek(0,true)
	camera = Camera3D.new(); camera.projection = Camera3D.PROJECTION_ORTHOGONAL; camera.size = 2.65
	scene.add_child(camera); camera.position = Vector3(0,1,5); camera.look_at(Vector3(0,1,0)); camera.current = true
	await capture("01-front")
	actor.rotation.y = PI / 2; await capture("02-side")
	actor.rotation.y = PI; await capture("03-back")
	actor.rotation.y = -0.4; actor.play_clip("Cast",0); actor.animation.seek(0.4,true); actor.animation.pause()
	await capture("04-cast")
	actor.play_clip("Run",0); actor.animation.seek(0.2,true); actor.animation.pause(); await capture("05-run")
	actor.play_clip("Idle",0); actor.animation.seek(0,true); actor.animation.pause()
	actor.position.x = -1.22; actor.rotation.y = -0.32
	for i in 2:
		var other := PortalCharacter.new(); scene.add_child(other)
		other.animation.seek(0,true); other.animation.pause()
		other.position.x = i * 1.22; other.rotation.y = PI / 2 if i == 0 else PI + 0.24
	var caption := Label.new(); caption.position = Vector2(28,22)
	caption.text = "PORTAL ANOMALY  /  0.1\n2520 TRIS   |   128 PX ATLAS   |   21 BONES"
	caption.add_theme_font_size_override("font_size",19); root.add_child(caption)
	await capture("00-character-views")
	print("RESULT character_preview clips=",actor.clips.keys()," sockets=",actor.sockets.keys()," bones=",actor.skeleton.get_bone_count())
	scene.queue_free(); await process_frame; quit()
