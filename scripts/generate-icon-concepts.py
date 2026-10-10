#!/usr/bin/env python3
"""
AgentFloat App Icon Concepts Generator
Generates 3 distinct high-res (1024x1024) icon concepts:
- Concept A: 灵动悬浮舱 / 状态浮标 (Floating HUD Capsule & Status Beacon)
- Concept B: 多层悬浮玻璃卡片 (Stacked Translucent Floating Cards)
- Concept C: 极简现代几何棱镜 / 哨兵 (Minimalist Floating Prism & Sentinel Diamond)
"""

from __future__ import annotations
import math
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
OUTPUT_DIR = ROOT / "assets" / "appicon"
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

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

def make_base_canvas() -> tuple[Image.Image, Image.Image, tuple[int, int, int, int], int]:
    """Returns (output_canvas, base_canvas, squircle_bounds, squircle_radius)"""
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

    return output, base, (sq_x0, sq_y0, sq_x1, sq_y1), sq_radius

def finish_and_save(output: Image.Image, base: Image.Image, bounds: tuple[int, int, int, int], radius: int, out_path: Path):
    size = CANVAS_SIZE
    sq_x0, sq_y0, sq_x1, sq_y1 = bounds

    # Outer Squircle Rim Bevel
    rim = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    rdraw = ImageDraw.Draw(rim)
    rdraw.rounded_rectangle(bounds, radius=radius, outline=(255, 255, 255, 45), width=S(2))
    rdraw.line((sq_x0 + S(110), sq_y0 + S(1.5), sq_x1 - S(110), sq_y0 + S(1.5)), fill=(255, 255, 255, 95), width=S(2))
    base.alpha_composite(rim)

    # Mask to Squircle
    mask = rounded_rect_mask(size, bounds, radius)
    output.paste(base, (0, 0), mask)

    # 2x Lanczos Downsampling to 1024x1024
    final_img = output.resize((1024, 1024), Image.Resampling.LANCZOS)
    final_img.save(out_path)
    print(f"✅ 生成概念图: {out_path.name}")


# ==============================================================================
# Concept A: 灵动悬浮舱 / 状态浮标 (Floating HUD Capsule & Status Beacon)
# ==============================================================================
def generate_concept_a():
    output, base, bounds, radius = make_base_canvas()
    sq_x0, sq_y0, sq_x1, sq_y1 = bounds

    # Ambient Glows
    draw_glow(base, (S(700), S(300)), S(280), (16, 185, 129, 95), S(100))  # Emerald top-right
    draw_glow(base, (S(300), S(720)), S(260), (56, 189, 248, 80), S(90))   # Cyan bottom-left
    draw_glow(base, (S(512), S(512)), S(220), (99, 102, 241, 60), S(85))   # Center aura

    # Background subtle radial rings (Radar / Sounding pulse)
    rings = Image.new("RGBA", (CANVAS_SIZE, CANVAS_SIZE), (0, 0, 0, 0))
    rdraw = ImageDraw.Draw(rings)
    cx, cy = S(512), S(512)
    for r in [S(220), S(310), S(390)]:
        rdraw.ellipse((cx - r, cy - r, cx + r, cy + r), outline=(255, 255, 255, 12), width=S(1.5))
    base.alpha_composite(rings)

    # Hero Element: 3D Floating HUD Capsule
    # Elevated capsule centered at (512, 512)
    cap_w, cap_h = S(580), S(240)
    cap_x0 = cx - cap_w // 2
    cap_y0 = cy - cap_h // 2
    cap_x1 = cap_x0 + cap_w
    cap_y1 = cap_y0 + cap_h
    cap_r = cap_h // 2

    # Capsule 3D Drop Shadow
    cap_shadow = Image.new("RGBA", (CANVAS_SIZE, CANVAS_SIZE), (0, 0, 0, 0))
    cs_draw = ImageDraw.Draw(cap_shadow)
    cs_draw.rounded_rectangle((cap_x0 + S(8), cap_y0 + S(36), cap_x1 - S(8), cap_y1 + S(54)), radius=cap_r, fill=(0, 0, 0, 190))
    cs_draw.rounded_rectangle((cap_x0 + S(16), cap_y0 + S(54), cap_x1 - S(16), cap_y1 + S(74)), radius=cap_r, fill=(0, 0, 0, 120))
    cap_shadow = cap_shadow.filter(ImageFilter.GaussianBlur(S(36)))
    base.alpha_composite(cap_shadow)

    # Capsule Frosted Glass Body
    cap_surf = Image.new("RGBA", (CANVAS_SIZE, CANVAS_SIZE), (0, 0, 0, 0))
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

    # Activity bars / audio-style waveform (Agent thinking / settling)
    bars = [S(24), S(42), S(70), S(96), S(65), S(88), S(45), S(60), S(35)]
    bar_step = (line_x_end - line_x_start) / (len(bars) - 1)
    for i, bh in enumerate(bars):
        bx = int(line_x_start + i * bar_step)
        by0 = cy - bh // 2
        by1 = cy + bh // 2
        # Gradient colors from Cyan to Mint
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
    # 4-point sparkle
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
    finish_and_save(output, base, bounds, radius, OUTPUT_DIR / "concept_A_capsule.png")


# ==============================================================================
# Concept B: 多层悬浮卡片堆叠 (Stacked Floating Glass Cards)
# ==============================================================================
def generate_concept_b():
    output, base, bounds, radius = make_base_canvas()
    sq_x0, sq_y0, sq_x1, sq_y1 = bounds
    cx, cy = S(512), S(512)

    # Ambient Lighting
    draw_glow(base, (S(720), S(260)), S(280), (16, 185, 129, 90), S(100))
    draw_glow(base, (S(260), S(760)), S(280), (99, 102, 241, 85), S(100))

    # Dot grid background
    dots = Image.new("RGBA", (CANVAS_SIZE, CANVAS_SIZE), (0, 0, 0, 0))
    ddraw = ImageDraw.Draw(dots)
    step = S(48)
    for gx in range(sq_x0 + S(36), sq_x1 - S(36), step):
        for gy in range(sq_y0 + S(36), sq_y1 - S(36), step):
            ddraw.ellipse((gx - S(1.5), gy - S(1.5), gx + S(1.5), gy + S(1.5)), fill=(255, 255, 255, 16))
    base.alpha_composite(dots)

    card_w = S(540)
    card_h = S(270)
    card_r = S(48)

    # --- 1. Bottom / Deepest Card ---
    c1_x0 = cx - card_w // 2 - S(40)
    c1_y0 = cy - card_h // 2 - S(90)
    c1_x1 = c1_x0 + card_w
    c1_y1 = c1_y0 + card_h

    c1_layer = Image.new("RGBA", (CANVAS_SIZE, CANVAS_SIZE), (0, 0, 0, 0))
    c1_draw = ImageDraw.Draw(c1_layer)
    c1_draw.rounded_rectangle((c1_x0, c1_y0, c1_x1, c1_y1), radius=card_r, fill=(28, 36, 56, 130), outline=(255, 255, 255, 25), width=S(1.5))
    base.alpha_composite(c1_layer)

    # --- 2. Middle Card ---
    c2_x0 = cx - card_w // 2 - S(20)
    c2_y0 = cy - card_h // 2 - S(45)
    c2_x1 = c2_x0 + card_w
    c2_y1 = c2_y0 + card_h

    # Middle shadow
    c2_sh = Image.new("RGBA", (CANVAS_SIZE, CANVAS_SIZE), (0, 0, 0, 0))
    c2s_draw = ImageDraw.Draw(c2_sh)
    c2s_draw.rounded_rectangle((c2_x0, c2_y0 + S(18), c2_x1, c2_y1 + S(28)), radius=card_r, fill=(0, 0, 0, 110))
    c2_sh = c2_sh.filter(ImageFilter.GaussianBlur(S(18)))
    base.alpha_composite(c2_sh)

    c2_layer = Image.new("RGBA", (CANVAS_SIZE, CANVAS_SIZE), (0, 0, 0, 0))
    c2_draw = ImageDraw.Draw(c2_layer)
    c2_draw.rounded_rectangle((c2_x0, c2_y0, c2_x1, c2_y1), radius=card_r, fill=(32, 42, 68, 175), outline=(255, 255, 255, 38), width=S(1.8))
    base.alpha_composite(c2_layer)

    # --- 3. Hero Top Card ---
    c3_x0 = cx - card_w // 2 + S(20)
    c3_y0 = cy - card_h // 2 + S(20)
    c3_x1 = c3_x0 + card_w
    c3_y1 = c3_y0 + card_h

    # Hero shadow
    c3_sh = Image.new("RGBA", (CANVAS_SIZE, CANVAS_SIZE), (0, 0, 0, 0))
    c3s_draw = ImageDraw.Draw(c3_sh)
    c3s_draw.rounded_rectangle((c3_x0 + S(4), c3_y0 + S(32), c3_x1 - S(4), c3_y1 + S(50)), radius=card_r, fill=(0, 0, 0, 190))
    c3_sh = c3_sh.filter(ImageFilter.GaussianBlur(S(28)))
    base.alpha_composite(c3_sh)

    c3_layer = Image.new("RGBA", (CANVAS_SIZE, CANVAS_SIZE), (0, 0, 0, 0))
    c3_draw = ImageDraw.Draw(c3_layer)
    c3_draw.rounded_rectangle((c3_x0, c3_y0, c3_x1, c3_y1), radius=card_r, fill=(24, 32, 54, 242), outline=(255, 255, 255, 60), width=S(2))
    # Top glass sheen
    c3_draw.rounded_rectangle((c3_x0 + S(2), c3_y0 + S(2), c3_x1 - S(2), c3_y0 + S(80)), radius=card_r, fill=(255, 255, 255, 20))

    # Hero Card Content: Glowing Verification Badge & Pill
    badge_cx = c3_x0 + S(90)
    badge_cy = (c3_y0 + c3_y1) // 2

    draw_glow(c3_layer, (badge_cx, badge_cy), S(65), (16, 185, 129, 140), S(22))
    # Verification Circle with Glowing Checkmark
    c3_draw.ellipse((badge_cx - S(42), badge_cy - S(42), badge_cx + S(42), badge_cy + S(42)), fill=(16, 185, 129, 255), outline=(52, 211, 153, 200), width=S(2))
    # Thick modern checkmark
    chk_p1 = (badge_cx - S(18), badge_cy - S(2))
    chk_p2 = (badge_cx - S(6), badge_cy + S(12))
    chk_p3 = (badge_cx + S(18), badge_cy - S(14))
    c3_draw.line([chk_p1, chk_p2, chk_p3], fill=(255, 255, 255, 255), width=S(9), joint="curve")

    # Card Title / Summary Pills
    pill_x0 = badge_cx + S(65)
    c3_draw.rounded_rectangle((pill_x0, badge_cy - S(24), pill_x0 + S(220), badge_cy - S(4)), radius=S(10), fill=(255, 255, 255, 230))
    c3_draw.rounded_rectangle((pill_x0, badge_cy + S(8), pill_x0 + S(150), badge_cy + S(22)), radius=S(7), fill=(56, 189, 248, 160))

    # Top-right tiny status pulse dot
    dot_cx, dot_cy = c3_x1 - S(42), c3_y0 + S(36)
    draw_glow(c3_layer, (dot_cx, dot_cy), S(24), (52, 211, 153, 160), S(8))
    c3_draw.ellipse((dot_cx - S(8), dot_cy - S(8), dot_cx + S(8), dot_cy + S(8)), fill=(52, 211, 153, 255))

    base.alpha_composite(c3_layer)
    finish_and_save(output, base, bounds, radius, OUTPUT_DIR / "concept_B_cards.png")


# ==============================================================================
# Concept C: 极简现代几何棱镜 / 哨兵 (Minimalist Floating Prism & Sentinel Diamond)
# ==============================================================================
def generate_concept_c():
    output, base, bounds, radius = make_base_canvas()
    sq_x0, sq_y0, sq_x1, sq_y1 = bounds
    cx, cy = S(512), S(512)

    # Rich Atmospheric Background Lighting
    draw_glow(base, (S(700), S(260)), S(290), (16, 185, 129, 90), S(100))   # Mint top-right
    draw_glow(base, (S(280), S(740)), S(290), (99, 102, 241, 85), S(100))   # Violet bottom-left
    draw_glow(base, (cx, cy), S(240), (56, 189, 248, 80), S(90))             # Cyan center

    # Gyroscopic / Orbital Floating Rings (Levitation feel)
    orbit = Image.new("RGBA", (CANVAS_SIZE, CANVAS_SIZE), (0, 0, 0, 0))
    odraw = ImageDraw.Draw(orbit)

    # Elliptical tilted rings
    # Ring 1
    r1_box = (cx - S(320), cy - S(140), cx + S(320), cy + S(140))
    odraw.ellipse(r1_box, outline=(56, 189, 248, 45), width=S(2))
    # Ring 2 (Tilted aspect)
    r2_box = (cx - S(260), cy - S(200), cx + S(260), cy + S(200))
    odraw.ellipse(r2_box, outline=(52, 211, 153, 35), width=S(1.5))
    base.alpha_composite(orbit)

    # Hero Element: The 3D Floating Prism Diamond (Geometric & Iconic)
    prism_h = S(260)
    prism_w = S(210)

    # Diamond Vertices
    top_v = (cx, cy - prism_h)
    bot_v = (cx, cy + prism_h)
    left_v = (cx - prism_w, cy)
    right_v = (cx + prism_w, cy)
    center_v = (cx, cy - S(25)) # Slightly elevated center for 3D depth

    # Prism Drop Shadow on base
    pr_sh = Image.new("RGBA", (CANVAS_SIZE, CANVAS_SIZE), (0, 0, 0, 0))
    prs_draw = ImageDraw.Draw(pr_sh)
    prs_draw.ellipse((cx - S(220), cy + S(180), cx + S(220), cy + S(260)), fill=(0, 0, 0, 160))
    pr_sh = pr_sh.filter(ImageFilter.GaussianBlur(S(36)))
    base.alpha_composite(pr_sh)

    prism_layer = Image.new("RGBA", (CANVAS_SIZE, CANVAS_SIZE), (0, 0, 0, 0))
    pdraw = ImageDraw.Draw(prism_layer)

    # Facet 1: Top-Left (Electric Cyan Gradient)
    f1 = [top_v, left_v, center_v]
    pdraw.polygon(f1, fill=(56, 189, 248, 235))

    # Facet 2: Top-Right (Brilliant Cyan/Mint Specular)
    f2 = [top_v, right_v, center_v]
    pdraw.polygon(f2, fill=(224, 242, 254, 250))

    # Facet 3: Bottom-Left (Deep Indigo/Cyan Refraction)
    f3 = [left_v, bot_v, center_v]
    pdraw.polygon(f3, fill=(14, 116, 144, 240))

    # Facet 4: Bottom-Right (Emerald Verification Facet)
    f4 = [right_v, bot_v, center_v]
    pdraw.polygon(f4, fill=(16, 185, 129, 245))

    # Crisp Internal Facet Edges / Specular Ridges
    pdraw.line([top_v, center_v], fill=(255, 255, 255, 230), width=S(2.5))
    pdraw.line([left_v, center_v], fill=(255, 255, 255, 180), width=S(2))
    pdraw.line([right_v, center_v], fill=(255, 255, 255, 210), width=S(2))
    pdraw.line([bot_v, center_v], fill=(255, 255, 255, 160), width=S(2))
    pdraw.line([top_v, right_v, bot_v, left_v, top_v], fill=(255, 255, 255, 140), width=S(2))

    # Brilliant central vertex glint
    draw_glow(prism_layer, center_v, S(50), (255, 255, 255, 200), S(14))
    pdraw.ellipse((center_v[0] - S(10), center_v[1] - S(10), center_v[0] + S(10), center_v[1] + S(10)), fill=(255, 255, 255, 255))

    # Satellite pulse beacon (Orbiting particle)
    orbit_pt = (cx + S(260) * math.cos(math.radians(-35)), cy + S(140) * math.sin(math.radians(-35)))
    draw_glow(prism_layer, (int(orbit_pt[0]), int(orbit_pt[1])), S(36), (52, 211, 153, 190), S(12))
    pdraw.ellipse((int(orbit_pt[0]) - S(10), int(orbit_pt[1]) - S(10), int(orbit_pt[0]) + S(10), int(orbit_pt[1]) + S(10)), fill=(255, 255, 255, 255))

    base.alpha_composite(prism_layer)
    finish_and_save(output, base, bounds, radius, OUTPUT_DIR / "concept_C_prism.png")


def main():
    print("🎨 开始生成 3 款全新设计概念图标 (2x 超采样 Lanczos 渲染)...")
    generate_concept_a()
    generate_concept_b()
    generate_concept_c()
    print("✨ 全部 3 款概念图标生成完毕！")

if __name__ == "__main__":
    main()
