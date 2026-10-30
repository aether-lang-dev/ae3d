#!/usr/bin/env python3
"""Per block of a scanline EXR: 'raw' when the writer stored it uncompressed
(PIZ does when it would not be smaller, which every small or noisy file hits),
else, for PIZ, the number of distinct 16-bit values it holds (a rank of 16384
or more takes the wavelet's 16-bit form). A development aid for choosing the
PIZ fixtures; see PIZ.md.   blocks.py file.exr..."""
import struct, sys, os

def info(fn):
    d = open(fn, 'rb').read()
    i = 8; w = h = None; chans = []
    while d[i] != 0:
        n = d.index(b'\0', i); t = d.index(b'\0', n + 1)
        sz = struct.unpack('<I', d[t + 1:t + 5])[0]
        name = d[i:n]; val = d[t + 5:t + 5 + sz]
        if name == b'dataWindow':
            x0, y0, x1, y1 = struct.unpack('<iiii', val); w = x1 - x0 + 1; h = y1 - y0 + 1
        if name == b'channels':
            p = 0
            while val[p] != 0:
                e = val.index(b'\0', p); chans.append(struct.unpack('<i', val[e + 1:e + 5])[0]); p = e + 17
        i = t + 5 + sz
    i += 1
    bpl = sum(2 if c == 1 else 4 for c in chans) * w
    nb = (h + 31) // 32
    offs = [struct.unpack('<Q', d[i + 8 * k:i + 8 * k + 8])[0] for k in range(nb)]
    res = []
    for k, o in enumerate(offs):
        y, sz = struct.unpack('<ii', d[o:o + 8])
        raw = bpl * min(32, h - k * 32)
        if sz == raw:
            res.append('raw'); continue
        b = o + 8
        mn, mx = struct.unpack('<HH', d[b:b + 4])
        cnt = 1
        if mn <= mx:
            bm = bytearray(8192); bm[mn:mx + 1] = d[b + 4:b + 4 + mx - mn + 1]
            cnt = 1 + sum(bin(x).count('1') for x in bm) - (bm[0] & 1)
        res.append(cnt)
    return res

for fn in sys.argv[1:]:
    r = info(fn)
    print(os.path.basename(fn), ' '.join(str(x) for x in r[:8]), '...' if len(r) > 8 else '')
