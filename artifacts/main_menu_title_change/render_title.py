from pathlib import Path

from PIL import Image, ImageDraw, ImageFont, PngImagePlugin


ROOT = Path(__file__).resolve().parents[2]
TITLE = "\u767d\u5929\u6253\u602a,\u665a\u4e0a\u7406\u8d22"
SIZE = (700, 160)
font = ImageFont.truetype('C:/Windows/Fonts/msyhbd.ttc', 72)
bounds = font.getbbox(TITLE)
position = ((SIZE[0] - (bounds[2] - bounds[0])) // 2 - bounds[0],
            (SIZE[1] - (bounds[3] - bounds[1])) // 2 - bounds[1] - 3)

result = Image.new('RGBA', SIZE)
draw = ImageDraw.Draw(result)
# Match the original title's warm gold face, dark outline and shallow relief.
for depth in range(5, 0, -1):
    draw.text((position[0] + 2, position[1] + depth), TITLE, font=font,
              fill='#6a5935', stroke_width=4, stroke_fill='#252a20')
draw.text(position, TITLE, font=font, fill='#e4c57d',
          stroke_width=3, stroke_fill='#4e4930')
draw.text(position, TITLE, font=font, fill='#e4c57d',
          stroke_width=1, stroke_fill='#fff0bb')
mask = Image.new('L', SIZE)
ImageDraw.Draw(mask).text(position, TITLE, font=font, fill=255)
face = Image.new('RGBA', SIZE)
face_draw = ImageDraw.Draw(face)
top = position[1] + bounds[1]
height = bounds[3] - bounds[1]
for y in range(SIZE[1]):
    mix = max(0.0, min(1.0, (y - top) / max(1, height)))
    color = tuple(round(a + (b - a) * mix) for a, b in zip((255, 235, 171), (215, 176, 91)))
    face_draw.line((0, y, SIZE[0], y), fill=(*color, 255))
face.putalpha(mask)
result.alpha_composite(face)
metadata = PngImagePlugin.PngInfo()
metadata.add_itxt('Title', TITLE)
result.save(ROOT / 'assets/ui/main_menu/title_main_menu.png', pnginfo=metadata)
print('TITLE_TEXT=' + TITLE.encode('unicode_escape').decode('ascii'))
print('IMAGE_SIZE=' + str(result.size))
print('CONTENT_BOUNDS=' + str(result.getbbox()))
