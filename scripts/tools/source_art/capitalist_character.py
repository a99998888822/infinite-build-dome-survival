"""Hand-authored pixel artwork for the capitalist character review.

Produces review PNGs and an animated GIF. Pass --install to update game assets.
Run: python scripts/tools/source_art/capitalist_character.py
"""

from pathlib import Path
import argparse
import shutil

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / "artifacts/previews/capitalist_character"
NEAREST = Image.Resampling.NEAREST
CLEAR = (0, 0, 0, 0)
P = {
    "ink": "#171b25", "deep": "#222633", "coat": "#333945",
    "coat_mid": "#424958", "coat_lit": "#586172", "coat_hi": "#6b7280",
    "wine_dark": "#492d3b", "wine": "#713d48", "wine_lit": "#965557",
    "wine_hi": "#b87368", "skin_dark": "#987363", "skin_mid": "#c39a7a",
    "skin": "#dfba94", "skin_lit": "#f0d2ac", "skin_hi": "#ffe6bf",
    "linen_dark": "#aaa99c", "linen": "#d6d0bb", "linen_lit": "#f3e9d0",
    "gold_dark": "#715738", "gold": "#ab824b", "gold_lit": "#d7ae66",
    "gold_hi": "#f5d58a", "jade_dark": "#253d3b", "jade": "#42695c",
    "jade_lit": "#7aa88b", "jade_hi": "#bdd0a2", "boot": "#292a32",
    "boot_lit": "#4a4445", "hair": "#534746", "hair_lit": "#86776a",
}


def artist(im, transform=None):
    d = ImageDraw.Draw(im)

    def color(c):
        return P.get(c, c)

    def poly(points, c):
        if transform is not None:
            points = [transform(x, y) for x, y in points]
        d.polygon(points, fill=color(c))

    def rect(box, c):
        if transform is None:
            d.rectangle(box, fill=color(c))
        else:
            x0, y0, x1, y1 = box
            poly([(x0,y0),(x1,y0),(x1,y1),(x0,y1)], c)

    def line(points, c, width=1):
        if transform is not None:
            points = [transform(x, y) for x, y in points]
        d.line(points, fill=color(c), width=width)

    def oval(box, c):
        if transform is not None:
            x0,y0 = transform(*box[:2])
            x1,y1 = transform(*box[2:])
            box = (min(x0,x1),min(y0,y1),max(x0,x1),max(y0,y1))
        d.ellipse(box, fill=color(c))

    return poly, rect, line, oval


# Four authored poses at six frames per second. Foot and cane contact heights
# stay fixed while the torso bobs. Lifted feet have separate swing trajectories.
WALK_POSES = (
    {"body":0,"near":(10,0),"far":(-10,0),"grip":(0,0),"tip":(8,0),"arm":-5,"tail":2},
    {"body":-2,"near":(0,0),"far":(0,-7),"grip":(-1,-2),"tip":(0,0),"arm":-1,"tail":0},
    {"body":0,"near":(-10,0),"far":(10,0),"grip":(-2,-2),"tip":(-6,-6),"arm":5,"tail":-2},
    {"body":-2,"near":(0,-7),"far":(0,0),"grip":(2,-4),"tip":(6,-4),"arm":1,"tail":0},
)
WALK_NAMES = ("落杖迈步", "承重跟进", "抬杖换步", "前送手杖")
WALK_FPS = 6


def posed_artist(im, pose, part):
    if pose is None:
        return artist(im)
    small = im.width == 54
    scale = 54 / 128 if small else 1.0
    hip, ankle = (40,47) if small else (97,112)
    grip_y, tip_y = (32,50) if small else (77,120)
    shoulder_x, hand_x = (32,40) if small else (75,98)
    arm_y, wrist_y = (32,42) if small else (74,100)
    tail_y, tail_end = (39,45) if small else (96,109)
    body = pose["body"] * scale

    def weight(v, start, end):
        return max(0.0,min(1.0,(v-start)/(end-start)))

    def transform(x,y):
        dx,dy = 0,body
        if part in ("near_leg","far_leg"):
            foot_x,foot_y=pose["near" if part == "near_leg" else "far"]
            if part == "far_leg" and not small:
                foot_y += 1
            t=weight(y,hip,ankle)
            center_offset = 14 if part == "near_leg" else -14
            dx=(center_offset+foot_x)*scale*t
            dy=body*(1-t)+foot_y*scale*t
        elif part == "coat":
            dx=pose["tail"]*scale*weight(y,tail_y,tail_end)
        elif part == "free_arm":
            dx=pose["arm"]*scale*weight(y,arm_y,wrist_y)
        elif part == "cane":
            t=weight(y,grip_y,tip_y)
            gx,gy=pose["grip"]
            tx,ty=pose["tip"]
            dx=(gx*(1-t)+tx*t)*scale
            dy=(gy*(1-t)+ty*t)*scale
        elif part == "cane_arm":
            t=weight(x,shoulder_x,hand_x)
            gx,gy=pose["grip"]
            dx=gx*scale*t
            dy=body*(1-t)+gy*scale*t
        return round(x+dx),round(y+dy)

    return artist(im,transform)


def draw_walk_legs(im,pose):
    """Pose-specific knees and right-facing shoes, redrawn at each resolution."""
    poly,rect,line,oval=artist(im)
    small=im.width==54
    scale=54/128 if small else 1
    body=round(pose["body"]*scale)
    hips=(28,22) if small else (64,49)
    center=24 if small else 54
    hip_y,knee_y,ankle_y,ground=(40,44,47,50) if small else (96,104,112,120)
    thigh,shin,heel,toe=(3,2,3,5) if small else (7,4,7,12)
    poly([(hips[1]-thigh,hip_y+body-1),(hips[0]+thigh,hip_y+body-1),
          (hips[0]+2,knee_y),(hips[1]-1,knee_y)],"deep")
    for part,hx in zip(("far","near"),hips):
        sx,lift=pose[part]
        sx,lift=round(sx*scale),round(lift*scale)
        ax,ay=center+sx,ankle_y+lift
        kx=round((hx+ax)/2)+(1 if small else 2)
        ky=knee_y+round(lift*0.35+body*0.65)
        by=ground+lift
        poly([(hx-thigh,hip_y+body),(hx+thigh,hip_y+body),
              (kx+shin+1,ky),(ax+shin,ay+1),(ax-shin,ay+1),
              (kx-shin,ky+1)],"ink")
        poly([(hx-thigh+1,hip_y+body),(hx+thigh-2,hip_y+body),
              (kx+shin-1,ky),(ax+shin-1,ay),(ax-shin+1,ay),
              (kx-shin+1,ky)],"coat_mid" if part=="near" else "coat")
        line([(hx-thigh+2,hip_y+body+1),(kx-shin+1,ky),(ax-shin+1,ay-1)],
             "coat_lit" if part=="near" else "coat_mid",1 if small else 2)
        sole_height=3 if small else 6
        poly([(ax-heel+1,by-sole_height),(ax+1,by-sole_height),
              (ax+toe-1,by-2),(ax+toe,by-1),(ax+toe,by),
              (ax-heel,by),(ax-heel,by-2)],"ink")
        line([(ax-heel+1,by-2),(ax+toe-2,by-2)],"boot_lit",1 if small else 2)
        if not small:
            poly([(ax-heel+2,by-sole_height+1),(ax+1,by-sole_height+1),
                  (ax+toe-3,by-3),(ax-heel+2,by-3)],"boot")
            line([(ax-2,by-5),(ax+2,by-5),(ax+6,by-3)],"boot_lit")
        if part=="near":
            rect((ax-1,by-sole_height,ax+1,by-sole_height),"gold_dark")


def draw_character(pose=None):
    im = Image.new("RGBA", (128, 128), CLEAR)
    poly, rect, line, oval = posed_artist(im,pose,"far_leg")

    # Rear trousers and polished shoes; both soles sit on the same baseline.
    poly([(49,94),(76,94),(75,106),(72,111),(80,113),(81,119),
          (58,119),(55,115)], "ink")
    poly([(58,100),(72,99),(71,110),(65,113),(59,111)], "coat")
    line([(67,101),(66,110)], "coat_mid", 2)
    poly([(62,112),(73,112),(78,115),(78,116),(59,116)], "boot")
    line([(67,113),(74,113),(76,114)], "boot_lit", 2)
    poly, rect, line, oval = posed_artist(im,pose,"near_leg")
    poly([(37,94),(60,95),(59,106),(54,112),(54,117),(51,120),
          (29,120),(29,115),(39,110)], "ink")
    poly([(42,99),(55,100),(53,109),(46,113),(40,111)], "coat_mid")
    poly([(43,101),(49,102),(46,110),(40,111)], "coat_lit")
    poly([(39,112),(50,112),(51,117),(33,117),(33,115)], "boot")
    line([(36,114),(43,113),(48,114)], "boot_lit", 2)
    rect((43,112,48,114), "gold_dark")
    rect((44,112,47,112), "gold_lit")

    # A tailored waist, mostly closed coat and a narrow waistcoat opening.
    if pose is not None:
        # Replace the spread, outward-facing idle shoes with a forward gait.
        im.paste(CLEAR,(0,0,128,128))
        draw_walk_legs(im,pose)
    poly, rect, line, oval = posed_artist(im,pose,"coat")
    poly([(38,63),(48,60),(66,61),(74,65),(78,75),(77,86),(79,103),
          (72,105),(64,100),(50,102),(37,109),(28,108),(33,90),(31,76)], "ink")
    poly([(36,72),(43,65),(65,64),(73,68),(76,78),(74,88),(76,102),
          (70,102),(62,98),(49,100),(37,106),(31,105),(37,85)], "coat")
    poly([(37,73),(43,68),(44,77),(41,89),(36,99),(32,104),(36,85)], "coat_mid")
    poly([(69,66),(73,69),(76,78),(73,88),(76,101),(71,101),(64,96)], "coat_mid")
    line([(73,89),(74,98),(72,101)], "coat_lit")
    poly, rect, line, oval = posed_artist(im,pose,"body")
    poly([(50,65),(64,64),(70,72),(68,84),(63,91),(54,86),(48,74)], "wine_dark")
    poly([(54,68),(63,67),(67,73),(65,83),(62,87),(57,83),(52,75)], "wine")
    poly([(60,72),(64,72),(65,78),(63,84),(61,83)], "wine_lit")
    # Navy fronts overlap at the waist instead of outlining a round belly.
    poly([(42,66),(47,64),(50,72),(55,78),(61,87),(61,98),
          (48,99),(41,101),(42,86),(40,76)], "coat")
    poly([(69,65),(73,68),(75,77),(72,87),(75,100),(68,100),
          (62,96),(62,87),(66,78)], "coat_mid")
    line([(61,88),(61,97)], "deep")
    for y in (89,96):
        rect((62,y,64,y+1), "gold_dark")
        rect((62,y,63,y), "gold_lit")

    # Ivory shirt, split collar and burgundy tie framed by satin lapels.
    poly([(47,61),(66,61),(69,69),(59,81),(48,71)], "ink")
    poly([(48,62),(65,62),(66,68),(59,77),(50,69)], "linen")
    poly([(50,62),(57,65),(53,71),(48,67)], "linen_lit")
    poly([(58,65),(64,62),(67,67),(62,70)], "linen_lit")
    poly([(55,66),(60,66),(62,69),(59,72),(55,70)], "wine_dark")
    rect((56,67,59,68), "wine_lit")
    poly([(57,70),(60,71),(60,77),(58,79),(55,75)], "wine")
    poly([(44,64),(48,63),(51,71),(57,78),(53,79),(58,85),(43,76)], "coat_lit")
    line([(45,66),(49,72),(54,78)], "coat_hi")
    poly([(67,63),(72,66),(71,73),(64,83),(67,75),(64,73)], "coat_lit")
    line([(70,66),(69,72),(66,77)], "coat_hi")

    # One relaxed hand and one gloved hand resting on the cane.
    poly, rect, line, oval = posed_artist(im,pose,"free_arm")
    poly([(29,73),(36,70),(43,78),(41,89),(37,95),(29,93),(25,84)], "ink")
    poly([(30,75),(35,74),(39,80),(37,89),(30,90),(28,83)], "coat_mid")
    line([(30,77),(29,83),(32,87)], "coat_lit", 2)
    poly([(30,90),(37,90),(38,94),(34,97),(28,95)], "linen_dark")
    poly([(29,94),(37,93),(39,97),(38,103),(34,106),(28,102),(26,97)], "ink")
    poly([(29,95),(35,95),(37,98),(35,103),(30,102),(28,99)], "linen")
    line([(29,96),(33,96),(34,97)], "linen_lit", 2)
    line([(30,100),(33,101)], "linen_dark")
    line([(34,98),(35,99)], "linen_dark")

    # Cane: warm, polished metal, restrained jade eye/scroll motif.
    poly, rect, line, oval = posed_artist(im,pose,"cane")
    poly([(98,75),(102,75),(101,114),(103,117),(102,120),(97,120),
          (96,118),(98,113)], "ink")
    rect((99,81,100,113), "gold_dark")
    rect((99,83,99,111), "boot_lit")
    rect((99,85,100,111), "deep")
    rect((99,114,101,117), "gold")
    rect((99,114,100,114), "gold_hi")
    rect((98,118,102,119), "gold_dark")
    poly([(95,71),(98,67),(104,67),(109,70),(111,74),(109,79),(104,81),
          (99,79),(97,76),(94,76)], "ink")
    poly([(97,71),(100,69),(104,69),(108,72),(109,75),(106,78),(102,78),
          (100,75),(96,75)], "gold")
    line([(98,71),(101,70),(104,70),(107,72)], "gold_hi", 2)
    line([(107,73),(107,76),(104,77),(102,76)], "gold_dark")
    oval((101,71,107,77), "jade_dark")
    oval((103,72,106,75), "jade")
    rect((103,72,104,73), "jade_lit")
    rect((103,72,103,72), "jade_hi")
    line([(108,77),(106,79),(103,79)], "gold_lit")

    poly, rect, line, oval = posed_artist(im,pose,"cane_arm")
    poly([(75,69),(82,70),(87,78),(94,78),(95,86),(87,89),(80,86),
          (74,81),(71,74)], "ink")
    poly([(76,71),(80,72),(85,80),(91,80),(92,84),(86,86),(80,82),(74,75)], "coat_mid")
    line([(77,72),(81,76),(83,80),(88,82)], "coat_lit", 2)
    poly([(91,77),(96,77),(98,82),(93,86),(90,84)], "linen_dark")
    poly([(95,73),(101,73),(104,76),(103,80),(99,83),(94,82),(92,77)], "ink")
    poly([(96,74),(100,74),(102,76),(101,79),(98,81),(95,80),(94,77)], "linen")
    poly([(96,74),(100,74),(101,76),(96,77),(94,76)], "linen_lit")
    line([(97,78),(99,79)], "linen_dark")
    line([(99,76),(100,77)], "linen_dark")

    # Watch chain: sparse points so it reads as jewellery, not a busy grid.
    poly, rect, line, oval = posed_artist(im,pose,"body")
    line([(63,86),(66,89),(70,90),(73,88),(74,85)], "gold_dark", 2)
    line([(63,85),(66,88),(69,89),(72,87),(73,84)], "gold_lit")
    rect((69,89,70,89), "gold_hi")
    rect((72,83,75,84), "deep")

    # Three-quarter face: nearer eye under the monocle, far eye beside the
    # bridge, and a shorter nose below their shared eyeline.
    poly([(43,35),(60,33),(74,37),(79,43),(79,49),(81,53),(80,56),
          (77,57),(75,62),(68,66),(54,64),(45,60),(39,52),(38,43)], "ink")
    poly([(44,37),(58,36),(71,39),(76,44),(77,50),(79,53),(78,55),
          (75,56),(74,61),(68,64),(55,63),(46,59),(41,51),(41,44)], "skin_mid")
    poly([(48,39),(60,37),(71,40),(74,45),(73,51),(76,55),(72,59),
          (65,61),(55,59),(48,55),(44,47)], "skin")
    poly([(52,40),(65,39),(71,42),(72,46),(66,47),(57,46),(49,48),(48,43)], "skin_lit")
    poly([(51,54),(58,54),(63,57),(62,60),(55,58)], "skin_lit")
    oval((38,43,47,54), "ink")
    oval((40,45,47,52), "skin_mid")
    line([(42,47),(44,47),(45,49),(43,50)], "skin_dark")
    rect((40,46,41,48), "skin_lit")
    poly([(43,38),(49,38),(48,43),(46,46),(46,53),(43,51)], "hair")
    line([(45,40),(46,41),(44,45)], "hair_lit")

    # Both pupils share an eyeline. The monocle belongs to the nearer eye;
    # skin and a readable pupil remain visible through the lightly tinted lens.
    line([(54,43),(59,42),(64,43)], "hair")
    line([(71,46),(74,45),(76,46)], "hair")
    oval((53,44,67,57), "gold_dark")
    oval((54,45,66,56), "gold_lit")
    oval((55,46,65,55), "skin_lit")
    line([(56,48),(58,46),(60,46)], "jade_lit")
    rect((57,47,57,47), "jade_hi")
    line([(57,49),(60,48),(63,49)], "hair")
    rect((58,50,63,51), "linen_lit")
    rect((61,49,62,52), "ink")
    rect((61,50,61,50), "linen_lit")
    line([(59,54),(63,54)], "skin_mid")
    line([(55,46),(56,45),(60,45)], "gold_hi")
    line([(55,55),(58,56)], "gold_hi")
    line([(54,55),(51,59),(52,63),(54,65)], "gold_dark")
    line([(54,56),(52,60),(53,63)], "gold_lit")
    line([(71,49),(74,49)], "hair")
    rect((72,50,74,50), "linen_lit")
    rect((74,49,74,51), "ink")
    # The compact nose starts between the eyes and ends below them.
    line([(69,48),(69,51),(71,54)], "skin_mid")
    poly([(71,49),(73,50),(74,52),(78,53),(79,54),(77,55),
          (73,55),(70,53)], "skin_lit")
    line([(74,54),(78,54)], "skin_hi")
    line([(73,56),(76,56)], "skin_dark")
    # A small moustache and mouth follow the nose rather than the lens edge.
    poly([(64,58),(67,59),(70,57),(73,58),(75,57),(78,58),
          (76,60),(73,60),(70,59),(67,61),(64,60)], "hair")
    line([(66,59),(68,59)], "hair_lit")
    rect((74,58,75,58), "hair_lit")
    line([(68,63),(72,63),(74,62)], "skin_dark")
    line([(64,63),(66,64)], "skin_hi")

    # Tall satin top hat, subtly curved crown and a clear projecting brim.
    poly([(37,9),(43,6),(71,6),(79,9),(80,16),(79,33),(86,34),(92,38),
          (91,42),(85,45),(72,45),(60,42),(45,43),(32,41),(28,38),
          (30,34),(38,33),(37,20)], "ink")
    poly([(39,11),(44,9),(69,9),(76,11),(77,18),(76,34),(66,37),
          (48,35),(40,32)], "coat")
    poly([(41,13),(45,11),(50,11),(49,31),(43,31)], "coat_mid")
    line([(43,14),(43,27)], "coat_lit", 2)
    poly([(64,10),(74,11),(76,15),(74,31),(66,34)], "deep")
    line([(42,10),(47,8),(67,8),(74,10)], "coat_lit")
    line([(49,9),(63,9)], "coat_hi")
    poly([(40,28),(47,30),(63,31),(76,28),(76,34),(65,38),
          (48,36),(40,33)], "gold_dark")
    poly([(41,29),(48,31),(63,32),(75,30),(75,33),(64,36),(48,34),(41,32)], "gold")
    line([(42,29),(49,31),(62,32),(73,30)], "gold_lit")
    rect((68,31,71,35), "gold_dark")
    rect((69,31,70,34), "gold_hi")
    poly([(32,35),(39,35),(48,38),(64,39),(79,35),(85,36),(89,38),
          (88,40),(79,42),(70,42),(60,40),(44,40),(33,38)], "coat_mid")
    line([(34,35),(40,36),(48,38),(61,39)], "coat_lit")
    line([(78,38),(85,37),(88,39)], "coat_hi")
    line([(36,39),(44,41),(57,41)], "deep")
    return im


def draw_combat(pose=None):
    """A separately authored 54px study, not a filtered portrait shrink."""
    im = Image.new("RGBA", (54, 54), CLEAR)
    poly, rect, line, oval = artist(im)
    if pose is None:
        poly([(19,40),(32,40),(31,46),(34,48),(34,50),(25,50),
              (24,46),(22,49),(15,50),(13,49),(15,47),(18,46)], "ink")
        rect((19,42,22,46), "coat_mid")
        rect((27,42,30,46), "coat")
        line([(16,48),(20,48)], "boot_lit")
        line([(27,48),(32,48)], "boot_lit")
    else:
        draw_walk_legs(im,pose)
    poly,rect,line,oval=posed_artist(im,pose,"coat")
    poly([(17,27),(21,25),(28,25),(32,28),(34,34),(33,39),(34,44),
          (30,44),(27,42),(22,43),(15,45),(12,44),(14,37),(13,31)], "ink")
    poly([(16,29),(21,27),(30,28),(32,33),(31,40),(29,42),
          (23,41),(16,43),(14,43),(16,36)], "coat")
    line([(16,30),(15,34),(16,38)], "coat_mid")
    poly,rect,line,oval=posed_artist(im,pose,"body")
    poly([(23,29),(27,28),(29,31),(28,36),(26,38),(23,34)], "wine_dark")
    poly([(24,30),(27,30),(28,32),(27,36),(25,34)], "wine")
    rect((26,32,26,34), "wine_lit")
    poly([(17,27),(20,28),(22,31),(25,35),(26,39),(23,42),
          (17,43),(15,41),(17,35)], "coat")
    poly([(29,27),(32,29),(33,35),(31,38),(33,43),(28,42),
          (27,38),(28,33)], "coat_mid")
    poly([(20,26),(28,26),(27,30),(25,33),(21,29)], "linen_lit")
    rect((24,28,25,29), "wine_dark")
    line([(24,29),(25,32)], "wine")
    poly([(18,27),(21,28),(24,35),(18,32)], "coat_lit")
    poly([(29,27),(31,29),(28,34),(29,30),(27,30)], "coat_lit")
    rect((26,38,26,38), "gold_lit")
    rect((26,41,26,41), "gold_lit")
    line([(28,37),(30,39),(31,38)], "gold_lit")
    poly,rect,line,oval=posed_artist(im,pose,"free_arm")
    poly([(12,31),(16,30),(18,34),(16,39),(12,40),(10,36)], "ink")
    poly([(13,32),(15,32),(16,35),(15,38),(12,37)], "coat_mid")
    poly([(12,39),(16,39),(16,43),(14,44),(11,42)], "linen")
    rect((12,39,14,40), "linen_lit")
    poly,rect,line,oval=posed_artist(im,pose,"cane")
    rect((41,32,43,49), "ink")
    rect((42,34,42,47), "gold_dark")
    rect((41,49,43,50), "gold")
    oval((40,28,46,34), "ink")
    oval((40,29,45,33), "gold_lit")
    rect((43,30,44,32), "jade_dark")
    rect((43,30,43,30), "jade_lit")
    poly,rect,line,oval=posed_artist(im,pose,"cane_arm")
    poly([(32,29),(35,30),(37,33),(40,33),(41,36),(36,38),(32,35)], "ink")
    poly([(33,30),(35,32),(37,35),(39,34),(39,36),(35,36),(32,33)], "coat_mid")
    poly([(39,31),(42,31),(43,33),(41,35),(38,34)], "linen")
    rect((39,31,41,32), "linen_lit")
    poly,rect,line,oval=posed_artist(im,pose,"body")
    poly([(18,16),(25,14),(31,17),(33,20),(33,22),(35,23),(34,25),
          (32,25),(31,27),(27,29),(20,27),(17,24),(16,20)], "ink")
    poly([(20,17),(27,16),(30,18),(31,20),(31,22),(33,23),(32,24),
          (30,24),(30,26),(26,27),(21,25),(18,22)], "skin")
    rect((21,18,27,19), "skin_lit")
    rect((17,20,19,23), "skin_mid")
    line([(18,18),(19,19),(19,21)], "hair")
    # Small-size counterpart of the nearer-eye monocle, same eyeline and nose.
    oval((20,19,28,26), "gold_dark")
    oval((21,20,27,25), "gold_lit")
    rect((22,21,26,24), "skin_lit")
    rect((22,21,23,21), "jade_lit")
    line([(23,22),(26,22)], "hair")
    rect((23,23,24,23), "linen_lit")
    rect((25,22,25,24), "ink")
    rect((21,21,21,21), "gold_hi")
    line([(21,25),(20,26),(21,27)], "gold")
    rect((30,22,31,22), "ink")
    line([(29,23),(31,24)], "skin_mid")
    rect((32,23,33,23), "skin_lit")
    line([(29,26),(30,26),(31,25),(32,26)], "hair")
    rect((29,27,30,27), "skin_dark")
    poly([(16,5),(19,3),(29,3),(33,5),(33,13),(37,15),(38,17),
          (35,19),(29,19),(25,18),(15,18),(12,16),(13,14),(16,14)], "ink")
    poly([(17,6),(20,5),(29,5),(31,6),(31,13),(26,15),(18,13)], "coat")
    rect((18,6,20,11), "coat_mid")
    line([(19,5),(28,5)], "coat_lit")
    line([(18,6),(18,10)], "coat_lit")
    poly([(17,12),(24,13),(31,12),(31,14),(26,16),(18,14)], "gold")
    line([(18,12),(24,13),(29,12)], "gold_lit")
    rect((29,13,29,14), "gold_hi")
    line([(14,15),(20,16),(26,17),(34,15),(36,16)], "coat_mid", 2)
    line([(15,15),(21,17),(25,17)], "coat_lit")
    return im


def font(size, bold=False):
    name = "msyhbd.ttc" if bold else "msyh.ttc"
    return ImageFont.truetype(str(Path("C:/Windows/Fonts") / name), size)


def make_board(hero, combat):
    board = Image.new("RGB", (1600, 1060), "#eae5d8")
    d = ImageDraw.Draw(board)
    ink, muted, rule = "#292d32", "#777665", "#c9c1ac"

    def text(x, y, value, size=22, color=ink, bold=False):
        d.text((x, y), value, fill=color, font=font(size, bold))

    def label(x, y, num, title, sub):
        text(x, y, num, 18, "#9b7e49", True)
        text(x+42, y-4, title, 24, ink, True)
        text(x+42, y+31, sub, 17, muted)

    d.rectangle((0,0,1599,9), fill="#292d32")
    text(64,38,"CHARACTER STUDY  /  01",18,muted)
    text(64,70,"资本家",46,ink,True)
    text(66,135,"高帽  /  单片镜  /  手杖   ·   90% 绅士，10% 异样",20,muted)
    text(1110,53,"ORIGINAL PIXEL ART",18,muted)
    text(1110,85,"角色形象 · 美术参照",23,ink)
    d.line((64,182,1536,182), fill=rule,width=1)

    # Main character is enlarged only by an integer nearest-neighbour scale.
    d.rectangle((64,210,728,898), fill="#dfd9c9")
    d.line((88,872,704,872),fill="#c3bba6",width=1)
    text(90,231,"FULL-BODY / 向右",16,muted)
    d.ellipse((226,815,615,852),fill="#c8c0ac")
    board.paste(hero.resize((640,640),NEAREST),(70,245),hero.resize((640,640),NEAREST))
    # Keep the full-body face unobstructed; the enlarged studies carry detail.

    # Detail studies are crops of the actual master so identity stays exact.
    label(786,222,"01","体面之下","旧金镜框与低饱和幽绿，只占少量细节")
    d.rectangle((786,296,1114,558),fill="#f5f0e4")
    face = hero.crop((35,29,86,68)).resize((255,195),NEAREST)
    board.paste(face,(822,314),face)
    d.rectangle((1138,296,1536,558),fill="#f5f0e4")
    cane = hero.crop((89,65,114,87)).resize((200,176),NEAREST)
    board.paste(cane,(1235,328),cane)
    text(811,528,"单片镜 / 小八字胡",16,muted)
    text(1162,528,"白手套 / 镶玉杖头",16,muted)

    label(786,590,"02","战斗尺寸辨识","独立绘制 54 × 54 像素，保留帽、镜、杖")
    d.rectangle((786,668,1536,897),fill="#232d2e")
    # A simple flat patch previews contrast with the game's dark green floor.
    d.ellipse((840,852,1025,874),fill="#1a2225")
    c4=combat.resize((216,216),NEAREST)
    board.paste(c4,(824,673),c4)
    text(1052,690,"4× 最近邻放大",19,"#dcd4bd")
    board.paste(combat,(1070,737),combat)
    board.paste(combat.transpose(Image.Transpose.FLIP_LEFT_RIGHT),(1170,737),
                combat.transpose(Image.Transpose.FLIP_LEFT_RIGHT))
    text(1060,809,"1× 原尺寸",17,"#b2b9a8")
    text(1276,731,"右向 / 镜像",18,"#dcd4bd")
    text(1276,767,"硬透明边缘",18,"#b2b9a8")
    text(1276,803,"脚底锚点一致",18,"#b2b9a8")

    d.line((64,928,1536,928),fill=rule,width=1)
    text(65,950,"“损失可以转嫁，收益必须留下。”",27,ink,True)
    text(66,999,"手工像素绘制  ·  素材与数值均为审阅稿",18,muted)
    colors=[P[k] for k in ("ink","coat","coat_lit","wine","skin","linen_lit","gold","gold_hi","jade","jade_lit")]
    for i,c in enumerate(colors):
        x=1092+i*44
        d.rectangle((x,958,x+31,989),fill=c)
    text(1092,1000,"CHARCOAL / IVORY / OLD GOLD / JADE",14,muted)
    return board


def make_sheet(frames):
    w,h=frames[0].size
    sheet=Image.new("RGBA",(w*len(frames),h),CLEAR)
    for i,frame in enumerate(frames):
        sheet.paste(frame,(i*w,0))
    return sheet


def make_walk_board(large,small):
    im=Image.new("RGB",(1200,720),"#eae5d8")
    d=ImageDraw.Draw(im)
    d.rectangle((0,0,1199,7),fill="#292d32")
    d.text((36,24),"食利者 · 行走四帧",font=font(32,True),fill="#292d32")
    d.text((768,34),"向右 / 6 FPS / 美术审阅",font=font(20),fill="#777665")
    for i,(big,little) in enumerate(zip(large,small)):
        x=36+i*284
        d.rectangle((x,94,x+270,636),fill="#dfd9c9")
        d.line((x+12,353,x+257,353),fill="#bfb79f")
        scaled=big.resize((256,256),NEAREST)
        im.paste(scaled,(x+7,110),scaled)
        d.text((x+20,380),f"0{i+1}  {WALK_NAMES[i]}",font=font(22,True),fill="#343b41")
        d.line((x+18,422,x+252,422),fill="#c7bfaa")
        d.rectangle((x+18,440,x+252,618),fill="#232d2e")
        d.line((x+30,603,x+240,603),fill="#485149")
        scaled=little.resize((162,162),NEAREST)
        im.paste(scaled,(x+55,450),scaled)
    d.text((38,660),"上：256×256 源帧    下：54×54 战斗帧（3× 放大）",font=font(20),fill="#676b61")
    d.text((38,690),"每帧画布与脚底基准一致；摆腿、抬杖、衣摆分别运动。正式角色采用 6 FPS。",font=font(16),fill="#777665")
    return im


def make_walk_preview(large,small,index):
    im=Image.new("RGB",(1120,760),"#eae5d8")
    d=ImageDraw.Draw(im)
    dark,muted="#292d32","#777665"
    d.rectangle((0,0,1119,7),fill=dark)
    d.text((36,27),"资本家",font=font(35,True),fill=dark)
    d.text((718,39),"行走动画 / 4 帧 / 6 FPS",font=font(22),fill=muted)
    d.text((38,81),"小步前行，落杖承重；高帽与上身轻微起伏。",font=font(20),fill=muted)
    d.rectangle((36,128,550,684),fill="#dfd9c9")
    d.text((58,145),"源图动作",font=font(18),fill=muted)
    d.ellipse((182,613,451,639),fill="#c4bca8")
    big=large.resize((512,512),NEAREST)
    im.paste(big,(27,151),big)
    d.text((60,650),f"0{index+1}  {WALK_NAMES[index]}",font=font(21,True),fill=dark)
    for i in range(4):
        d.rectangle((382+i*33,658,403+i*33,664),fill="#ad8849" if i==index else "#c7bea9")

    d.rectangle((578,128,1084,684),fill="#232d2e")
    d.text((604,147),"战斗尺寸 · 4× 放大",font=font(20),fill="#ded7c5")
    d.ellipse((642,407,796,426),fill="#192123")
    d.ellipse((870,407,1036,426),fill="#192123")
    right=small.resize((216,216),NEAREST)
    left=right.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
    im.paste(right,(608,220),right)
    im.paste(left,(842,220),left)
    d.text((673,450),"向右",font=font(19),fill="#d7d3bf")
    d.text((902,450),"左向镜像",font=font(19),fill="#d7d3bf")
    d.line((604,500,1058,500),fill="#48534f")
    d.text((606,522),"1× 原尺寸",font=font(18),fill="#b2b9a8")
    im.paste(small,(704,563),small)
    mirror=small.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
    im.paste(mirror,(940,563),mirror)
    d.line((688,615,778,615),fill="#566155")
    d.line((924,615,1014,615),fill="#566155")
    d.text((606,647),"固定锚点 / 硬透明素材 / 最近邻播放",font=font(17),fill="#b2b9a8")
    d.text((38,710),"素材逐帧播放预览 · 游戏内录像单独保存",font=font(19),fill=muted)
    return im


def save_walk_gif(large,small):
    frames=[make_walk_preview(a,b,i) for i,(a,b) in enumerate(zip(large,small))]
    palette=frames[0].quantize(colors=256,method=Image.Quantize.MEDIANCUT,dither=Image.Dither.NONE)
    frames=[im.quantize(palette=palette,dither=Image.Dither.NONE) for im in frames]
    # Three cycles use an exact two-second total despite GIF's 10ms tick.
    sequence=frames*3
    durations=[170,160,170]*4
    sequence[0].save(OUT/"capitalist_walk.gif",save_all=True,append_images=sequence[1:],
                     duration=durations,loop=0,disposal=1,optimize=True)
    with Image.open(OUT/"capitalist_walk.gif") as gif:
        total=0
        assert gif.n_frames == 12
        for i in range(gif.n_frames):
            gif.seek(i)
            total+=gif.info["duration"]
        assert total == 2000,total
    print("capitalist_walk.gif: 1120x760; 4 poses, 6 fps average, seamless loop")


def validate_walk(frames,size):
    assert len(frames)==4
    assert len({im.tobytes() for im in frames})==4
    for im in frames:
        assert im.size==size
        assert set(im.getchannel("A").tobytes())=={0,255}
        bounds=im.getbbox()
        assert bounds and bounds[0]>0 and bounds[1]>0
        assert bounds[2]<size[0] and bounds[3]<size[1],bounds
    # Every pose has a planted shoe at the same baseline; raised shoes/cane
    # are allowed above it. There is no whole-character translation trick.
    ground=121 if size[0]==128 else 51
    assert all(im.getbbox()[3]==ground for im in frames)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--install", action="store_true", help="Install approved textures into assets/")
    args = parser.parse_args()
    OUT.mkdir(parents=True,exist_ok=True)
    hero=draw_character()
    combat=draw_combat()
    master=hero.resize((256,256),NEAREST)
    # A bust view remains unframed for potential character-selection use.
    portrait=hero.crop((28,5,92,69)).resize((128,128),NEAREST)
    walk_large=[draw_character(pose) for pose in WALK_POSES]
    walk_small=[draw_combat(pose) for pose in WALK_POSES]
    validate_walk(walk_large,(128,128))
    validate_walk(walk_small,(54,54))
    outputs={
        "capitalist_display.png":master,
        "capitalist_portrait.png":portrait,
        "capitalist_combat_study.png":combat,
        "capitalist_review.png":make_board(hero,combat),
        "capitalist_walk_right.png":make_sheet([im.resize((256,256),NEAREST) for im in walk_large]),
        "capitalist_combat_walk_right.png":make_sheet(walk_small),
        "capitalist_walk_frames.png":make_walk_board(walk_large,walk_small),
    }
    for name,im in outputs.items():
        im.save(OUT/name,optimize=True)
        print(f"{name}: {im.width}x{im.height} {im.mode}")
    for name in ("capitalist_display.png","capitalist_portrait.png","capitalist_combat_study.png"):
        im=outputs[name]
        alpha=set(im.getchannel("A").tobytes())
        assert alpha == {0,255}, (name,alpha)
        assert im.getbbox() is not None
    print("PASS: hard transparency and fixed animation baseline")
    save_walk_gif(walk_large,walk_small)
    if args.install:
        install_assets()


def install_assets():
    assets = {
        "capitalist_display.png": "assets/sprites/player/capitalist_idle_right.png",
        "capitalist_portrait.png": "assets/ui/icons/characters/icon_capitalist.png",
        "capitalist_combat_study.png": "assets/sprites/player/combat/capitalist_idle_right.png",
        "capitalist_combat_walk_right.png": "assets/sprites/player/combat/capitalist_walk_right_spritesheet.png",
    }
    for source, destination in assets.items():
        target = ROOT / destination
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(OUT / source, target)
        print(f"INSTALLED: {destination}")


if __name__ == "__main__":
    main()
