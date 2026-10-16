"""Offline authoring for the original IEG stylized footballer.

Run from the repository root:
  blender --background --python tools/art/build_footballer.py

The old asset is the animation/rig source only; all visible geometry is rebuilt.
No Blender or Python is required by the shipped Godot project.
"""
from pathlib import Path
import math
import random
import bpy
import bmesh
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'assets/characters/footballer_polished.glb'
ARTIFACTS = Path('/workspace/scratch/character-art')
ARTIFACTS.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(ROOT / 'assets/characters/footballer.glb'))
rig = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
for obj in list(bpy.data.objects):
    if obj != rig:
        bpy.data.objects.remove(obj, do_unlink=True)
for old_material in list(bpy.data.materials):
    bpy.data.materials.remove(old_material)

verts, faces, face_mats, weights, texcoords = [], [], [], [], []
materials = []

def material(name, color, roughness=.6, metallic=0):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1)
    mat.use_nodes = True
    shader = mat.node_tree.nodes.get('Principled BSDF')
    shader.inputs['Base Color'].default_value = (*color, 1)
    shader.inputs['Roughness'].default_value = roughness
    shader.inputs['Metallic'].default_value = metallic
    materials.append(mat)
    return len(materials) - 1

SKIN = material('skin', (.68, .43, .29), .67)
SKIN_SHADE = material('skin_shade', (.52, .27, .19), .71)
JERSEY = material('jersey', (.07, .35, .72), .82)
PANEL = material('jersey_shadow', (.025, .13, .28), .8)
SOCK = material('jersey_socks', (.07, .35, .72), .86)
TRIM = material('kit_ivory', (.91, .94, .96), .66)
SHORTS = material('shorts', (.017, .029, .059), .82)
HAIR = material('hair', (.025, .018, .021), .56)
HAIR_HI = material('hair_highlight', (.075, .055, .065), .65)
EYE = material('eye_white', (.9, .95, .94), .34)
IRIS = material('iris', (.12, .33, .35), .32)
BLACK = material('ink', (.008, .012, .025), .65)
BOOT = material('boots', (.022, .036, .052), .43)
SOLE = material('sole', (.055, .075, .095), .55)
ACCENT = material('boot_accent', (.3, .92, .82), .36)
BADGE = material('crest_gold', (.95, .63, .18), .36, .3)

def vertex(p, bone, uv=(0, 0)):
    verts.append(tuple(p)); texcoords.append(uv)
    weights.append({bone: 1.0} if isinstance(bone, str) else bone)
    return len(verts) - 1

def face(indices, mat):
    faces.append(tuple(indices)); face_mats.append(mat)

def torso_weight(p):
    z = p[2]
    if z < 1.01:
        t = max(0, min(1, (z - .92) / .17))
        return {'Hips': 1-t, 'Spine': t}
    t = max(0, min(1, (z - 1.09) / .20))
    return {'Spine': 1-t, 'Chest': t}

def loft(rings, mat, bone, n=20, capped=True, axis='z'):
    """Smooth cross sections: (center, first radius, second radius)."""
    previous = None
    first = None
    for ri, (center, ra, rb) in enumerate(rings):
        ring = []
        for i in range(n):
            a = i * 2*math.pi/n
            if axis == 'z':
                p = (center[0]+ra*math.cos(a), center[1]+rb*math.sin(a), center[2])
            elif axis == 'y':
                p = (center[0]+ra*math.cos(a), center[1], center[2]+rb*math.sin(a))
            else:
                direction = Vector(rings[min(ri+1,len(rings)-1)][0])-Vector(rings[max(ri-1,0)][0])
                direction.normalize()
                side = direction.cross(Vector((0,1,0))).normalized()
                up = side.cross(direction).normalized()
                p = Vector(center)+side*(ra*math.cos(a))+up*(rb*math.sin(a))
            w = bone(p) if callable(bone) else bone
            ring.append(vertex(p, w, (i/n, ri/max(1, len(rings)-1))))
        if previous is not None:
            for i in range(n):
                face((previous[i],previous[(i+1)%n],ring[(i+1)%n],ring[i]),mat)
        else:
            first = ring
        previous = ring
    if capped:
        face(tuple(reversed(first)),mat); face(previous,mat)

def oval(center, scale, mat, bone, n=16, rows=8):
    rings=[]
    for j in range(rows+1):
        a=-math.pi/2 + j*math.pi/rows
        c=(center[0], center[1], center[2]+scale[2]*math.sin(a))
        rings.append((c, max(.0003,scale[0]*math.cos(a)), max(.0003,scale[1]*math.cos(a))))
    loft(rings,mat,bone,n=n)

def tube(points, radius, mat, bone, n=6):
    loft([(p,radius,radius) for p in points],mat,bone,n=n,axis='path')

def patch(points, mat, bone):
    ids=[vertex(p,bone) for p in points]
    face(ids,mat)

# Athletic torso: narrow waist, developed chest, sloped shoulders and fitted hem.
loft([
    ((0,.003,.905),.180,.096), ((0,.006,.945),.181,.099),
    ((0,.008,1.02),.163,.095), ((0,.010,1.12),.180,.105),
    ((0,.014,1.24),.221,.120), ((0,.011,1.32),.245,.117),
    ((0,.006,1.365),.233,.105), ((0,.005,1.405),.154,.083),
    ((0,.005,1.435),.075,.064),
],JERSEY,torso_weight,n=24)
loft([((0,.005,z),x,y) for z,x,y in [(1.419,.084,.071),(1.434,.079,.068),(1.448,.072,.063)]],TRIM,'Chest')
loft([((0,.005,z),.066,.056) for z in [1.432,1.477,1.508]],SKIN,'Neck',n=16)
# Fitted side insets and seam piping, following the curved jersey.
for sign in [-1,1]:
    patch([(sign*.183,.031,.925),(sign*.168,.063,1.02),(sign*.188,.079,1.15),
           (sign*.222,.069,1.29),(sign*.228,.034,1.34),(sign*.206,.022,1.17)],PANEL,'Chest')
    tube([(sign*.166,.063,1.01),(sign*.186,.079,1.15),(sign*.221,.070,1.28)],.0028,TRIM,'Chest',n=5)
    # Shoulder ivory ribbon and slim contrasting jersey cuff.
    tube([(sign*.085,.024,1.433),(sign*.16,.024,1.406),(sign*.238,.026,1.365)],.008,TRIM,'Chest',n=6)
loft([((0,.003,z),.181,.100) for z in [.914,.924,.933]],PANEL,'Hips',n=24)

# Chest badge, collar notch, restrained manufacturer mark.
patch([(-.109,.129,1.322),(-.073,.133,1.322),(-.073,.135,1.282),(-.091,.134,1.267),(-.109,.130,1.282)],TRIM,'Chest')
patch([(-.101,.135,1.312),(-.081,.138,1.312),(-.081,.139,1.288),(-.091,.139,1.279),(-.101,.136,1.288)],BADGE,'Chest')
patch([(.082,.134,1.307),(.111,.130,1.313),(.102,.134,1.298),(.080,.136,1.300)],TRIM,'Chest')
patch([(-.014,.070,1.434),(0,.087,1.409),(.014,.070,1.434)],PANEL,'Chest')

# Shorts are sculpted as two flared cloth legs, with a continuous waistband.
loft([((0,0,z),.184,.103) for z in [.865,.898,.923]],SHORTS,'Hips',n=24)
for sign,side in [(-1,'L'),(1,'R')]:
    upper='UpperLeg'+side; lower='LowerLeg'+side; foot='Foot'+side
    arm='UpperArm'+side; forearm='LowerArm'+side; hand='Hand'+side
    x=sign*.115
    loft([((x,0,.89),.105,.10),((x,.003,.82),.110,.105),
          ((x,.004,.735),.107,.104),((x,.006,.675),.110,.101)],SHORTS,upper,n=20)
    loft([((x,.006,z),.111,.102) for z in [.676,.685]],TRIM,upper,n=20)
    # Outer shorts stripe uses a curve on each outer side.
    tube([(x+sign*.104,.015,.874),(x+sign*.108,.018,.78),(x+sign*.108,.018,.696)],.008,TRIM,upper,n=6)
    def knee_weight(p):
        t=max(0,min(1,(.53-p[2])/.09))
        return {upper:1-t,lower:t}
    loft([((x,0,.74),.087,.081),((x,.002,.64),.082,.080),((x,.007,.55),.066,.063),
          ((x,.013,.487),.059,.064),((x,.012,.430),.055,.059)],SKIN,knee_weight,n=18)
    loft([((x,.008,.440),.061,.064),((x,.003,.405),.064,.066),
          ((x,-.004,.32),.061,.064),((x,-.004,.23),.046,.049),((x,.002,.14),.039,.042)],SOCK,lower,n=18)
    loft([((x,.005,z),.063,.065) for z in [.407,.430,.439]],TRIM,lower,n=18)
    loft([((x,.006,z),.064,.066) for z in [.417,.422]],PANEL,lower,n=18)
    tube([(x-sign*.016,.065,.405),(x-sign*.016,.061,.36),(x-sign*.015,.049,.30)],.003,TRIM,lower,n=5)
    # Upper arms, elbow, tendons and forearm all follow the retained rig.
    loft([((sign*.190,0,1.345),.068,.076),((sign*.235,.001,1.325),.083,.086),((sign*.260,.005,1.270),.076,.077),
          ((sign*.287,.010,1.198),.067,.068)],JERSEY,arm,n=18,axis='path')
    loft([((sign*.285,.010,1.206),.068,.069),((sign*.290,.011,1.190),.067,.069)],TRIM,arm,n=18,axis='path')
    loft([((sign*.286,.010,1.214),.059,.058),((sign*.306,.016,1.151),.055,.055),
          ((sign*.320,.020,1.085),.043,.046)],SKIN,arm,n=18,axis='path')
    oval((sign*.32,.020,1.085),(.044,.046,.043),SKIN,forearm,n=16,rows=6)
    loft([((sign*.320,.020,1.085),.043,.044),((sign*.332,.032,1.023),.049,.049),
          ((sign*.346,.048,.947),.036,.037),((sign*.355,.060,.884),.030,.031)],SKIN,forearm,n=18,axis='path')
    loft([((sign*.353,.058,.906),.032,.033),((sign*.356,.061,.887),.032,.033)],TRIM,forearm,n=16,axis='path')
    oval((sign*.358,.067,.851),(.038,.026,.054),SKIN,hand,n=16,rows=8)
    for finger in range(4):
        fx=sign*(.335+finger*.014)
        length=[.035,.044,.043,.034][finger]
        oval((fx,.073,.803),(.0085,.012,length),SKIN,hand,n=8,rows=6)
    oval((sign*.321,.073,.849),(.014,.016,.034),SKIN,hand,n=10,rows=6)
    # Sculpted football boot with a tapered toe and a separate outsole.
    loft([((x,-.073,.079),.030,.037),((x,-.048,.079),.047,.048),
          ((x,.013,.078),.052,.051),((x,.09,.069),.061,.040),
          ((x,.168,.057),.055,.027),((x,.203,.053),.032,.017),
          ((x,.211,.051),.009,.009)],BOOT,foot,n=16,axis='y')
    loft([((x,-.074,.030),.029,.010),((x,-.044,.030),.048,.011),
          ((x,.035,.026),.055,.010),((x,.13,.025),.061,.010),
          ((x,.195,.025),.039,.010),((x,.211,.026),.012,.007)],SOLE,foot,n=12,axis='y')
    # Heel brace, tongue, diagonal side marks, individual crossed laces.
    tube([(x-sign*.040,-.045,.084),(x-sign*.052,.01,.068),(x-sign*.056,.095,.050),
          (x-sign*.043,.16,.044)],.005,ACCENT,foot,n=5)
    tube([(x+sign*.043,-.04,.085),(x+sign*.050,.02,.073),(x+sign*.052,.12,.052)],.004,TRIM,foot,n=5)
    patch([(x-.021,-.005,.129),(x+.021,-.005,.129),(x+.024,.095,.105),(x-.024,.095,.105)],SOLE,foot)
    for k in range(5):
        y=.011+k*.016; z=.131-k*.004
        tube([(x-.019,y,z),(x+.018,y+.010,z-.002)],.0025,TRIM,foot,n=5)
        tube([(x+.019,y,z),(x-.018,y+.010,z-.002)],.0025,TRIM,foot,n=5)
    for yy in [-.04,.055,.145]:
        for dx in [-.030,.030]:
            loft([((x+dx,yy,.009),.009,.009),((x+dx,yy,.022),.011,.011)],SOLE,foot,n=6)

# Face is a single sculpted silhouette, with a proper jaw/chin rather than a ball.
loft([
    ((0,.018,1.481),.035,.041),((0,.023,1.497),.069,.065),
    ((0,.022,1.535),.108,.087),((0,.012,1.584),.130,.106),
    ((0,.007,1.634),.137,.113),((0,0,1.687),.132,.113),
    ((0,-.002,1.730),.110,.101),((0,-.006,1.757),.070,.070),
    ((0,-.006,1.772),.012,.014)
],SKIN,'Head',n=24)
for sign in [-1,1]:
    oval((sign*.135,.002,1.601),(.023,.031,.043),SKIN,'Head',n=12,rows=7)
    oval((sign*.145,.026,1.602),(.010,.012,.022),SKIN_SHADE,'Head',n=10,rows=6)
    # Almond eyes nested in sculpted lids, with smaller iris/pupil glints.
    oval((sign*.054,.109,1.644),(.036,.014,.020),SKIN_SHADE,'Head',n=16,rows=6)
    oval((sign*.054,.120,1.645),(.032,.008,.016),EYE,'Head',n=16,rows=6)
    oval((sign*.052,.127,1.645),(.014,.004,.015),IRIS,'Head',n=14,rows=6)
    oval((sign*.052,.131,1.645),(.006,.002,.011),BLACK,'Head',n=10,rows=6)
    oval((sign*.048,.133,1.651),(.003,.002,.004),TRIM,'Head',n=8,rows=5)
    tube([(sign*.023,.128,1.658),(sign*.050,.131,1.664),(sign*.080,.116,1.655)],.0027,BLACK,'Head',n=5)
    tube([(sign*.024,.119,1.688),(sign*.050,.123,1.694),(sign*.083,.108,1.683)],.006,HAIR,'Head',n=6)
# Nose bridge with a soft tip, nostrils, a restrained mouth and lower lip.
oval((0,.114,1.616),(.018,.022,.031),SKIN,'Head',n=12,rows=7)
oval((0,.133,1.603),(.020,.018,.013),SKIN,'Head',n=12,rows=6)
for sign in [-1,1]:
    oval((sign*.014,.141,1.598),(.004,.003,.0025),SKIN_SHADE,'Head',n=8,rows=4)
tube([(-.026,.107,1.562),(0,.117,1.558),(.026,.107,1.562)],.0026,SKIN_SHADE,'Head',n=6)
oval((0,.110,1.551),(.018,.005,.004),SKIN,'Head',n=12,rows=4)

# Layered swept hair: a fitted scalp shell, with hand-shaped tapered locks.
hairrings=[]
for k in range(7):
    t=k/6; ids=[]
    for i in range(24):
        a=2*math.pi*i/24
        front=(math.sin(a)+1)/2
        zbottom=1.568+.128*front
        # Follow the cranial dome. A linear shrink here would sink the scalp
        # into the forehead/back of the skull halfway up the head.
        latitude=math.acos((zbottom-1.64)/.17)*(1-t)
        z=1.64+.17*math.cos(latitude)
        factor=math.sin(latitude)*(1+.012*math.sin(a*3))
        ids.append(vertex((.151*math.cos(a)*factor,-.006+.136*math.sin(a)*factor,z),'Head',(i/24,t)))
    if hairrings:
        for i in range(24):
            face((hairrings[-1][i],hairrings[-1][(i+1)%24],ids[(i+1)%24],ids[i]),HAIR)
    hairrings.append(ids)
face(hairrings[-1],HAIR)

def hairlock(points, width, depth, highlight=False):
    rings=[]
    for k in range(9):
        t=k/8
        p=Vector(points[0])*(1-t)**3 + Vector(points[1])*3*t*(1-t)**2 + Vector(points[2])*3*t*t*(1-t) + Vector(points[3])*t**3
        f=max(.009, (.55+.8*math.sin(math.pi*t))*(1-t)**.65)
        rings.append((p,width*f,depth*f))
    loft(rings,HAIR_HI if highlight else HAIR,'Head',n=8,axis='path')

random.seed(24)
for i in range(7):
    x=-.120+i*.036
    root=(x-.024,-.018,1.763+(.017 if i>2 else 0))
    bend=(x-.010,.047,1.837-(i%3)*.009)
    fall=(x+.038,.133,1.770-(i%2)*.019)
    tip=(x+.022,.145,1.661+i*.008)
    hairlock([root,bend,fall,tip],.031,.019,highlight=i in [1,5])
for sign in [-1,1]:
    for i in range(4):
        hairlock([(sign*.075,-.055+i*.027,1.774),
                  (sign*.133,-.057+i*.026,1.775),
                  (sign*.157,-.038+i*.023,1.716),
                  (sign*.145,-.020+i*.023,1.644-i*.006)],.024,.017,highlight=i==0)
    hairlock([(sign*.134,.007,1.69),(sign*.148,.023,1.668),
              (sign*.143,.030,1.638),(sign*.135,.038,1.615)],.018,.013)
for i in range(5):
    x=-.09+i*.045
    hairlock([(x,-.048,1.78),(x+.026,-.095,1.796),(x+.033,-.128,1.742),
              (x+.030,-.130,1.655)],.026,.017,highlight=i==3)

mesh=bpy.data.meshes.new('AthleticFootballerGeometry')
mesh.from_pydata(verts,[],faces); mesh.materials.clear()
for m in materials: mesh.materials.append(m)
mesh.update()
obj=bpy.data.objects.new('FootballKit',mesh); bpy.context.collection.objects.link(obj)
for index,poly in enumerate(mesh.polygons):
    poly.material_index=face_mats[index]; poly.use_smooth=True
mesh.validate(verbose=True)
normal_mesh=bmesh.new();normal_mesh.from_mesh(mesh)
bmesh.ops.recalc_face_normals(normal_mesh,faces=list(normal_mesh.faces))
normal_mesh.to_mesh(mesh);normal_mesh.free()
uv=mesh.uv_layers.new(name='UVMap')
for poly in mesh.polygons:
    for li in poly.loop_indices:
        uv.data[li].uv=texcoords[mesh.loops[li].vertex_index]
for name in rig.data.bones.keys(): obj.vertex_groups.new(name=name)
for i,w in enumerate(weights):
    for name,value in w.items():
        if value>0: obj.vertex_groups[name].add([i],value,'REPLACE')
obj.parent=rig
modifier=obj.modifiers.new('Footballer rig','ARMATURE'); modifier.object=rig

# One white cloth weave texture shared by all kit colors. The runtime tint remains
# entirely controlled by IEGPlayerProfile. Texture is embedded in the GLB.
size=256
image=bpy.data.images.new('micro_knit',width=size,height=size)
pixels=[]
for y in range(size):
    for x in range(size):
        weave= .96 + .025*math.sin(x*math.pi/2)*math.cos(y*math.pi/2)
        if (x+y)%8==0: weave-=.025
        pixels.extend([weave,weave,weave,1])
image.pixels.foreach_set(pixels); image.pack()
for mi in [JERSEY,PANEL,SOCK,SHORTS]:
    mat=materials[mi]; shader=mat.node_tree.nodes.get('Principled BSDF')
    # glTF stores the base color factor alongside the neutral texture.
    tex=mat.node_tree.nodes.new('ShaderNodeTexImage'); tex.image=image
    mat.node_tree.links.new(tex.outputs['Color'],shader.inputs['Base Color'])
    # Keep original factors via mesh material diffuse color at export/runtime tint.

bpy.context.view_layer.objects.active=rig
rig.select_set(True); obj.select_set(True)
for o in bpy.context.selected_objects:
    if o not in [rig,obj]: o.select_set(False)
bpy.ops.export_scene.gltf(filepath=str(OUT),export_format='GLB',use_selection=True,
    export_animations=True,export_animation_mode='ACTIONS',export_skins=True,
    export_yup=True,export_apply=False,export_texcoords=True,export_normals=True,
    export_materials='EXPORT')
triangles=sum(len(p.vertices)-2 for p in mesh.polygons)
print('IEG ART RESULT',len(mesh.vertices),'vertices',triangles,'triangles',len(materials),'materials',OUT)

# A reproducible close-up lookdev render, separate from the exported asset.
if '--render' in __import__('sys').argv:
    # Nodes linked to neutral weave require their tint explicitly for Blender lookdev.
    for mi,col in [(JERSEY,(.055,.25,.64)),(PANEL,(.012,.045,.12)),(SOCK,(.055,.25,.64)),(SHORTS,(.012,.020,.045))]:
        mat=materials[mi]; shader=mat.node_tree.nodes.get('Principled BSDF')
        for link in list(shader.inputs['Base Color'].links): mat.node_tree.links.remove(link)
        shader.inputs['Base Color'].default_value=(*col,1)
    scene=bpy.context.scene
    world=bpy.data.worlds.new('Studio'); scene.world=world; world.use_nodes=True
    world.node_tree.nodes['Background'].inputs[0].default_value=(.035,.05,.08,1)
    world.node_tree.nodes['Background'].inputs[1].default_value=.45
    for loc,power,size_light,color in [((3,4,5),500,4,(.78,.86,1)),((-3,2,3),350,3,(1,.68,.38)),((0,-3,4),650,3,(.3,.75,1))]:
        bpy.ops.object.light_add(type='AREA',location=loc)
        light=bpy.context.object; light.data.energy=power; light.data.shape='DISK';light.data.size=size_light;light.data.color=color
        light.rotation_euler=(Vector((0,0,1))-light.location).to_track_quat('-Z','Y').to_euler()
    bpy.ops.object.camera_add(location=(2.6,4.4,2.15))
    camera=bpy.context.object;camera.rotation_euler=(Vector((0,0,1.04))-camera.location).to_track_quat('-Z','Y').to_euler()
    camera.data.type='ORTHO';camera.data.ortho_scale=2.2;scene.camera=camera
    scene.render.engine='CYCLES';scene.cycles.samples=40;scene.cycles.use_denoising=False
    scene.render.resolution_x=1000;scene.render.resolution_y=1200;scene.render.resolution_percentage=100
    scene.render.image_settings.file_format='PNG';scene.render.filepath=str(ARTIFACTS/'footballer-lookdev.png')
    scene.view_settings.view_transform='AgX'
    scene.frame_set(0)
    # Rest pose for a clean character-sheet view.
    if rig.animation_data: rig.animation_data.action=None
    for p in rig.pose.bones: p.matrix_basis.identity()
    bpy.ops.render.render(write_still=True)
