"""Original 32px pixel geometry for three principal-dependent relic candidates.

Follows the existing hand-authored relic icon workflow. No model/API calls.
This script creates review artifacts and reads integration state from the catalog.
"""

from PIL import Image, ImageDraw, ImageFont

INK = '#29283b'
DEEP = '#57404a'
SHADE = '#865b3a'
GOLD = '#c18a4d'
LIGHT = '#ebbc70'
SHINE = '#ffe4a0'
VOID = (0, 0, 0, 0)


def canvas():
    im = Image.new('RGBA', (32, 32), VOID)
    return im, ImageDraw.Draw(im)


def coin_heart():
    im, d = canvas()
    # Two broad heart lobes and a single pointed tip; no anatomical gore.
    d.polygon([(7, 5), (12, 5), (16, 9), (20, 5), (25, 5),
               (29, 9), (29, 15), (27, 19), (16, 29), (4, 18),
               (2, 14), (2, 10)], fill=INK)
    d.polygon([(7, 7), (11, 7), (16, 12), (21, 7), (24, 7),
               (27, 10), (27, 15), (25, 19), (16, 26), (6, 17),
               (4, 13), (4, 10)], fill=GOLD)
    d.polygon([(7, 7), (11, 7), (15, 11), (12, 14), (7, 16),
               (5, 13), (5, 10)], fill=LIGHT)
    d.line([(7, 8), (10, 8), (12, 10)], fill=SHINE, width=1)
    d.line([(5, 11), (5, 13)], fill=SHINE)
    d.polygon([(25, 11), (27, 11), (27, 15), (25, 19),
               (16, 26), (15, 23), (21, 17)], fill=SHADE)
    d.line([(8, 18), (15, 24)], fill=LIGHT)
    d.line([(17, 24), (23, 19)], fill=GOLD)
    # A small crimson core, enclosed by the coin-like plates of the heart.
    d.polygon([(12, 14), (16, 12), (20, 15), (19, 19),
               (16, 23), (12, 19)], fill=DEEP)
    d.polygon([(14, 15), (16, 14), (18, 16), (17, 19),
               (16, 21), (14, 18)], fill='#a4505c')
    d.line([(14, 15), (15, 15), (15, 17)], fill='#e79585')
    # An inset square-holed gold coin dominates the upper-right lobe.
    d.polygon([(20, 6), (24, 6), (27, 9), (27, 13),
               (24, 16), (20, 16), (17, 13), (17, 9)], fill=INK)
    d.polygon([(20, 8), (23, 8), (25, 10), (25, 12),
               (23, 14), (20, 14), (19, 12), (19, 10)], fill=LIGHT)
    d.line([(20, 8), (23, 8), (25, 10)], fill=SHINE)
    d.line([(20, 14), (23, 14), (25, 12)], fill=SHADE)
    d.rectangle((21, 10, 23, 12), fill=SHADE)
    d.rectangle((21, 10, 22, 11), fill=DEEP)
    # Metal seams explain the heart as a made object, not a candy icon.
    d.line([(8, 12), (10, 14), (10, 17), (12, 19)], fill=SHADE)
    d.point((9, 17), fill=SHINE)
    return im


def hoarders_ring():
    im, d = canvas()
    # Open negative space is essential to identifying the ring at 32px.
    d.polygon([(8, 11), (20, 9), (26, 13), (28, 19), (26, 25),
               (21, 29), (14, 29), (8, 25), (5, 19)], fill=INK)
    d.polygon([(9, 13), (20, 11), (24, 14), (26, 19), (24, 24),
               (20, 27), (14, 27), (10, 24), (7, 19)], fill=GOLD)
    d.line([(9, 14), (8, 19), (11, 24), (15, 26), (20, 26)], fill=LIGHT)
    d.line([(24, 15), (25, 19), (23, 23), (20, 25)], fill=SHADE)
    d.polygon([(13, 14), (19, 13), (22, 16), (23, 20), (20, 24),
               (15, 24), (11, 21), (10, 17)], fill=INK)
    d.polygon([(14, 16), (18, 15), (20, 17), (21, 20), (19, 22),
               (15, 22), (13, 20), (12, 18)], fill=VOID)
    d.line([(15, 24), (20, 24), (22, 21)], fill=SHINE)
    # A massive coin signet with a second visible rim behind it.
    d.polygon([(10, 3), (19, 3), (24, 7), (24, 13), (20, 17),
               (10, 17), (5, 13), (5, 7)], fill=INK)
    d.polygon([(9, 6), (19, 5), (22, 8), (22, 13), (19, 15),
               (11, 15), (7, 12), (7, 8)], fill=SHADE)
    d.line([(11, 15), (19, 15), (22, 12)], fill=GOLD)
    d.polygon([(10, 4), (18, 4), (22, 7), (22, 10), (18, 14),
               (10, 14), (6, 11), (6, 7)], fill=LIGHT)
    d.line([(10, 5), (17, 5), (20, 7)], fill=SHINE)
    d.line([(8, 8), (8, 10), (11, 12), (18, 12), (20, 10)], fill=GOLD)
    # Uncanny eye incised into the coin: restrained purple, no external glow.
    d.polygon([(10, 9), (13, 7), (16, 7), (19, 9), (16, 11),
               (13, 11)], fill=DEEP)
    d.line([(12, 9), (17, 9)], fill='#80628e')
    d.line([(14, 8), (14, 10)], fill=SHINE)
    # Hooked gold claws cling to the coin instead of ordinary jewel prongs.
    d.line([(5, 12), (4, 9), (5, 5), (8, 3), (10, 4)], fill=INK, width=3)
    d.line([(5, 11), (5, 8), (7, 5), (9, 4)], fill=GOLD, width=1)
    d.line([(6, 7), (7, 5), (9, 4)], fill=SHINE)
    d.line([(21, 14), (24, 11), (24, 7), (22, 5)], fill=INK, width=3)
    d.line([(21, 14), (23, 11), (23, 8), (22, 6)], fill=GOLD)
    d.point((22, 7), fill=LIGHT)
    d.point((10, 24), fill=SHINE)
    return im


def golden_sarcophagus():
    im, d = canvas()
    # Thick right face gives a coffin volume, distinct from a shield or tablet.
    d.polygon([(12, 2), (20, 2), (27, 9), (23, 28), (20, 30),
               (12, 30), (8, 27), (5, 10)], fill=INK)
    d.polygon([(23, 9), (25, 10), (21, 27), (19, 28),
               (13, 28), (10, 26)], fill=SHADE)
    d.line([(24, 12), (21, 26), (19, 28), (14, 28)], fill=GOLD)
    d.line([(22, 24), (21, 27), (19, 29)], fill=DEEP)
    # The narrow dark/teal lid seam suggests that life is sealed inside.
    d.polygon([(11, 3), (19, 3), (24, 9), (20, 27),
               (11, 27), (6, 10)], fill=DEEP)
    d.line([(11, 4), (18, 4), (21, 7)], fill='#79ada5')
    d.line([(7, 11), (10, 23)], fill='#416767')
    # Hexagonal lid: broad shoulders, flat narrow head and tapered foot.
    d.polygon([(12, 3), (18, 3), (23, 9), (19, 26),
               (12, 26), (7, 10)], fill=GOLD)
    d.line([(12, 4), (17, 4), (21, 8)], fill=SHINE)
    d.line([(11, 5), (8, 10), (12, 24)], fill=LIGHT)
    d.line([(22, 10), (18, 25), (13, 25)], fill=SHADE)
    # Inset dark-gold panel with short, symmetric funerary ornament.
    d.polygon([(13, 6), (17, 6), (20, 10), (17, 23),
               (14, 23), (10, 10)], fill=SHADE)
    d.line([(13, 7), (17, 7), (19, 10)], fill=LIGHT)
    d.line([(11, 10), (14, 21)], fill=GOLD)
    d.line([(15, 8), (15, 11)], fill=DEEP)
    d.line([(13, 9), (17, 9)], fill=DEEP)
    d.point((15, 8), fill='#b6dbca')
    # A coin seal and two gold bindings lock the lid shut.
    d.line([(10, 15), (19, 15)], fill=DEEP, width=3)
    d.line([(10, 14), (20, 14)], fill=LIGHT)
    d.polygon([(14, 11), (17, 11), (19, 13), (19, 16),
               (17, 18), (14, 18), (12, 16), (12, 13)], fill=INK)
    d.polygon([(14, 12), (17, 12), (18, 14), (18, 15),
               (16, 17), (14, 16), (13, 14)], fill=GOLD)
    d.line([(14, 12), (16, 12), (17, 13)], fill=SHINE)
    d.rectangle((15, 14, 16, 15), fill=DEEP)
    d.line([(13, 21), (18, 21)], fill=DEEP, width=2)
    d.line([(13, 20), (18, 20)], fill=LIGHT)
    d.point((15, 23), fill=SHINE)
    d.line([(7, 12), (9, 19)], fill='#79ada5')
    d.line([(7, 12), (7, 14)], fill='#b6dbca')
    return im


ENTRIES = [
    {'id': 'relic_coin_heart', 'name': '金币心脏', 'rarity': '稀有',
     'concept': '金币嵌入金属心脏，中央留一枚暗红心核。',
     'theme': '本金维系生命',
     'effect_draft': '每100本金：最大生命 +1。',
     'factory': coin_heart},
    {'id': 'relic_hoarders_ring', 'name': '囤积者戒指', 'rarity': '史诗',
     'concept': '爪形镶座紧扣金币，币面刻着紫色眼睛。',
     'theme': '抓紧财富，失去理智',
     'effect_draft': '每500本金：金币获取 +5%，理智 −2。',
     'factory': hoarders_ring},
    {'id': 'relic_golden_sarcophagus', 'name': '黄金棺椁', 'rarity': '神话',
     'concept': '厚金棺盖以金币封印，缝隙透出一线青光。',
     'theme': '用财富买回一次生命',
     'effect_draft': '本金≥1000时：致死消耗500本金，恢复50%生命；每局一次。',
     'factory': golden_sarcophagus},
]
