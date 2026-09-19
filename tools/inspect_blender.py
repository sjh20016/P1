import bpy, json
from mathutils import Vector
report = {'version': bpy.app.version_string, 'collections': [c.name for c in bpy.data.collections], 'meshes': []}
for ob in bpy.context.scene.objects:
    if ob.type != 'MESH':
        continue
    corners = [ob.matrix_world @ Vector(v) for v in ob.bound_box]
    report['meshes'].append({'name': ob.name, 'vertices': len(ob.data.vertices), 'min': [min(v[i] for v in corners) for i in range(3)], 'max': [max(v[i] for v in corners) for i in range(3)]})
with open('E:/world7/build/blender_inspection.json', 'w', encoding='utf-8') as f:
    json.dump(report, f, indent=2)
print('INSPECTED', len(report['meshes']))
