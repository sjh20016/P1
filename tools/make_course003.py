"""Offline fixed gameplay laboratory inside the existing finite canyon."""
from pathlib import Path
root=Path(__file__).resolve().parents[1]
lines=['[gd_scene format=3]',
'[ext_resource type="Script" path="res://scripts/rnd/course_controller.gd" id="1"]',
'[ext_resource type="Script" path="res://scripts/destruction/destructible_segment.gd" id="2"]',
'[ext_resource type="PackedScene" path="res://scenes/destruction/ink_rubble.scn" id="3"]',
'[ext_resource type="Material" path="res://assets/placeholders/paper.tres" id="4"]',
'[ext_resource type="Material" path="res://assets/placeholders/cut_ink.tres" id="5"]']
lines.append('[ext_resource type="Font" path="res://assets/placeholders/ui_zh.tres" id="6"]')
resources=[];nodes=[]
def v(x):return 'Vector3('+', '.join(map(str,x))+')'
def block(name,pos,size,weight=1):
 resources.extend([f'[sub_resource type="BoxMesh" id="M_{name}"]\nsize = {v(size)}\nmaterial = ExtResource("4")',f'[sub_resource type="BoxShape3D" id="S_{name}"]\nsize = {v(size)}'])
 lower=tuple(-x/2 for x in size)
 nodes.append(f'[node name="{name}" type="StaticBody3D" parent="."]\nposition = {v(pos)}\nscript = ExtResource("2")\nbroken_scene = ExtResource("3")\ndebris_at_hit = true\nstructure_weight = {weight}\nlocal_bounds = AABB({", ".join(map(str,lower+size))})')
 nodes.append(f'[node name="IntactVisual" type="MeshInstance3D" parent="{name}"]\nmesh = SubResource("M_{name}")')
 if name in {'GateA','GateB','ShellFront','FinalGate'}:
  label={'GateA':'02 / 撞开','GateB':'04 / 切断','ShellFront':'05 / 通道','FinalGate':'08 / 重击'}[name]
  nodes.append(f'[node name="Guide" type="Label3D" parent="{name}/IntactVisual"]\nposition = {v((0,min(size[1]*.25,4),size[2]/2+.06))}\ntext = "{label}"\nfont = ExtResource("6")\nfont_size = 64\npixel_size = 0.022\noutline_size = 0\nmodulate = Color(0.02, 0.02, 0.02, 1)\nno_depth_test = false')
 nodes.append(f'[node name="Collision" type="CollisionShape3D" parent="{name}"]\nshape = SubResource("S_{name}")')
def anchor(name,pos):
 resources.extend([f'[sub_resource type="TorusMesh" id="M_{name}"]\ninner_radius = 1.25\nouter_radius = 1.65\nrings = 24\nring_segments = 8\nmaterial = ExtResource("5")',f'[sub_resource type="SphereShape3D" id="S_{name}"]\nradius = 1.65'])
 nodes.append(f'[node name="{name}" type="StaticBody3D" parent="."]\nposition = {v(pos)}\nscript = ExtResource("2")\nbroken_scene = ExtResource("3")\ndebris_at_hit = true\nstructure_weight = 0\nlocal_bounds = AABB(-1.65, -1.65, -1.65, 3.3, 3.3, 3.3)')
 nodes.append(f'[node name="IntactVisual" type="MeshInstance3D" parent="{name}"]\nrotation_degrees = Vector3(90, 0, 0)\nmesh = SubResource("M_{name}")')
 nodes.append(f'[node name="Collision" type="CollisionShape3D" parent="{name}"]\nshape = SubResource("S_{name}")')
block('GateA',(0,53,-65),(25,22,2),1)
block('LandingA',(0,39,-83),(14,1,12),0)
block('GateB',(0,55,-127),(25,3,3),0)
block('CanopyB',(0,65,-129),(18,1,8),0)
block('ShellFront',(0,48,-173),(16,18,2),1)
block('RoomFloor',(0,38,-183),(16,1,22),1)
block('RoomLeft',(-8.5,48,-183),(1,20,22),1)
block('RoomRight',(8.5,48,-183),(1,20,22),1)
block('RoomRoof',(0,58,-183),(16,1,22),1)
block('WallLab',(12,-60,-220),(2,26,20),1)
block('RecoveryDeck',(0,-68,-222),(14,1,12),0)
block('FinalGate',(0,-53,-246),(24,23,3),2)
for name,pos in [
 ('AnchorStart',(0,70,-24)),('AnchorA',(0,63,-89)),
 ('AnchorChainL',(-12,78,-102)),('AnchorChainR',(12,76,-117)),
 ('AnchorSweep',(14,77,-143)),('AnchorInner',(0,49,-188)),
 ('AnchorDive',(0,-65,-202)),('AnchorRescue',(9,-62,-213)),
 ('AnchorExit',(-9,-27,-239)),('AnchorFinish',(0,-29,-268))]:anchor(name,pos)
lines+=resources+['[node name="Course003" type="Node3D"]\nscript = ExtResource("1")']+nodes
(root/'project/scenes/rnd/course003.tscn').write_text('\n'.join(lines)+'\n',encoding='utf-8')
print('Fixed course: 12 breakable structures, 10 anchors, inside original canyon footprint')
