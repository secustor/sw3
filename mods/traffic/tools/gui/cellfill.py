"""Count opaque pixels per ships.tuv cell for every shipsNN.dds (decoded to raw RGBA by ffmpeg).
Usage: python3 -I cellfill.py <Slots dir>"""
import sys, os, subprocess
S = sys.argv[1]
cells = [(0,0),(512,0),(0,340),(512,340),(0,680),(512,680)]
for f in sorted(os.listdir(S)):
    if not f.lower().endswith('.dds'): continue
    raw = subprocess.run(['ffmpeg','-v','error','-i',os.path.join(S,f),'-f','rawvideo','-pix_fmt','rgba','-'],capture_output=True).stdout
    W = 1024
    res = []
    for cx, cy in cells:
        n = 0; colored = 0
        for y in range(cy, cy+340):
            row = raw[(y*W+cx)*4:(y*W+cx+512)*4]
            for i in range(3, len(row), 4):
                if row[i] > 16:
                    n += 1
                    r, g, b = row[i-3], row[i-2], row[i-1]
                    if max(r,g,b) - min(r,g,b) > 40: colored += 1
        res.append('%6d/%5d' % (n, colored))
    # rows 1020-1023 below last cell
    tail = sum(1 for y in range(1020,1024) for x in range(1024) if raw[(y*W+x)*4+3] > 16)
    print('%-20s' % f, ' '.join(res), ' tail=%d' % tail)
print('format: opaque_pixels/colored_pixels per cell index 0..5')
