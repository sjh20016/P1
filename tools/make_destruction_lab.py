from pathlib import Path
root = Path(__file__).resolve().parents[1] / 'project'
d = root/'scenes/destruction'
d.mkdir(parents=True, exist_ok=True)
(d/'test_block.tscn').write_text('''[gd_scene load_steps=5 format=3]
[ext_resource type="Script" path="res://scripts/destruction/destructible_segment.gd" id="1"]
[sub_resource type="BoxMesh" id="Mesh"]
size = Vector3(6, 4, 2)
[sub_resource type="BoxShape3D" id="Shape"]
size = Vector3(6, 4, 2)
[sub_resource type="StandardMaterial3D" id="Mat"]
albedo_color = Color(0.88, 0.34, 0.18, 1)
roughness = 0.9
[node name="DestructibleTestBlock" type="StaticBody3D"]
script = ExtResource("1")
[node name="IntactVisual" type="MeshInstance3D" parent="."]
mesh = SubResource("Mesh")
material_override = SubResource("Mat")
[node name="IntactCollision" type="CollisionShape3D" parent="."]
shape = SubResource("Shape")
''',encoding='utf-8')
parts = ['''[gd_scene load_steps=5 format=3]
[ext_resource type="Script" path="res://scripts/destruction/debris_piece.gd" id="1"]
[sub_resource type="BoxMesh" id="Mesh"]
size = Vector3(2.98, 1.98, 1.98)
[sub_resource type="BoxShape3D" id="Shape"]
size = Vector3(2.94, 1.94, 1.94)
[sub_resource type="StandardMaterial3D" id="Mat"]
albedo_color = Color(0.16, 0.19, 0.2, 1)
roughness = 0.9
[node name="BrokenBlock" type="Node3D"]
''']
for i,(x,y) in enumerate([(-1.5,-1),(1.5,-1),(-1.5,1),(1.5,1)]):
    parts.append(f'''[node name="Piece{i}" type="RigidBody3D" parent="."]
position = Vector3({x}, {y}, 0)
script = ExtResource("1")
mass = 4.0
[node name="Visual" type="MeshInstance3D" parent="Piece{i}"]
mesh = SubResource("Mesh")
material_override = SubResource("Mat")
[node name="Collision" type="CollisionShape3D" parent="Piece{i}"]
shape = SubResource("Shape")
''')
(d/'broken_block.tscn').write_text('\n'.join(parts),encoding='utf-8')
(root/'scenes/maps/destruction_lab.tscn').write_text('''[gd_scene load_steps=6 format=3]
[ext_resource type="PackedScene" path="res://scenes/maps/graybox.tscn" id="1"]
[ext_resource type="PackedScene" path="res://scenes/destruction/test_block.tscn" id="2"]
[ext_resource type="Script" path="res://scripts/destruction/destruction_manager.gd" id="3"]
[ext_resource type="Script" path="res://scripts/destruction/impact_detector.gd" id="4"]
[ext_resource type="Script" path="res://scripts/destruction/tentacle_sweep.gd" id="5"]
[node name="DestructionLab" instance=ExtResource("1")]
[node name="DestructionManager" type="Node3D" parent="."]
script = ExtResource("3")
[node name="ImpactDetector" type="Node" parent="Player"]
script = ExtResource("4")
[node name="TestBlock" parent="." instance=ExtResource("2")]
position = Vector3(0, 30, -10)
[node name="TentacleSweep" type="Node" parent="Player"]
script = ExtResource("5")
''',encoding='utf-8')
