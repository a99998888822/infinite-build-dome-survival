"""Original 32x32 pixel icons for the approved range/area relic designs.

Follows capital_relics.py's hand-authored, opaque-palette pixel art workflow.
Rebuilds production icons and the review overview; does not edit the relic catalog.
Run from any directory: python scripts/tools/source_art/range_relics.py
"""

from pathlib import Path
import math
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[3]
OUTPUT = ROOT / 'artifacts/reviews/ui/range_relics'
INK = '#29283b'
BRASS_D, BRASS, BRASS_L, BRASS_H = '#865b3a', '#c18a4d', '#ebbc70', '#ffe4a0'
IRON_D, IRON, IRON_L, IRON_H = '#343c50', '#52677b', '#8cabb5', '#d5e8dd'
TEAL_D, TEAL, TEAL_L, TEAL_H = '#2e5264', '#4b8995', '#84c8c7', '#d0f3df'
PURPLE_D, PURPLE, PURPLE_L, PURPLE_H = '#423858', '#785a94', '#b08dbd', '#e9cfdf'
RED_D, RED, RED_L, RED_H = '#65344a', '#ad515c', '#e68b79', '#ffe2ba'
CLEAR = (0, 0, 0, 0)


def canvas():
    image = Image.new('RGBA', (32, 32), CLEAR)
    return image, ImageDraw.Draw(image)


def telescope():
    im, d = canvas()
    # A broad, stepped brass barrel faces the upper right. Leather eyepiece below.
    d.polygon([(3,23),(9,17),(11,18),(20,8),(19,6),(23,2),(28,4),
               (30,9),(26,13),(24,12),(15,22),(15,24),(9,30),(4,28)], fill=INK)
    d.polygon([(10,18),(20,8),(25,12),(15,22)], fill=BRASS)
    d.polygon([(10,18),(20,8),(22,9),(12,20)], fill=BRASS_L)
    d.line([(12,18),(20,10)], fill=BRASS_H)
    d.line([(15,21),(23,12)], fill=BRASS_D, width=2)
    # Two brass collars interrupt the long cylinder and clarify its volume.
    d.line([(14,12),(21,18)], fill=INK, width=3)
    d.line([(15,12),(21,17)], fill=BRASS_L, width=2)
    d.point((16,12), fill=BRASS_H)
    d.polygon([(4,23),(9,18),(14,22),(14,24),(9,28),(5,27)], fill='#62424a')
    d.line([(5,23),(9,19),(11,20)], fill='#a77860')
    d.line([(7,25),(11,21)], fill='#3f3345')
    d.line([(9,27),(13,23)], fill=BRASS_D)
    d.polygon([(2,24),(5,21),(9,25),(9,28),(6,30),(3,28)], fill=INK)
    d.line([(3,24),(5,23),(8,26)], fill=BRASS_L, width=2)
    d.line([(4,27),(6,28)], fill=BRASS)
    # The visible tilted objective lens is the single bright cyan accent.
    d.polygon([(22,3),(26,3),(29,6),(29,9),(26,12),(22,11),(19,8),(19,6)], fill=INK)
    d.polygon([(22,4),(25,4),(28,7),(28,9),(26,10),(23,10),(20,7)], fill=BRASS_L)
    d.polygon([(23,5),(25,5),(27,7),(27,9),(25,9),(22,7)], fill=TEAL_D)
    d.line([(23,5),(25,5),(26,6)], fill=TEAL_L)
    d.point((24,5), fill=TEAL_H)
    d.point((21,5), fill=BRASS_H)
    d.point((27,10), fill=BRASS_D)
    return im


def cracked_bell():
    im, d = canvas()
    # The loop, flared skirt and hanging clapper remain readable at native size.
    d.ellipse((11,2,19,10), fill=INK)
    d.ellipse((13,3,17,8), fill=BRASS)
    d.rectangle((14,5,16,7), fill=CLEAR)
    d.point((13,4), fill=BRASS_H)
    d.polygon([(12,8),(18,8),(22,12),(22,18),(26,23),(26,26),
               (5,26),(5,23),(9,18),(9,12)], fill=INK)
    d.polygon([(12,10),(17,10),(20,13),(20,18),(23,22),(8,22),
               (11,17),(11,13)], fill=BRASS)
    d.polygon([(12,11),(15,10),(15,19),(11,22),(8,22),(11,17)], fill=BRASS_L)
    d.line([(12,12),(12,16)], fill=BRASS_H)
    d.polygon([(18,11),(20,13),(20,18),(23,22),(18,21)], fill=BRASS_D)
    d.rectangle((7,23,24,24), fill=BRASS_L)
    d.line([(8,23),(14,23)], fill=BRASS_H)
    d.line([(7,25),(23,25)], fill=BRASS_D)
    d.polygon([(13,26),(18,26),(18,28),(16,30),(13,29)], fill=INK)
    d.rectangle((14,27,16,28), fill=BRASS)
    d.point((14,27), fill=BRASS_H)
    # A dark zigzag crack cuts right through the rim.
    d.line([(17,11),(16,15),(19,17),(17,20),(20,23),(19,25)], fill=INK)
    d.point((20,23), fill=CLEAR)
    d.line([(5,12),(3,14),(3,18),(5,20)], fill=IRON)
    d.line([(26,11),(28,13),(29,16),(28,20)], fill=BRASS_D)
    d.line([(27,13),(28,16)], fill=BRASS_L)
    return im


def long_focus_lens():
    im, d = canvas()
    # A narrow horizontal iron optic, distinct from the diagonal brass telescope.
    d.polygon([(2,13),(6,11),(10,11),(12,9),(23,9),(25,7),(28,8),
               (30,12),(30,18),(28,22),(25,23),(23,21),(12,21),
               (10,19),(6,19),(2,17)], fill=INK)
    d.rectangle((7,12,22,18), fill=IRON)
    d.rectangle((10,12,23,14), fill=IRON_L)
    d.line([(11,11),(22,11)], fill=IRON_H)
    d.rectangle((10,16,23,19), fill=IRON_D)
    d.rectangle((3,14,7,16), fill='#635262')
    d.point((3,14), fill=IRON_L)
    d.rectangle((9,11,10,19), fill=INK)
    d.rectangle((11,11,12,19), fill=BRASS_D)
    d.line([(11,11),(11,13)], fill=BRASS_L)
    # Turret dial and underslung mounting shoe.
    d.rectangle((15,6,20,10), fill=INK)
    d.rectangle((16,6,19,8), fill=BRASS)
    d.line([(16,6),(18,6)], fill=BRASS_H)
    d.polygon([(15,21),(20,21),(21,24),(13,24)], fill=INK)
    d.line([(15,22),(19,22)], fill=IRON)
    # Slim red objective with a bright top-left glint and deep lower-right glass.
    d.polygon([(25,8),(27,9),(29,13),(29,18),(27,21),(25,22),
               (23,19),(23,12)], fill=IRON_L)
    d.polygon([(25,10),(27,12),(28,14),(28,17),(26,20),(25,20),
               (24,17),(24,13)], fill=INK)
    d.polygon([(25,12),(26,12),(27,15),(27,17),(26,19),(25,17)], fill=RED)
    d.line([(25,12),(26,14)], fill=RED_H)
    d.line([(26,17),(26,19)], fill=RED_D)
    return im


def diffusion_nozzle():
    im, d = canvas()
    # Short rear coupling flares into a wide, scorched mouth in three-quarter view.
    d.polygon([(3,10),(7,6),(11,6),(16,10),(22,7),(27,10),(30,16),
               (29,23),(24,28),(19,29),(13,24),(11,18),(7,18),(3,14)], fill=INK)
    d.polygon([(4,10),(7,8),(10,8),(16,13),(12,17),(8,16),(4,13)], fill=IRON)
    d.line([(5,10),(8,9),(13,12)], fill=IRON_L)
    d.line([(7,8),(6,11),(10,16)], fill=BRASS_D, width=2)
    d.point((7,8), fill=BRASS_L)
    d.polygon([(11,10),(17,11),(19,23),(15,24),(12,18)], fill=BRASS_D)
    d.line([(12,11),(16,13),(17,17)], fill=BRASS_L)
    d.polygon([(21,8),(26,11),(29,16),(28,22),(24,26),(19,27),
               (15,23),(13,17),(16,11)], fill=IRON)
    d.line([(20,9),(17,12),(15,17),(16,21)], fill=IRON_H)
    d.line([(24,26),(28,22),(29,17)], fill=IRON_D)
    d.polygon([(21,11),(25,13),(27,17),(26,21),(22,24),(19,24),
               (17,21),(16,17),(18,13)], fill=INK)
    d.polygon([(21,13),(24,14),(25,17),(24,20),(22,22),(19,21),
               (18,17),(19,15)], fill='#512f37')
    # A hollow, dark bore surrounded by a few heated vanes, not a filled fireball.
    d.line([(19,15),(18,17),(20,21)], fill=RED)
    d.line([(22,13),(24,15),(25,18)], fill=BRASS_D)
    d.line([(23,21),(24,19)], fill='#e89650', width=2)
    d.rectangle((20,16,22,18), fill=INK)
    d.point((19,15), fill=RED_L)
    d.point((23,21), fill=BRASS_H)
    d.rectangle((25,10,26,11), fill=BRASS_L)
    d.point((17,24), fill=BRASS)
    return im


def range_tripod():
    im, d = canvas()
    # Three separate feet and open negative spaces distinguish it from a wand.
    for points in [[(14,17),(5,28)],[(17,17),(26,28)],[(16,17),(16,29)]]:
        d.line(points, fill=INK, width=4)
    d.line([(14,18),(6,27)], fill=IRON_L, width=2)
    d.line([(18,19),(25,27)], fill=IRON, width=2)
    d.line([(16,19),(16,27)], fill=BRASS_D, width=2)
    d.line([(8,24),(23,24)], fill=IRON_D)
    for box in [(3,27,8,29),(14,28,18,30),(24,27,29,29)]:
        d.rectangle(box, fill=INK)
        d.line([(box[0]+1,box[1]),(box[2]-1,box[1])], fill=IRON_L)
    # Brass collar under an angular teal survey crystal.
    d.rectangle((11,14,21,18), fill=INK)
    d.rectangle((12,15,20,16), fill=BRASS)
    d.line([(12,15),(16,15)], fill=BRASS_H)
    d.polygon([(15,2),(20,5),(22,10),(19,15),(13,15),(10,10),(11,5)], fill=INK)
    d.polygon([(15,4),(19,6),(20,10),(18,13),(13,13),(12,10),(13,6)], fill=TEAL)
    d.polygon([(15,4),(15,10),(12,10),(13,6)], fill=TEAL_L)
    d.polygon([(15,10),(19,7),(20,10),(18,13),(15,13)], fill=TEAL_D)
    d.line([(15,4),(13,6)], fill=TEAL_H)
    d.point((14,6), fill=TEAL_H)
    d.rectangle((9,8,11,11), fill=BRASS_D)
    d.rectangle((21,8,23,11), fill=BRASS_D)
    d.point((10,8), fill=BRASS_L)
    return im


def aftershock_hourglass():
    im, d = canvas()
    # Upper and lower chambers pinch together, with heavy iron posts.
    d.polygon([(8,5),(23,5),(22,10),(18,15),(18,17),(22,22),
               (23,26),(8,26),(9,22),(13,17),(13,15),(9,10)], fill=INK)
    d.polygon([(10,7),(21,7),(20,10),(16,14),(15,14),(11,10)], fill=TEAL_D)
    d.line([(10,7),(11,10),(14,13)], fill=IRON_L)
    d.polygon([(12,9),(20,9),(17,12),(15,12)], fill=BRASS_D)
    d.line([(12,9),(18,9)], fill=BRASS_L)
    d.polygon([(15,17),(17,18),(21,23),(21,24),(10,24),(11,21)], fill='#4b4556')
    d.polygon([(15,21),(17,21),(20,24),(11,24)], fill=BRASS)
    d.line([(15,21),(16,20),(18,22)], fill=BRASS_H)
    d.line([(16,15),(16,18)], fill=BRASS_L)
    d.point((16,19), fill=BRASS_H)
    d.line([(20,21),(18,18)], fill=IRON_L)
    for x in [6,24]:
        d.rectangle((x,5,x+2,26), fill=INK)
        d.line([(x,7),(x,23)], fill=IRON)
        d.point((x,8), fill=IRON_H)
    for box in [(5,3,27,6),(5,25,27,28)]:
        d.rectangle(box, fill=INK)
        d.rectangle((box[0]+1,box[1]+1,box[2]-1,box[1]+2), fill=IRON)
        d.line([(box[0]+2,box[1]+1),(box[2]-5,box[1]+1)], fill=IRON_L)
    # Two quiet broken arcs are the aftershock, not a permanent icon backdrop.
    d.line([(2,22),(2,26),(5,29),(10,30)], fill=TEAL)
    d.line([(29,22),(29,26),(27,29),(22,30)], fill=TEAL_D)
    d.point((2,23), fill=TEAL_L)
    return im


def golden_rangefinder():
    im, d = canvas()
    # A dividers/compass silhouette with two tapering gold legs and a suspended coin.
    d.line([(14,10),(5,27)], fill=INK, width=5)
    d.line([(17,10),(27,27)], fill=INK, width=5)
    d.line([(14,12),(6,25)], fill=BRASS, width=3)
    d.line([(14,12),(7,23)], fill=BRASS_H)
    d.line([(18,12),(26,25)], fill=BRASS_D, width=3)
    d.line([(18,12),(25,24)], fill=BRASS_L)
    d.line([(5,26),(3,30)], fill=IRON_L)
    d.line([(27,26),(28,30)], fill=IRON)
    # The curved screw bridge reinforces the measuring-instrument identity.
    d.line([(8,20),(10,18),(21,18),(24,21)], fill=INK, width=3)
    d.line([(9,19),(11,18),(20,18),(23,20)], fill=BRASS)
    d.rectangle((22,17,25,20), fill=INK)
    d.line([(23,18),(24,18)], fill=BRASS_H)
    d.line([(16,9),(16,17)], fill=BRASS_D)
    d.point((16,13), fill=BRASS_H)
    # Gold coin hangs freely in the open gap.
    d.polygon([(14,16),(18,16),(21,19),(21,23),(18,26),(14,26),(11,23),(11,19)], fill=INK)
    d.polygon([(14,17),(18,17),(20,19),(20,23),(18,25),(14,25),(12,23),(12,19)], fill=BRASS)
    d.line([(14,18),(17,18),(19,20)], fill=BRASS_H)
    d.line([(13,20),(13,23),(16,24)], fill=BRASS_L)
    d.rectangle((15,20,17,22), fill=BRASS_D)
    d.line([(16,20),(16,22)], fill=INK)
    # Small green jewel at the hinge, with a broad brass socket.
    d.polygon([(13,2),(18,2),(21,5),(20,9),(17,12),(13,11),(10,7),(10,5)], fill=INK)
    d.polygon([(13,3),(17,3),(19,5),(19,8),(16,10),(13,9),(12,6)], fill=BRASS_L)
    d.polygon([(14,4),(16,4),(18,6),(16,8),(14,8),(13,6)], fill='#376759')
    d.line([(14,4),(13,6)], fill='#a1d5a5')
    d.point((14,5), fill=TEAL_H)
    return im


def abyssal_echo_shell():
    im, d = canvas()
    # Large stepped whorl and a separate pear-shaped opening; no generic gem silhouette.
    d.polygon([(13,2),(19,2),(23,5),(26,10),(27,15),(25,19),
               (29,22),(28,27),(24,30),(18,30),(14,27),(11,27),
               (7,24),(4,20),(3,15),(5,10),(9,8),(10,4)], fill=INK)
    d.polygon([(13,4),(18,4),(21,6),(24,11),(24,16),(21,20),
               (17,24),(12,25),(8,22),(5,18),(5,14),(8,11),(11,10),(11,6)], fill=TEAL_D)
    d.polygon([(13,4),(17,4),(21,7),(22,11),(20,15),(16,18),
               (11,19),(8,17),(8,13),(11,11)], fill=TEAL)
    d.line([(13,5),(17,5),(20,8),(20,11),(17,14),(13,14),(11,12)], fill=TEAL_L, width=2)
    d.line([(13,7),(16,7),(18,9),(17,11),(14,11)], fill=INK)
    d.point((15,9), fill=TEAL_L)
    d.line([(8,12),(6,15),(7,19),(10,22),(14,23)], fill=TEAL_L)
    d.line([(6,15),(6,17)], fill=TEAL_H)
    # Lip catches pale blue light, while the interior remains deep indigo.
    d.polygon([(20,16),(24,17),(28,21),(27,26),(23,29),(18,28),(15,25),(16,20)], fill=INK)
    d.polygon([(20,18),(23,18),(26,21),(26,25),(23,27),(19,27),(17,24),(18,21)], fill=TEAL_L)
    d.polygon([(21,19),(24,21),(24,24),(22,26),(19,25),(19,22)], fill='#253e60')
    d.line([(21,21),(22,22),(22,24)], fill='#5c97cf')
    d.point((21,22), fill='#badfee')
    d.line([(18,23),(18,25),(20,26)], fill=TEAL_H)
    # Two dark seaweed curls hang from the left edge of the shell.
    d.line([(8,22),(5,23),(5,26),(2,28)], fill=INK, width=2)
    d.line([(10,25),(8,28),(10,29)], fill='#394d4c', width=2)
    d.point((4,26), fill='#506b61')
    return im


def folded_star_chart():
    im, d = canvas()
    # Three visible folded planes and a torn edge, rather than another book icon.
    d.polygon([(3,6),(11,3),(20,6),(28,3),(29,23),(21,28),(12,25),
               (4,29),(2,26)], fill=INK)
    d.polygon([(4,7),(10,5),(12,24),(5,27),(4,25)], fill='#b1957b')
    d.polygon([(11,5),(19,8),(21,26),(13,24)], fill='#e0c8a0')
    d.polygon([(20,8),(27,5),(27,22),(22,26)], fill='#8e7a70')
    d.line([(4,7),(10,5),(18,8)], fill='#fff0c6')
    d.line([(20,8),(27,5)], fill='#d5c09d')
    d.line([(11,6),(12,13)], fill='#7a5e60')
    d.line([(20,10),(21,22)], fill='#64545e')
    d.line([(5,24),(8,23)], fill='#77615e')
    d.line([(24,22),(26,21)], fill='#584d5a')
    # A violet fault crosses the creases and swallows part of the constellation.
    d.polygon([(17,8),(19,12),(17,15),(21,18),(18,21),(17,25),
               (14,22),(16,18),(13,15),(16,12)], fill=PURPLE_D)
    d.line([(17,10),(18,12),(15,15),(18,18),(16,21),(17,23)], fill=PURPLE)
    d.line([(17,11),(17,12),(15,15)], fill=PURPLE_L)
    d.point((18,18), fill=PURPLE_H)
    # Sparse star points connected across the folded surfaces.
    d.line([(6,11),(9,15),(7,20)], fill='#665776')
    d.line([(9,15),(14,11)], fill=PURPLE)
    d.line([(21,13),(24,10),(25,18),(22,21)], fill='#514963')
    for x,y in [(6,11),(9,15),(7,20),(14,11),(24,10),(25,18),(22,21)]:
        d.point((x,y), fill=PURPLE_H)
    d.line([(24,9),(24,11)], fill=TEAL_H)
    d.line([(23,10),(25,10)], fill=TEAL_H)
    # A small ragged notch interrupts the lower silhouette.
    d.polygon([(8,26),(10,25),(10,27)], fill=CLEAR)
    return im


def orbital_points(rx, ry, angle, start=0, end=math.tau, steps=64):
    points=[]
    for i in range(steps+1):
        t=start+(end-start)*i/steps
        x,y=rx*math.cos(t),ry*math.sin(t)
        point=(round(16+x*math.cos(angle)-y*math.sin(angle)),
               round(15+x*math.sin(angle)+y*math.cos(angle)))
        if not points or point != points[-1]: points.append(point)
    return points


def horizon_orrery():
    im, d = canvas()
    # Small pedestal and three inclined brass rings surround an opaque void star.
    d.polygon([(14,22),(19,22),(20,26),(24,28),(24,30),(8,30),(8,28),(13,26)], fill=INK)
    d.rectangle((15,23,18,26), fill=BRASS_D)
    d.line([(14,27),(19,27),(22,29),(10,29)], fill=BRASS)
    d.line([(12,28),(17,28)], fill=BRASS_H)
    rings=[(12,6,-0.42),(7,12,-0.40),(11,7,0.67)]
    for rx,ry,angle in rings:
        points=orbital_points(rx,ry,angle)
        d.line(points,fill=INK,width=3)
        d.line(points,fill=BRASS_D)
    # A faceted black star, not a bright white orb: warm light is kept on the rims.
    d.polygon([(15,6),(19,9),(22,13),(22,18),(18,22),(14,22),(10,18),(9,13),(11,9)],fill=INK)
    d.polygon([(14,9),(18,9),(20,12),(20,17),(17,20),(14,20),(11,17),(11,13)],fill='#403b50')
    d.polygon([(15,11),(17,12),(18,15),(16,18),(14,17),(13,14)],fill='#171e2c')
    d.line([(12,12),(12,16),(14,18)],fill=PURPLE)
    d.point((13,11),fill=PURPLE_L)
    # Front arcs deliberately overlap the core, explaining the orbital structure.
    for rx,ry,angle in rings:
        points=orbital_points(rx,ry,angle,0.10,math.pi-0.12,30)
        d.line(points,fill=INK,width=3)
        d.line(points,fill=BRASS_L)
        d.line(points[4:10],fill=BRASS_H)
    # An open tip and a single four-pixel glint make the orange-tier item special.
    d.line([(25,6),(28,5)],fill=BRASS)
    d.line([(27,3),(27,7)],fill=BRASS_H)
    d.line([(25,5),(29,5)],fill=BRASS_H)
    d.point((27,5),fill='#fff2d5')
    return im


ENTRIES = [
    {'id':'relic_old_brass_telescope','name':'旧铜望远镜','rarity':'common','factory':telescope,
     'effect':'攻击距离 +15，远程伤害 +1。','brief':'短黄铜望远镜、棕色握套、青色镜片。'},
    {'id':'relic_cracked_bronze_bell','name':'裂纹铜铃','rarity':'common','factory':cracked_bell,
     'effect':'伤害范围 +15，元素伤害 +1。','brief':'裂纹铜铃、外扩的铃口、短弧回声。'},
    {'id':'relic_long_focus_eyepiece','name':'长焦目镜','rarity':'uncommon','factory':long_focus_lens,
     'effect':'攻击距离 +35，远程伤害 +3，攻击速度 −8。','brief':'细长黑铁镜筒、红色镜片、黄铜旋钮。'},
    {'id':'relic_diffusion_nozzle','name':'扩散喷口','rarity':'uncommon','factory':diffusion_nozzle,
     'effect':'伤害范围 +30，伤害加成 +15，攻击速度 −6。','brief':'张开的短金属喷口、烧黑内壁、橙红余烬。'},
    {'id':'relic_range_tripod','name':'定距脚架','rarity':'rare','factory':range_tripod,
     'effect':'攻击速度 +12；连续静止1秒后，额外攻击距离 +40、伤害加成 +20；移动立即取消额外加成。',
     'brief':'三条撑脚、金属固定环、青色测距晶体。'},
    {'id':'relic_aftershock_hourglass','name':'余震沙漏','rarity':'rare','factory':aftershock_hourglass,
     'effect':'伤害范围 +20，伤害加成 +12；获得后每完成一波，伤害范围再 +2。',
     'brief':'铁灰沙漏、琥珀沙粒、底部断续回声弧。'},
    {'id':'relic_golden_rangefinder','name':'黄金测距仪','rarity':'epic','factory':golden_rangefinder,
     'effect':'每满100本金：攻击距离 +3、伤害加成 +3，随当前本金变化。',
     'brief':'打开的黄铜圆规、悬挂金币、绿色铰链宝石。'},
    {'id':'relic_abyssal_echo_shell','name':'深海回声螺','rarity':'epic','factory':abyssal_echo_shell,
     'effect':'伤害范围 +40，元素伤害 +8，理智值 −15。',
     'brief':'蓝绿螺壳、幽蓝壳口、少量深色海藻。'},
    {'id':'relic_folded_star_chart','name':'折叠星图','rarity':'epic','factory':folded_star_chart,
     'effect':'攻击距离 +25，伤害范围 +25，伤害加成 +20，侵蚀度 +5。',
     'brief':'三折旧星图、紫黑裂缝、跨越折痕的星座。'},
    {'id':'relic_horizon_orrery','name':'地平线星仪','rarity':'mythic','factory':horizon_orrery,
     'effect':'攻击距离 +40，伤害加成 +30；每满10点正攻击距离加成，额外伤害范围 +5。',
     'brief':'三道倾斜黄铜轨道、黑色星核、暖金缺口光。'},
]
RARITIES = {'common':('普通','#b3bdc7'),'uncommon':('优秀','#59eb73'),
            'rare':('稀有','#599eff'),'epic':('史诗','#b86bff'),'mythic':('神话','#ff9438')}


def font(size, bold=False):
    return ImageFont.truetype('C:/Windows/Fonts/msyhbd.ttc' if bold else 'C:/Windows/Fonts/msyh.ttc', size)


def build_review(icons):
    board=Image.new('RGB',(1280,1010),'#111b20')
    d=ImageDraw.Draw(board)
    d.text((28,20),'攻击距离 / 伤害范围 · 遗物图标',font=font(34,True),fill='#f0ead7')
    d.text((28,72),'10 件素材审阅稿   ·   32×32 透明像素图   ·   下方同时展示 32px / 64px 尺寸',font=font(20),fill='#aebec1')
    for i,(entry,icon) in enumerate(zip(ENTRIES,icons)):
        x=16+(i%5)*252;y=123+(i//5)*414
        rank,color=RARITIES[entry['rarity']]
        d.rounded_rectangle((x,y,x+239,y+398),radius=8,fill='#19242b',outline='#35434b',width=1)
        d.line((x+15,y+1,x+225,y+1),fill=color,width=2)
        d.text((x+16,y+16),f'{i+1:02d}  {entry["name"]}',font=font(21,True),fill='#f0ead7')
        d.text((x+16,y+51),rank,font=font(16),fill=color)
        enlarged=icon.resize((192,192),Image.Resampling.NEAREST)
        board.paste(enlarged,(x+24,y+92),enlarged)
        # Native and double scale, placed on a quiet warm surface to check the edge.
        d.rectangle((x+17,y+302,x+222,y+381),fill='#28312f')
        board.paste(icon,(x+41,y+326),icon)
        bigger=icon.resize((64,64),Image.Resampling.NEAREST)
        board.paste(bigger,(x+129,y+310),bigger)
        d.text((x+40,y+384),'32px',font=font(11),fill='#94a8a9')
        d.text((x+143,y+384),'64px',font=font(11),fill='#94a8a9')
    d.text((28,975),'材质原色 · 深色轮廓 · 左上光源；边框仅用于审阅，独立 PNG 不含底板或文字。',font=font(18),fill='#aebec1')
    board.save(OUTPUT/'icons.png')


def build():
    icon_dir=ROOT/'assets/ui/icons/relics'
    icon_dir.mkdir(parents=True,exist_ok=True)
    OUTPUT.mkdir(parents=True,exist_ok=True)
    icons=[]
    for entry in ENTRIES:
        im=entry['factory']()
        assert im.mode=='RGBA' and im.size==(32,32)
        alpha=im.getchannel('A')
        assert set(alpha.tobytes())=={0,255}, entry['id']
        bbox=alpha.getbbox()
        assert bbox and min(bbox[:2])>=1 and max(bbox[2:])<=31, (entry['id'],bbox)
        colors=im.getcolors(maxcolors=32)
        assert colors is not None, entry['id']
        im.save(icon_dir/(entry['id']+'.png'))
        icons.append(im)
        print(entry['id'], 'RGBA 32x32', 'colors',len(colors), 'bounds',bbox)
    build_review(icons)
    # Keep the curated runtime review README; regeneration only replaces images.


if __name__=='__main__':
    build()
