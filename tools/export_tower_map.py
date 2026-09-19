"""Offline Blender -> GLB bake. Does not modify the supplied .blend file."""
import bpy, json
from pathlib import Path
from mathutils import Vector
ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT/'project/assets/blender_maps'
OUT.mkdir(parents=True, exist_ok=True)
report = {'collections': {}, 'markers': [], 'collisions': [], 'destructibles': [], 'source': '资产模型/VerticalCanyon.blend'}
for col in bpy.data.collections:
    report['collections'][col.name] = {'count': len(col.all_objects), 'examples': [o.name for o in list(col.all_objects)[:8]]}
for ob in bpy.context.scene.objects:
    if ob.type == 'EMPTY':
        report['markers'].append({'name': ob.name,'position':list(ob.matrix_world.translation)})
    if ob.type == 'MESH' and any(c.name.startswith(('03_', '07_')) for c in ob.users_collection):
        vs = [ob.matrix_world @ Vector(v) for v in ob.bound_box]
        target = 'collisions' if any(c.name.startswith('07_') for c in ob.users_collection) else 'destructibles'
        report[target].append({'name': ob.name, 'min':[min(v[i] for v in vs) for i in range(3)], 'max':[max(v[i] for v in vs) for i in range(3)]})
bpy.ops.object.select_all(action='DESELECT')
selected = []
for col in bpy.data.collections:
    if col.name.startswith(('01_', '02_')):
        col.hide_viewport = False
        for ob in list(col.all_objects):
            if ob is not None and ob.type == 'MESH':
                ob.hide_set(False)
                ob.hide_viewport = False
                ob.select_set(True)
                selected.append(ob)
# One fixed map. Collisions are authored separately from source collision proxies.
bpy.ops.export_scene.gltf(filepath=str(OUT/'tower_forest.glb'), export_format='GLB', use_selection=True, export_apply=True, export_animations=False, export_cameras=False, export_lights=False, export_extras=False)
report['exported_mesh_objects'] = len(selected)
# Export authored intact/shard pairs at their shared local origin.
DEST = ROOT/'project/assets/destructibles'
DEST.mkdir(parents=True, exist_ok=True)
report['segment_placements'] = []
for col in bpy.data.collections:
    if col.name.startswith(('03_', '04_')):
        col.hide_viewport = False
        col.hide_render = False
bpy.context.view_layer.update()
for index in range(1, 13):
    key = f'D{index:02d}'
    intact = bpy.data.objects.get(key + '_INTACT')
    if not intact:
        continue
    report['segment_placements'].append({'id':key, 'position':list(intact.matrix_world.translation), 'rotation':list(intact.rotation_euler)})
    bpy.ops.object.select_all(action='DESELECT')
    original = intact.matrix_world.copy()
    intact.hide_set(False)
    intact.hide_viewport = False
    intact.select_set(True)
    intact.location = (0,0,0)
    bpy.context.view_layer.update()
    bpy.ops.export_scene.gltf(filepath=str(DEST/(key+'_intact.glb')),export_format='GLB',use_selection=True,export_apply=True,export_animations=False)
    intact.matrix_world = original
    bpy.ops.object.select_all(action='DESELECT')
    shards = [bpy.data.objects.get(key + f'_Shard_{i}') for i in range(4)]
    for ob in shards:
        if ob:
            ob.hide_set(False)
            ob.hide_viewport = False
            ob.select_set(True)
    bpy.context.view_layer.update()
    bpy.ops.export_scene.gltf(filepath=str(DEST/(key+'_broken.glb')),export_format='GLB',use_selection=True,export_apply=True,export_animations=False)
    report.setdefault('shard_bounds',{})[key] = [{'name':o.name,'location':list(o.location),'bounds':list(o.dimensions)} for o in shards if o]
(OUT/'map_manifest.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print('MAP_EXPORT', len(selected), str(OUT/'tower_forest.glb'))
