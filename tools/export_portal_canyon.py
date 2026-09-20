"""Run with Blender --background --factory-startup --python; source is read-only.

Bake original scene triangles into spatial damage cells. This preserves source
silhouettes/material colors; Godot merges surviving cells into one draw surface
per object. No per-cell nodes and no runtime Blender dependency.
"""
import bpy
import hashlib
import json
import math
import struct
import gzip
import io
from collections import defaultdict
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "资产模型" / "VerticalCanyon.blend"
OUTPUT = ROOT / "project" / "assets" / "canyon"
OUTPUT.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(SOURCE))


def game(v):
    return (v.x, v.z, -v.y)


def clip(poly, axis, boundary, positive):
    if not poly:
        return []
    result = []
    a = poly[-1]
    da = (a[axis] - boundary) * positive
    for b in poly:
        db = (b[axis] - boundary) * positive
        if (da >= -1e-6) != (db >= -1e-6):
            t = da / (da - db)
            result.append(tuple(a[i] + (b[i] - a[i]) * t for i in range(3)))
        if db >= -1e-6:
            result.append(b)
        a, da = b, db
    return result


def cells(poly, axis=0, key=()):
    if axis == 3:
        yield key, poly
        return
    low = math.floor(min(v[axis] for v in poly) / 8)
    high = math.floor((max(v[axis] for v in poly) - 1e-6) / 8)
    for k in range(low, max(low, high) + 1):
        section = clip(clip(poly, axis, k * 8, 1), axis, (k + 1) * 8, -1)
        if len(section) >= 3:
            yield from cells(section, axis + 1, key + (k,))


def rgba(mat):
    if mat is None:
        return (0.8, 0.8, 0.8, 1.0)
    if mat.use_nodes:
        node = next((n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
        if node:
            return tuple(node.inputs["Base Color"].default_value)
    return tuple(mat.diffuse_color)


def u32(file, value):
    file.write(struct.pack("<I", value))


def floats(file, values):
    file.write(struct.pack("<" + "f" * len(values), *values))


names = ["01_STATIC_TowerForest_BAKED", "02_STATIC_Bridges_And_Anchors", "03_DESTRUCTIBLE_Intact"]
objects = sorted({o for name in names for o in bpy.data.collections[name].objects if o.type == "MESH"}, key=lambda o: o.name)
report = {"source": "资产模型/VerticalCanyon.blend", "source_sha256": hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
          "cell_size_m": 8, "objects": [], "markers": {o.name: game(o.matrix_world.translation) for o in bpy.data.collections["05_LAYOUT_Markers_NO_GAME_LOGIC"].objects},
          "basis": "Blender (X,Y,Z) -> Godot (X,Z,-Y); triangle winding reversed"}
depsgraph = bpy.context.evaluated_depsgraph_get()
with (OUTPUT / "vertical_canyon.bin").open("wb") as file:
    u32(file, 0x43414E33)
    u32(file, len(objects))
    for number, obj in enumerate(objects):
        evaluated = obj.evaluated_get(depsgraph)
        mesh = evaluated.to_mesh()
        mesh.calc_loop_triangles()
        origin = Vector(game(obj.matrix_world.translation))
        vertices = [tuple(Vector(game(obj.matrix_world @ v.co)) - origin) for v in mesh.vertices]
        normal_matrix = obj.matrix_world.to_3x3().inverted().transposed()
        batches = defaultdict(list)
        original = []
        for triangle_id, tri in enumerate(mesh.loop_triangles):
            n = game((normal_matrix @ tri.normal).normalized())
            color = rgba(mesh.materials[tri.material_index] if tri.material_index < len(mesh.materials) else None)
            polygon = [vertices[i] for i in tri.vertices]
            original.extend([(polygon[i], n, color) for i in [0, 2, 1]])
            for key, section in cells(polygon):
                for i in range(1, len(section) - 1):
                    a, b, c = section[0], section[i + 1], section[i]
                    if (Vector(b) - Vector(a)).cross(Vector(c) - Vector(a)).length_squared < 1e-10:
                        continue
                    batches[key].extend([(a, n, color, triangle_id), (b, n, color, triangle_id), (c, n, color, triangle_id)])
        positions, normals, colors, metadata, source_ids = [], [], [], [], []
        for key in sorted(batches):
            batch = batches[key]
            start = len(positions) // 3
            lo = [min(v[0][axis] for v in batch) for axis in range(3)]
            hi = [max(v[0][axis] for v in batch) for axis in range(3)]
            metadata.append((lo, hi, start, len(batch)))
            for at, (v, n, color, source_id) in enumerate(batch):
                positions.extend(v); normals.extend(n); colors.extend(color)
                if at % 3 == 0:
                    source_ids.append(source_id)
        name = obj.name.encode("utf-8")
        u32(file, len(name)); file.write(name); floats(file, origin)
        u32(file, len(original))
        for channel in range(3):
            floats(file, [value for vertex in original for value in vertex[channel]])
        payload = io.BytesIO()
        u32(payload, len(positions) // 3)
        floats(payload, positions); floats(payload, normals); floats(payload, colors)
        payload.write(struct.pack("<" + "I" * len(source_ids), *source_ids))
        u32(payload, len(metadata))
        for lo, hi, start, count in metadata:
            floats(payload, lo + hi); u32(payload, start); u32(payload, count)
        data = payload.getvalue()
        compressed = gzip.compress(data, compresslevel=6, mtime=0)
        u32(file, len(data)); u32(file, len(compressed)); file.write(compressed)
        report["objects"].append({"name": obj.name, "cells": len(metadata), "triangles": len(positions) // 9})
        evaluated.to_mesh_clear()
        if number % 40 == 0:
            print("CANYON_BAKE", number, obj.name, flush=True)
report["total_cells"] = sum(o["cells"] for o in report["objects"])
report["total_triangles"] = sum(o["triangles"] for o in report["objects"])
(OUTPUT / "layout.json").write_text(json.dumps(report, indent=2, ensure_ascii=False), encoding="utf-8")
print("CANYON_EXPORTED", len(objects), "objects", report["total_cells"], "cells", report["total_triangles"], "triangles", flush=True)
