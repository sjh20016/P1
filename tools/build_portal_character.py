"""Deterministic, editable low-poly character + pixel atlas + skin + actions.
Run: blender --background --factory-startup --python tools/build_portal_character.py
Front is Blender -Y / glTF +Z. Grounded root is at the soles, meters.
"""
import bpy
import math
import json
from pathlib import Path
from mathutils import Vector, Euler

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "project/assets/characters/portal_anomaly"
SOURCE = ROOT / "角色资产"
OUT.mkdir(parents=True, exist_ok=True)
SOURCE.mkdir(parents=True, exist_ok=True)
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
bpy.context.preferences.filepaths.save_version = 0
for action in list(bpy.data.actions):
    bpy.data.actions.remove(action)

# Deliberately discrete palette. No baked light gradients, normal/roughness maps.
PALETTE = {
    "void": "10121D", "ink": "1B2030", "ink_light": "323A50", "slate": "515B72",
    "white": "E7EBF0", "white_shade": "BAC6D4", "white_high": "F7F9FC",
    "hair": "A9CBE8", "hair_shade": "7195BA", "hair_light": "CFE5F4",
    "skin": "E8D8D3", "skin_shade": "C3AAAE", "eye": "527FA8", "steel": "869BAF",
}
def rgba(key):
    h = PALETTE[key]
    return tuple(int(h[i:i+2], 16) / 255 for i in (0, 2, 4)) + (1.0,)

N = 128
pixels = list(rgba("ink")) * (N * N)
def pixel(x, y, color):
    pixels[(y * N + x)*4:(y * N + x)*4+4] = rgba(color)
def rect(x, y, w, h, color):
    for row in range(y, y+h):
        for col in range(x, x+w): pixel(col, row, color)

tiles = {}
for i, key in enumerate(PALETTE):
    tx, ty = (i % 8) * 16, (i // 8) * 16
    rect(tx, ty, 16, 16, key); tiles[key] = (tx, ty, 16, 16)
for key, dark, light in [("white", "white_shade", "white_high"), ("hair", "hair_shade", "hair_light"), ("ink", "void", "ink_light")]:
    tx, ty, _, _ = tiles[key]
    rect(tx, ty, 3, 16, dark); rect(tx+3, ty, 3, 6, dark)
    rect(tx+12, ty+9, 2, 5, light); rect(tx+10, ty+12, 2, 3, light)
    rect(tx+5, ty+2, 3, 2, dark)
# Face is a 32-pixel, hand-plotted expression, not an image pasted onto a head.
FACE = (0, 48, 32, 32)
rect(*FACE, "skin")
rect(0, 48, 3, 32, "skin_shade"); rect(29, 48, 3, 32, "skin_shade")
rect(3, 48, 26, 3, "skin_shade")
for x in [5, 20]:
    rect(x, 61, 8, 2, "ink"); rect(x+1, 57, 6, 4, "white_high")
    rect(x+3, 57, 3, 4, "eye"); rect(x+4, 58, 2, 3, "ink")
    rect(x+3, 60, 1, 1, "hair_light"); rect(x+1, 56, 6, 1, "skin_shade")
    rect(x+1, 66, 6, 1, "hair_shade")
rect(16, 55, 1, 2, "skin_shade"); rect(14, 52, 4, 1, "ink_light")
# Dedicated diamond sigil and glove rune tiles.
tiles["sigil"] = (40, 48, 16, 24)
rect(40, 48, 16, 24, "void")
for y in range(4, 21):
    half = max(0, int((8-abs(y-12)) * 0.55))
    for x in range(8-half, 9+half): pixel(40+x, 48+y, "slate")
rect(48, 56, 1, 10, "white_shade")
tiles["rune"] = (64, 48, 16, 16)
rect(64, 48, 16, 16, "ink")
for y in range(3, 13):
    w = 4-abs(y-8)
    if w >= 0:
        pixel(72-w, 48+y, "steel"); pixel(72+w, 48+y, "steel")
rect(72, 53, 1, 6, "white_shade")
image = bpy.data.images.new("Anomaly_PixelAtlas_128", width=N, height=N, alpha=False)
image.pixels[:] = pixels
image.filepath_raw = str(OUT / "pixel_atlas_128.png"); image.file_format = "PNG"; image.save()
image.pack()
material = bpy.data.materials.new("Pixel_ColdInk_Unlit")
material.use_nodes = True
nodes = material.node_tree.nodes; nodes.clear()
tex = nodes.new("ShaderNodeTexImage"); tex.image = image; tex.interpolation = "Closest"; tex.extension = "EXTEND"
emission = nodes.new("ShaderNodeEmission"); emission.inputs["Strength"].default_value = 1
output = nodes.new("ShaderNodeOutputMaterial")
material.node_tree.links.new(tex.outputs["Color"], emission.inputs["Color"])
material.node_tree.links.new(emission.outputs[0], output.inputs["Surface"])

verts, faces, uv_faces, weights, parts = [], [], [], [], {}
def uv_rect(key):
    x, y, w, h = FACE if key == "face" else tiles[key]
    return ((x+0.5)/N, (y+0.5)/N, (x+w-0.5)/N, (y+h-0.5)/N)

def piece(name, points, polys, bone, tile="ink", face_tiles=None, influence=None):
    start = len(verts); verts.extend(points)
    for i, p in enumerate(points):
        weights.append(influence[i] if influence else {bone: 1.0})
    for i, poly in enumerate(polys):
        faces.append(tuple(start+j for j in poly))
        key = face_tiles[i] if face_tiles else tile
        u0, v0, u1, v1 = uv_rect(key)
        if len(poly) == 4: uv_faces.append([(u0,v0),(u1,v0),(u1,v1),(u0,v1)])
        else: uv_faces.append([((u0+u1)/2+(u1-u0)*0.48*math.cos(j*math.tau/len(poly)),(v0+v1)/2+(v1-v0)*0.48*math.sin(j*math.tau/len(poly))) for j in range(len(poly))])
    parts[name] = {"vertices": len(points), "bone": bone, "start": start}

def loft(name, rings, bone, tile, sides=8, ring_weights=None):
    points = []
    for x,y,z,rx,ry in rings:
        for i in range(sides):
            a = math.tau * i / sides + math.pi/8
            points.append((x+rx*math.cos(a),y+ry*math.sin(a),z))
    polys = [tuple(reversed(range(sides)))]
    for k in range(len(rings)-1):
        for i in range(sides): polys.append((k*sides+i,k*sides+(i+1)%sides,(k+1)*sides+(i+1)%sides,(k+1)*sides+i))
    polys.append(tuple((len(rings)-1)*sides+i for i in range(sides)))
    inf = [w for w in ring_weights for _ in range(sides)] if ring_weights else None
    piece(name,points,polys,bone,tile,influence=inf)
    # Wrap one pixel patch around a whole form: preserve the atlas but avoid
    # multiplying the same folds on every small polygon.
    if tile in ["white","hair","ink"]:
        u0,v0,u1,v1=uv_rect(tile)
        first=len(uv_faces)-len(polys)+1
        for k in range(len(rings)-1):
            for i in range(sides):
                a=u0+i/sides*(u1-u0); b=u0+(i+1)/sides*(u1-u0)
                c=v0+k/(len(rings)-1)*(v1-v0); d=v0+(k+1)/(len(rings)-1)*(v1-v0)
                uv_faces[first+k*sides+i]=[(a,c),(b,c),(b,d),(a,d)]

def bevel_box(name, center, size, bone, tile, bevel=0.02):
    # Eight-sided cross-section and inset end caps: readable low-poly chamfers.
    x,y,z = center; sx,sy,sz = size
    polygon = [(-sx/2+bevel,-sy/2),(sx/2-bevel,-sy/2),(sx/2,-sy/2+bevel),(sx/2,sy/2-bevel),(sx/2-bevel,sy/2),(-sx/2+bevel,sy/2),(-sx/2,sy/2-bevel),(-sx/2,-sy/2+bevel)]
    points = [(x+px*f,y+py*f,z+height) for f,height in [(0.85,-sz/2),(1,-sz/2+bevel),(1,sz/2-bevel),(0.85,sz/2)] for px,py in polygon]
    polys = [tuple(reversed(range(8)))] + [(k*8+i,k*8+(i+1)%8,(k+1)*8+(i+1)%8,(k+1)*8+i) for k in range(3) for i in range(8)] + [tuple(range(24,32))]
    piece(name,points,polys,bone,tile)

def plate(name, outline, depth, bone, tile, front_tile=None):
    # Outline coordinates are x,z; depth is (front_y, back_y).
    n = len(outline)
    points = [(x,y,z) for y in depth for x,z in outline]
    polys = [tuple(range(n)), tuple(reversed(range(n,2*n)))] + [(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    piece(name,points,polys,bone,tile,face_tiles=[front_tile or tile,tile]+[tile]*n)

# Main costume. The loose trousers taper at knees/ankles; no giant skirt volume.
loft("White_Tunic",[(0,0,.83,.21,.14),(0,0,.94,.20,.13),(0,0,1.16,.245,.15),(0,0,1.28,.27,.135)],"spine","white",12)
loft("Hip_Waist",[(0,0,.78,.20,.13),(0,0,.91,.205,.14)],"pelvis","ink",10)
plate("Tunic_Split_L",[(-.21,.92),(-.015,.91),(-.025,.76),(-.12,.80),(-.22,.77)],(-.147,-.115),"pelvis","white")
plate("Tunic_Split_R",[(.025,.91),(.21,.92),(.20,.78),(.10,.82),(.03,.76)],(-.147,-.115),"pelvis","white")
for sign, suffix in [(-1,"L"),(1,"R")]:
    x = sign*.13
    loft("Trouser_Upper_"+suffix,[(x,0,.50,.104,.115),(x,0,.60,.15,.145),(x,0,.77,.16,.145),(x,0,.87,.125,.12)],"thigh_"+suffix,"ink",10,
         [{"thigh_"+suffix:.5,"shin_"+suffix:.5},{"thigh_"+suffix:1},{"thigh_"+suffix:1},{"thigh_"+suffix:1}])
    loft("Trouser_Lower_"+suffix,[(x,0,.20,.068,.075),(x,0,.27,.078,.09),(x,0,.44,.108,.113),(x,0,.50,.104,.115)],"shin_"+suffix,"ink",10,
         [{"shin_"+suffix:1},{"shin_"+suffix:1},{"shin_"+suffix:1},{"thigh_"+suffix:.5,"shin_"+suffix:.5}])
    bevel_box("Boot_"+suffix,(x,-.045,.105),(.19,.30,.21),"foot_"+suffix,"void",.025)
    bevel_box("Boot_Sole_"+suffix,(x,-.055,.035),(.202,.315,.06),"foot_"+suffix,"ink_light",.016)
    bevel_box("Boot_Cuff_"+suffix,(x,0,.22),(.17,.19,.08),"shin_"+suffix,"ink_light",.012)
    loft("Sleeve_Upper_"+suffix,[(sign*.37,0,1.01,.102,.103),(sign*.34,0,1.11,.12,.125),(sign*.285,0,1.26,.108,.12)],"upper_arm_"+suffix,"white",8,
         [{"upper_arm_"+suffix:.5,"forearm_"+suffix:.5},{"upper_arm_"+suffix:1},{"upper_arm_"+suffix:1}])
    loft("Sleeve_Lower_"+suffix,[(sign*.425,0,.83,.074,.075),(sign*.41,0,.90,.098,.10),(sign*.37,0,1.01,.102,.103)],"forearm_"+suffix,"white",8,
         [{"forearm_"+suffix:1},{"forearm_"+suffix:1},{"upper_arm_"+suffix:.5,"forearm_"+suffix:.5}])
    bevel_box("Cuff_"+suffix,(sign*.427,0,.824),(.16,.16,.052),"forearm_"+suffix,"void" if suffix=="R" else "white_shade",.012)
    bevel_box("Hand_"+suffix,(sign*.445,-.016,.744),(.125,.118,.155),"hand_"+suffix,"ink" if suffix=="R" else "skin",.024)
    bevel_box("Thumb_"+suffix,(sign*.384,-.05,.75),(.05,.074,.085),"hand_"+suffix,"ink" if suffix=="R" else "skin",.012)
    if suffix == "R":
        plate("Glove_Rune",[(.405,.79),(.486,.79),(.486,.71),(.405,.71)],(-.078,-.076),"hand_R","ink",front_tile="rune")
        plate("Glove_Cut_Cuff",[(.36,.85),(.49,.88),(.52,.81),(.44,.79)],(-.075,-.055),"forearm_R","ink_light")

# Head has a chamfered silhouette, with a real pixel-UV face and geometric ears.
loft("Neck",[(0,0,1.25,.068,.07),(0,0,1.45,.07,.07)],"head","skin",8)
loft("Head",[(0,0,1.43,.095,.11),(0,0,1.475,.155,.153),(0,0,1.55,.206,.183),(0,0,1.66,.221,.195),(0,0,1.79,.202,.177)],"head","skin",16)
face_outline=[(-.09,1.444),(.09,1.444),(.163,1.485),(.185,1.57),(.177,1.755),(-.177,1.755),(-.185,1.57),(-.163,1.485)]
piece("Face",[(x,-.202 if z>1.49 else -.19,z) for x,z in face_outline],[tuple(range(8))],"head","face")
u0,v0,u1,v1=uv_rect("face")
uv_faces[-1]=[(u0+(x+.185)/.37*(u1-u0),v0+(z-1.444)/.311*(v1-v0)) for x,z in face_outline]
for sign in [-1,1]:
    bevel_box("Ear_"+str(sign),(sign*.222,.002,1.585),(.052,.09,.12),"head","skin",.014)

# Broad hair masses: cap, three bangs, two side locks, three rear locks.
loft("Hair_Crown",[(0,.016,1.70,.253,.225),(0,.020,1.81,.252,.226),(0,.025,1.90,.19,.19),(0,.025,1.953,.072,.083)],"head","hair",12)
bangs = [([(-.25,1.81),(-.11,1.865),(-.052,1.735),(-.13,1.585),(-.145,1.72),(-.22,1.64)],(-.23,-.175)),
         ([(-.12,1.87),(.066,1.87),(.095,1.70),(.025,1.615),(.017,1.73),(-.035,1.68)],(-.249,-.18)),
         ([(.05,1.855),(.215,1.825),(.243,1.63),(.17,1.69),(.13,1.755)],(-.23,-.165))]
for i,(outline,depth) in enumerate(bangs): plate("Bang_%d"%i,outline,(depth[0],depth[0]+.026),"head","hair")
for s in [-1,1]:
    p=[]
    for x,y,z,width in [(.185,.005,1.86,.15),(.246,.005,1.73,.19),(.234,-.025,1.59,.135),(.213,-.055,1.515,.015)]:
        p.extend([(s*(x-.009),y-width/2,z),(s*(x+.009),y,z+.012),(s*(x-.009),y+width/2,z)])
    piece("Side_Hair_%d"%s,p,[(j*3+i,j*3+i+1,(j+1)*3+i+1,(j+1)*3+i) for j in range(3) for i in range(2)],"head","hair")
for i in [-1,0,1]:
    x=i*.14
    plate("Rear_Hair_%d"%i,[(x-.092,1.77),(x+.085,1.77),(x+.07,1.53),(x+.01,1.47),(x-.04,1.55),(x-.08,1.51)],(.14,.205),"hair_back","hair_shade" if i==0 else "hair")
for i,(x,z) in enumerate([(-.21,1.84),(-.09,1.936),(.09,1.943),(.216,1.84)]):
    plate("Crown_Tuft_%d"%i,[(x-.07,z-.03),(x+.06,z),(x+.02,z+.026),(x-.01,z+.019)],(-.025,.025),"head","hair_light" if i==1 else "hair")

# High collar is an open ring; shallow shoulder panels and three bone-driven tails.
segments = 16
pts = []
for z,rx,ry in [(1.285,.13,.118),(1.435,.155,.132),(1.435,.147,.124),(1.29,.122,.110)]:
    for i in range(segments):
        a=i*math.tau/segments; pts.append((rx*math.cos(a),ry*math.sin(a),z))
polys=[]
for k in range(3):
    for i in range(segments): polys.append((k*segments+i,k*segments+(i+1)%segments,(k+1)*segments+(i+1)%segments,(k+1)*segments+i))
piece("High_Collar",pts,polys,"spine","void")
# Folded cloth surfaces with a thin hem instead of extruded solid slabs.
def cloth(name, rows, bone, tile="ink", root_blend=False):
    p=[]; w=[]; columns=5
    for j,(left,right,z,y,ridge) in enumerate(rows):
        for c in range(columns):
            t=c/(columns-1)
            p.append((left+(right-left)*t,y+math.sin(t*math.pi*2)*ridge,z))
            mix=max(0,1-j/2)*.85 if root_blend else 0
            w.append({"spine":mix,bone:1-mix} if mix else {bone:1})
    f=[(j*columns+c,j*columns+c+1,(j+1)*columns+c+1,(j+1)*columns+c) for j in range(len(rows)-1) for c in range(columns-1)]
    piece(name,p,f,bone,tile,influence=w)
    u0,v0,u1,v1=uv_rect(tile)
    for q,poly in enumerate(f):
        uv_faces[-len(f)+q]=[(u0+(k%columns)/4*(u1-u0),v1-(k//columns)/(len(rows)-1)*(v1-v0)) for k in poly]
    boundary=list(range(columns))+[j*columns+4 for j in range(1,len(rows))]+list(range(len(p)-2,len(p)-columns-1,-1))+[j*columns for j in range(len(rows)-2,0,-1)]
    edge=[p[k] for k in boundary]+[(p[k][0],p[k][1]-.004,p[k][2]) for k in boundary]
    n=len(boundary)
    piece(name+"_Hem",edge,[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)],bone,"ink_light",influence=[w[k] for k in boundary]*2)
for s in [-1,1]:
    rows=[(.025,.14,1.36,-.105,.012),(.07,.24,1.30,-.16,.018),(.10,.315,1.245,-.15,.021),(.14,.30,1.205,-.14,.016)]
    cloth("Shoulder_Mantle_%d"%s,[(s*a,s*b,z,y,r) for a,b,z,y,r in rows],"spine")
    # Fold over the shoulder to join front lapel and rear yoke.
    p=[(s*x,y,z) for x,y,z in [(.14,-.105,1.35),(.24,-.16,1.30),(.315,-.15,1.245),(.15,.01,1.355),(.25,.015,1.305),(.323,.025,1.25),(.135,.125,1.35),(.25,.165,1.27),(.285,.195,1.16)]]
    piece("Mantle_Bridge_%d"%s,p,[(0,1,4,3),(1,2,5,4),(3,4,7,6),(4,5,8,7)],"spine","ink")
cloth("Back_Yoke",[(-.135,.135,1.35,.125,.012),(-.27,.27,1.27,.165,.025),(-.285,.285,1.16,.195,.024),(-.25,.25,1.10,.22,.018)],"spine")
cloth("Cape_Tail_L",[(-.275,-.07,1.20,.205,.024),(-.285,-.075,1.04,.25,.032),(-.31,-.09,.86,.275,.025),(-.33,-.155,.69,.31,.017),(-.345,-.285,.58,.33,.006)],"cape_L",root_blend=True)
cloth("Cape_Tail_R",[(.065,.275,1.20,.21,.023),(.07,.285,1.03,.26,.030),(.10,.32,.84,.30,.024),(.18,.355,.64,.335,.012),(.31,.365,.51,.35,.005)],"cape_R",root_blend=True)
cloth("Cape_Tail_C",[(-.073,.073,1.17,.23,.012),(-.083,.087,1.04,.27,.018),(-.065,.078,.86,.30,.015),(-.012,.034,.72,.33,.004)],"cape_C","void",root_blend=True)
# Back sigil faces +Y and uses the same graphic texture as the glove language.
piece("Back_Diamond",[(-.065,.272,1.045),(.065,.272,1.045),(.065,.198,1.27),(-.065,.198,1.27)],[(3,2,1,0)],"spine","sigil")
# Chest ring, collar clasp and geometric pendant: 12-sided, no jewelry simulation.
def ring(name, center, outer, inner, bone, tile, n=12):
    x,y,z=center
    p=[(x+r*math.sin(i*math.tau/n),y,z+r*math.cos(i*math.tau/n)) for r in [outer,inner] for i in range(n)]
    f=[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    piece(name,p,f,bone,tile)
ring("Chest_Ring",(0,-.178,1.20),.059,.038,"spine","white_shade")
bevel_box("Collar_Clasp",(0,-.148,1.345),(.024,.024,.065),"spine","white_shade",.004)
plate("Pendant",[(0,1.15),(.03,1.08),(0,1.015),(-.03,1.08)],(-.176,-.15),"pendant","void")

# Slim costume volume around each limb; apply the same width factor to the rig.
for name,part in parts.items():
    for i in range(part["start"],part["start"]+part["vertices"]):
        x,y,z=verts[i]
        sign=-1 if name.endswith("L") else 1
        if name.startswith(("Trouser_","Boot_")):
            x=sign*.13+(x-sign*.13)*.82; y*=.9
        elif name.startswith("Sleeve_"):
            center=sign*(.425-(z-.83)*.32)
            x=center+(x-center)*.79; y*=.8
        elif name.startswith(("Hand_","Thumb_")):
            center=sign*(.445 if name.startswith("Hand") else .384)
            x=center+(x-center)*.85; y*=.85
        verts[i]=(x*.88,y,z)

# One mesh / one atlas material. Named vertex groups retain authored part ownership.
mesh=bpy.data.meshes.new("Anomaly_Lowpoly_Mesh"); mesh.from_pydata(verts,[],faces); mesh.update()
body=bpy.data.objects.new("Anomaly_Body",mesh); bpy.context.collection.objects.link(body)
mesh.materials.append(material)
uv=mesh.uv_layers.new(name="PixelAtlas")
for polygon,coords in zip(mesh.polygons,uv_faces):
    for loop,coord in zip(polygon.loop_indices,coords): uv.data[loop].uv=coord
for bone in sorted({name for w in weights for name in w}): body.vertex_groups.new(name=bone)
for i,w in enumerate(weights):
    for bone,value in w.items(): body.vertex_groups[bone].add([i],value,"REPLACE")
# Recalculate outward normals for closed costume parts. Face and decals remain front-facing.
bpy.context.view_layer.objects.active=body; body.select_set(True)
bpy.ops.object.mode_set(mode="EDIT"); bpy.ops.mesh.select_all(action="SELECT"); bpy.ops.mesh.normals_make_consistent(inside=False); bpy.ops.object.mode_set(mode="OBJECT")

arm=bpy.data.armatures.new("Anomaly_Rig_v01"); rig=bpy.data.objects.new("Anomaly_Rig",arm); bpy.context.collection.objects.link(rig)
bpy.context.view_layer.objects.active=rig; body.select_set(False); rig.select_set(True); bpy.ops.object.mode_set(mode="EDIT")
def bone(name,head,tail,parent=None):
    b=arm.edit_bones.new(name); b.head=(head[0]*.88,head[1],head[2]); b.tail=(tail[0]*.88,tail[1],tail[2])
    if parent: b.parent=arm.edit_bones[parent]
    return b
bone("root",(0,0,0),(0,0,.18)); bone("pelvis",(0,0,.82),(0,0,1.01),"root")
bone("spine",(0,0,1.01),(0,0,1.32),"pelvis"); bone("head",(0,0,1.32),(0,0,1.79),"spine")
for s,k in [(-1,"L"),(1,"R")]:
    bone("upper_arm_"+k,(s*.26,0,1.255),(s*.37,0,1.01),"spine")
    bone("forearm_"+k,(s*.37,0,1.01),(s*.425,0,.82),"upper_arm_"+k)
    bone("hand_"+k,(s*.425,0,.82),(s*.45,0,.70),"forearm_"+k)
    bone("thigh_"+k,(s*.13,0,.84),(s*.13,0,.50),"pelvis")
    bone("shin_"+k,(s*.13,0,.50),(s*.13,0,.19),"thigh_"+k)
    bone("foot_"+k,(s*.13,0,.19),(s*.13,-.19,.07),"shin_"+k)
for name,x in [("cape_L",-.18),("cape_R",.18),("cape_C",0)]: bone(name,(x,.17,1.15),(x,.20,.83),"spine")
bone("hair_back",(0,.12,1.72),(0,.18,1.51),"head")
bone("pendant",(0,-.16,1.16),(0,-.16,1.055),"spine")
bpy.ops.object.mode_set(mode="OBJECT")
modifier=body.modifiers.new("Skin_21_Bones","ARMATURE"); modifier.object=rig; body.parent=rig
rig.show_in_front=True
anchors={"FX_CastHand":("hand_R",(.455,-.09,.735)),"FX_Chest":("spine",(0,-.21,1.20)),"FX_Waist":("pelvis",(0,-.18,.87)),
         "FX_Foot_L":("foot_L",(-.13,-.045,.012)),"FX_Foot_R":("foot_R",(.13,-.045,.012)),"FX_Cape":("cape_C",(0,.23,.83))}
for name,(parent,location) in anchors.items():
    obj=bpy.data.objects.new(name,None); bpy.context.collection.objects.link(obj); obj.empty_display_size=.06
    obj.parent=rig; obj.parent_type="BONE"; obj.parent_bone=parent
    bpy.context.view_layer.update()
    obj.matrix_world.translation=Vector((location[0]*.88,location[1],location[2]))

FPS=30; bpy.context.scene.render.fps=FPS
actions={"Idle":(60,True),"Run":(24,True),"Jump":(18,False),"Fall":(30,True),"Land":(12,False),"Cast":(24,False),"Cut":(24,False),"Dash":(18,True)}
for name,(duration,loop) in actions.items():
    rig.animation_data_create(); rig.animation_data.action=bpy.data.actions.new(name)
    action=rig.animation_data.action; action.use_fake_user=True
    for frame in sorted(set(list(range(0,duration+1,2))+[duration])):
        phase=frame/duration; sine=math.sin(phase*math.tau)
        for pb in rig.pose.bones:
            pb.rotation_mode="XYZ"; pb.rotation_euler=(0,0,0); pb.location=(0,0,0); pb.scale=(1,1,1)
        def rot(b,x=0,y=0,z=0):
            pb=rig.pose.bones[b]
            rest=pb.bone.matrix_local.to_3x3()
            desired=Euler(tuple(math.radians(v) for v in (x,y,z)),"XYZ").to_matrix()
            pb.rotation_euler=(rest.inverted() @ desired @ rest).to_euler("XYZ")
        if name=="Idle":
            rot("spine",sine*1.3); rot("head",-sine*.8); rot("forearm_R",-8)
            rig.pose.bones["pelvis"].location.y=sine*.006
        elif name=="Run":
            for s,k in [(-1,"L"),(1,"R")]:
                rot("thigh_"+k,s*sine*33); rot("shin_"+k,max(0,-s*sine)*42)
                rot("upper_arm_"+k,-s*sine*28); rot("forearm_"+k,-24-max(0,s*sine)*12)
            rot("spine",10,0,sine*2); rot("head",-5,0,-sine)
            rig.pose.bones["pelvis"].location.y=abs(sine)*.018
        elif name=="Jump":
            lift=math.sin(phase*math.pi)
            rot("thigh_L",-22*lift); rot("thigh_R",-32*lift); rot("shin_L",28*lift); rot("shin_R",44*lift)
            rot("upper_arm_L",-28*lift); rot("upper_arm_R",-35*lift); rot("spine",-5*lift)
        elif name=="Fall":
            rot("spine",-5); rot("head",4)
            rot("upper_arm_L",-18+sine*2,0,-12); rot("upper_arm_R",-14-sine*2,0,12)
            rot("forearm_L",-15); rot("forearm_R",-20); rot("shin_L",14); rot("shin_R",24)
        elif name=="Land":
            squash=math.sin(phase*math.pi)
            rot("thigh_L",-20*squash); rot("thigh_R",-20*squash); rot("shin_L",35*squash); rot("shin_R",35*squash)
            rot("spine",12*squash); rig.pose.bones["pelvis"].location.y=-.05*squash
        elif name in ["Cast","Cut"]:
            reach=math.sin(phase*math.pi)
            rot("upper_arm_R",-68*reach,0,-10*reach); rot("forearm_R",-28*reach); rot("hand_R",0,0,-12*reach)
            rot("spine",3*reach,0,(-14 if name=="Cut" else -5)*sine)
            if name=="Cut":
                # Compact anticipation, fast diagonal release, then recover.
                sweep=min(1,max(0,(phase-.10)/.32))
                recovery=max(0,(phase-.65)/.35)
                rot("upper_arm_R",(-48-35*sweep)*(1-recovery),0,(-38+83*sweep)*(1-recovery))
                rot("forearm_R",(-35+20*sweep)*(1-recovery))
                rot("spine",5*(1-recovery),0,(-10+22*sweep)*(1-recovery))
            rot("upper_arm_L",8*reach); rot("forearm_L",-12*reach)
        elif name=="Dash":
            rot("spine",28); rot("head",-14); rot("upper_arm_L",32); rot("upper_arm_R",24)
            rot("thigh_L",-18); rot("shin_L",26); rot("shin_R",12)
        for i,b in enumerate(["cape_L","cape_C","cape_R"]):
            flutter=math.sin(phase*math.tau + i*.65)
            rot(b,(-22 if name in ["Run","Dash","Fall"] else -3)+flutter*(3+i),0,flutter*1.5)
        rot("hair_back",sine*2); rot("pendant",sine*4)
        for pb in rig.pose.bones:
            pb.keyframe_insert(data_path="rotation_euler",frame=frame,group=pb.name)
            pb.keyframe_insert(data_path="location",frame=frame,group=pb.name)
    # glTF exporter discovers all compatible armature actions in ACTIONS mode.
    action["loop"]=loop
rig.animation_data.action=None
for pb in rig.pose.bones: pb.rotation_euler=(0,0,0); pb.location=(0,0,0)
bpy.context.scene.frame_set(0)
mesh.calc_loop_triangles()
report={"name":"Portal Anomaly 0.1 - slender cloth revision","triangles":len(mesh.loop_triangles),"vertices":len(mesh.vertices),"materials":1,
        "atlas":[128,128],"palette":PALETTE,"bones":len(arm.bones),"height_m":round(max(v.co.z for v in mesh.vertices),3),
        "head_ratio":"approximately 3.8 heads","forward":"Blender -Y; glTF +Z","root":"soles / meters",
        "actions":{k:{"seconds":v[0]/FPS,"loop":v[1]} for k,v in actions.items()},"anchors":anchors,"parts":parts,
        "weights_max":max(len(w) for w in weights),"physics":"Visual-only skin; no cloth simulation; game owns collision and root movement"}
assert 1500 <= report["triangles"] <= 4000, report["triangles"]
(OUT/"model_report.json").write_text(json.dumps(report,indent=2,ensure_ascii=False),encoding="utf-8")
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/"PortalAnomaly_01.blend"))
bpy.ops.object.select_all(action="DESELECT")
body.select_set(True); rig.select_set(True)
for name in anchors: bpy.data.objects[name].select_set(True)
bpy.ops.export_scene.gltf(filepath=str(OUT/"portal_anomaly.glb"),export_format="GLB",use_selection=True,
                          export_animations=True,export_animation_mode="ACTIONS",export_skins=True,export_yup=True)
print("CHARACTER_BUILT",json.dumps({k:report[k] for k in ["triangles","vertices","bones","height_m","weights_max"]}),flush=True)
