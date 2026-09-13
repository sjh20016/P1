"""Compile authored box-panel shell and structural metadata. No runtime geometry guessing."""
from pathlib import Path
import json
root=Path(__file__).resolve().parents[1]
out=root/'project/scenes/consequence'
out.mkdir(exist_ok=True,parents=True)
meta={'version':4,'interior_width':15.2,'panel_step':2,'chunks':[{'id':i,'support':i==0,'active':True} for i in range(4)],'bonds':[{'a':i,'b':i+1,'health':100,'seam_y':-6+i*6,'broken':False} for i in range(3)],'panels':[]}
def v(a):return 'Vector3('+', '.join(map(str,a))+')'
ext='''[ext_resource type="Material" path="res://assets/consequence/wall.tres" id="paper"]
[ext_resource type="PackedScene" path="res://scenes/destruction/ink_rubble.scn" id="rubble"]
'''
res=[];nodes=[]
for side in range(4):
 size=(2,2,.8) if side<2 else (.8,2,2)
 res += [f'[sub_resource type="BoxMesh" id="Mesh{side}"]\nsize = {v(size)}\nmaterial = ExtResource("paper")',f'[sub_resource type="BoxShape3D" id="Shape{side}"]\nsize = {v(size)}']
 for row in range(12):
  for col in range(8):
   pos=(col*2-7,row*2-11,8 if side==0 else -8) if side<2 else ((8 if side==2 else -8),row*2-11,col*2-7)
   normal=(0,0,1 if side==0 else -1) if side<2 else (1 if side==2 else -1,0,0)
   i=len(meta['panels']);meta['panels'].append({'id':i,'chunk_id':row//3,'position':pos,'size':size,'normal':normal,'neighbors':[],'weak_seam':abs(pos[1])<2})
   lower=tuple(-x*.5 for x in size)
   nodes.append(f'[node name="P{i:03}" type="StaticBody3D" parent="."]\nposition = {v(pos)}\nscript = ExtResource("panel")\npanel_id = {i}\nchunk_id = {row//3}\nface_normal = {v(normal)}\nbroken_scene = ExtResource("rubble")\nlocal_bounds = AABB({", ".join(map(str,lower+size))})')
   nodes.append(f'[node name="IntactVisual" type="MeshInstance3D" parent="P{i:03}"]\nmesh = SubResource("Mesh{side}")')
   nodes.append(f'[node name="Collision" type="CollisionShape3D" parent="P{i:03}"]\nshape = SubResource("Shape{side}")')
for p in meta['panels']:
 p['neighbors']=[q['id'] for q in meta['panels'] if q['id']!=p['id'] and sum((a-b)**2 for a,b in zip(p['position'],q['position']))<4.1]
(root/'project/assets/consequence/tower_metadata.json').write_text(json.dumps(meta,indent=2),encoding='utf-8')
(out/'tower_panels.tscn').write_text('[gd_scene format=3]\n'+ext+'[ext_resource type="Script" path="res://scripts/consequence/consequence_panel.gd" id="panel"]\n'+'\n'.join(res+['[node name="Panels" type="Node3D"]']+nodes),encoding='utf-8')
res=[];nodes=[]
for side in range(4):
 size=(16,24,.8) if side<2 else (.8,24,16)
 pos=(0,0,8 if side==0 else -8) if side<2 else (8 if side==2 else -8,0,0)
 res += [f'[sub_resource type="BoxMesh" id="Mesh{side}"]\nsize = {v(size)}\nmaterial = ExtResource("paper")',f'[sub_resource type="BoxShape3D" id="Shape{side}"]\nsize = {v(size)}']
 nodes += [f'[node name="Wall{side}" type="MeshInstance3D" parent="IntactVisual"]\nposition = {v(pos)}\nmesh = SubResource("Mesh{side}")',f'[node name="Collision{side}" type="CollisionShape3D" parent="."]\nposition = {v(pos)}\nshape = SubResource("Shape{side}")']
(out/'breachable_tower.tscn').write_text('[gd_scene format=3]\n'+ext+'''[ext_resource type="Script" path="res://scripts/consequence/breachable_tower.gd" id="tower"]
[ext_resource type="PackedScene" path="res://scenes/consequence/tower_panels.tscn" id="panels"]
'''+ '\n'.join(res)+'''
[node name="BreachableTower" type="StaticBody3D"]
script = ExtResource("tower")
panels_scene = ExtResource("panels")
broken_scene = ExtResource("rubble")
metadata_path = "res://assets/consequence/tower_metadata.json"
local_bounds = AABB(-8.4, -12, -8.4, 16.8, 24, 16.8)
[node name="IntactVisual" type="Node3D" parent="."]
'''+ '\n'.join(nodes),encoding='utf-8')
print('Compiled consequence tower: 384 lazy panels, 4 chunks, 3 authored bonds; 15.2 m cavity')
