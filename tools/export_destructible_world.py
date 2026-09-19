"""Offline segmentation of every supplied architectural mesh; never runs in game."""
import bpy, bmesh, json, math, time
from pathlib import Path
from mathutils import Vector, Matrix

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT/'project/assets/blender_maps'
BAND = 24.0
started = time.time()
source_objects = []
for collection in bpy.data.collections:
    if collection.name.startswith(('01_', '02_')):
        collection.hide_viewport = False
        source_objects += [ob for ob in list(collection.all_objects) if ob and ob.type == 'MESH']
source_objects = sorted(set(source_objects), key=lambda ob: ob.name)
derived = bpy.data.collections.new('DERIVED_DESTRUCTIBLE_WORLD')
bpy.context.scene.collection.children.link(derived)
cap = bpy.data.materials.new('INK_CUT_FACE')
cap.diffuse_color = (0.008,0.008,0.008,1)
manifest = {'band_height':BAND, 'source':'资产模型/VerticalCanyon.blend', 'buildings':[], 'section_count':0}

def mesh_object(name, bm, parent, source_materials):
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    mesh.update()
    for material in source_materials: mesh.materials.append(material)
    mesh.materials.append(cap)
    ob = bpy.data.objects.new(name, mesh)
    derived.objects.link(ob)
    ob.parent = parent
    return ob

def cut(bm, height, lower, cap_index):
    result = bmesh.ops.bisect_plane(bm, geom=list(bm.verts)+list(bm.edges)+list(bm.faces),
        dist=0.0001, plane_co=(0,0,height), plane_no=(0,0,1),
        clear_inner=lower, clear_outer=not lower)
    boundary = [e for e in result['geom_cut'] if isinstance(e,bmesh.types.BMEdge) and e.is_valid and e.is_boundary]
    if boundary:
        faces = bmesh.ops.holes_fill(bm, edges=boundary, sides=0).get('faces',[])
        for face in faces: face.material_index = cap_index

for index, source in enumerate(source_objects):
    key = f'B{index:03d}'
    source.hide_set(False)
    source.hide_viewport = False
    bpy.context.view_layer.update()
    evaluated = source.evaluated_get(bpy.context.evaluated_depsgraph_get())
    mesh = evaluated.to_mesh()
    bm = bmesh.new()
    bm.from_mesh(mesh)
    evaluated.to_mesh_clear()
    bmesh.ops.transform(bm, matrix=source.matrix_world, verts=list(bm.verts))
    bounds_min = Vector([min(v.co[i] for v in bm.verts) for i in range(3)])
    bounds_max = Vector([max(v.co[i] for v in bm.verts) for i in range(3)])
    center = (bounds_min+bounds_max)*0.5
    bmesh.ops.translate(bm, vec=-center, verts=list(bm.verts))
    parent = bpy.data.objects.new(key, None)
    derived.objects.link(parent)
    parent.location = center
    materials = list(source.data.materials)
    mesh_object(key+'_Intact',bm,parent,materials)
    section_bounds = []
    bottom, top = bounds_min.z, bounds_max.z
    cuts = [bottom] + [v*BAND for v in range(math.floor(bottom/BAND)+1,math.ceil(top/BAND))] + [top]
    for lower,upper in zip(cuts,cuts[1:]):
        piece = bm.copy()
        if lower > bottom+0.0001: cut(piece,lower-center.z,True,len(materials))
        if upper < top-0.0001: cut(piece,upper-center.z,False,len(materials))
        if piece.faces:
            bmesh.ops.recalc_face_normals(piece,faces=list(piece.faces))
            mesh_object(f'{key}_S{len(section_bounds):03d}',piece,parent,materials)
            section_bounds.append([lower-center.z,upper-center.z])
        piece.free()
    bm.free()
    manifest['buildings'].append({'id':key,'source_name':source.name,'position':[center.x,center.z,-center.y], 'sections':len(section_bounds), 'height_ranges':section_bounds})
    manifest['section_count'] += len(section_bounds)
    if index%20==0: print('SEGMENT',index,'/',len(source_objects),'parts',manifest['section_count'],flush=True)

bpy.ops.object.select_all(action='DESELECT')
for ob in list(derived.all_objects): ob.select_set(True)
bpy.context.view_layer.update()
bpy.ops.export_scene.gltf(filepath=str(OUT/'destructible_world.glb'),export_format='GLB',use_selection=True,
    export_apply=True,export_animations=False,export_cameras=False,export_lights=False,export_extras=False)
manifest['elapsed_seconds'] = round(time.time()-started,2)
(OUT/'destructible_manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
print('OFFLINE WORLD COMPLETE',len(source_objects),'buildings',manifest['section_count'],'sections',manifest['elapsed_seconds'],'seconds',flush=True)
