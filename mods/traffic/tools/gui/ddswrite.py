"""Write uncompressed 32-bit A8R8G8B8 DDS files (no mips), the layout of 214-216 vanilla
icons per size in TEXTURE/Interface/Carcass/{32,64,128} (pf flags 0x41, 32 bit,
masks R 0xff0000 G 0xff00 B 0xff A 0xff000000), and of the GUI sheets TEXTURE/GUI/bg-fon*.dds.
Input: PNG written by render.py (8-bit RGBA, non-interlaced) or raw RGBA via ffmpeg.
Usage: python3 -I ddswrite.py <in.png> <out.dds>"""
import struct, sys, zlib, subprocess

def read_png_rgba(path):
    # decode any image to RGBA with ffmpeg (handles PNG/DDS/TGA)
    probe = open(path, 'rb').read(32)
    if probe[:8] == b'\x89PNG\r\n\x1a\n':
        w, h = struct.unpack('>II', probe[16:24])
    else:
        raise SystemExit('PNG input expected')
    raw = subprocess.run(['ffmpeg', '-v', 'error', '-i', path, '-f', 'rawvideo', '-pix_fmt', 'rgba', '-'],
                         capture_output=True).stdout
    assert len(raw) == w * h * 4, (len(raw), w, h)
    return w, h, raw

def write_dds_argb(path, w, h, rgba):
    DDSD_CAPS, DDSD_HEIGHT, DDSD_WIDTH, DDSD_PITCH, DDSD_PIXELFORMAT = 0x1, 0x2, 0x4, 0x8, 0x1000
    hdr = struct.pack('<4sIIIIIII', b'DDS ', 124, DDSD_CAPS | DDSD_HEIGHT | DDSD_WIDTH | DDSD_PITCH | DDSD_PIXELFORMAT,
                      h, w, w * 4, 0, 0) + b'\0' * 44
    pf = struct.pack('<II4sIIIII', 32, 0x41, b'\0\0\0\0', 32, 0xff0000, 0xff00, 0xff, 0xff000000)
    caps = struct.pack('<IIIII', 0x1000, 0, 0, 0, 0)
    body = bytearray(w * h * 4)
    body[0::4] = rgba[2::4]   # B
    body[1::4] = rgba[1::4]   # G
    body[2::4] = rgba[0::4]   # R
    body[3::4] = rgba[3::4]   # A
    data = hdr + pf + caps
    assert len(data) == 128
    open(path, 'wb').write(data + bytes(body))

if __name__ == '__main__':
    w, h, raw = read_png_rgba(sys.argv[1])
    write_dds_argb(sys.argv[2], w, h, raw)
    print('wrote', sys.argv[2], w, h)
