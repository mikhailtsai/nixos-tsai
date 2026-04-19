#!/usr/bin/env python3
"""
Merge a base .conf.dist file with an overrides file.
Keys present in the dist file are replaced in-place.
Keys not present in the dist file are appended at the end.
Usage: merge-conf.py <dist_file> <overrides_file> <output_file>
"""
import re, sys

with open(sys.argv[1]) as f:
    dist = f.read()
with open(sys.argv[2]) as f:
    over_text = f.read()

# Parse overrides: key -> full line
overrides = {}
for line in over_text.splitlines():
    m = re.match(r'^([A-Za-z][A-Za-z0-9_.]*)\s*=', line)
    if m:
        overrides[m.group(1)] = line.rstrip()

replaced = set()
out_lines = []
for line in dist.splitlines():
    m = re.match(r'^([A-Za-z][A-Za-z0-9_.]*)\s*=', line)
    if m and m.group(1) in overrides:
        out_lines.append(overrides[m.group(1)])
        replaced.add(m.group(1))
    else:
        out_lines.append(line)

extra = [v for k, v in overrides.items() if k not in replaced]
if extra:
    out_lines += ['', '# NixOS extra settings (not in dist)'] + extra

with open(sys.argv[3], 'w') as f:
    f.write('\n'.join(out_lines) + '\n')
