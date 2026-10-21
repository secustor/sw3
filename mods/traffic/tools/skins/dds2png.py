"""Export the top level of a DDS as two PNGs for painting: <prefix>_rgb.png (opaque RGB) and <prefix>_alpha.png (grey).
Usage: python3 -I dds2png.py <scripts dir> <in.dds> <prefix>"""
import sys; sys.path.insert(0, sys.argv[1]); import dxt
from PIL import Image
d = dxt.read_dds(sys.argv[2]); im = dxt.decode(d['mips'][0], d['W'], d['H'], d['fourcc'])
Image.fromarray(im[..., :3]).save(sys.argv[3] + '_rgb.png'); Image.fromarray(im[..., 3]).save(sys.argv[3] + '_alpha.png')
print('wrote', sys.argv[3] + '_rgb.png', sys.argv[3] + '_alpha.png', d['W'], d['H'], d['fourcc'].decode(), len(d['mips']), 'levels')
