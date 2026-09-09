from pathlib import Path
root = Path(__file__).resolve().parents[1]
parts = ['''[gd_scene load_steps=8 format=3]
[ext_resource type="PackedScene" path="res://scenes/player/player.tscn" id="1"]
[ext_resource type="Script" path="res://scripts/debug/graybox.gd" id="2"]
[ext_resource type="Script" path="res://scripts/debug/debug_hud.gd" id="3"]
[sub_resource type="Environment" id="Env"]
background_mode = 1
background_color = Color(0.04, 0.065, 0.08, 1)
ambient_light_source = 3
ambient_light_color = Color(0.65, 0.76, 0.8, 1)
ambient_light_energy = 0.65
tonemap_mode = 2
fog_enabled = true
fog_light_color = Color(0.1, 0.15, 0.18, 1)
fog_density = 0.002
[sub_resource type="BoxMesh" id="TowerMesh"]
size = Vector3(10, 100, 10)
[sub_resource type="BoxShape3D" id="TowerShape"]
size = Vector3(10, 100, 10)
[sub_resource type="StandardMaterial3D" id="TowerMat"]
albedo_color = Color(0.6, 0.65, 0.65, 1)
roughness = 0.9
[node name="Graybox" type="Node3D"]
script = ExtResource("2")
[node name="Environment" type="WorldEnvironment" parent="."]
environment = SubResource("Env")
[node name="Sun" type="DirectionalLight3D" parent="."]
rotation_degrees = Vector3(-40, -25, 0)
light_energy = 1.6
shadow_enabled = true
directional_shadow_max_distance = 180.0
[node name="Player" parent="." instance=ExtResource("1")]
[node name="HUD" type="CanvasLayer" parent="."]
script = ExtResource("3")
''']
for i, (x,y,z,sx,sy,sz) in enumerate([(-27,0,-18,1,1,1),(27,0,-18,1,1,1),(-30,-10,35,1,1,1),(30,12,35,1,1,1),(-20,10,-65,1,1,1),(26,-8,-70,1,1,1),(0,35,20,1,0.1,1)]):
    parts.append(f'''[node name="Tower{i}" type="StaticBody3D" parent="."]
position = Vector3({x}, {y}, {z})
scale = Vector3({sx}, {sy}, {sz})
[node name="Mesh" type="MeshInstance3D" parent="Tower{i}"]
mesh = SubResource("TowerMesh")
material_override = SubResource("TowerMat")
[node name="Collision" type="CollisionShape3D" parent="Tower{i}"]
shape = SubResource("TowerShape")
''')
out = root / 'project/scenes/maps/graybox.tscn'
out.parent.mkdir(parents=True, exist_ok=True)
out.write_text('\n'.join(parts), encoding='utf-8')
