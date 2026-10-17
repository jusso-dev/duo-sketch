# Draws App/DuoSketch/Assets.xcassets/AppIcon.appiconset/AppIcon.png.
# Run from App/: python3 ../scripts/make_app_icon.py (needs Pillow).
from PIL import Image, ImageDraw
S=4; N=1024*S
img=Image.new("RGB",(N,N))
d=ImageDraw.Draw(img)
top=(24,58,74); bot=(12,30,44)
for y in range(N):
    t=y/(N-1); d.line([(0,y),(N,y)],fill=tuple(round(a+(b-a)*t) for a,b in zip(top,bot)))
def s(v): return int(v*S)
paper=(244,236,220); shade=(220,210,192)
# two panels of a folding phone, open like a book, with a hinge gap
d.rounded_rectangle([s(168),s(232),s(500),s(792)],radius=s(56),fill=shade)
d.rounded_rectangle([s(524),s(232),s(856),s(792)],radius=s(56),fill=paper)
# one continuous amber line that runs across the hinge
amber=(198,148,71)
pts=[(250,640),(250,520),(330,520),(330,420),(430,420),(430,340),(600,340),(600,470),(700,470),(700,600),(750,600)]
pts=[(s(x),s(y)) for x,y in pts]
d.line(pts,fill=amber,width=s(30),joint="curve")
for p in (pts[0],):
    r=s(15); d.ellipse([p[0]-r,p[1]-r,p[0]+r,p[1]+r],fill=amber)
r=s(30); x,y=s(780),s(600); d.ellipse([x-r,y-r,x+r,y+r],outline=amber,width=s(10))
img=img.resize((1024,1024),Image.LANCZOS)
img.save("DuoSketch/Assets.xcassets/AppIcon.appiconset/AppIcon.png",optimize=True)
