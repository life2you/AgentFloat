#!/usr/bin/env python3
"""
AgentFloat macOS App Icon Generator - Concept A (Floating HUD Capsule & Status Beacon)
Generates the master 1024x1024 PNG, multi-res iconset, and macOS AppIcon.icns.
"""

from __future__ import annotations
import math
import shutil
import subprocess
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
ASSET_DIR = ROOT / "assets" / "appicon"
MASTER_PNG = ASSET_DIR / "AppIcon-1024.png"
ICONSET_DIR = ASSET_DIR / "AppIcon.iconset"
ICNS_PATH = ASSET_DIR / "AppIcon.icns"
APP_RESOURCES_ICNS = ROOT / "Sources" / "AgentFloatApp" / "Resources" / "AppIcon.icns"

SS = 2
CANVAS_SIZE = 1024 * SS

def S(val: float | int) -> int:
    return int(round(val * SS))

def rounded_rect_mask(size: int, bounds: tuple[int, int, int, int], radius: int) -> Image.Image:
    mask = Image.new("L", (size, size), 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle(bounds, radius=radius, fill=255)
    return mask

def draw_glow(canvas: Image.Image, center: tuple[int, int], radius: int, color: tuple[int, int, int, int], blur: int):
    glow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    gdraw = ImageDraw.Draw(glow)
    cx, cy = center
    gdraw.ellipse((cx - radius, cy - radius, cx + radius, cy + radius), fill=color)
    glow = glow.filter(ImageFilter.GaussianBlur(blur))
    canvas.alpha_composite(glow)

def build_master_icon() -> Image.Image:
    size = CANVAS_SIZE
    output = Image.new("RGBA", (size, size), (0, 0, 0, 0))

    sq_x0, sq_y0, sq_x1, sq_y1 = S(112), S(112), S(912), S(912)
    sq_radius = S(184)
    sq_h = sq_y1 - sq_y0

    # System Drop Shadow below Squircle
    sq_shadow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    ss_draw = ImageDraw.Draw(sq_shadow)
    ss_draw.rounded_rectangle((sq_x0 + S(6), sq_y0 + S(34), sq_x1 - S(6), sq_y1 + S(50)), radius=sq_radius, fill=(0, 0, 0, 140))
    ss_draw.rounded_rectangle((sq_x0 + S(16), sq_y0 + S(52), sq_x1 - S(16), sq_y1 + S(68)), radius=sq_radius, fill=(0, 0, 0, 100))
    sq_shadow = sq_shadow.filter(ImageFilter.GaussianBlur(S(36)))
    output.alpha_composite(sq_shadow)

    # Base Squircle Gradient: Deep Cosmic Obsidian (#141726 -> #090B12)
    base = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    b_pixels = base.load()
    top_color = (20, 24, 38)
    bottom_color = (9, 11, 18)

    for y in range(sq_y0, sq_y1 + 1):
        ty = (y - sq_y0) / sq_h
        r = int(top_color[0] + (bottom_color[0] - top_color[0]) * ty)
        g = int(top_color[1] + (bottom_color[1] - top_color[1]) * ty)
        b = int(top_color[2] + (bottom_color[2] - top_color[2]) * ty)
        for x in range(sq_x0, sq_x1 + 1):
            b_pixels[x, y] = (r, g, b, 255)

    # Ambient Glows
    draw_glow(base, (S(700), S(300)), S(280), (16, 185, 129, 95), S(100))  # Emerald top-right
    draw_glow(base, (S(300), S(720)), S(260), (56, 189, 248, 80), S(90))   # Cyan bottom-left
    draw_glow(base, (S(512), S(512)), S(220), (99, 102, 241, 60), S(85))   # Center aura

    # Background subtle radial rings (Radar / Sounding pulse)
    rings = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    rdraw = ImageDraw.Draw(rings)
    cx, cy = S(512), S(512)
    for r in [S(220), S(310), S(390)]:
        rdraw.ellipse((cx - r, cy - r, cx + r, cy + r), outline=(255, 255, 255, 12), width=S(1.5))
    base.alpha_composite(rings)

    # Hero Element: 3D Floating HUD Capsule
    cap_w, cap_h = S(580), S(240)
    cap_x0 = cx - cap_w // 2
    cap_y0 = cy - cap_h // 2
    cap_x1 = cap_x0 + cap_w
    cap_y1 = cap_y0 + cap_h
    cap_r = cap_h // 2

    # Capsule 3D Drop Shadow
    cap_shadow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    cs_draw = ImageDraw.Draw(cap_shadow)
    cs_draw.rounded_rectangle((cap_x0 + S(8), cap_y0 + S(36), cap_x1 - S(8), cap_y1 + S(54)), radius=cap_r, fill=(0, 0, 0, 190))
    cs_draw.rounded_rectangle((cap_x0 + S(16), cap_y0 + S(54), cap_x1 - S(16), cap_y1 + S(74)), radius=cap_r, fill=(0, 0, 0, 120))
    cap_shadow = cap_shadow.filter(ImageFilter.GaussianBlur(S(36)))
    base.alpha_composite(cap_shadow)

    # Capsule Frosted Glass Body
    cap_surf = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    cdraw = ImageDraw.Draw(cap_surf)
    cdraw.rounded_rectangle((cap_x0, cap_y0, cap_x1, cap_y1), radius=cap_r, fill=(24, 32, 52, 235), outline=(255, 255, 255, 60), width=S(2))
    # Top highlight sheen
    cdraw.rounded_rectangle((cap_x0 + S(2), cap_y0 + S(2), cap_x1 - S(2), cap_y0 + cap_h // 2), radius=cap_r, fill=(255, 255, 255, 22))

    # Left: Luminous Emerald Status Beacon (The "Completed & Live" Sentinel)
    beacon_cx = cap_x0 + cap_h // 2
    beacon_cy = cy

    # Beacon pulse rings
    draw_glow(cap_surf, (beacon_cx, beacon_cy), S(75), (16, 185, 129, 140), S(25))
    cdraw.ellipse((beacon_cx - S(48), beacon_cy - S(48), beacon_cx + S(48), beacon_cy + S(48)), outline=(52, 211, 153, 140), width=S(2))
    cdraw.ellipse((beacon_cx - S(32), beacon_cy - S(32), beacon_cx + S(32), beacon_cy + S(32)), fill=(16, 185, 129, 255))
    cdraw.ellipse((beacon_cx - S(18), beacon_cy - S(18), beacon_cx + S(18), beacon_cy + S(18)), fill=(209, 250, 229, 255))
    cdraw.ellipse((beacon_cx - S(8), beacon_cy - S(8), beacon_cx + S(8), beacon_cy + S(8)), fill=(255, 255, 255, 255))

    # Center-Right: High-Tech HUD Activity Waveform & Floating Badge
    line_x_start = beacon_cx + S(80)
    line_x_end = cap_x1 - S(60)

    # Activity bars / waveform
    bars = [S(24), S(42), S(70), S(96), S(65), S(88), S(45), S(60), S(35)]
    bar_step = (line_x_end - line_x_start) / (len(bars) - 1)
    for i, bh in enumerate(bars):
        bx = int(line_x_start + i * bar_step)
        by0 = cy - bh // 2
        by1 = cy + bh // 2
        t = i / (len(bars) - 1)
        bar_color = (
            int(56 + (52 - 56) * t),
            int(189 + (211 - 189) * t),
            int(248 + (153 - 248) * t),
            230
        )
        cdraw.rounded_rectangle((bx - S(5), by0, bx + S(5), by1), radius=S(4), fill=bar_color)

    # Floating Satellite Sparkle on top-right of capsule
    sat_cx, sat_cy = cap_x1 - S(20), cap_y0 - S(20)
    draw_glow(cap_surf, (sat_cx, sat_cy), S(45), (56, 189, 248, 160), S(15))
    sparkle_pts = [
        (sat_cx, sat_cy - S(40)),
        (sat_cx + S(10), sat_cy - S(10)),
        (sat_cx + S(40), sat_cy),
        (sat_cx + S(10), sat_cy + S(10)),
        (sat_cx, sat_cy + S(40)),
        (sat_cx - S(10), sat_cy + S(10)),
        (sat_cx - S(40), sat_cy),
        (sat_cx - S(10), sat_cy - S(10)),
    ]
    cdraw.polygon(sparkle_pts, fill=(255, 255, 255, 255))

    base.alpha_composite(cap_surf)

    # Outer Squircle Rim Bevel
    rim = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    rdraw = ImageDraw.Draw(rim)
    rdraw.rounded_rectangle((sq_x0, sq_y0, sq_x1, sq_y1), radius=sq_radius, outline=(255, 255, 255, 45), width=S(2))
    rdraw.line((sq_x0 + S(110), sq_y0 + S(1.5), sq_x1 - S(110), sq_y0 + S(1.5)), fill=(255, 255, 255, 95), width=S(2))
    base.alpha_composite(rim)

    # Mask to Squircle
    mask = rounded_rect_mask(size, (sq_x0, sq_y0, sq_x1, sq_y1), sq_radius)
    output.paste(base, (0, 0), mask)

    # 2x Lanczos Downsampling to 1024x1024
    final_img = output.resize((1024, 1024), Image.Resampling.LANCZOS)
    return final_img

def ensure_iconset(master: Image.Image) -> None:
    if ICONSET_DIR.exists():
        shutil.rmtree(ICONSET_DIR)
    ICONSET_DIR.mkdir(parents=True, exist_ok=True)

    sizes = [
        ("icon_16x16.png", 16),
        ("icon_16x16@2x.png", 32),
        ("icon_32x32.png", 32),
        ("icon_32x32@2x.png", 64),
        ("icon_128x128.png", 128),
        ("icon_128x128@2x.png", 256),
        ("icon_256x256.png", 256),
        ("icon_256x256@2x.png", 512),
        ("icon_512x512.png", 512),
        ("icon_512x512@2x.png", 1024),
    ]

    for filename, px in sizes:
        resized = master.resize((px, px), Image.Resampling.LANCZOS)
        resized.save(ICONSET_DIR / filename)

def build_icns() -> None:
    subprocess.run(
        ["/usr/bin/iconutil", "-c", "icns", str(ICONSET_DIR), "-o", str(ICNS_PATH)],
        check=True,
    )
    APP_RESOURCES_ICNS.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(ICNS_PATH, APP_RESOURCES_ICNS)

def main():
    ASSET_DIR.mkdir(parents=True, exist_ok=True)
    print("🎨 正在生成 AgentFloat 灵动悬浮舱官方应用图标...")
    master = build_master_icon()
    master.save(MASTER_PNG)
    print(f"✅ 生成高清 Master PNG: {MASTER_PNG}")
    ensure_iconset(master)
    print(f"✅ 生成 Multi-res Iconset: {ICONSET_DIR}")
    build_icns()
    print(f"✅ 生成 macOS AppIcon.icns: {ICNS_PATH}")
    print(f"✅ 已同步至工程资源目录: {APP_RESOURCES_ICNS}")

if __name__ == "__main__":
    main()
