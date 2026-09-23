"""Original pixel drawing for the armored rusher; no model or API calls.

Pillow is a build-time dependency only. Existing sprites are read exclusively
for the scale-comparison preview and never sampled into the new character.
"""

from __future__ import annotations

import json
import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets/sprites/enemies/elite_rusher"
COMBAT = ROOT / "assets/sprites/enemies/combat/elite_rusher"
PREVIEW = ROOT / "artifacts/elite_rusher_assets_20260923"
TELEGRAPH = ROOT / "assets/sprites/effects/telegraphs"
PREFIX = "enemy_rift_rusher"
SIZE = 128
P = {
    "ink": "#141B1E", "crease": "#233334", "deep": "#2B4443",
    "body_dark": "#354B49", "body": "#516B60", "body_light": "#799079",
    "shell_dark": "#3D5550", "shell_low": "#526A57", "shell": "#708363",
    "shell_light": "#95A078", "shell_high": "#B5BA8B", "shell_glint": "#D1D2A0",
    "bone_dark": "#827B61", "bone_mid": "#B4AA80", "bone": "#D8CEA0",
    "bone_light": "#EFE3B7", "eye_dark": "#594A32", "eye": "#DA9A52",
    "eye_light": "#F9D18B", "gill": "#9D7361", "gill_dark": "#654E46",
    "eldritch": "#92B4A3", "eldritch_dark": "#4B7F79", "toe": "#A9B29A",
}
SPECS = {
    "idle": {"count": 4, "durations": [240, 200, 240, 200], "loop": True},
    "move": {"count": 6, "durations": [110] * 6, "loop": True},
    "windup": {"count": 3, "durations": [160, 180, 460], "loop": False},
    "dash": {"count": 2, "durations": [100, 100], "loop": True},
    "recover": {"count": 3, "durations": [160, 160, 180], "loop": False},
    "death": {"count": 5, "durations": [100, 110, 120, 140, 400], "loop": False},
}


def pose_for(action: str, index: int) -> dict:
    pose = dict(dx=0, dy=0, sx=1.0, sy=1.0, head_x=0, head_y=0,
                rear=0, front=0, far_rear=0, far_front=0, lift=0,
                blink=False, tense=False, death=0.0)
    if action == "idle":
        pose["dy"] = [0, -1, 0, 1][index]
        pose["head_y"] = [0, 0, 1, 0][index]
    elif action == "move":
        phase = index * math.tau / 6
        step = round(math.sin(phase) * 5)
        pose.update(dy=[0, -1, -2, 0, 1, 2][index], head_y=1 if index == 3 else 0, rear=step,
                    front=-step, far_rear=-step, far_front=step,
                    lift=round(abs(math.sin(phase)) * 3))
    elif action == "windup":
        strength = (index + 1) / 3
        pose.update(dx=round(-2 * strength), dy=round(4 * strength),
                    sy=1 - .04 * strength, head_x=round(2 * strength),
                    head_y=round(5 * strength), rear=-3, front=3, tense=True)
    elif action == "dash":
        pose.update(dx=2, dy=3 + index, sx=1.035, sy=.94, head_x=3,
                    head_y=3, rear=-8 + index * 3, front=-6 + index * 2,
                    far_rear=-5, far_front=-3, lift=4, tense=True)
    elif action == "recover":
        strength = [1.0, .5, 0.0][index]
        pose.update(dx=round(2 * strength), dy=round(5 * strength),
                    head_y=round(4 * strength), head_x=round(-strength),
                    front=round(5 * strength), rear=round(-2 * strength))
    elif action == "death":
        strength = index / 4
        pose.update(dy=round(16 * strength), sy=1 - .25 * strength,
                    head_y=round(7 * strength), head_x=round(-3 * strength),
                    blink=index >= 2, death=strength)
    return pose


class PixelPainter:
    def __init__(self, pose: dict):
        self.image = Image.new("RGBA", (SIZE, SIZE))
        self.draw = ImageDraw.Draw(self.image)
        self.pose = pose

    def point(self, xy, head=False):
        x, y = xy
        p = self.pose
        x = 64 + (x - 64) * p["sx"] + p["dx"]
        y = 72 + (y - 72) * p["sy"] + p["dy"]
        if head:
            x += p["head_x"]
            y += p["head_y"]
        return round(x), round(y)

    def poly(self, points, color, outline=None, head=False):
        self.draw.polygon([self.point(xy, head) for xy in points],
                          fill=P[color], outline=P[outline] if outline else None)

    def line(self, points, color, width=1, head=False):
        self.draw.line([self.point(xy, head) for xy in points],
                       fill=P[color], width=width, joint="curve")

    def dot(self, x, y, color, head=False):
        self.draw.point(self.point((x, y), head), fill=P[color])

    def leg(self, hip, knee, foot, far=False, shift=0, lift=0):
        # Foot placement has its own ground space, so breathing moves the hip
        # but does not translate grounded toes up and down.
        hip = self.point(hip)
        knee = self.point((knee[0] + shift * .45, knee[1]))
        death = self.pose["death"]
        foot = (round(foot[0] + shift), round(foot[1] - lift))
        if death:
            knee = (knee[0] + round((knee[0] - 64) * death * .22),
                    round(knee[1] * (1 - death) + 97 * death))
            foot = (foot[0] + round((foot[0] - 64) * death * .2), 100)
        draw = self.draw
        draw.line([hip, knee, foot], fill=P["ink"], width=12 if not far else 10, joint="curve")
        draw.line([hip, knee, foot], fill=P["body_dark" if far else "body"],
                  width=8 if not far else 6, joint="curve")
        if not far:
            draw.line([(hip[0]-1,hip[1]-1),(knee[0]-2,knee[1]),
                       (foot[0]-2,foot[1]-1)], fill=P["body_light"], width=3)
        fx, fy = foot
        draw.polygon([(fx-5,fy-4),(fx+4,fy-4),(fx+8,fy-1),(fx+8,fy+2),
                      (fx-6,fy+2),(fx-7,fy)], fill=P["ink"])
        draw.polygon([(fx-4,fy-3),(fx+3,fy-3),(fx+6,fy),(fx+4,fy+1),
                      (fx-5,fy+1)], fill=P["shell_dark" if far else "shell_low"])
        if not far:
            for tx in (fx+1,fx+5):
                draw.line([(tx,fy-2),(tx+2,fy)],fill=P["toe"],width=2)


def draw_frame(action: str, index: int) -> Image.Image:
    p = pose_for(action, index)
    r = PixelPainter(p)
    # Far-side limbs first.
    r.leg((46,72),(36,82),(34,94),True,p["far_rear"],p["lift"] if p["far_rear"] > 0 else 0)
    r.leg((78,71),(84,82),(86,94),True,p["far_front"],p["lift"] if p["far_front"] > 0 else 0)
    # A short, harmless-looking rear feeler is the first subtle eldritch note.
    r.line([(32,69),(25,71),(23,77),(27,80),(30,77)],"ink",5)
    r.line([(32,69),(25,72),(25,77),(28,78)],"body",3)
    r.dot(26,74,"body_light")
    # Low body under the raised carapace.
    r.poly([(32,61),(43,53),(66,51),(85,60),(95,73),(90,86),
            (74,91),(47,86),(31,75)],"body_dark","ink")
    r.poly([(38,68),(62,63),(87,72),(88,82),(73,86),(48,80)],"body")
    r.poly([(47,74),(67,72),(78,79),(71,84),(51,80)],"body_light")
    r.line([(42,78),(48,83),(66,88),(83,85)],"crease",2)
    # Warm joint/gill recesses, no gore.
    for x, y in [(45,77),(52,79),(59,81)]:
        r.line([(x,y),(x+2,y+4)],"gill_dark",3)
        r.line([(x,y),(x+1,y+2)],"gill",1)
    # Shell silhouette and broad hand-placed shading clusters.
    r.poly([(29,64),(30,54),(35,44),(42,36),(53,31),(65,30),
            (75,34),(84,42),(89,52),(91,65),(86,75),(73,81),
            (56,82),(40,77),(31,71)],"shell_dark","ink")
    r.poly([(31,59),(36,46),(44,38),(55,33),(65,32),(76,37),
            (84,45),(87,55),(80,65),(65,72),(45,71),(33,65)],"shell")
    r.poly([(36,49),(45,39),(56,35),(65,34),(73,38),(67,44),
            (53,46),(46,55),(35,59)],"shell_light")
    r.poly([(43,43),(54,37),(62,36),(64,38),(53,40),(47,46)],"shell_high")
    r.line([(48,40),(55,37),(60,37)],"shell_glint",1)
    r.poly([(32,65),(42,71),(57,76),(73,74),(86,65),(87,72),
            (73,78),(56,79),(41,75),(33,70)],"shell_low")
    # Three separate overlapping shell plates, with deliberate pixel staircases.
    r.line([(43,37),(46,46),(43,56),(46,66),(44,73)],"crease",2)
    r.line([(45,39),(48,46),(46,55)],"shell_high",1)
    r.line([(62,32),(65,42),(62,54),(66,65),(63,76)],"crease",2)
    r.line([(65,34),(68,42),(65,52),(68,61)],"shell_high",1)
    r.line([(79,39),(80,48),(77,56),(81,65),(77,75)],"crease",2)
    r.line([(81,43),(83,49),(80,56)],"shell_light",1)
    # Small bony shoulder/back ridges; same anatomy in all poses.
    r.poly([(39,38),(40,31),(45,29),(48,34),(47,40)],"bone_dark","ink")
    r.poly([(41,34),(44,31),(46,35),(45,37)],"bone")
    r.poly([(57,31),(59,24),(64,22),(67,28),(65,34)],"bone_mid","ink")
    r.poly([(60,28),(64,24),(65,28),(63,31)],"bone_light")
    r.poly([(75,37),(76,31),(80,29),(84,35),(83,42)],"bone_dark","ink")
    r.poly([(78,34),(80,31),(82,35),(81,37)],"bone")
    # Near hind limb and its shoulder plate.
    r.leg((46,75),(43,86),(45,99),False,p["rear"],p["lift"] if p["rear"] > 0 else 0)
    r.poly([(38,71),(48,68),(56,75),(54,82),(45,85),(38,79)],"shell_dark","ink")
    r.poly([(40,73),(48,71),(52,76),(50,79),(41,77)],"shell_light")
    r.line([(42,74),(48,73)],"shell_high",1)
    # Neck and head are independently posed during anticipation/recovery.
    r.poly([(76,57),(87,53),(95,59),(99,70),(96,85),(88,90),
            (76,84),(71,72)],"body_dark","ink",True)
    r.poly([(83,61),(93,64),(95,76),(89,85),(81,81),(79,70)],"body",head=True)
    # Large ivory forehead/ram shield, slanted forward rather than a helmet.
    r.poly([(83,47),(92,48),(99,55),(101,64),(97,70),(87,68),
            (79,61),(77,54)],"bone_dark","ink",True)
    r.poly([(82,49),(90,49),(96,55),(96,61),(89,60),(81,56)],"bone",head=True)
    r.poly([(83,50),(89,50),(92,52),(90,54),(83,53)],"bone_light",head=True)
    r.poly([(80,59),(88,63),(97,63),(95,67),(87,65)],"bone_mid",head=True)
    # Two stubby forward ramming prongs, not threatening gore-like tusks.
    r.poly([(96,56),(102,50),(107,47),(106,57),(101,64),(96,65)],"bone_mid","ink",True)
    r.poly([(100,57),(105,50),(104,56),(101,60)],"bone_light",head=True)
    # Eye socket and expressive restrained brow.
    r.poly([(88,65),(97,65),(101,70),(100,75),(92,77),(87,72)],"ink",head=True)
    r.poly([(91,68),(97,67),(99,70),(98,73),(92,74),(90,71)],"eye_dark",head=True)
    if not p["blink"]:
        r.poly([(92,68),(97,68),(98,70),(97,73),(93,73),(91,71)],"eye",head=True)
        r.line([(94,69),(95,72)],"ink",2,True)
        r.dot(92,69,"eye_light",True)
        if p["tense"]:
            r.line([(88,66),(97,69),(100,68)],"bone_dark",2,True)
    else:
        r.line([(91,71),(97,72)],"crease",2,True)
    # Rounded cheek plate and mouth, no large teeth.
    r.poly([(92,78),(100,77),(103,82),(100,87),(92,87),(87,83)],"shell_dark","ink",True)
    r.poly([(94,79),(99,79),(101,82),(97,84),(91,82)],"shell_light",head=True)
    r.line([(96,85),(101,84)],"crease",1,True)
    # Two tiny chin tendrils are the second (and final) eldritch accent.
    r.line([(97,87),(99,91),(104,91),(106,87)],"ink",4,True)
    r.line([(97,87),(100,90),(103,90),(104,88)],"eldritch_dark",2,True)
    r.line([(89,86),(88,90),(92,92),(94,90)],"ink",4,True)
    r.line([(89,86),(90,90),(92,90)],"body_light",2,True)
    # The closest braced forelimb completes the strong charging silhouette.
    r.leg((79,78),(87,87),(91,99),False,p["front"],p["lift"] if p["front"] > 0 else 0)
    r.poly([(73,71),(82,69),(88,76),(86,83),(78,87),(71,81)],"shell_dark","ink")
    r.poly([(75,73),(81,72),(85,76),(82,80),(75,79)],"shell_light")
    r.line([(76,74),(80,74)],"shell_high",1)
    # One muted two-pixel shell pore, deliberately avoiding runes or glowing eyes.
    r.dot(56,58,"eldritch_dark")
    r.dot(57,58,"eldritch")
    # Death never fades the alpha: runtime owns fading and cleanup.
    if p["death"] >= .75:
        r.line([(51,66),(55,71),(60,72)],"crease",1)
    return r.image


def save_sheet(frames: list[Image.Image], path: Path, scale=1):
    size = SIZE * scale
    sheet = Image.new("RGBA", (size * len(frames), size))
    for index, frame in enumerate(frames):
        if scale != 1:
            frame = frame.resize((size, size), Image.Resampling.NEAREST)
        sheet.paste(frame, (index * size, 0))
    sheet.save(path, optimize=True)


def save_sprite_frames():
    total=sum(spec["count"] for spec in SPECS.values())
    lines=[f'[gd_resource type="SpriteFrames" load_steps={1+len(SPECS)+total} format=3]',""]
    for action in SPECS:
        lines.append(f'[ext_resource type="Texture2D" path="res://assets/sprites/enemies/combat/elite_rusher/{PREFIX}_{action}.png" id="tex_{action}"]')
    lines.append("")
    for action,spec in SPECS.items():
        for index in range(spec["count"]):
            lines.extend([f'[sub_resource type="AtlasTexture" id="frame_{action}_{index}"]',
                          f'atlas = ExtResource("tex_{action}")',
                          f'region = Rect2({index*SIZE}, 0, {SIZE}, {SIZE})',""])
    lines.extend(["[resource]","animations = [{"])
    for action_index,(action,spec) in enumerate(SPECS.items()):
        if action_index:
            lines.append("}, {")
        lines.append('"frames": [{')
        for index,duration in enumerate(spec["durations"]):
            if index:
                lines.append("}, {")
            lines.extend([f'"duration": {duration/100:.3f},',
                          f'"texture": SubResource("frame_{action}_{index}")'])
        lines.extend(['}],',f'"loop": {str(spec["loop"]).lower()},',
                      f'"name": &"{action}",','"speed": 10.0'])
    lines.extend(["}]",""])
    (SOURCE/"elite_rusher_sprite_frames.tres").write_text("\n".join(lines),encoding="utf-8")


def make_telegraph():
    # A geometry asset, deliberately separate from the original character art.
    image = Image.new("RGBA", (304, 64))
    draw = ImageDraw.Draw(image)
    draw.rectangle((0, 0, 303, 63), fill=(255, 59, 48, 77))
    image.save(TELEGRAPH / "elite_rusher_dash_path.png", optimize=True)
    return image


def font(size: int):
    path = Path("C:/Windows/Fonts/consola.ttf")
    return ImageFont.truetype(str(path), size) if path.exists() else ImageFont.load_default()


def background(size):
    canvas = Image.new("RGB", size, "#202B2D")
    draw = ImageDraw.Draw(canvas)
    for y in range(0,size[1],16):
        for x in range(0,size[0],16):
            if (x//16+y//16)%2:
                draw.rectangle((x,y,x+15,y+15),fill="#273335")
    return canvas


def make_previews(frames, telegraph):
    board = Image.new("RGB", (1120, 880), "#182326")
    d = ImageDraw.Draw(board)
    d.text((28,22), "RIFT RUSHER  /  ORIGINAL PIXEL ART",font=font(27),fill="#E7DDB5")
    d.text((30,61),"Armored charger  |  subtle eldritch details  |  RGBA PNG",font=font(16),fill="#A9BBAA")
    portrait = frames["idle"][0].resize((384,384),Image.Resampling.NEAREST)
    board.paste(portrait,(14,76),portrait)
    d.text((405,104),"NATIVE-SIZE COMPARISON",font=font(19),fill="#E7DDB5")
    assets=[("HUNTER", ROOT/"assets/sprites/player/combat/void_hunter_idle_right.png"),
            ("NORMAL", ROOT/"assets/sprites/enemies/combat/enemy_gloom_mite_idle.png")]
    x=420
    for label,path in assets:
        with Image.open(path) as source:
            source=source.convert("RGBA")
            cropped=source.crop(source.getbbox())
            board.paste(cropped,(x,245-cropped.height),cropped)
            d.text((x-8,260),label,font=font(14),fill="#A9BBAA")
        x+=120
    character=frames["idle"][0]
    cropped=character.crop(character.getbbox())
    board.paste(cropped,(x,245-cropped.height),cropped)
    d.text((x-8,260),"ELITE",font=font(14),fill="#E7DDB5")
    d.text((407,310),"DASH TELEGRAPH  /  30% OPACITY",font=font(18),fill="#E7DDB5")
    board.paste(telegraph,(410,346),telegraph)
    d.text((407,425),"Red path stays separate from the sprite.",font=font(15),fill="#A9BBAA")
    labels=[("IDLE","idle",0),("MOVE","move",2),("WINDUP","windup",2),
            ("DASH","dash",0),("RECOVER","recover",0),("DEATH","death",4)]
    for i,(label,action,index) in enumerate(labels):
        x=28+i*180
        d.rectangle((x,490,x+168,683),fill="#263438")
        tile=frames[action][index].resize((192,192),Image.Resampling.NEAREST)
        board.paste(tile,(x-12,494),tile)
        d.text((x+9,695),label,font=font(17),fill="#D6D8BE")
    d.text((30,750),"6 animation sheets  /  23 original poses  /  128px native frames",font=font(20),fill="#E7DDB5")
    d.text((30,791),"Shared palette. Hard alpha. Fixed anchor. Left facing uses flip_h.",font=font(16),fill="#A9BBAA")
    d.text((30,824),"Artwork only - gameplay integration pending.",font=font(16),fill="#A9BBAA")
    board.save(PREVIEW/"elite_rusher_preview.png")

    contact=Image.new("RGB",(6*192+150,6*215+30),"#202C30")
    dc=ImageDraw.Draw(contact)
    for row,(action,seq) in enumerate(frames.items()):
        dc.text((16,40+row*215),action.upper(),font=font(19),fill="#E7DDB5")
        for col,frame in enumerate(seq):
            enlarged=frame.resize((192,192),Image.Resampling.NEAREST)
            contact.paste(enlarged,(140+col*192,10+row*215),enlarged)
            dc.text((215+col*192,195+row*215),str(col+1),font=font(14),fill="#A9BBAA")
    contact.save(PREVIEW/"elite_rusher_contact_sheet.png")

    sequence=[]; durations=[]
    order=[("idle",2),("move",3),("windup",1),("dash",2),("recover",1),("idle",1),("death",1)]
    for action,repeats in order:
        for _ in range(repeats):
            for index,frame in enumerate(frames[action]):
                canvas=background((384,384))
                large=frame.resize((384,384),Image.Resampling.NEAREST)
                canvas.paste(large,(0,0),large)
                ImageDraw.Draw(canvas).text((14,14),action.upper(),font=font(18),fill="#E7DDB5")
                sequence.append(canvas)
                durations.append(SPECS[action]["durations"][index])
    sequence[0].save(PREVIEW/"elite_rusher_animation.gif",save_all=True,
                     append_images=sequence[1:],duration=durations,loop=0,disposal=2)


def validate(frames):
    checks=[]; colors=set()
    for action,sequence in frames.items():
        assert len(sequence)==SPECS[action]["count"]
        seen=set()
        for i,frame in enumerate(sequence):
            alpha={value for _,value in frame.getchannel("A").getcolors(SIZE*SIZE)}
            assert alpha == {0,255},(action,i,alpha)
            bbox=frame.getbbox()
            assert bbox and bbox[0]>0 and bbox[1]>0 and bbox[2]<SIZE and bbox[3]<SIZE
            visible={pixel for _,pixel in frame.getcolors(SIZE*SIZE) if pixel[3]}
            colors.update(visible)
            seen.add(frame.tobytes())
            checks.append(dict(action=action,frame=i,bbox=list(bbox),visible_colors=len(visible)))
        assert len(seen)==len(sequence),(action,"duplicate frames")
    assert len(colors)<=32,len(colors)
    return {"status":"passed","native_frame_size":[128,128],"total_frames":sum(map(len,frames.values())),
            "shared_palette_colors":len(colors),"binary_alpha":True,"checks":checks}


def main():
    for folder in (SOURCE,COMBAT,PREVIEW,TELEGRAPH):
        folder.mkdir(parents=True,exist_ok=True)
    frames={action:[draw_frame(action,index) for index in range(spec["count"])]
            for action,spec in SPECS.items()}
    for action,sequence in frames.items():
        name=f"{PREFIX}_{action}.png"
        save_sheet(sequence,COMBAT/name)
        save_sheet(sequence,SOURCE/name,scale=2)
    frames["idle"][0].resize((256,256),Image.Resampling.NEAREST).save(SOURCE/f"{PREFIX}_reference.png")
    save_sprite_frames()
    telegraph=make_telegraph()
    make_previews(frames,telegraph)
    report=validate(frames)
    (PREVIEW/"validation.json").write_text(json.dumps(report,indent=2)+"\n",encoding="utf-8")
    metadata={"asset_id":PREFIX,"method":"original direct pixel drawing with Pillow; no model/API",
              "source_script":"scripts/tools/build_elite_rusher_assets.py",
              "native_frame_size":[128,128],"master_frame_size":[256,256],
              "native_anchor":[64,84],"native_sprite_offset":[0,-20],
              "outline":P["ink"],"palette":P,"actions":SPECS,
              "telegraph":{"path":"assets/sprites/effects/telegraphs/elite_rusher_dash_path.png",
                           "size":[304,64],"alpha_byte":77,"opacity":0.3,"shape":"rectangle","arrows":False,"center_travel_px":240,"half_width_px":32},
              "integration":"not yet wired to enemy scenes or gameplay"}
    (SOURCE/"asset_manifest.json").write_text(json.dumps(metadata,indent=2)+"\n",encoding="utf-8")
    print(json.dumps({"validation":report["status"],"frames":report["total_frames"],
                      "colors":report["shared_palette_colors"],"preview":str(PREVIEW/"elite_rusher_preview.png")}))


if __name__=="__main__":
    main()
