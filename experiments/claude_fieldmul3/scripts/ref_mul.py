#!/usr/bin/env python3
import sys
p0 = 0x685acce9767254a4638810719ac425f0e39d54522cdd119f5e9063de245e8001
p1 = 0x7fdb925e8a0ed8d99d124d9a15af79db117e776f218059db80f0da5cb537e38
p2 = 0x01c4c62d92c41110229022eee2cdadb7f997505b8fafed5eb7e8f96c97d873
p = p0 | (p1 << 256) | (p2 << 512)
a0, a1, a2, b0, b1, b2 = map(int, sys.argv[1:])
a = a0 | (a1 << 256) | (a2 << 512)
b = b0 | (b1 << 256) | (b2 << 512)
r = (a * b) % p
print("0x" + r.to_bytes(96, "big").hex())
