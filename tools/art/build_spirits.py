"""Build the original Karma models. Run with Blender 4.3+ in background mode.

This is an offline authoring tool, never a game dependency. Coordinates below use
Godot's Y-up convention; mesh creation converts them to Blender's Z-up space.
Every part is named and independently pivoted for the GDScript presentation rig.
"""

import math
import os
import bpy
from mathutils import Vector

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "assets", "karma")
os.makedirs(OUT, exist_ok=True)
TAU = math.tau


def vec(p):
    return Vector((p[0], -p[2], p[1]))


def material(name, color, metal=0.0, rough=0.4, emission=0.0):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*color, 1)
    m.use_nodes = True
    s = m.node_tree.nodes.get("Principled BSDF")
    s.inputs["Base Color"].default_value = (*color, 1)
    s.inputs["Metallic"].default_value = metal
    s.inputs["Roughness"].default_value = rough
    if emission:
        s.inputs["Emission Color"].default_value = (*color, 1)
        s.inputs["Emission Strength"].default_value = emission
    return m


def empty(name, location=(0, 0, 0), parent=None):
    o = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(o)
    o.location = vec(location)
    if parent:
        o.parent = parent
    return o


def mesh(name, vertices, faces, mat, parent, smooth=False, bevel=0):
    data = bpy.data.meshes.new(name)
    data.from_pydata([vec(v) for v in vertices], [], faces)
    data.update()
    o = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(o)
    o.parent = parent
    o.data.materials.append(mat)
    for p in data.polygons:
        p.use_smooth = smooth
    if bevel:
        mod = o.modifiers.new("Forged edge highlights", "BEVEL")
        mod.width = bevel
        mod.segments = 2
        mod.affect = 'EDGES'
        mod = o.modifiers.new("Weighted normals", "WEIGHTED_NORMAL")
        mod.keep_sharp = True
    return o


def plate(name, outline, depth, location, mat, parent, bevel=0.016):
    # A chamfered, closed shield/armour plate, rather than a scaled cube.
    n = len(outline)
    v = [(x + location[0], y + location[1], location[2] + z)
         for z in [-depth / 2, depth / 2] for x, y in outline]
    f = [tuple(reversed(range(n))), tuple(range(n, n * 2))]
    f += [(i, (i + 1) % n, (i + 1) % n + n, i + n) for i in range(n)]
    return mesh(name, v, f, mat, parent, bevel=bevel)


def loft(name, sections, mat, parent, sides=12, smooth=False, bevel=0.012):
    v = []
    for y, rx, rz, x, z in sections:
        for j in range(sides):
            angle = (j + 0.5) * TAU / sides
            v.append((x + math.cos(angle) * rx, y, z + math.sin(angle) * rz))
    f = [tuple(reversed(range(sides)))]
    for ring in range(len(sections) - 1):
        for j in range(sides):
            a, b = ring * sides + j, ring * sides + (j + 1) % sides
            f.append((a, b, b + sides, a + sides))
    f.append(tuple(range((len(sections) - 1) * sides, len(sections) * sides)))
    return mesh(name, v, f, mat, parent, smooth, bevel)


def beam(name, a, b, width, depth, mat, parent):
    # A chamfered strut with an actual octagonal cross section.
    a, b = Vector(a), Vector(b)
    axis = (b - a).normalized()
    normal = axis.cross(Vector((0, 0, 1)))
    if normal.length < 0.01:
        normal = axis.cross(Vector((0, 1, 0)))
    normal.normalize()
    other = axis.cross(normal).normalized()
    points = []
    for p in [a, b]:
        for j in range(8):
            angle = (j + 0.5) * TAU / 8
            points.append(tuple(p + normal * math.cos(angle) * width + other * math.sin(angle) * depth))
    return mesh(name, points, [tuple(reversed(range(8))), tuple(range(8, 16))]
                + [(j, (j + 1) % 8, (j + 1) % 8 + 8, j + 8) for j in range(8)],
                mat, parent, bevel=0.007)


def tube(name, radius, thickness, location, mat, parent, normal="z", start=0, end=TAU, segments=80):
    v, f = [], []
    for i in range(segments + 1):
        theta = start + (end - start) * i / segments
        for j in range(8):
            phi = j * TAU / 8
            r = radius + math.cos(phi) * thickness
            if normal == "z":
                p = (math.cos(theta) * r, math.sin(theta) * r, math.sin(phi) * thickness)
            else:
                p = (math.cos(theta) * r, math.sin(phi) * thickness, math.sin(theta) * r)
            v.append(tuple(p[k] + location[k] for k in range(3)))
    for i in range(segments):
        for j in range(8):
            f.append((i * 8 + j, i * 8 + (j + 1) % 8,
                      (i + 1) * 8 + (j + 1) % 8, (i + 1) * 8 + j))
    return mesh(name, v, f, mat, parent, smooth=True)


def gem(name, location, size, mat, parent, rays=4):
    x, y, z = location
    v = [(x, y, z - size * .4), (x, y, z + size * .4)]
    for j in range(rays * 2):
        a = j * TAU / (rays * 2)
        r = size if j % 2 == 0 else size * .35
        v.append((x + math.cos(a) * r, y + math.sin(a) * r, z))
    n = rays * 2
    return mesh(name, v, [(0, 2 + j, 2 + (j + 1) % n) for j in range(n)]
                + [(1, 2 + (j + 1) % n, 2 + j) for j in range(n)], mat, parent)


def curve_strut(name, points, radius, mat, parent):
    # The deliberately polygonal sweep creates shaped engraved conduits.
    for index in range(len(points) - 1):
        beam(name + str(index), points[index], points[index + 1], radius, radius, mat, parent)


def merge(name, objects, parent, location=(0, 0, 0)):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objects:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.object.convert(target="MESH")
    bpy.ops.object.join()
    o = bpy.context.object
    o.name = name
    o.parent = parent
    # Shift the mesh origin without moving its geometry.
    offset = vec(location)
    for vertex in o.data.vertices:
        vertex.co -= offset
    o.location = offset
    return o


def hand(parent, side, materials, keeper=False):
    armor, trim, light, dark, glass = materials
    x = side * (0.12 if not keeper else .20)
    y = -1.10 if not keeper else -1.04
    palm = [(-.15, .12), (-.18, -.05), (-.12, -.23), (.10, -.23), (.17, -.02), (.13, .12)]
    plate("palm_primary", palm, .18, (x, y, -.04), armor, parent, .025)
    plate("palm_trim", [(-.10, .08), (-.12, -.03), (0, -.15), (.11, -.03), (.09, .08)],
          .025, (x, y, -.15), trim, parent, .008)
    for finger in range(4):
        fx = x + (finger - 1.5) * .078
        length = [.17, .23, .22, .16][finger]
        # Fingertips curl towards the viewer, each finger has two joints.
        a, b = (fx, y - .18, -.035), (fx + side * .018, y - .18 - length, -.08)
        c = (b[0], b[1] - .055, -.17)
        beam("finger_primary", a, b, .039, .045, armor, parent)
        beam("fingertip_trim", b, c, .034, .039, trim, parent)
        beam("knuckle_light", (a[0]-.018, a[1]-.035, -.094),
             (a[0]+.018, a[1]-.035, -.094), .013, .01, light, parent)
    beam("thumb_primary", (x - side * .12, y-.04, -.04),
         (x-side*.25, y-.17, -.09), .055, .06, armor, parent)
    beam("thumb_trim", (x-side*.25, y-.17, -.09),
         (x-side*.23, y-.25, -.18), .045, .05, trim, parent)


def astreion(materials):
    armor, copper, light, dark, glass = materials
    root = empty("Astreion")
    body = empty("Body", parent=root)
    # Backbone, waist and individually forged chest shells leave an open furnace.
    loft("primary_dorsal_cuirass", [(1.76,.28,.19,0,.1), (2.15,.40,.24,0,.10),
         (2.65,.55,.26,0,.12), (2.98,.61,.23,0,.12), (3.09,.28,.16,0,.10)], armor, body)
    loft("dark_abdominal_flexure", [(1.55,.25,.18,0,0), (1.9,.32,.20,0,0),
         (2.27,.29,.19,0,0)], dark, body, 10)
    plate("primary_abdominal_keel", [(-.27,.3),(-.3,0),(-.15,-.34),(0,-.45),(.15,-.34),(.3,0),(.27,.3)],
          .22, (0,1.94,-.19), armor, body, .025)
    for side in [-1, 1]:
        # The chest flares backwards at its top and opens around the star core.
        outline = [(side*x,y) for x,y in [(.11,.40),(.42,.44),(.65,.24),(.59,-.12),(.28,-.37),(.16,-.23),(.22,.07)]]
        plate("primary_pectoral", outline,.28,(0,2.67,-.25),armor,body,.035)
        outline = [(side*x,y) for x,y in [(.18,.32),(.39,.35),(.54,.23),(.48,.12),(.27,.02),(.26,-.20),(.18,-.16)]]
        plate("trim_pectoral_lip",outline,.042,(0,2.67,-.415),copper,body,.012)
        curve_strut("light_chest_inlay",[(side*.29,2.84,-.45),(side*.46,2.89,-.45),
                    (side*.53,2.82,-.45)],.009,light,body)
        # Hanging lamellar plates; no legs, a floating pointed silhouette.
        for i in range(3):
            xx=side*(.23+i*.12)
            plate("primary_fauld",[(-.11,.15),(.09,.15),(.13,-.21),(.01,-.36),(-.10,-.21)],
                  .12,(xx,1.68-i*.06,-.17+i*.05),armor,body,.014)
            beam("trim_fauld_edge",(xx-.07,1.73-i*.06,-.25),(xx+.065,1.73-i*.06,-.25),.018,.014,copper,body)
    tube("trim_furnace_outer",.30,.037,(0,2.64,-.355),copper,body)
    tube("dark_furnace_inner",.245,.025,(0,2.64,-.39),dark,body)
    for j in range(12):
        a=j*TAU/12
        beam("trim_furnace_tooth",(math.cos(a)*.23,2.64+math.sin(a)*.23,-.41),
             (math.cos(a)*.285,2.64+math.sin(a)*.285,-.43),.012,.015,copper,body)
    core=gem("Core",(0,0,0),.21,light,body,6)
    core.location=vec((0,2.64,-.43))
    # A tall eclipse helm with a split face shield and swept crown.
    loft("primary_helmet",[(3.14,.19,.16,0,0),(3.3,.29,.25,0,.02),(3.57,.29,.21,0,.04),
         (3.75,.15,.13,0,.09),(3.79,.05,.06,0,.11)],armor,body,12)
    plate("dark_face",[(-.18,.12),(.18,.12),(.16,-.15),(0,-.24),(-.16,-.15)],.045,(0,3.43,-.224),dark,body,.008)
    tube("trim_eclipse_visor",.239,.024,(0,3.47,-.253),copper,body,start=-.12,end=math.pi+ .12,segments=48)
    for side in [-1,1]:
        plate("trim_cheek",[(side*x,y) for x,y in [(.12,.04),(.29,.16),(.26,-.15),(.08,-.28)]],
              .09,(0,3.40,-.20),copper,body,.012)
        beam("light_eyes",(side*.035,3.46,-.26),(side*.17,3.48,-.26),.013,.008,light,body)
        plate("primary_crown_fin",[(side*x,y) for x,y in [(.16,0),(.38,.33),(.30,.42),(.05,.14)]],
              .09,(0,3.65,.04),armor,body,.012)
        beam("trim_crown_edge",(side*.16,3.78,-.016),(side*.30,4.06,-.016),.014,.012,copper,body)
    plate("trim_forehead",[(-.065,0),(0,.24),(.065,0),(0,-.10)],.06,(0,3.69,-.15),copper,body,.006)
    # Layered shoulder plates and lean gauntlets, pivoted for the signature pose.
    for side,name in [(-1,"ArmLeft"),(1,"ArmRight")]:
        arm=empty(name,(side*.73,2.92,0),root)
        loft("dark_upperarm",[(.03,.17,.17,0,0),(-.37,.15,.14,side*.04,0),(-.59,.12,.12,side*.06,0)],dark,arm)
        for layer in range(3):
            shape=[(-.28,.12),(.13,.19),(.44,.01),(.46,-.15),(.08,-.20),(-.22,-.08)]
            plate("primary_pauldron",[(side*x,y) for x,y in shape], .31,
                  (side*.04,.12-layer*.085,.01-layer*.045), armor,arm,.025)
            beam("trim_pauldron_edge",(side*-.18,.24-layer*.085,-.17-layer*.045),
                 (side*.35,.12-layer*.085,-.17-layer*.045),.018,.018,copper,arm)
        tube("trim_elbow",.14,.026,(side*.07,-.55,0),copper,arm,normal="y",segments=32)
        loft("primary_gauntlet",[(-.60,.15,.15,side*.07,0),(-.72,.22,.20,side*.09,0),
             (-1.03,.17,.18,side*.12,-.01),(-1.12,.13,.12,side*.12,-.02)],armor,arm,10)
        plate("trim_gauntlet_crest",[(-.1,.15),(0,.23),(.1,.15),(.08,-.19),(0,-.25),(-.08,-.19)],
              .045,(side*.10,-.84,-.185),copper,arm,.012)
        beam("light_gauntlet",(side*.10,-.72,-.22),(side*.10,-1.00,-.22),.013,.011,light,arm)
        hand(arm,side,materials)
    # The weapon is a meteor-shaped octagonal hammer with recessed luminous seams.
    hammer=empty("Hammer",(0,-1.25,-.10),root)
    beam("dark_hammer_shaft",(0,.35,0),(0,-1.13,0),.045,.045,dark,hammer)
    for j in range(10):
        tube("trim_grip_band",.055,.012,(0,.22-j*.10,0),copper,hammer,normal="y",segments=16)
    shape=[(-.64,.13),(-.46,.32),(.42,.32),(.64,.12),(.64,-.20),(.44,-.34),(-.44,-.34),(-.64,-.15)]
    plate("primary_meteor_head",shape,.47,(0,-1.17,0),armor,hammer,.045)
    plate("dark_hammer_recess",[(-.37,.18),(.37,.18),(.49,0),(.37,-.18),(-.37,-.18),(-.49,0)],
          .04,(0,-1.17,-.255),dark,hammer,.012)
    for side in [-1,1]:
        plate("trim_meteor_end",[(side*x,y) for x,y in [(.42,.30),(.62,.11),(.62,-.18),(.42,-.31),(.33,-.19),(.33,.17)]],
              .51,(0,-1.17,0),copper,hammer,.022)
        beam("light_hammer_rune",(side*.10,-1.17,-.285),(side*.30,-1.17,-.285),.014,.01,light,hammer)
    gem("light_hammer_star",(0,-1.17,-.29),.16,light,hammer,4)
    # Three independent engraved orbital bands. Thin enough to read the armour.
    for index in range(3):
        orbit=empty("OrbitWork",parent=root)
        radius=1.30+index*.16
        tube("trim_orbit",radius,.013,(0,0,0),copper,orbit,normal="y",segments=96)
        tube("light_orbit_trace",radius-.024,.004,(0,.012,0),light,orbit,normal="y",segments=96)
        for j in range(18):
            a=(j+index*.25)*TAU/18
            beam("light_orbit_glyph",(math.cos(a)*(radius-.055),0,math.sin(a)*(radius-.055)),
                 (math.cos(a)*(radius+.045),0,math.sin(a)*(radius+.045)),.005,.005,light,orbit)
        merged=merge("Orbit%d"%index,list(orbit.children),root)
        merged.location=vec((0,2.65,.18))
        bpy.data.objects.remove(orbit)
    # Sculpted energy skirt: tapered wisps and three copper coils instead of balls.
    for side in [-1,1]:
        loft("glass_energy_tail",[(.20,.015,.012,side*.10,.04),(.54,.06,.06,side*.15,.01),
             (.94,.10,.09,side*.20,.02),(1.39,.16,.12,side*.18,.04),(1.57,.16,.13,side*.14,.05)],glass,body,8)
    for index in range(3):
        tube("trim_levitation_seal",.18+index*.09,.012,(0,.52+index*.28,0),copper,body,normal="y",segments=48)
    return root


def wing(name,side,materials,parent):
    armor,trim,light,dark,glass=materials
    temporary=empty("WingWork",parent=parent)
    # A thick, curved manta shell with sculpted span and scalloped trailing edge.
    sections=[(0,.0,.0,.25),(.26,.09,.03,.56),(.64,.19,.11,.94),
              (1.05,.27,.18,1.22),(1.46,.36,.26,.84),(1.83,.49,.34,.035)]
    v=[]
    for offset in [-.025,.025]:
        for x,y,z,drop in sections:
            for j in range(5):
                t=j/4
                v.append((side*x,y-drop*t,z+math.sin(t*math.pi)*.19+offset))
    n=len(sections)*5
    f=[]
    for layer in range(2):
        for row in range(len(sections)-1):
            for j in range(4):
                a=layer*n+row*5+j
                q=(a,a+1,a+6,a+5)
                f.append(q if layer else tuple(reversed(q)))
    for row in range(len(sections)-1):
        a,b=row*5,(row+1)*5
        f += [(a,b,b+n,a+n),(a+4,a+4+n,b+4+n,b+4)]
    for row in [0,len(sections)-1]:
        for j in range(4):
            a=row*5+j
            f.append((a,a+n,a+1+n,a+1))
    mesh("glass_manta_membrane",v,f,glass,temporary,smooth=True)
    # An armour ridge follows the leading edge; ribs have a soft backwards sweep.
    curve_strut("trim_manta_leading",[(side*x,y,z-.04) for x,y,z,drop in sections],.027,trim,temporary)
    for index in [1,2,3,4,5]:
        x,y,z,drop=sections[index]
        points=[]
        for j in range(5):
            t=j/4
            points.append((side*(x-.10*math.sin(t*math.pi)), y-drop*t,
                           z+math.sin(t*math.pi)*.19-.032))
        curve_strut("primary_manta_rib",points,.018,armor,temporary)
        if index in [2,4]:
            curve_strut("light_manta_vein",[(p[0]+side*.025,p[1],p[2]-.012) for p in points],.006,light,temporary)
    for j in range(4):
        x,y,z,drop=sections[j+1]
        plate("primary_wing_scale",[(side*a,b) for a,b in [(-.08,.05),(.18,.10),(.20,-.08),(.03,-.18)]],
              .05,(side*x,y-.08,z-.06),armor,temporary,.014)
    obj=merge(name,list(temporary.children),parent)
    bpy.data.objects.remove(temporary)
    obj.location=vec((side*.40,2.78,.19))
    return obj


def thalassa(materials):
    armor,trim,light,dark,glass=materials
    root=empty("Thalassa")
    body=empty("Body",parent=root)
    loft("primary_cuirass",[(1.58,.18,.13,0,.03),(1.84,.30,.20,0,.02),(2.25,.37,.25,0,0),
         (2.69,.43,.25,0,.03),(2.88,.29,.19,0,.04)],armor,body,16,True,.014)
    # Front glass lamellae reveal the flowing bright channels beneath.
    for side in [-1,1]:
        outline=[(side*x,y) for x,y in [(.04,.36),(.30,.30),(.39,.08),(.26,-.25),(.10,-.33),(.03,-.12)]]
        plate("glass_breastplate",outline,.12,(0,2.45,-.255),glass,body,.024)
        curve_strut("trim_breastplate_edge",[(side*.06,2.81,-.31),(side*.30,2.75,-.31),
                    (side*.39,2.53,-.31),(side*.26,2.20,-.31)],.018,trim,body)
        curve_strut("light_water_channel",[(side*.08,2.68,-.33),(side*.19,2.53,-.34),
                    (side*.12,2.28,-.33)],.012,light,body)
        plate("primary_hipfin",[(side*x,y) for x,y in [(.10,.15),(.38,.23),(.53,-.09),(.34,-.48),(.12,-.29)]],
              .13,(0,1.85,-.04),armor,body,.018)
        curve_strut("trim_hipfin_edge",[(side*.34,2.05,-.12),(side*.49,1.76,-.12),(side*.34,1.40,-.12)],.014,trim,body)
    gem("Core",(0,0,0),.12,light,body,4).location=vec((0,2.61,-.34))
    # Long, curved watercloth keel; swept lower fins give a manta silhouette.
    loft("glass_watercloth",[(.18,.025,.018,0,.20),(.52,.08,.045,0,.13),(1.02,.14,.11,0,.09),
         (1.46,.24,.15,0,.05),(1.78,.27,.16,0,.03)],glass,body,12,True)
    for side in [-1,1]:
        plate("glass_lower_fin",[(side*x,y) for x,y in [(.09,.25),(.28,.30),(.46,-.12),(.29,-.60),(.15,-.44)]],
              .06,(0,1.20,.05),glass,body,.012)
        curve_strut("light_lower_current",[(side*.20,1.42,-.0),(side*.35,1.12,.0),(side*.24,.70,.02)],.009,light,body)
    # Mask and fin crown: no spherical head, a narrow stylised guardian face.
    loft("primary_helm",[(2.98,.15,.14,0,.03),(3.12,.23,.19,0,.02),(3.44,.25,.18,0,.04),
         (3.60,.15,.13,0,.10),(3.68,.055,.07,0,.16)],armor,body,12)
    plate("glass_face_mask",[(-.17,.14),(.17,.14),(.16,-.12),(0,-.25),(-.16,-.12)],
          .06,(0,3.30,-.18),glass,body,.014)
    plate("trim_mask_bridge",[(-.035,.15),(.035,.15),(.05,-.05),(0,-.16),(-.05,-.05)],
          .035,(0,3.30,-.223),trim,body,.008)
    for side in [-1,1]:
        beam("light_eyes",(side*.045,3.34,-.227),(side*.135,3.36,-.227),.009,.008,light,body)
        plate("primary_crown_sweep",[(side*x,y) for x,y in [(.08,.02),(.31,.18),(.48,.28),(.36,-.01),(.13,-.08)]],
              .075,(0,3.52,.07),armor,body,.009)
        curve_strut("trim_crown_edge",[(side*.14,3.64,.02),(side*.31,3.70,.02),(side*.48,3.80,.02)],.012,trim,body)
        plate("glass_cheek_fin",[(side*x,y) for x,y in [(.15,.15),(.31,.28),(.36,.02),(.23,-.30),(.15,-.11)]],
              .055,(0,3.22,.02),glass,body,.012)
    for side,name in [(-1,"ArmLeft"),(1,"ArmRight")]:
        arm=empty(name,(side*.49,2.74,-.03),root)
        loft("dark_arm_flexure",[(.03,.12,.13,0,0),(-.45,.11,.11,side*.14,0),
             (-.64,.09,.10,side*.17,0)],dark,arm,10)
        plate("primary_shoulder",[(side*x,y) for x,y in [(-.12,.09),(.13,.21),(.38,.03),(.28,-.24),(.03,-.28),(-.13,-.10)]],
              .27,(0,0,.02),armor,arm,.022)
        curve_strut("trim_shoulder_edge",[(side*.04,.15,-.13),(side*.30,.0,-.13),(side*.24,-.18,-.13)],.018,trim,arm)
        loft("glass_gauntlet",[(-.58,.13,.14,side*.16,0),(-.76,.20,.17,side*.19,0),
             (-1.05,.13,.12,side*.20,-.01)],glass,arm,12,True,.01)
        for j in range(3):
            beam("primary_forearm_flute",(side*.19+(j-1)*.065,-.69,-.15),
                 (side*.20+(j-1)*.045,-1.02,-.13),.018,.025,armor,arm)
        hand(arm,side,materials,True)
        tube("trim_palm_guard",.29,.017,(side*.20,-1.08,-.19),trim,arm,segments=64)
        tube("light_palm_guard",.27,.007,(side*.20,-1.08,-.20),light,arm,segments=64)
        wing("WingLeft" if side<0 else "WingRight",side,materials,root)
        # The housing is stationary; eleven curved blades spin inside it.
        center=(side*.80,2.94,.37)
        for radius,thickness,mat in [(.34,.055,armor),(.285,.018,trim),(.36,.009,light)]:
            tube("primary_turbine_housing" if mat==armor else "trim_turbine_housing",radius,thickness,
                 center,mat,body,segments=64)
        rotor=empty("TurbineLeft" if side<0 else "TurbineRight",center,root)
        for blade in range(11):
            a=blade*TAU/11
            outline=[]
            for r,angle in [(.085,a),(.24,a+.12),(.27,a+.33),(.11,a+.45)]:
                outline.append((math.cos(angle)*r,math.sin(angle)*r))
            plate("trim_turbine_vane",outline,.045,(0,0,0),trim,rotor,.006)
            beam("light_vane_edge",(math.cos(a+.12)*.22,math.sin(a+.12)*.22,-.028),
                 (math.cos(a+.33)*.25,math.sin(a+.33)*.25,-.028),.005,.005,light,rotor)
        gem("light_turbine_hub",(0,0,-.03),.08,light,rotor,5)
    # Deep-sea halo with little navigation marks, placed behind the crown.
    tube("trim_moon_halo",.43,.012,(0,3.42,.27),trim,body,start=math.pi*.10,end=math.pi*.90,segments=48)
    return root


def export_spirit(name, constructor, colors):
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    materials=[material("Primary",colors[0],.65,.31),material("Trim",colors[1],.72,.28),
               material("Light",colors[2],.1,.28,1.2),material("Dark",(.018,.035,.066),.3,.48),
               material("Glass",colors[3],.38,.24)]
    root=constructor(materials)
    bpy.context.view_layer.update()
    # One mesh per articulated region keeps the game to a few material passes.
    # Core and orbital bands remain independent animation targets.
    body=next(o for o in root.children if o.name=="Body")
    first=next(o for o in body.children if o.name.startswith("primary_"))
    first.name="BodyArmor"
    others=[o for o in body.children if o.type=='MESH' and o!=first and o.name!="Core"]
    merge("BodyDetails",others,body)
    for region in [o for o in root.children if o.type=='EMPTY' and o!=body]:
        objects=list(region.children)
        if objects:
            merge(region.name+"Geometry",objects,region)
    # All closed shells face outwards after mirrored left/right plate outlines.
    bpy.ops.object.select_all(action="DESELECT")
    meshes=[o for o in bpy.data.objects if o.type=='MESH']
    for o in meshes:
        o.select_set(True)
    bpy.context.view_layer.objects.active=meshes[0]
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.object.mode_set(mode='OBJECT')
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT,name+".glb"),export_format="GLB",
                              use_selection=True,export_apply=True,export_yup=True,
                              export_animations=False,export_cameras=False,export_lights=False)
    print(name, "objects",len(bpy.data.objects),"vertices",sum(len(o.data.vertices) for o in bpy.data.objects if o.type=='MESH'))


export_spirit("astreion",astreion,[(.035,.07,.13),(.62,.28,.11),(1,.63,.23),(.24,.115,.05)])
export_spirit("thalassa",thalassa,[(.03,.12,.18),(.20,.57,.61),(.40,.96,.92),(.08,.37,.43)])
