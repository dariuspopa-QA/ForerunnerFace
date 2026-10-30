#!/usr/bin/env python3
# Converts a 32-bit ZPixmap xwd dump (xwd -root) to PNG.
import struct, sys
from PIL import Image
d = open(sys.argv[1], 'rb').read()
h = struct.unpack('>25I', d[:100])
hsize, w, ht, bpl, ncolors = h[0], h[4], h[5], h[12], h[19]
off = hsize + ncolors * 12
Image.frombuffer('RGB', (w, ht), d[off:off + bpl * ht], 'raw', 'BGRX', bpl, 1).save(sys.argv[2])
print(w, ht)
