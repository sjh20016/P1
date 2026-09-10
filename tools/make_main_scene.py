"""Author a fixed gameplay layout. This tool is never shipped as runtime map generation."""
from pathlib import Path
import json
ROOT = Path(__file__).resolve().parents[1]
manifest = json.loads((ROOT/'project/assets/blender_maps/map_manifest.json').read_text())
def vec(v):
    return 'Vector3('+', '.join(f'{n:.5f}' for n in v)+')'
def godot(v):
    return [v[0],v[2],-v[1]]
parts = ['[gd_scene load_steps=40 format=3]']
resources = {'1':('PackedScene','scenes/maps/destructible_tower_forest.scn'),'2':('PackedScene','scenes/player/player.tscn'),'3':('Script','scripts/game_controller.gd'),'4':('Script','scripts/destruction/destruction_manager.gd'),'5':('Script','scripts/destruction/impact_detector.gd'),'6':('Script','scripts/destruction/tentacle_sweep.gd'),'7':('Script','scripts/camera/camera_shake.gd'),'8':('Script','scripts/vfx/impact_vfx.gd'),'9':('Script','scripts/debug/game_hud.gd'),'10':('Script','scripts/debug/debug_draw.gd'),'11':('Script','scripts/vfx/impact_overlay.gd'),'12':('Script','scripts/destruction/destructible_segment.gd'),'13':('Script','scripts/player/ink_body.gd'),'14':('Script','scripts/vfx/ink_marks.gd'),'15':('PackedScene','scenes/destruction/ink_rubble.scn'),'16':('Script','scripts/rnd/gameplay_telemetry.gd'),'17':('Script','scripts/vfx/grapple_feedback.gd')}
for i in range(1,15): resources[str(20+i)] = ('PackedScene',f'scenes/destruction/D{i:02d}.tscn')
for id,(typ,path) in resources.items(): parts.append(f'[ext_resource type="{typ}" path="res://{path}" id="{id}"]')
parts.append('''[sub_resource type="Environment" id="Env"]
background_mode = 1
background_color = Color(0.97, 0.964, 0.944, 1)
ambient_light_source = 3
ambient_light_color = Color(0.57, 0.7, 0.76, 1)
ambient_light_energy = 0.42
tonemap_mode = 0
fog_enabled = true
fog_light_color = Color(0.97, 0.964, 0.944, 1)
fog_density = 0.0032
[sub_resource type="StandardMaterial3D" id="Mint"]
shading_mode = 0
albedo_color = Color(0.045, 0.045, 0.045, 1)
[sub_resource type="StandardMaterial3D" id="DeckMat"]
albedo_color = Color(0.97, 0.964, 0.944, 1)
roughness = 0.8
[sub_resource type="BoxMesh" id="DeckMesh"]
size = Vector3(12, 1, 14)
material = SubResource("DeckMat")
[sub_resource type="BoxShape3D" id="DeckShape"]
size = Vector3(12, 1, 14)
[sub_resource type="TorusMesh" id="AnchorRing"]
inner_radius = 0.85
outer_radius = 1.1
rings = 20
ring_segments = 8
material = SubResource("Mint")
[sub_resource type="SphereShape3D" id="AnchorShape"]
radius = 1.1
[sub_resource type="BoxMesh" id="Stripe"]
size = Vector3(0.10, 0.025, 13)
material = SubResource("Mint")
[sub_resource type="SphereMesh" id="CoreMark"]
radius = 0.1
height = 0.2
material = SubResource("Mint")
[node name="Ravage" type="Node3D"]
script = ExtResource("3")
[node name="Environment" type="WorldEnvironment" parent="."]
environment = SubResource("Env")
[node name="Sun" type="DirectionalLight3D" parent="."]
rotation_degrees = Vector3(-32, -18, 0)
light_color = Color(0.93, 0.97, 1, 1)
light_energy = 0.95
shadow_enabled = false
directional_shadow_max_distance = 210.0
[node name="StaticTowerForest" parent="." instance=ExtResource("1")]
[node name="Player" parent="." instance=ExtResource("2")]
spawn_position = Vector3(0, 48, 12)
fall_recovery_enabled = true
[node name="ImpactDetector" type="Node" parent="Player"]
script = ExtResource("5")
momentum_response = true
[node name="TentacleSweep" type="Node" parent="Player"]
script = ExtResource("6")
cut_speed_threshold = 20.0
tension_threshold = 12.0
[node name="CameraShake" type="Node" parent="Player"]
script = ExtResource("7")
[node name="InkBody" type="MeshInstance3D" parent="Player"]
script = ExtResource("13")
[node name="GrappleFeedback" type="Node" parent="Player"]
script = ExtResource("17")
[node name="DestructionManager" type="Node3D" parent="."]
script = ExtResource("4")
ink_art = true
[node name="InkMarks" type="MeshInstance3D" parent="."]
script = ExtResource("14")
[node name="ImpactVFX" type="Node3D" parent="."]
script = ExtResource("8")
[node name="Telemetry" type="Node" parent="."]
script = ExtResource("16")
[node name="DebugDraw" type="MeshInstance3D" parent="."]
script = ExtResource("10")
[node name="UI" type="CanvasLayer" parent="."]
layer = 10
[node name="HUD" type="Control" parent="UI"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
script = ExtResource("9")
[node name="ImpactOverlay" type="Control" parent="UI"]
script = ExtResource("11")
[node name="LaunchDeck" type="StaticBody3D" parent="."]
position = Vector3(0, 46, 10)
script = ExtResource("12")
debris_at_hit = true
broken_scene = ExtResource("15")
local_bounds = AABB(-6, -0.5, -7, 12, 1, 14)
[node name="IntactVisual" type="MeshInstance3D" parent="LaunchDeck"]
mesh = SubResource("DeckMesh")
[node name="Collision" type="CollisionShape3D" parent="LaunchDeck"]
shape = SubResource("DeckShape")
[node name="StripeL" type="MeshInstance3D" parent="LaunchDeck/IntactVisual"]
position = Vector3(-4.8, 0.51, 0)
mesh = SubResource("Stripe")
[node name="StripeR" type="MeshInstance3D" parent="LaunchDeck/IntactVisual"]
position = Vector3(4.8, 0.51, 0)
mesh = SubResource("Stripe")
[node name="LaunchSign" type="Label3D" parent="."]
position = Vector3(0, 48, 2)
text = "DROP INTO THE CANYON\nHOLD A MOUSE BUTTON TO GRAB"
font_size = 42
pixel_size = 0.004
outline_size = 0
modulate = Color(0.045, 0.045, 0.045, 1)
billboard = 1
no_depth_test = false
''')
for segment in manifest['segment_placements']:
    key=segment['id']; pos=godot(segment['position']); i=int(key[1:])
    parts.append(f'[node name="{key}" parent="." instance=ExtResource("{20+i}")]\nposition = {vec(pos)}\n')
parts.append('''[node name="D13" parent="." instance=ExtResource("33")]
position = Vector3(0, 38, -55)
label = "SWEEP BEAM"
[node name="D14" parent="." instance=ExtResource("34")]
position = Vector3(0, 17, -155)
label = "HOLLOW DRUM"
[node name="SweepSign" type="Label3D" parent="."]
position = Vector3(0, 41, -55)
text = "SWEEP ZONE\nF2 TO PRACTICE"
font_size = 48
pixel_size = 0.013
outline_size = 0
modulate = Color(0.045, 0.045, 0.045, 1)
billboard = 1
''')
anchors=[(-14,66,-25),(14,62,-34),(-14,58,-83),(13,60,-99),(-12,56,-129),(14,58,-160),(-12,58,-189),(13,70,-222),(14,50,-65)]
for i,pos in enumerate(anchors):
    name='PracticeAnchor' if i==8 else f'Anchor{i}'
    parts.append(f'''[node name="{name}" type="StaticBody3D" parent="."]
position = {vec(pos)}
script = ExtResource("12")
local_bounds = AABB(-1.1, -1.1, -1.1, 2.2, 2.2, 2.2)
debris_at_hit = true
broken_scene = ExtResource("15")
[node name="IntactVisual" type="MeshInstance3D" parent="{name}"]
rotation_degrees = Vector3(90, 0, 0)
mesh = SubResource("AnchorRing")
[node name="Collision" type="CollisionShape3D" parent="{name}"]
shape = SubResource("AnchorShape")
[node name="Tag" type="Label3D" parent="{name}/IntactVisual"]
position = Vector3(0, 1.7, 0)
text = "ANCHOR / {i+1:02d}"
font_size = 36
pixel_size = 0.012
outline_size = 0
billboard = 1
modulate = Color(0.045, 0.045, 0.045, 1)
''')
(ROOT/'project/scenes/maps/main.tscn').write_text('\n'.join(parts),encoding='utf-8')
config=ROOT/'project/project.godot'
config.write_text(config.read_text(encoding='utf-8').replace('run/main_scene="res://scenes/maps/graybox.tscn"','run/main_scene="res://scenes/maps/main.tscn"'),encoding='utf-8')
