import sys
from PIL import Image, ImageDraw, ImageFont, ImageFilter
S = "build/shots/"
FONT = "/System/Library/Fonts/Supplemental/Arial Rounded Bold.ttf"
items = [
 ("home.png",         ["COPY THE MOVE.", "BEAT YOUR FRIENDS."], ((255,69,191),(64,230,255))),
 ("raw_watch.png",    ["WATCH THE MOVE", "IN 3 SECONDS"],       ((64,230,255),(120,90,255))),
 ("raw_live.png",     ["COPY IT FROM", "MEMORY. FAST."],        ((255,69,191),(255,140,60))),
 ("raw_reveal.png",   ["SEE HOW CLOSE", "YOU REALLY WERE"],     ((120,255,150),(64,230,255))),
 ("friends.png",      ["CHALLENGE ANYONE", "WITH ONE LINK"],    ((64,230,255),(255,69,191))),
 ("raw_victory.png",  ["SHARE YOUR", "REPLAY VIDEO"],           ((255,69,191),(255,160,60))),
 ("stats.png",        ["DAILY STREAKS &", "RANKS TO CLIMB"],    ((255,170,60),(255,69,191))),
 ("skins.png",        ["UNLOCK GLOWING", "TRAIL SKINS"],        ((120,90,255),(64,230,255))),
]
def grad(w, h, c1, c2):
    base = Image.new("RGB", (w, h), (10, 8, 26))
    d = ImageDraw.Draw(base)
    for y in range(h):
        t = y / h
        d.line([(0, y), (w, y)], fill=(int(24*(1-t)+6*t), int(14*(1-t)+6*t), int(58*(1-t)+16*t)))
    glow = Image.new("RGB", (w, h), (0, 0, 0))
    gd = ImageDraw.Draw(glow)
    gd.ellipse([w*0.45, -h*0.1, w*1.5, h*0.4], fill=c1)
    gd.ellipse([-w*0.5, h*0.55, w*0.6, h*1.1], fill=c2)
    glow = glow.filter(ImageFilter.GaussianBlur(w*0.18)).point(lambda v: int(v*0.42))
    from PIL import ImageChops
    return ImageChops.add(base, glow)
def make(size, out):
    W, H = size
    for i, (src, lines, (c1, c2)) in enumerate(items, 1):
        bg = grad(W, H, c1, c2)
        shot = Image.open(S + src).convert("RGB")
        sw = int(W * 0.84)
        sh = int(shot.height * sw / shot.width)
        shot = shot.resize((sw, sh), Image.LANCZOS)
        mask = Image.new("L", shot.size, 0)
        ImageDraw.Draw(mask).rounded_rectangle([0, 0, sw, sh], radius=int(sw*0.085), fill=255)
        x = (W - sw) // 2
        y = int(H * 0.235)
        # glow/frame
        frame = Image.new("RGBA", (sw+24, sh+24), (255,255,255,0))
        ImageDraw.Draw(frame).rounded_rectangle([0,0,sw+23,sh+23], radius=int(sw*0.09), fill=(255,255,255,60))
        bg.paste(frame, (x-12, y-12), frame)
        bg.paste(shot, (x, y), mask)
        d = ImageDraw.Draw(bg)
        fs = int(W * 0.093)
        f = ImageFont.truetype(FONT, fs)
        while max(ImageDraw.Draw(bg).textlength(l, font=f) for l in lines) > W * 0.9:
            fs -= 2
            f = ImageFont.truetype(FONT, fs)
        ty = int(H * 0.05)
        for ln in lines:
            tw = d.textlength(ln, font=f)
            d.text(((W - tw) / 2 + 3, ty + 3), ln, font=f, fill=(0, 0, 0))
            d.text(((W - tw) / 2, ty), ln, font=f, fill=(255, 255, 255))
            ty += int(fs * 1.12)
        bg.save(f"{out}/shot{i}.png", "PNG")
import os
for name, size in [("p65", (1284, 2778)), ("p69", (1320, 2868))]:
    os.makedirs(f"build/store/{name}", exist_ok=True)
    make(size, f"build/store/{name}")
print("done")
