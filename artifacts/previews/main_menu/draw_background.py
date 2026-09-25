"""Original pixel painting, authored as geometry and restricted color ramps.

The environment never opens a reference image. All geometry is drawn on a
640x360 grid and exported at 3x with nearest-neighbor sampling.
"""

from pathlib import Path
from math import sin, cos, pi, sqrt
import json
import random

from PIL import Image, ImageDraw, ImageColor


OUT = Path(__file__).resolve().parent
WIDTH, HEIGHT = 640, 360
RNG = random.Random(92326)
NEAREST = Image.Resampling.NEAREST

SKY = ['#202f29', '#293b31', '#324638', '#405340', '#53654c', '#6b7856', '#828867', '#9c9f77']
FAR = ['#2d4236', '#354c3c', '#3e5543', '#465f49']
STONE = ['#252e23', '#323b2a', '#444a33', '#53573c', '#676449', '#827853', '#9a8b63', '#b5a474']
FRAME = ['#111b17', '#18241c', '#243023', '#303a28', '#404631', '#51553a', '#656546']
GOLD = ['#514d31', '#756342', '#9b8050', '#c2a566', '#dcc78a']
MOSS = ['#283826', '#36492d', '#465737', '#5c6941', '#778151']


def xy(points):
    return [(round(x), round(y)) for x, y in points]


def polygon(image, points, fill):
    ImageDraw.Draw(image).polygon(xy(points), fill=fill)


def line(image, points, fill, width=1):
    ImageDraw.Draw(image).line(xy(points), fill=fill, width=width)


def blank():
    return Image.new('RGBA', (WIDTH, HEIGHT))


def mask_of(points):
    mask = Image.new('L', (WIDTH, HEIGHT))
    ImageDraw.Draw(mask).polygon(xy(points), fill=255)
    return mask


def texture(image, mask, palette, count, seed, scale=1):
    """Paint compact mineral clusters only inside a material mask."""
    rng = random.Random(seed)
    bounds = mask.getbbox()
    if bounds is None:
        return
    x0, y0, x1, y1 = bounds
    layer = blank()
    d = ImageDraw.Draw(layer)
    mp = mask.load()
    for _ in range(count):
        x = rng.randrange(x0, x1)
        y = rng.randrange(y0, y1)
        if not mp[x, y]:
            continue
        w = rng.randint(1, 5) * scale
        h = rng.choice([1, 1, 2]) * scale
        color = rng.choice(palette)
        d.rectangle((x, y, x+w, y+h-1), fill=color)
        if w > 3 and rng.random() < 0.3:
            d.rectangle((x+1,y-1,x+w-2,y),fill=color)
    alpha = layer.getchannel('A')
    from PIL import ImageChops
    layer.putalpha(ImageChops.multiply(alpha, mask))
    image.alpha_composite(layer)


def plane(image, points, fill, colors=None, seed=0, count=15):
    polygon(image, points, fill)
    if colors:
        texture(image, mask_of(points), colors, count, seed)


def ellipse_point(cx, cy, rx, ry, angle):
    return (cx+rx*cos(angle), cy+ry*sin(angle))


def arc_points(cx, cy, rx, ry, a, b, steps=12):
    return [ellipse_point(cx,cy,rx,ry,a+(b-a)*i/steps) for i in range(steps+1)]


def sky_layer():
    image = blank()
    pix = image.load()
    # Quantized light fields; a tiny ordered transition at ramp boundaries.
    bayer = ((0,8,2,10),(12,4,14,6),(3,11,1,9),(15,7,13,5))
    for y in range(HEIGHT):
        for x in range(WIDTH):
            radial = max(0.0, 1-sqrt(((x-412)/350)**2+((y-88)/210)**2))
            value = 1.2+radial*4.4
            index = int(value)
            if value-index > .72+bayer[y%4][x%4]/57:
                index += 1
            pix[x,y] = (*ImageColor.getrgb(SKY[max(0,min(7,index))]),255)
    # Long, angular cloud banks are painted as joined pixel clusters.
    banks = [
        ([(105,45),(137,45),(145,39),(181,39),(188,34),(218,34),(224,31),(258,31),(272,35),(306,35),(314,40),(339,40),(344,47),(372,47),(375,53),(340,53),(337,57),(289,57),(280,53),(247,53),(239,56),(203,56),(190,52),(145,52),(140,49),(105,49)], SKY[3]),
        ([(300,73),(319,73),(328,66),(369,66),(377,59),(416,59),(425,62),(451,62),(460,69),(497,69),(507,74),(539,74),(543,81),(519,81),(515,85),(461,85),(451,81),(418,81),(409,77),(359,77),(354,81),(317,81),(317,78),(300,78)], SKY[5]),
        ([(208,108),(248,108),(258,102),(291,102),(298,98),(329,98),(337,104),(365,104),(373,110),(397,110),(403,118),(362,118),(357,122),(310,122),(304,118),(265,118),(258,115),(220,115)], SKY[4]),
        ([(420,126),(450,126),(461,120),(508,120),(516,115),(552,115),(563,120),(601,120),(614,125),(639,125),(639,137),(570,137),(563,132),(519,132),(513,135),(471,135),(460,132),(420,132)], SKY[4]),
    ]
    for points,color in banks:
        plane(image,points,color)
    # Distant broken celestial ring, low contrast, never an interface element.
    for a,b in [(-2.85,-1.75),(-1.61,-.5),(-.27,.61),(.83,1.57),(1.8,2.68)]:
        line(image,arc_points(443,83,45,45,a,b,40), SKY[6])
    line(image,arc_points(443,83,39,39,-2.7,-.1,60),SKY[5])
    line(image,[(471,43),(474,48),(472,53),(477,58)],SKY[5])
    # Mist behind the ruins.
    for y in range(155,217,11):
        color=SKY[4 if y<183 else 3]
        polygon(image,[(0,y+8),(140,y+4),(244,y+8),(343,y-2),(441,y+3),(549,y-1),(639,y+4),(639,y+15),(0,y+15)],color)
    return image


def distant_layer():
    image=blank()
    polygon(image,[(0,188),(27,180),(40,180),(53,172),(82,170),(99,176),(115,175),(131,157),(152,160),(160,170),(184,176),(199,162),(219,160),(233,174),(257,166),(278,176),(301,165),(323,175),(349,171),(370,179),(392,172),(409,174),(439,161),(456,166),(470,170),(487,161),(510,170),(530,161),(549,167),(570,158),(588,167),(609,161),(639,179),(639,229),(0,229)],FAR[2])
    towers=[(171,131,19,72),(218,118,27,81),(282,129,23,74),(497,96,28,103),(539,123,20,81)]
    for k,(x,y,w,h) in enumerate(towers):
        color=FAR[1 if k%2 else 0]
        p=[(x,y+h),(x,y+18),(x+3,y+18),(x+3,y+8),(x+w*.43,y+8),(x+w*.43,y-18),(x+w*.53,y-18),(x+w*.53,y),(x+w*.7,y),(x+w*.7,y+11),(x+w-3,y+11),(x+w-3,y+23),(x+w,y+23),(x+w,y+h)]
        plane(image,p,color)
        line(image,[(x+w-3,y+29),(x+w-3,y+h)],FAR[2])
        for wy in range(y+33,y+h-5,19):
            ImageDraw.Draw(image).rectangle((x+8,wy,x+10,wy+7),fill=SKY[3])
    # Distant broken bridges and lintels.
    polygon(image,[(204,154),(242,154),(242,158),(254,158),(254,165),(241,164),(241,162),(204,162)],FAR[1])
    polygon(image,[(495,163),(556,159),(556,165),(537,166),(533,170),(495,170)],FAR[1])
    return image


def pointed_hole(image,cx,top,w,bottom):
    pts=[(cx-w/2,bottom),(cx-w/2,top+w*.62),(cx-w*.43,top+w*.36),(cx-w*.24,top+w*.16),(cx,top),(cx+w*.24,top+w*.16),(cx+w*.43,top+w*.36),(cx+w/2,top+w*.62),(cx+w/2,bottom)]
    polygon(image,pts,(0,0,0,0))


def middle_layer():
    image=blank()
    # Crumbling arcade silhouetted against the atmosphere.
    wall=[(244,217),(247,162),(247,151),(254,151),(254,135),(267,135),(267,123),(283,123),(283,111),(289,111),(289,96),(296,99),(296,111),(305,114),(309,126),(323,127),(323,131),(341,131),(341,123),(351,123),(357,110),(367,113),(367,126),(376,126),(377,119),(389,123),(389,133),(405,133),(405,123),(414,122),(414,107),(421,112),(428,112),(428,124),(439,128),(439,137),(452,137),(452,148),(465,147),(465,164),(478,169),(478,218)]
    plane(image,wall,'#26392c',['#2b3d2e','#30412f','#203127'],831,270)
    d=ImageDraw.Draw(image)
    # Masonry joints are visible but subordinate to the main altar.
    wallmask=image.getchannel('A').copy()
    joints=blank()
    jd=ImageDraw.Draw(joints)
    for y in range(105,218,10):
        jd.line((242,y,480,y),fill='#203127')
        for x in range(242+(y//10%2)*13,480,27):
            jd.line((x,y,x,y+9),fill='#203127')
    from PIL import ImageChops
    joints.putalpha(ImageChops.multiply(joints.getchannel('A'),wallmask))
    image.alpha_composite(joints)
    for cx,top,w in [(286,138,33),(342,147,34),(399,146,35),(447,166,21)]:
        # Thin light rim around the pointed arch.
        pts=[(cx-w/2-3,215),(cx-w/2-3,top+w*.62),(cx-w*.35,top+7),(cx,top-4),(cx+w*.35,top+7),(cx+w/2+3,top+w*.62),(cx+w/2+3,215)]
        line(image,pts,'#4b5339',2)
        pointed_hole(image,cx,top,w,222)
    # Pillar buttresses and a broken capital.
    for x,y in [(258,142),(313,136),(369,139),(424,141)]:
        polygon(image,[(x,y),(x+8,y-2),(x+8,219),(x-3,219)],'#303e2b')
        line(image,[(x+6,y+3),(x+6,215)],'#495139')
        for yy in range(y+12,219,17):
            line(image,[(x,yy),(x+7,yy)],'#1e2d23')
    # Foreground end of the arcade, fractured dark wall on the left.
    plane(image,[(82,173),(114,159),(140,160),(153,151),(166,158),(179,174),(209,177),(220,184),(251,188),(262,209),(265,243),(71,245)],'#263329',['#2b392c','#202d25'],41,190)
    return image


def floor_layer():
    image=blank()
    polygon(image,[(0,223),(130,209),(250,211),(371,202),(487,209),(585,219),(640,217),(640,360),(0,360)],'#1c291f')
    # Receding rows of offset flagstones; gaps are the underlying dark floor.
    rows=[(214,222,26),(223,235,34),(237,253,48),(255,277,67),(280,310,91),(313,359,128)]
    rng=random.Random(519)
    for row,(yt,yb,width) in enumerate(rows):
        for index,x in enumerate(range(-width if row%2 else -width//2,640+width,width)):
            perspective=(yb-yt)*.19
            topx=x+(390-x)*.022
            bottomx=x-(390-x)*.018
            points=[(topx+2,yt+rng.choice([0,0,1])),(topx+width-3,yt),(bottomx+width-4,yb-2),(bottomx+5,yb),(bottomx+1,yb-3)]
            light=max(0,1-abs(x+width/2-404)/340)
            ramp=2+int(light*1.7)
            if x<200:
                ramp=max(1,ramp-1)
            fill=STONE[ramp]
            plane(image,points,fill,[STONE[max(0,ramp-1)],STONE[ramp]],700+row*29+index,14)
            line(image,[points[0],points[1]],STONE[min(6,ramp+1)])
            line(image,[points[-2],points[2]],STONE[max(0,ramp-1)])
            if rng.random()<.45:
                cx=x+rng.randrange(8,max(9,width-5))
                line(image,[(cx,yt),(cx+3,yt+4),(cx-2,yt+7),(cx+2,min(yb,yt+11))],STONE[0])
    # Low wall to the right and fallen masonry behind the terrace.
    plane(image,[(483,215),(510,198),(523,204),(561,204),(580,213),(577,231),(511,234)],'#454b33',['#3a422f','#50553a'],919,80)
    line(image,[(485,215),(510,198),(523,204),(561,204)],'#626345',2)
    line(image,[(516,204),(514,225),(544,227),(545,207)],'#283323')
    line(image,[(548,218),(576,218)],'#303c28')
    # A broken staircase recedes left of the altar.
    for k in range(7):
        y=207+k*4
        left=268-k*5
        right=330+k*2
        plane(image,[(left,y),(right,y-1),(right+2,y+2),(left-3,y+3)],STONE[4+(k%3==0)])
        line(image,[(left-3,y+3),(right+2,y+2)],STONE[1])
    return image


def altar_layer():
    image=blank()
    d=ImageDraw.Draw(image)
    cx,cy,rx,ry=411,270,145,49
    # Three stepped courses support individually shaped radial flagstones.
    d.ellipse((cx-157,cy-44,cx+157,cy+75),fill='#111c17')
    d.ellipse((cx-153,cy-48,cx+153,cy+64),fill='#303927')
    d.ellipse((cx-151,cy-52,cx+151,cy+56),fill='#55573a')
    line(image,arc_points(cx,cy+3,151,52,0,pi,90),'#70704b',2)
    for j in range(26):
        a=j*2*pi/26
        if sin(a)>0:
            x,y=ellipse_point(cx,cy+3,151,52,a)
            line(image,[(x,y),(x,y+8)],'#1d291e',2)
    d.ellipse((cx-rx,cy-ry,cx+rx,cy+ry+17),fill='#313725')
    d.ellipse((cx-rx,cy-ry,cx+rx,cy+ry),fill='#1f291f')
    rings=[(1,.74,24),(.73,.49,18),(.48,.23,12)]
    rng=random.Random(221)
    for ring,(outer,inner,num) in enumerate(rings):
        for j in range(num):
            a=2*pi*j/num+ring*.13+.009
            b=2*pi*(j+1)/num+ring*.13-.009
            lift=-rng.choice([0,0,0,1])
            outer_arc=arc_points(cx,cy+lift,rx*outer,ry*outer,a,b,5)
            inner_arc=arc_points(cx,cy+lift,rx*inner,ry*inner,b,a,5)
            shape=outer_arc+inner_arc
            front=[(x,y+12) for x,y in outer_arc]+list(reversed(outer_arc))
            if sin((a+b)/2)>0 and ring==0:
                plane(image,front,STONE[2], [STONE[1],STONE[3]],900+j,6)
            brightness=5+int(cos((a+b)/2+2.2)*.85)
            brightness+=rng.choice([-1,0,0,0,1])
            brightness=max(3,min(7,brightness))
            if ring==0 and j==19:
                brightness=2
                lift=4
                shape=[(x,y+4) for x,y in shape]
            plane(image,shape,STONE[brightness],[STONE[max(2,brightness-1)],STONE[brightness]],3000+ring*100+j,8)
            line(image,outer_arc,STONE[min(7,brightness+1)])
            line(image,[shape[0],shape[-1]],STONE[max(1,brightness-2)])
            if rng.random()<.45:
                ax,ay=ellipse_point(cx,cy,rx*(inner+.10),ry*(inner+.10),(a+b)/2)
                bx,by=ellipse_point(cx,cy,rx*(outer-.06),ry*(outer-.06),(a+b)/2+.022)
                mid=((ax+bx)/2+3,(ay+by)/2)
                line(image,[(ax,ay),mid,(mid[0]-3,mid[1]+2),(bx,by)],STONE[2])
    # Inset central seal with deliberately discontinuous antique-gold lines.
    d.ellipse((cx-32,cy-11,cx+32,cy+11),fill='#353f2b')
    line(image,arc_points(cx,cy,32,11,0,2*pi,88),'#929066')
    line(image,arc_points(cx,cy,28,9,0,2*pi,88),'#202e22')
    spiral=[]
    for i in range(91):
        a=i/90*4.8*pi
        r=2+i/90*19
        spiral.append((cx+cos(a)*r,cy+sin(a)*r*.34))
    line(image,spiral,GOLD[2])
    # Geometric chisel marks follow the outer seal; these are not UI text.
    for j in range(16):
        a=2*pi*j/16+.09
        center=ellipse_point(cx,cy,rx*.61,ry*.61,a)
        tangent=(-sin(a)*3.5,cos(a)*1.8)
        outward=(cos(a)*3,sin(a)*1.7)
        x,y=center
        pts=[(x-tangent[0],y-tangent[1]),(x+outward[0],y+outward[1]),(x+tangent[0],y+tangent[1])]
        line(image,[(xx,yy+1) for xx,yy in pts],STONE[2])
        line(image,pts,GOLD[2] if j%4 else GOLD[3])
    # Radial fracture traverses two courses, visibly offset at the joints.
    line(image,[(435,265),(448,260),(447,256),(462,255),(470,249),(469,245),(486,239),(489,234)],'#253122')
    line(image,[(448,260),(455,264),(461,264)],'#39432c')
    line(image,[(316,292),(329,288),(337,289),(347,285),(348,281)],'#2a3525')
    # Moss grows in shaded seams, never evenly sprayed across the stone.
    for x,y in [(281,270),(295,286),(309,302),(507,291),(528,277),(327,228),(497,309)]:
        for k in range(5):
            xx=x+rng.randrange(-7,8)
            yy=y+rng.randrange(-2,3)
            d.rectangle((xx,yy,xx+rng.randrange(2,5),yy+1),fill=rng.choice(MOSS[1:4]))
    return image


def rubble(image,x,y,w,h,seed,bright=False):
    rng=random.Random(seed)
    colors=STONE if bright else FRAME
    a=3 if bright else 2
    top=[(x,y),(x+w*.6,y-h*.34),(x+w,y-h*.03),(x+w*.40,y+h*.2)]
    left=[(x,y),(x+w*.40,y+h*.2),(x+w*.4,y+h*.8),(x+1,y+h*.51)]
    right=[(x+w*.40,y+h*.2),(x+w,y-h*.03),(x+w*.9,y+h*.51),(x+w*.4,y+h*.8)]
    plane(image,left,colors[a-1])
    plane(image,right,colors[a])
    plane(image,top,colors[a+2],[colors[a+1],colors[a+2]],seed,5)
    line(image,[top[0],top[1],top[2]],colors[min(6,a+3)])
    if w>18:
        line(image,[(x+w*.5,y-h*.24),(x+w*.4,y+h*.02),(x+w*.5,y+h*.10)],colors[a])


def foreground_layer():
    image=blank()
    rng=random.Random(9421)
    # Large roof arch: solid framing outside an open ellipse.
    inner=arc_points(320,218,281,216,0,-pi,180)
    polygon(image,[(0,0),(640,0),(640,218)]+inner+[(0,218)],FRAME[0])
    # Separate voussoirs, some chipped, drawn as genuinely low-resolution stone.
    for j in range(27):
        a=-pi+j*pi/27+.005
        b=-pi+(j+1)*pi/27-.006
        outer=arc_points(320,218,350,270,a,b,9)
        inner_arc=arc_points(320,218,281,216,b,a,9)
        shape=outer+inner_arc
        if j in (10,21):
            polygon(image,shape,(0,0,0,0))
            continue
        ramp=2+int(j>13)
        plane(image,shape,FRAME[ramp],[FRAME[ramp-1],FRAME[ramp],FRAME[ramp+1]],280+j,52)
        line(image,list(reversed(inner_arc)),FRAME[ramp+2],2)
        line(image,[outer[-1],inner_arc[0]],FRAME[0],2)
        if j%3==0:
            a1=(a+b)/2
            p1=ellipse_point(320,218,288,222,a1)
            p2=ellipse_point(320,218,312,241,a1+.014)
            p3=ellipse_point(320,218,325,251,a1-.006)
            line(image,[p1,p2,p3],FRAME[0])
    # A second carved groove on the inner rim unifies the frame.
    for a,b in [(-pi,-2.23),(-1.12,0)]:
        line(image,arc_points(320,218,290,224,a,b,90),FRAME[1])
    # Worn capitals and fluted stone columns.
    for side,(x,w,top,bottom) in enumerate([(15,49,197,337),(582,53,190,336)]):
        ramp=2+side
        # Side face and front face.
        plane(image,[(x-4,top),(x+w,top-2),(x+w+6,bottom),(x-3,bottom)],FRAME[1])
        plane(image,[(x+5,top),(x+w-6,top),(x+w-3,bottom),(x+3,bottom)],FRAME[ramp],[FRAME[ramp-1],FRAME[ramp+1]],601+side,150)
        line(image,[(x+w-5,top),(x+w-2,bottom)],FRAME[ramp+2],2)
        # Recessed vertical flutes and articulated stone courses.
        for xx in range(x+10,x+w-8,10):
            line(image,[(xx,top+10),(xx-2,bottom-13)],FRAME[1],2)
            line(image,[(xx+2,top+10),(xx,bottom-13)],FRAME[ramp+1])
        for yy in range(top+17,bottom,27):
            line(image,[(x+3,yy),(x+w-1,yy+1)],FRAME[0],2)
            line(image,[(x+5,yy+2),(x+w-3,yy+3)],FRAME[ramp+1])
        for yy,extra,height in [(top-15,9,7),(top-6,5,6),(bottom-8,4,8),(bottom+1,11,8),(bottom+10,17,10)]:
            shape=[(x-extra,yy),(x+w+extra,yy),(x+w+extra,yy+height),(x-extra,yy+height)]
            plane(image,shape,FRAME[ramp], [FRAME[ramp-1],FRAME[ramp+1]],int(yy)*8+side,23)
            line(image,[(x-extra,yy),(x+w+extra,yy)],FRAME[ramp+2],2)
            line(image,[(x-extra,yy+height),(x+w+extra,yy+height)],FRAME[0],2)
        line(image,[(x+w-11,top+21),(x+w-18,top+38),(x+w-12,top+48),(x+w-24,top+64)],FRAME[0],2)
    # Rubble at the base gives depth and hides geometric joins.
    for k,(x,y,w,h,bright) in enumerate([(77,303,31,21,False),(36,328,38,23,False),(93,326,18,10,False),(144,339,38,21,False),(224,337,24,17,False),(265,347,16,10,False),(538,316,32,22,True),(555,333,27,18,False),(506,342,34,22,False),(607,346,36,17,False),(466,348,13,10,False),(251,245,15,10,True),(527,231,19,11,True)]):
        rubble(image,x,y,w,h,808+k,bright)
    # Creeping ivy is clustered along cracks and the edges of columns.
    for points in [[(608,42),(600,56),(607,68),(600,87),(605,104),(596,121),(599,143),(590,162),(594,177)],[(627,100),(619,115),(623,138),(615,153),(618,170),(611,186),(614,201)],[(40,170),(47,188),(40,207),(43,227),(37,245)],[(580,318),(574,308),(578,291),(569,279)]]:
        line(image,points,MOSS[0],2)
        for k in range(len(points)-1):
            x,y=points[k]
            direction=-1 if k%2 else 1
            polygon(image,[(x,y),(x+direction*5,y-4),(x+direction*8,y-3),(x+direction*5,y+1),(x+direction,y+2)],MOSS[2])
            line(image,[(x+direction*2,y),(x+direction*5,y-2)],MOSS[3])
            if k%3==0:
                polygon(image,[(x+2,y+4),(x+7,y+2),(x+8,y+5),(x+4,y+7)],MOSS[1])
    return image


def atmosphere_layer():
    image=blank()
    # A handful of hovering stone chips. No living shapes are present.
    for k,(x,y,w,h) in enumerate([(339,50,8,7),(376,83,6,6),(492,49,10,9),(506,100,5,6),(308,83,5,6),(465,149,6,7)]):
        rubble(image,x,y,w,h,777+k,True)
    d=ImageDraw.Draw(image)
    for x,y in [(292,62),(357,39),(406,122),(480,71),(475,166),(528,144),(281,106),(364,191),(502,191),(462,217),(541,251)]:
        d.point((x,y),fill=GOLD[2])
    for x,y in [(387,55),(479,113),(329,167)]:
        d.point((x-1,y),fill=GOLD[1])
        d.point((x+1,y),fill=GOLD[1])
        d.point((x,y-1),fill=GOLD[1])
        d.point((x,y+1),fill=GOLD[1])
        d.point((x,y),fill=GOLD[3])
    return image


def build():
    functions=[('01-sky',sky_layer),('02-distant-ruins',distant_layer),('03-arcade',middle_layer),('04-floor',floor_layer),('05-empty-altar',altar_layer),('06-foreground',foreground_layer),('07-dust-and-stones',atmosphere_layer)]
    canvas=blank()
    for name,function in functions:
        layer=function()
        canvas.alpha_composite(layer)
    background=canvas.convert('RGB')
    background.save(OUT/'background-native-640x360.png')
    background.resize((1920,1080),NEAREST).save(OUT/'background-redrawn-v2.png')
    # The UI overlay is a separate review composition; never load its old scene.
    ui=Image.open(OUT/'menu-overlay-v2.png').convert('RGBA')
    composed=canvas.copy()
    composed.alpha_composite(ui)
    composed.convert('RGB').resize((1920,1080),NEAREST).save(OUT/'homepage-preview-v2.png')
    meta={
        'method':'Original code-authored pixel painting; no image generation API',
        'native_size':[640,360],
        'export_size':[1920,1080],
        'scaling':'nearest neighbor, exactly 3x',
        'environment_image_inputs':[],
        'characters':False,
        'unique_background_colors':len(background.getcolors(WIDTH*HEIGHT)),
        'layers':[name+'.png' for name,_ in functions],
        'ui_material_reference':'assets/ui/finance/finance_board.png',
    }
    print(json.dumps(meta))


if __name__=='__main__':
    build()
