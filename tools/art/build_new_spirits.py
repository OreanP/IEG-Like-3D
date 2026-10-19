"""Author Vaélis and Orvann in Blender 4.3+, offline only.

Run: blender --background --python tools/art/build_new_spirits.py
Coordinates use Godot Y-up, converted into Blender Z-up by shared art helpers.
The existing spirit sources are read as a library without running their exports.
Every articulated region is merged before export to keep runtime draw calls low.
"""
import os
import math
import bpy
from mathutils import Vector

# Reuse the project art primitives; do not rebuild or overwrite older Karma.
HELPERS = os.path.join(os.path.dirname(__file__), "build_spirits.py")
with open(HELPERS, encoding="utf-8") as source:
    library = source.read().split('\nexport_spirit("astreion"', 1)[0]
exec(compile(library, HELPERS, "exec"), globals())


def sweep(name, points, radii, material_, parent, sides=10):
    """Closed tapered sweep with elliptical cross section and real thickness."""
    vertices, faces = [], []
    for i, point in enumerate(points):
        if i == len(points)-1:
            direction = Vector(point)-Vector(points[i-1])
        else:
            direction = Vector(points[i+1])-Vector(point)
        direction.normalize()
        axis = direction.cross(Vector((0, 0, 1))).normalized()
        if axis.length < .01:
            axis = direction.cross(Vector((0, 1, 0))).normalized()
        across = direction.cross(axis).normalized()
        for j in range(sides):
            angle = j*TAU/sides
            vertices.append(tuple(Vector(point) + axis*math.cos(angle)*radii[i] + across*math.sin(angle)*radii[i]*.72))
    for i in range(len(points)-1):
        for j in range(sides):
            a=i*sides+j; b=i*sides+(j+1)%sides
            faces.append((a,b,b+sides,a+sides))
    faces.extend([tuple(reversed(range(sides))), tuple(range((len(points)-1)*sides,len(points)*sides))])
    return mesh(name, vertices, faces, material_, parent, True)


def claw_hand(parent, side, mats, white, broad=False):
    armor, trim, light, dark, glass = mats
    factor=1.15 if broad else .85
    center=side*.13
    plate("primary_palm",[(-.13,.1),(.14,.12),(.18,-.10),(.10,-.23),(-.12,-.22),(-.17,-.06)],
          .17,(center,-.92,-.04),armor,parent,.018)
    for finger in range(4):
        x=center+(finger-1.5)*.075*factor
        a=(x,-1.04,-.04); b=(x+side*.02,-1.22-([.0,.04,.03,-.02][finger]),-.09)
        c=(b[0],b[1]-.075,-.18)
        beam("primary_finger",a,b,.035*factor,.04*factor,armor,parent)
        beam("trim_claw",b,c,.026*factor,.035*factor,trim,parent)
    beam("primary_thumb",(center-side*.12,-.94,0),(center-side*.23,-1.08,-.07),.05,.05,armor,parent)
    beam("trim_thumb_claw",(center-side*.23,-1.08,-.07),(center-side*.20,-1.17,-.17),.033,.04,trim,parent)
    gem("light_palm_seal",(center,-.95,-.14),.07,light,parent,4)


def armored_leg(name, side, root, mats, slender):
    armor,trim,light,dark,glass=mats
    leg=empty(name,(side*.27,1.67,.01),root)
    bend=.06 if slender else .015
    loft("dark_leg_flexure",[(.02,.14,.15,0,0),(-.43,.13,.13,side*.05,.02),(-.73,.12,.13,side*.07,-bend),
         (-1.15,.09,.12,side*.07,.01)],dark,leg,10)
    plate("primary_thigh",[(-.16,.02),(.15,.02),(.16,-.24),(.07,-.45),(-.13,-.37)],.19,
          (side*.025,-.03,-.14),armor,leg,.02)
    plate("trim_knee",[(-.14,.12),(.14,.12),(.17,-.05),(0,-.22),(-.16,-.05)],.16,
          (side*.06,-.48,-.17),trim,leg,.018)
    loft("primary_shin",[(-.68,.14,.15,side*.07,0),(-.85,.16,.15,side*.07,.01),(-1.16,.10,.12,side*.07,.02)],armor,leg,10)
    curve_strut("light_shin_glyph",[(side*.07,-.72,-.16),(side*.13,-.88,-.16),(side*.07,-1.08,-.13)],.009,light,leg)
    loft("primary_boot",[(-1.11,.11,.14,side*.07,-.04),(-1.30,.15,.22,side*.07,-.10),(-1.35,.14,.24,side*.07,-.13)],armor,leg,10)
    plate("trim_boot_toe",[(-.13,.03),(.13,.03),(.11,-.06),(-.11,-.06)],.075,(side*.07,-1.29,-.36),trim,leg,.012)
    return leg


def vaelis(mats, white):
    armor,gold,light,dark,glass=mats
    root=empty("Vaelis")
    body=empty("Body",parent=root)
    # Narrow athletic torso, overlapping lacquer plates and woven gold seams.
    loft("primary_spine",[(1.55,.22,.16,0,.04),(1.95,.27,.18,0,.03),(2.45,.40,.21,0,.02),
         (2.77,.49,.20,0,.02),(2.94,.23,.16,0,.02)],armor,body,12)
    for side in [-1,1]:
        plate("primary_breastplate",[(side*x,y) for x,y in [(.03,.30),(.40,.22),(.43,.04),(.22,-.26),(.05,-.19)]],
              .13,(0,2.61,-.18),armor,body,.023)
        curve_strut("trim_chest_fox",[(side*.05,2.83,-.27),(side*.31,2.76,-.29),(side*.34,2.63,-.29),
                    (side*.13,2.42,-.27)],.017,gold,body)
        curve_strut("light_chest_stitch",[(side*.08,2.76,-.29),(side*.24,2.70,-.30),(side*.10,2.51,-.28)],.006,light,body)
        for index in range(3):
            plate("primary_hip_lamella",[(side*x,y) for x,y in [(.03,.18),(.25,.13),(.34,-.13),(.21,-.34),(.04,-.21)]],
                  .08,(0,1.90-index*.11,-.08+index*.10),armor,body,.013)
            beam("trim_hip_edge",(side*.09,1.91-index*.11,-.13+index*.10),(side*.23,1.88-index*.11,-.13+index*.10),.012,.012,gold,body)
    for index in range(4):
        plate("dark_abdominal_joint",[(-.20,.05),(.20,.05),(.16,-.06),(-.16,-.06)],.035,
              (0,2.31-index*.11,-.18),dark,body,.008)
        beam("trim_abdominal_seam",(-.12,2.31-index*.11,-.205),(.12,2.31-index*.11,-.205),.01,.008,gold,body)
    gem("Core",(0,2.59,-.31),.12,light,body,4)
    # Separate head pivot: elongated fox mask, pointed muzzle, sculpted cheek fans.
    head=empty("Head",(0,3.01,.00),root)
    loft("primary_skull",[(.02,.14,.14,0,.01),(.24,.24,.20,0,.05),(.47,.20,.17,0,.07),(.57,.09,.12,0,.09)],armor,head,12)
    plate("white_fox_mask",[(-.22,.22),(-.16,.37),(0,.30),(.16,.37),(.22,.22),(.16,-.03),(0,-.24),(-.16,-.03)],
          .10,(0,.18,-.18),white,head,.018)
    # Muzzle projects forward in a distinct faceted wedge.
    mesh("white_muzzle",[(-.10,.12,-.24),(.10,.12,-.24),(.055,-.04,-.39),(-.055,-.04,-.39),(0,-.13,-.33),(0,.01,-.43)],
         [(0,1,5),(0,5,3),(1,2,5),(2,4,5),(3,5,4),(0,3,4,2,1)],white,head,False,.008)
    gem("dark_fox_nose",(0,.015,-.435),.04,dark,head,3)
    for side in [-1,1]:
        # Tall ears with indigo outer edges and gold inner faces.
        plate("primary_fox_ear",[(side*x,y) for x,y in [(.12,.43),(.19,.91),(.39,.52),(.23,.34)]],
              .10,(0,0,.02),armor,head,.016)
        plate("trim_ear_inner",[(side*x,y) for x,y in [(.19,.49),(.205,.78),(.31,.52),(.23,.43)]],
              .028,(0,0,-.043),gold,head,.007)
        beam("dark_eye_socket",(side*.045,.21,-.249),(side*.17,.26,-.249),.029,.012,dark,head)
        beam("light_fox_eye",(side*.06,.215,-.266),(side*.158,.251,-.266),.010,.008,light,head)
        curve_strut("trim_cheek_mark",[(side*.18,.15,-.24),(side*.13,.10,-.27),(side*.16,.04,-.27)],.009,gold,head)
        for i in range(3):
            plate("white_cheek_tuft",[(side*x,y) for x,y in [(.16,.08),(.36,.14-i*.06),(.30,-.02-i*.04),(.15,-.08)]],
                  .06,(0,0,.00+i*.03),white,head,.009)
    # Athletic pauldrons and claw gauntlets on independently animated arms.
    for side,name in [(-1,"ArmLeft"),(1,"ArmRight")]:
        arm=empty(name,(side*.52,2.77,0),root)
        loft("dark_arm",[(.02,.12,.13,0,0),(-.48,.095,.10,side*.10,.03),(-.90,.095,.10,side*.13,0)],dark,arm,10)
        for i in range(3):
            plate("primary_shoulder_fan",[(side*x,y) for x,y in [(-.12,.12),(.12,.22),(.31,.03),(.22,-.17),(-.08,-.12)]],
                  .18,(side*i*.03,-i*.07,-i*.025),armor,arm,.018)
            beam("trim_shoulder_edge",(side*-.06,.11-i*.07,-.12-i*.025),(side*.23,.03-i*.07,-.12-i*.025),.011,.013,gold,arm)
        loft("primary_forearm",[(-.49,.12,.13,side*.10,0),(-.62,.16,.15,side*.12,0),(-.91,.11,.11,side*.13,-.01)],armor,arm,10)
        curve_strut("light_arm_glyph",[(side*.10,-.55,-.16),(side*.18,-.70,-.17),(side*.13,-.86,-.13)],.008,light,arm)
        claw_hand(arm,side,mats,white)
    armored_leg("LegLeft",-1,root,mats,True)
    armored_leg("LegRight",1,root,mats,True)
    # Nine thick, curved, tapered translucent tails, each with its own base pivot.
    for i in range(9):
        tail=empty("Tail%d"%i,(0,1.68,.29),root)
        angle=-1.28+i*2.56/8
        length=2.13+.15*math.cos(i*1.8)
        points=[]
        for j in range(15):
            t=j/14
            radial=length*(.12*t+.88*math.sin(t*math.pi*.5))
            points.append((math.sin(angle)*radial, math.cos(angle)*radial-.16*math.sin(t*math.pi),
                           .13+.42*math.sin(t*math.pi)-.15*t))
        radii=[.045+.17*math.sin(math.pi*j/14)**.8 for j in range(15)]
        radii[-1]=.005
        sweep("glass_tail",points,radii,glass,tail,12)
        # Solid gold tip and a thin dorsal light seam clarify the nine silhouettes.
        tip_points=points[10:]
        tip_radii=[r*1.05 for r in radii[10:]]
        sweep("trim_tail_tip",tip_points,tip_radii,gold,tail,12)
        seam=[(p[0],p[1],p[2]-.06) for p in points[3:12]]
        sweep("light_tail_filament",seam,[.008]*len(seam),light,tail,6)
    return root


def orvann(mats, white):
    stone,copper,light,dark,glass=mats
    root=empty("Orvann")
    body=empty("Body",parent=root)
    loft("primary_granite_cuirass",[(1.50,.30,.25,0,.05),(1.90,.37,.26,0,.05),(2.40,.53,.31,0,.05),
         (2.73,.57,.30,0,.05),(2.94,.29,.20,0,.04)],stone,body,12)
    plate("trim_chest_brace",[(-.48,.20),(0,.30),(.48,.20),(.38,-.07),(0,-.35),(-.38,-.07)],
          .055,(0,2.53,-.30),copper,body,.018)
    plate("primary_chest_bastion",[(-.39,.15),(0,.23),(.39,.15),(.31,-.03),(0,-.26),(-.31,-.03)],
          .07,(0,2.53,-.35),stone,body,.02)
    for side in [-1,1]:
        curve_strut("light_branch_glyph",[(side*.05,2.29,-.405),(side*.13,2.50,-.405),(side*.29,2.66,-.405)],.011,light,body)
        curve_strut("light_branch_glyph",[(side*.13,2.50,-.405),(side*.32,2.49,-.405),(side*.37,2.56,-.405)],.009,light,body)
        for i in range(3):
            plate("primary_hip_buttress",[(side*x,y) for x,y in [(.06,.16),(.37,.22),(.47,-.18),(.32,-.36),(.08,-.25)]],
                  .20,(0,1.93-i*.15,-.13+i*.11),stone,body,.02)
            beam("trim_hip_binding",(side*.09,1.96-i*.15,-.24+i*.11),(side*.34,2.00-i*.15,-.24+i*.11),.016,.018,copper,body)
    for i in range(4):
        plate("dark_waist_joint",[(-.25,.05),(.25,.05),(.21,-.065),(-.21,-.065)],.08,(0,2.24-i*.14,-.23),dark,body,.012)
    gem("Core",(0,2.60,-.43),.13,light,body,6)
    head=empty("Head",(0,3.00,.0),root)
    loft("primary_stag_helm",[(.01,.16,.18,0,.05),(.18,.25,.21,0,.05),(.40,.25,.19,0,.05),
         (.54,.14,.16,0,.05)],stone,head,12)
    # Long sculpted stag face and copper brow, distinct from the fox mask.
    plate("dark_stag_face",[(-.18,.35),(.18,.35),(.13,.06),(.06,-.15),(-.06,-.15),(-.13,.06)],
          .10,(0,0,-.21),dark,head,.012)
    plate("primary_stag_nasal",[(-.065,.34),(.065,.34),(.085,.03),(.045,-.18),(-.045,-.18),(-.085,.03)],
          .17,(0,0,-.28),stone,head,.015)
    for side in [-1,1]:
        beam("trim_stag_brow",(side*.06,.31,-.29),(side*.22,.38,-.25),.027,.025,copper,head)
        beam("light_stag_eye",(side*.09,.26,-.28),(side*.18,.29,-.26),.012,.012,light,head)
        plate("primary_stag_ear",[(side*x,y) for x,y in [(.15,.38),(.50,.55),(.48,.37),(.22,.25)]],
              .10,(0,0,.01),stone,head,.015)
        plate("trim_ear_inner",[(side*x,y) for x,y in [(.23,.39),(.43,.48),(.40,.38),(.25,.32)]],
              .025,(0,0,-.055),copper,head,.008)
        for i in range(2):
            plate("primary_stag_beard",[(side*x,y) for x,y in [(.03,.04),(.16,.10),(.19,-.14),(.06,-.31)]],
                  .08,(0,-i*.10,-.01+i*.04),stone,head,.01)
    # Geometric antlers rise from copper sockets and branch into miniature ramparts.
    for side,name in [(-1,"AntlerLeft"),(1,"AntlerRight")]:
        antler=empty(name,(side*.16,3.43,.06),root)
        trunk=[(0,0,0),(side*.13,.28,.01),(side*.34,.47,.04),(side*.55,.60,.06),(side*.72,.78,.08)]
        sweep("trim_antler_trunk",trunk,[.085,.074,.059,.045,.012],copper,antler,8)
        for i in range(1,4):
            base=Vector(trunk[i]); end=base+Vector((side*(-.06 if i%2 else .02),.30+i*.02,-.03))
            knee=base.lerp(end,.65)+Vector((side*.07,0,0))
            sweep("primary_antler_tine",[tuple(base),tuple(knee),tuple(end)],[.055,.033,.004],stone,antler,8)
            beam("light_antler_engraving",tuple(base+Vector((0,.02,-.047))),tuple(knee+Vector((0,0,-.03))),.008,.008,light,antler)
        # Small copper brackets emphasize carved, constructed antlers.
        for i in [1,2]:
            p=trunk[i]
            tube("trim_antler_collar",.068,.012,(p[0],p[1],p[2]),copper,antler,normal="y",segments=20)
    for side,name in [(-1,"ArmLeft"),(1,"ArmRight")]:
        arm=empty(name,(side*.65,2.75,0),root)
        loft("dark_arm_joint",[(.04,.16,.17,0,0),(-.43,.15,.15,side*.05,0),(-.94,.14,.14,side*.13,0)],dark,arm,10)
        # Towers are shaped stone shells with crenellations, copper cornices and slit windows.
        loft("primary_shoulder_tower",[(.0,.27,.24,side*.02,0),(.32,.28,.25,side*.02,0),(.48,.30,.25,side*.02,0)],stone,arm,8)
        for i in range(3):
            x=side*.02+(i-1)*.18
            plate("primary_merlon",[(-.065,.10),(.065,.10),(.065,-.08),(-.065,-.08)],.13,
                  (x,.54,-.17),stone,arm,.01)
        for yy in [.03,.36]:
            beam("trim_tower_course",(-.21,yy,-.25),(.25,yy,-.25),.018,.020,copper,arm)
        plate("dark_tower_arrow_slit",[(-.025,.10),(.025,.10),(.025,-.10),(-.025,-.10)],.012,
              (side*.02,.20,-.255),dark,arm,.004)
        beam("light_tower_slit",(side*.02,.13,-.268),(side*.02,.26,-.268),.008,.004,light,arm)
        loft("primary_forearm_bastion",[(-.40,.17,.18,side*.07,0),(-.59,.23,.21,side*.11,0),(-.91,.16,.16,side*.13,0)],stone,arm,10)
        plate("trim_forearm_border",[(-.14,.17),(.14,.17),(.16,-.16),(0,-.27),(-.16,-.16)],.035,
              (side*.11,-.65,-.21),copper,arm,.012)
        plate("primary_forearm_shield",[(-.105,.13),(.105,.13),(.12,-.12),(0,-.21),(-.12,-.12)],.04,
              (side*.11,-.65,-.24),stone,arm,.01)
        beam("light_forearm_rune",(side*.11,-.56,-.27),(side*.11,-.81,-.27),.012,.008,light,arm)
        claw_hand(arm,side,mats,white,True)
    armored_leg("LegLeft",-1,root,mats,False)
    armored_leg("LegRight",1,root,mats,False)
    return root


def export_new(name, constructor, colors):
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    mats=[material("Primary",colors[0],.18,.48),material("Trim",colors[1],.4,.36),
          material("Light",colors[2],.0,.35,.65),material("Dark",(.025,.025,.07),.10,.55),
          material("Glass",colors[3],.08,.35)]
    if name=="vaelis":
        mats[4].diffuse_color=(*colors[3],.62)
        shader=mats[4].node_tree.nodes.get("Principled BSDF")
        shader.inputs["Alpha"].default_value=.62
        mats[4].surface_render_method='DITHERED'
    white=material("White",(.88,.89,.86),.06,.42)
    root=constructor(mats,white)
    bpy.context.view_layer.update()
    body=next(o for o in root.children if o.name=="Body")
    merge("BodyArmor",[o for o in body.children if o.type=='MESH' and o.name!="Core"],body)
    # Give Core a real local pivot so animation spins the gem rather than its orbit.
    core=next(o for o in body.children if o.name=="Core")
    center=Vector((0,2.59,-.31) if name=="vaelis" else (0,2.60,-.43))
    for v in core.data.vertices:
        v.co-=vec(center)
    core.location=vec(center)
    for region in [o for o in root.children if o.type=='EMPTY' and o!=body]:
        meshes=[o for o in region.children if o.type=='MESH']
        if meshes:
            merge(region.name+"Geometry",meshes,region)
    bpy.ops.object.select_all(action="DESELECT")
    meshes=[o for o in bpy.data.objects if o.type=='MESH']
    for o in meshes:
        o.select_set(True)
    bpy.context.view_layer.objects.active=meshes[0]
    bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.mesh.normals_make_consistent(inside=False);bpy.ops.object.mode_set(mode='OBJECT')
    bpy.ops.object.select_all(action="SELECT")
    # Apply bevels for reliable exported topology and count actual authoring triangles.
    bpy.ops.object.convert(target='MESH')
    triangles=sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in bpy.data.objects if o.type=='MESH')
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT,name+".glb"),export_format="GLB",use_selection=True,
          export_apply=True,export_yup=True,export_animations=False,export_cameras=False,export_lights=False)
    print("KARMA_BUDGET",name,"triangles",triangles,"meshes",len(meshes),"vertices",sum(len(o.data.vertices) for o in bpy.data.objects if o.type=='MESH'))


export_new("vaelis",vaelis,[(.10,.075,.25),(.78,.50,.16),(.68,.65,1.0),(.43,.39,.88)])
export_new("orvann",orvann,[(.78,.80,.73),(.52,.26,.12),(.28,.94,.56),(.18,.54,.35)])
