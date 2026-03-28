"""Generate Slitherlink app icon - a minimalist puzzle grid with loop lines."""
from PIL import Image, ImageDraw
import os

def generate_icon(size):
    """Generate a Slitherlink-themed app icon at the given size."""
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Background: rounded rectangle with gradient-like effect
    # Dark purple background
    bg_color = (26, 26, 46)  # #1A1A2E
    margin = int(size * 0.08)
    radius = int(size * 0.22)

    # Draw rounded rect background
    draw.rounded_rectangle(
        [margin, margin, size - margin, size - margin],
        radius=radius,
        fill=bg_color,
    )

    # Inner glow/accent border
    accent_color = (108, 99, 255)  # #6C63FF
    draw.rounded_rectangle(
        [margin, margin, size - margin, size - margin],
        radius=radius,
        outline=accent_color,
        width=max(2, int(size * 0.02)),
    )

    # Draw a 3x3 grid of dots (puzzle nodes)
    grid_margin = int(size * 0.22)
    grid_size = size - 2 * grid_margin
    cell_size = grid_size / 3
    dot_radius = max(2, int(size * 0.025))
    dot_color = (144, 144, 176)  # dim dots #9090B0

    # Draw dots at grid intersections (4x4 = 16 dots)
    for r in range(4):
        for c in range(4):
            cx = int(grid_margin + c * cell_size)
            cy = int(grid_margin + r * cell_size)
            draw.ellipse(
                [cx - dot_radius, cy - dot_radius, cx + dot_radius, cy + dot_radius],
                fill=dot_color,
            )

    # Draw a loop path on the grid (the Slitherlink solution)
    # Loop: a simple closed loop visiting some edges
    # Using coordinates as (col, row) grid positions
    loop_edges = [
        # Top portion
        ((0, 0), (1, 0)),
        ((1, 0), (2, 0)),
        ((2, 0), (2, 1)),
        ((2, 1), (3, 1)),
        ((3, 1), (3, 2)),
        ((3, 2), (3, 3)),
        ((3, 3), (2, 3)),
        ((2, 3), (1, 3)),
        ((1, 3), (1, 2)),
        ((1, 2), (0, 2)),
        ((0, 2), (0, 1)),
        ((0, 1), (0, 0)),
    ]

    line_color = accent_color
    line_width = max(3, int(size * 0.04))

    for (c1, r1), (c2, r2) in loop_edges:
        x1 = int(grid_margin + c1 * cell_size)
        y1 = int(grid_margin + r1 * cell_size)
        x2 = int(grid_margin + c2 * cell_size)
        y2 = int(grid_margin + r2 * cell_size)
        draw.line([(x1, y1), (x2, y2)], fill=line_color, width=line_width)

    # Draw bright dots on the loop nodes
    loop_nodes = set()
    for (c1, r1), (c2, r2) in loop_edges:
        loop_nodes.add((c1, r1))
        loop_nodes.add((c2, r2))

    bright_dot_radius = max(3, int(size * 0.035))
    bright_dot_color = (224, 224, 255)  # #E0E0FF

    for (c, r) in loop_nodes:
        cx = int(grid_margin + c * cell_size)
        cy = int(grid_margin + r * cell_size)
        draw.ellipse(
            [cx - bright_dot_radius, cy - bright_dot_radius,
             cx + bright_dot_radius, cy + bright_dot_radius],
            fill=bright_dot_color,
        )

    # Draw hint numbers inside some cells
    # Cell centers
    numbers = {
        (0, 0): "2", (1, 0): "1", (2, 0): "2",
        (0, 1): "2",             (2, 1): "2",
        (0, 2): "1", (1, 2): "2", (2, 2): "2",
    }

    # Use simple approach - draw numbers as small text
    try:
        from PIL import ImageFont
        font_size = max(8, int(size * 0.1))
        try:
            font = ImageFont.truetype("arial.ttf", font_size)
        except:
            font = ImageFont.load_default()
    except:
        font = None

    num_color = (200, 200, 240)
    for (c, r), num in numbers.items():
        cx = int(grid_margin + (c + 0.5) * cell_size)
        cy = int(grid_margin + (r + 0.5) * cell_size)
        if font:
            bbox = draw.textbbox((cx, cy), num, font=font, anchor="mm")
            draw.text((cx, cy), num, fill=num_color, font=font, anchor="mm")
        else:
            draw.text((cx - 3, cy - 5), num, fill=num_color)

    return img


# Generate icons for all Android densities
sizes = {
    'mipmap-mdpi': 48,
    'mipmap-hdpi': 72,
    'mipmap-xhdpi': 96,
    'mipmap-xxhdpi': 144,
    'mipmap-xxxhdpi': 192,
}

base_path = 'android/app/src/main/res'

for folder, size in sizes.items():
    icon = generate_icon(size)
    out_path = os.path.join(base_path, folder, 'ic_launcher.png')
    icon.save(out_path)
    print(f"Generated {out_path} ({size}x{size})")

# Also generate a high-res version for assets
icon_512 = generate_icon(512)
icon_512.save('assets/images/app_icon.png')
print("Generated assets/images/app_icon.png (512x512)")

print("Done!")
