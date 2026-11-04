"""Minimal DDS reader/writer for SW3 skins (numpy).
read_dds(path) -> dict(header bytes, W, H, fourcc, mips list of raw bytes)
decode(raw, w, h, fourcc) -> HxWx4 uint8 RGBA
encode_level(rgba, fourcc) -> raw bytes (uses Pillow's BCn encoder for one level)
write_dds(path, header128, levels) -> writes header (copied) + level data"""
import struct, io, numpy as np

BPB = {b'DXT1': 8, b'DXT3': 16, b'DXT5': 16}

def read_dds(path):
    d = open(path, 'rb').read()
    assert d[:4] == b'DDS '
    flags, H, W, pitch, depth, mipc = struct.unpack_from('<6I', d, 8)
    fcc = d[84:88]; bpb = BPB[fcc]
    n = max(1, mipc); off = 128; levels = []; w, h = W, H
    for i in range(n):
        sz = max(1, (w + 3) // 4) * max(1, (h + 3) // 4) * bpb
        levels.append(d[off:off + sz]); off += sz
        w, h = max(1, w // 2), max(1, h // 2)
    return dict(header=d[:128], W=W, H=H, fourcc=fcc, mips=levels, trailing=len(d) - off)

def _565(c):
    c = c.astype(np.uint32)
    r = (c >> 11) & 31; g = (c >> 5) & 63; b = c & 31
    return np.stack([(r << 3) | (r >> 2), (g << 2) | (g >> 4), (b << 3) | (b >> 2)], -1).astype(np.int32)

def _color_block(cb, dxt1):
    # cb: N x 8 bytes
    c0 = cb[:, 0].astype(np.uint16) | (cb[:, 1].astype(np.uint16) << 8)
    c1 = cb[:, 2].astype(np.uint16) | (cb[:, 3].astype(np.uint16) << 8)
    p0, p1 = _565(c0), _565(c1)
    four = (c0 > c1) | (not dxt1)
    four = np.broadcast_to(np.asarray(four), c0.shape)
    p2 = np.where(four[:, None], (2 * p0 + p1) // 3, (p0 + p1) // 2)
    p3 = np.where(four[:, None], (p0 + 2 * p1) // 3, 0)
    pal = np.stack([p0, p1, p2, p3], 1)  # N x 4 x 3
    a3 = np.where(four, 255, 0)
    idx = cb[:, 4:8].astype(np.uint32)
    bits = idx[:, 0] | (idx[:, 1] << 8) | (idx[:, 2] << 16) | (idx[:, 3] << 24)
    sel = np.stack([(bits >> (2 * i)) & 3 for i in range(16)], 1)  # N x 16
    rgb = np.take_along_axis(pal, sel[:, :, None].repeat(3, 2), 1)
    alpha = np.where(sel == 3, a3[:, None], 255) if dxt1 else np.full(sel.shape, 255)
    return rgb, alpha

def decode(raw, w, h, fourcc):
    bw, bh = max(1, (w + 3) // 4), max(1, (h + 3) // 4)
    b = np.frombuffer(raw, np.uint8).reshape(bw * bh, BPB[fourcc])
    if fourcc == b'DXT1':
        rgb, a = _color_block(b, True)
    elif fourcc == b'DXT3':
        rgb, _ = _color_block(b[:, 8:], False)
        ab = b[:, :8]
        a = np.stack([(ab[:, i // 2] >> (4 * (i % 2))) & 15 for i in range(16)], 1).astype(np.int32) * 17
    elif fourcc == b'DXT5':
        rgb, _ = _color_block(b[:, 8:], False)
        a0 = b[:, 0].astype(np.int32); a1 = b[:, 1].astype(np.int32)
        bits = np.zeros(len(b), np.uint64)
        for i in range(6): bits |= b[:, 2 + i].astype(np.uint64) << np.uint64(8 * i)
        sel = np.stack([((bits >> np.uint64(3 * i)) & np.uint64(7)).astype(np.int32) for i in range(16)], 1)
        pal = np.zeros((len(b), 8), np.int32); pal[:, 0] = a0; pal[:, 1] = a1
        gt = a0 > a1
        for i in range(1, 7):
            pal[:, i + 1] = np.where(gt, ((7 - i) * a0 + i * a1) // 7, pal[:, i + 1])
        for i in range(1, 5):
            pal[:, i + 1] = np.where(~gt, ((5 - i) * a0 + i * a1) // 5, pal[:, i + 1])
        pal[:, 6] = np.where(~gt, 0, pal[:, 6]); pal[:, 7] = np.where(~gt, 255, pal[:, 7])
        a = np.take_along_axis(pal, sel, 1)
    px = np.concatenate([rgb, a[:, :, None]], 2).astype(np.uint8)  # N x 16 x 4
    img = px.reshape(bh, bw, 4, 4, 4).transpose(0, 2, 1, 3, 4).reshape(bh * 4, bw * 4, 4)
    return img[:h, :w]

def encode_level(rgba, fourcc):
    from PIL import Image
    im = Image.fromarray(np.ascontiguousarray(rgba), 'RGBA')
    bio = io.BytesIO(); im.save(bio, 'DDS', pixel_format=fourcc.decode())
    raw = bio.getvalue()[128:]
    if fourcc == b'DXT3':
        # Pillow 12.3 quantizes DXT3 alpha inexactly (e.g. 34 -> 51, 0 -> 17); write the explicit
        # 4-bit alpha half of every block ourselves: n = round(a / 17), texel i at bits 4*i.
        h, w = rgba.shape[:2]; bh, bw = (h + 3) // 4, (w + 3) // 4
        a = np.zeros((bh * 4, bw * 4), np.uint16); a[:h, :w] = rgba[..., 3]
        n = ((a + 8) // 17).astype(np.uint8)
        blk = n.reshape(bh, 4, bw, 4).transpose(0, 2, 1, 3).reshape(bh * bw, 16)
        packed = (blk[:, 0::2] | (blk[:, 1::2] << 4)).astype(np.uint8)  # 8 bytes per block
        b = np.frombuffer(raw, np.uint8).reshape(bh * bw, 16).copy(); b[:, :8] = packed
        raw = b.tobytes()
    return raw

def mip_chain(rgba, n):
    """Box-filter mip chain (2x2 average, alpha averaged too)."""
    out = [rgba]; cur = rgba.astype(np.float32)
    for _ in range(n - 1):
        h, w = cur.shape[:2]
        if h > 1 and w > 1: cur = cur.reshape(h // 2, 2, w // 2, 2, 4).mean((1, 3))
        elif h > 1: cur = cur.reshape(h // 2, 2, w, 4).mean(1)
        elif w > 1: cur = cur.reshape(h, w // 2, 2, 4).mean(2)
        out.append(np.clip(cur + 0.5, 0, 255).astype(np.uint8))
    return out

def write_dds(path, header128, levels):
    with open(path, 'wb') as f:
        f.write(header128)
        for l in levels: f.write(l)
