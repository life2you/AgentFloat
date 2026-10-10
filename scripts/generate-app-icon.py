#!/usr/bin/env python3
"""
AgentFloat macOS App Icon Generator (Harmonious Spacing Edition)
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


def quadratic_bezier(p0: tuple[float, float], p_ctrl: tuple[float, float], p1: tuple[float, float], steps: int = 24) -> list[tuple[float, float]]:
    pts = []
    for i in range(steps):
        t = i / steps
        one_minus_t = 1.0 - t
        x = (one_minus_t ** 2) * p0[0] + 2 * one_minus_t * t * p_ctrl[0] + (t ** 2) * p1[0]
        y = (one_minus_t ** 2) * p0[1] + 2 * one_minus_t * t * p_ctrl[1] + (t ** 2) * p1[1]
        pts.append((x, y))
    return pts


def create_bezier_sparkle(cx: float, cy: float, radius: float, steps: int = 24) -> list[tuple[float, float]]:
    """Creates a mathematically pristine Apple/AI 4-point sparkle star."""
    top = (cx, cy - radius)
    right = (cx + radius, cy)
    bottom = (cx, cy + radius)
    left = (cx - radius, cy)
    ctrl = (cx, cy)
    
    curve1 = quadratic_bezier(top, ctrl, right, steps)
    curve2 = quadratic_bezier(right, ctrl, bottom, steps)
    curve3 = quadratic_bezier(bottom, ctrl, left, steps)
    curve4 = quadratic_bezier(left, ctrl, top, steps)
    
    return curve1 + curve2 + curve3 + curve4


def build_master_icon() -> Image.Image:
    size = CANVAS_SIZE
    output = Image.new("RGBA", (size, size), (0, 0, 0, 0))

    # --- 1. Base Squircle Dimensions ---
    sq_x0, sq_y0, sq_x1, sq_y1 = S(112), S(112), S(912), S(912)
    sq_w = sq_x1 - sq_x0
    sq_h = sq_y1 - sq_y0
    sq_radius = S(184)

    # --- 2. System Drop Shadow below Squircle ---
    sq_shadow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    ss_draw = ImageDraw.Draw(sq_shadow)
    ss_draw.rounded_rectangle((sq_x0 + S(6), sq_y0 + S(32), sq_x1 - S(6), sq_y1 + S(48)), radius=sq_radius, fill=(0, 0, 0, 135))
    ss_draw.rounded_rectangle((sq_x0 + S(16), sq_y0 + S(50), sq_x1 - S(16), sq_y1 + S(66)), radius=sq_radius, fill=(0, 0, 0, 95))
    sq_shadow = sq_shadow.filter(ImageFilter.GaussianBlur(S(36)))
    output.alpha_composite(sq_shadow)

    # --- 3. Base Squircle Canvas ---
    base = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    b_pixels = base.load()

    # Premium Deep Cosmic Gradient: Midnight Obsidian (#151828) -> Deep Charcoal (#0A0C13)
    top_color = (21, 24, 40)
    bottom_color = (10, 12, 19)

    for y in range(sq_y0, sq_y1 + 1):
        ty = (y - sq_y0) / sq_h
        r = int(top_color[0] + (bottom_color[0] - top_color[0]) * ty)
        g = int(top_color[1] + (bottom_color[1] - top_color[1]) * ty)
        b = int(top_color[2] + (bottom_color[2] - top_color[2]) * ty)
        for x in range(sq_x0, sq_x1 + 1):
            b_pixels[x, y] = (r, g, b, 255)

    # Ambient Atmospheric Lighting on Base
    draw_glow(base, (S(740), S(230)), S(260), (16, 185, 129, 90), S(95))   # Top-right emerald
    draw_glow(base, (S(260), S(780)), S(270), (99, 102, 241, 75), S(95))   # Bottom-left indigo
    draw_glow(base, (S(512), S(512)), S(210), (56, 189, 248, 65), S(85))   # Center cyan aura

    # High-tech background grid dots
    grid_img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    gdraw = ImageDraw.Draw(grid_img)
    step = S(48)
    for gx in range(sq_x0 + S(36), sq_x1 - S(36), step):
        for gy in range(sq_y0 + S(36), sq_y1 - S(36), step):
            gdraw.ellipse((gx - S(1.5), gy - S(1.5), gx + S(1.5), gy + S(1.5)), fill=(255, 255, 255, 16))
    base.alpha_composite(grid_img)

    # --- 4. Layer 1: Background Secondary Floating Card (Stacking Depth) ---
    bg_card_x0, bg_card_y0, bg_card_x1, bg_card_y1 = S(246), S(206), S(778), S(420)
    bg_radius = S(46)
    
    bg_shadow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    bgs_draw = ImageDraw.Draw(bg_shadow)
    bgs_draw.rounded_rectangle((bg_card_x0, bg_card_y0 + S(18), bg_card_x1, bg_card_y1 + S(28)), radius=bg_radius, fill=(0, 0, 0, 115))
    bg_shadow = bg_shadow.filter(ImageFilter.GaussianBlur(S(22)))
    base.alpha_composite(bg_shadow)

    bg_card = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    bgc_draw = ImageDraw.Draw(bg_card)
    bgc_draw.rounded_rectangle(
        (bg_card_x0, bg_card_y0, bg_card_x1, bg_card_y1),
        radius=bg_radius,
        fill=(32, 40, 64, 155),
        outline=(255, 255, 255, 30),
        width=S(1.5)
    )
    base.alpha_composite(bg_card)

    # --- 5. Layer 2: Hero Floating Card (The Active Window) ---
    fc_x0, fc_y0, fc_x1, fc_y1 = S(194), S(266), S(830), S(804)
    fc_radius = S(56)

    # 3D Floating Shadow cast on base
    fc_shadow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    fcs_draw = ImageDraw.Draw(fc_shadow)
    fcs_draw.rounded_rectangle((fc_x0 + S(4), fc_y0 + S(28), fc_x1 - S(4), fc_y1 + S(46)), radius=fc_radius, fill=(0, 0, 0, 185))
    fcs_draw.rounded_rectangle((fc_x0 + S(14), fc_y0 + S(44), fc_x1 - S(14), fc_y1 + S(64)), radius=fc_radius, fill=(0, 0, 0, 125))
    fc_shadow = fc_shadow.filter(ImageFilter.GaussianBlur(S(32)))
    base.alpha_composite(fc_shadow)

    # Frosted Glass Card Surface
    fc_surf = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    fcsurf_draw = ImageDraw.Draw(fc_surf)

    # Dark frosted glass fill
    fcsurf_draw.rounded_rectangle(
        (fc_x0, fc_y0, fc_x1, fc_y1),
        radius=fc_radius,
        fill=(24, 30, 48, 240),
        outline=(255, 255, 255, 45),
        width=S(2)
    )

    # Glass top sheen
    sheen = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    sheen_draw = ImageDraw.Draw(sheen)
    sheen_draw.rounded_rectangle(
        (fc_x0 + S(2), fc_y0 + S(2), fc_x1 - S(2), fc_y0 + S(84)),
        radius=fc_radius,
        fill=(255, 255, 255, 18)
    )
    fc_surf.alpha_composite(sheen)

    # Window Header Traffic Lights
    dot_y = fc_y0 + S(44)
    dot_r = S(10)
    # Red
    fcsurf_draw.ellipse((fc_x0 + S(44) - dot_r, dot_y - dot_r, fc_x0 + S(44) + dot_r, dot_y + dot_r), fill=(244, 63, 94, 235))
    # Yellow
    fcsurf_draw.ellipse((fc_x0 + S(74) - dot_r, dot_y - dot_r, fc_x0 + S(74) + dot_r, dot_y + dot_r), fill=(251, 191, 36, 235))
    # Green (Active notification state with micro-glow)
    fcsurf_draw.ellipse((fc_x0 + S(104) - dot_r, dot_y - dot_r, fc_x0 + S(104) + dot_r, dot_y + dot_r), fill=(52, 211, 153, 255))

    # Header Divider Line
    header_line_y = fc_y0 + S(82)
    fcsurf_draw.line((fc_x0, header_line_y, fc_x1, header_line_y), fill=(255, 255, 255, 25), width=S(1.2))

    # Right-side Header Badge: AgentFloat status pill (matching in-app "1 pending" badge)
    badge_w, badge_h = S(76), S(24)
    badge_x1 = fc_x1 - S(38)
    badge_x0 = badge_x1 - badge_w
    badge_y0 = dot_y - badge_h // 2
    badge_y1 = badge_y0 + badge_h
    fcsurf_draw.rounded_rectangle((badge_x0, badge_y0, badge_x1, badge_y1), radius=badge_h // 2, fill=(16, 185, 129, 45), outline=(52, 211, 153, 160), width=S(1))
    fcsurf_draw.ellipse((badge_x0 + S(12) - S(4), dot_y - S(4), badge_x0 + S(12) + S(4), dot_y + S(4)), fill=(52, 211, 153, 255))
    fcsurf_draw.line((badge_x0 + S(24), dot_y, badge_x1 - S(14), dot_y), fill=(255, 255, 255, 180), width=S(2.5))

    base.alpha_composite(fc_surf)

    # --- 6. Foreground Hero Glyph Area ---
    glyph_cx = (fc_x0 + fc_x1) // 2
    glyph_cy = (header_line_y + fc_y1) // 2

    # A. Volumetric Ambient Glow behind Hero Emblem
    draw_glow(base, (glyph_cx - S(110), glyph_cy), S(135), (56, 189, 248, 115), S(42))
    draw_glow(base, (glyph_cx + S(90), glyph_cy), S(145), (52, 211, 153, 130), S(45))

    # B. Continuous Seamless Terminal Chevron `>` (Refined Proportion & Spacing)
    ch_layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    ch_draw = ImageDraw.Draw(ch_layer)

    ch_left = glyph_cx - S(185)
    ch_apex = glyph_cx - S(70)
    ch_top = glyph_cy - S(105)
    ch_bot = glyph_cy + S(105)
    stroke_w = S(34)

    ch_pts = [(ch_left, ch_top), (ch_apex, glyph_cy), (ch_left, ch_bot)]
    ch_draw.line(ch_pts, fill=(56, 189, 248, 255), width=stroke_w, joint="curve")

    # Round caps for top & bottom
    cap_r = stroke_w // 2
    ch_draw.ellipse((ch_left - cap_r, ch_top - cap_r, ch_left + cap_r, ch_top + cap_r), fill=(56, 189, 248, 255))
    ch_draw.ellipse((ch_left - cap_r, ch_bot - cap_r, ch_left + cap_r, ch_bot + cap_r), fill=(56, 189, 248, 255))

    # Inner Core Specular Highlight (Crisp White Line)
    spec_w = S(10)
    ch_draw.line(ch_pts, fill=(240, 253, 250, 230), width=spec_w, joint="curve")
    base.alpha_composite(ch_layer)

    # C. Pristine Bezier AI Agent Star `✦` (Perfect Breathing Room)
    star_layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    sdraw = ImageDraw.Draw(star_layer)

    star_cx = glyph_cx + S(90)
    star_cy = glyph_cy
    star_radius = S(118)

    star_pts = create_bezier_sparkle(star_cx, star_cy, star_radius, steps=32)
    
    # Soft core glow
    draw_glow(star_layer, (star_cx, star_cy), S(65), (255, 255, 255, 180), S(18))
    draw_glow(star_layer, (star_cx, star_cy), S(115), (52, 211, 153, 140), S(36))

    # Star Polygon Fill (Crisp pure white with cyan halo)
    sdraw.polygon(star_pts, fill=(255, 255, 255, 255))

    # Brilliant central lens glint
    sdraw.ellipse((star_cx - S(12), star_cy - S(12), star_cx + S(12), star_cy + S(12)), fill=(255, 255, 255, 255))

    # Satellite Accent Sparkle (Top-Right of Star)
    sat_cx, sat_cy = star_cx + S(84), star_cy - S(76)
    sat_pts = create_bezier_sparkle(sat_cx, sat_cy, S(36), steps=20)
    sdraw.polygon(sat_pts, fill=(56, 189, 248, 245))

    base.alpha_composite(star_layer)

    # --- 7. Outer Squircle Rim Bevel / Inner Highlight ---
    rim = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    rdraw = ImageDraw.Draw(rim)
    rdraw.rounded_rectangle(
        (sq_x0, sq_y0, sq_x1, sq_y1),
        radius=sq_radius,
        outline=(255, 255, 255, 46),
        width=S(2)
    )
    # Top edge light reflection
    rdraw.line((sq_x0 + S(110), sq_y0 + S(1.5), sq_x1 - S(110), sq_y0 + S(1.5)), fill=(255, 255, 255, 95), width=S(2))
    base.alpha_composite(rim)

    # --- 8. Final Squircle Mask Application ---
    mask = rounded_rect_mask(size, (sq_x0, sq_y0, sq_x1, sq_y1), sq_radius)
    output.paste(base, (0, 0), mask)

    # Downscale from 2048 to 1024 with LANCZOS for razor-sharp, flawless anti-aliasing
    final_master = output.resize((1024, 1024), Image.Resampling.LANCZOS)
    return final_master


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


def main() -> None:
    ASSET_DIR.mkdir(parents=True, exist_ok=True)
    print("🎨 正在生成和谐版 AgentFloat 原生应用图标...")
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
