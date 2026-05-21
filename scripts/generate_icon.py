#!/usr/bin/env python3
"""
Generates Claude Helper AppIcon PNGs with liquid-glass styling.
Renders all 10 macOS icon sizes from a 1024px master SVG using rsvg-convert.
"""

import subprocess, os, json, shutil

# Output directory
APPICONSET = os.path.join(
    os.path.dirname(__file__),
    "../Sources/ClaudeHelper/Resources/Assets.xcassets/AppIcon.appiconset"
)

# --------------------------------------------------------------------------
# SVG source — liquid-glass macOS icon
# Design: deep charcoal squircle + frosted glass layering + copper C-arc glow
# --------------------------------------------------------------------------

SVG = """\
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" width="1024" height="1024">
  <defs>
    <!-- Squircle clip (macOS icon shape, ~r=225 superellipse approx) -->
    <clipPath id="sq">
      <rect width="1024" height="1024" rx="225" ry="225"/>
    </clipPath>

    <!-- Glass body: deep dark radial -->
    <radialGradient id="bodyGrad" cx="38%" cy="28%" r="75%">
      <stop offset="0%"   stop-color="#2d2a35"/>
      <stop offset="55%"  stop-color="#1a1820"/>
      <stop offset="100%" stop-color="#0d0c11"/>
    </radialGradient>

    <!-- Subtle blue-teal rim atmosphere -->
    <radialGradient id="rimGrad" cx="50%" cy="50%" r="50%">
      <stop offset="60%"  stop-color="#000000" stop-opacity="0"/>
      <stop offset="100%" stop-color="#3a3d6e" stop-opacity="0.45"/>
    </radialGradient>

    <!-- Glass shine: upper-left highlight -->
    <linearGradient id="shineGrad" x1="5%" y1="3%" x2="55%" y2="50%">
      <stop offset="0%"   stop-color="#ffffff" stop-opacity="0.22"/>
      <stop offset="60%"  stop-color="#ffffff" stop-opacity="0.04"/>
      <stop offset="100%" stop-color="#ffffff" stop-opacity="0"/>
    </linearGradient>

    <!-- Specular top edge -->
    <linearGradient id="topEdge" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%"   stop-color="#ffffff" stop-opacity="0.18"/>
      <stop offset="100%" stop-color="#ffffff" stop-opacity="0"/>
    </linearGradient>

    <!-- Arc glow (copper) -->
    <filter id="arcGlow" x="-40%" y="-40%" width="180%" height="180%">
      <feGaussianBlur in="SourceGraphic" stdDeviation="18" result="blur"/>
      <feColorMatrix in="blur" type="matrix"
        values="1.4 0   0   0  0
                0   0.6 0   0  0
                0   0   0.3 0  0
                0   0   0   1  0" result="tinted"/>
      <feMerge>
        <feMergeNode in="tinted"/>
        <feMergeNode in="SourceGraphic"/>
      </feMerge>
    </filter>

    <!-- Soft inner shadow for depth -->
    <filter id="innerShadow" x="-5%" y="-5%" width="110%" height="110%">
      <feFlood flood-color="#000000" flood-opacity="0.6" result="shadow"/>
      <feComposite in="shadow" in2="SourceGraphic" operator="in" result="inside"/>
      <feGaussianBlur in="inside" stdDeviation="24" result="blurred"/>
      <feComposite in="blurred" in2="SourceGraphic" operator="in"/>
    </filter>
  </defs>

  <g clip-path="url(#sq)">
    <!-- 1. Dark glass body -->
    <rect width="1024" height="1024" fill="url(#bodyGrad)"/>

    <!-- 2. Rim atmosphere -->
    <rect width="1024" height="1024" fill="url(#rimGrad)"/>

    <!-- 3. Noise/texture layer via subtle pattern -->
    <rect width="1024" height="1024" fill="#ffffff" opacity="0.015"/>

    <!-- 4. Inner vignette -->
    <rect width="1024" height="1024" fill="url(#innerShadow)" opacity="0.5"/>

    <!-- 5. Claude C-arc — copper, glowing, centered -->
    <!-- Original: viewBox 0 0 24 24, path M17.55,5.12 A9,9 0 1 0 17.55,18.88 -->
    <!-- Scaled to 1024: multiply by 1024/24 = 42.667 → center ≈ (512,512) -->
    <!-- Translate so arc center (12*scale=512) maps to canvas center -->
    <g transform="translate(512,512) scale(42.667) translate(-12,-12)">
      <path d="M 17.55 5.12 A 9 9 0 1 0 17.55 18.88"
            fill="none"
            stroke="#cc785c"
            stroke-width="2.1"
            stroke-linecap="round"
            filter="url(#arcGlow)"
            opacity="1"/>
    </g>

    <!-- 6. Glass shine overlay -->
    <rect width="1024" height="1024" fill="url(#shineGrad)"/>

    <!-- 7. Specular top-edge highlight (thin strip) -->
    <rect width="1024" height="80" fill="url(#topEdge)"/>

    <!-- 8. Squircle border highlight -->
    <rect width="1024" height="1024" rx="225" ry="225"
          fill="none" stroke="#ffffff" stroke-width="2" opacity="0.12"/>
  </g>
</svg>
"""

SIZES = [
    ("16x16@1x",   16,  "icon_16x16.png"),
    ("16x16@2x",   32,  "icon_16x16@2x.png"),
    ("32x32@1x",   32,  "icon_32x32.png"),
    ("32x32@2x",   64,  "icon_32x32@2x.png"),
    ("128x128@1x", 128, "icon_128x128.png"),
    ("128x128@2x", 256, "icon_128x128@2x.png"),
    ("256x256@1x", 256, "icon_256x256.png"),
    ("256x256@2x", 512, "icon_256x256@2x.png"),
    ("512x512@1x", 512, "icon_512x512.png"),
    ("512x512@2x", 1024,"icon_512x512@2x.png"),
]

CONTENTS = {
    "images": [
        {"idiom": "mac", "scale": "1x", "size": "16x16",   "filename": "icon_16x16.png"},
        {"idiom": "mac", "scale": "2x", "size": "16x16",   "filename": "icon_16x16@2x.png"},
        {"idiom": "mac", "scale": "1x", "size": "32x32",   "filename": "icon_32x32.png"},
        {"idiom": "mac", "scale": "2x", "size": "32x32",   "filename": "icon_32x32@2x.png"},
        {"idiom": "mac", "scale": "1x", "size": "128x128", "filename": "icon_128x128.png"},
        {"idiom": "mac", "scale": "2x", "size": "128x128", "filename": "icon_128x128@2x.png"},
        {"idiom": "mac", "scale": "1x", "size": "256x256", "filename": "icon_256x256.png"},
        {"idiom": "mac", "scale": "2x", "size": "256x256", "filename": "icon_256x256@2x.png"},
        {"idiom": "mac", "scale": "1x", "size": "512x512", "filename": "icon_512x512.png"},
        {"idiom": "mac", "scale": "2x", "size": "512x512", "filename": "icon_512x512@2x.png"},
    ],
    "info": {"author": "xcode", "version": 1}
}

def main():
    os.makedirs(APPICONSET, exist_ok=True)

    # Write master SVG
    svg_path = "/tmp/claude_helper_icon_master.svg"
    with open(svg_path, "w") as f:
        f.write(SVG)

    print(f"Generating {len(SIZES)} icon sizes…")
    for label, px, filename in SIZES:
        out_path = os.path.join(APPICONSET, filename)
        result = subprocess.run(
            ["rsvg-convert", "-w", str(px), "-h", str(px), "-o", out_path, svg_path],
            capture_output=True, text=True
        )
        if result.returncode != 0:
            print(f"  FAILED {label}: {result.stderr.strip()}")
        else:
            size_kb = os.path.getsize(out_path) / 1024
            print(f"  {label:20s} → {filename}  ({size_kb:.1f} KB)")

    # Write Contents.json
    contents_path = os.path.join(APPICONSET, "Contents.json")
    with open(contents_path, "w") as f:
        json.dump(CONTENTS, f, indent=2)
    print(f"\nWrote {contents_path}")
    print("Done.")

if __name__ == "__main__":
    main()
