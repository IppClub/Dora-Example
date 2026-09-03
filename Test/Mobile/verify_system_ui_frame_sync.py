"""Verify SystemUIFrameSyncTest captures (requires Pillow)."""
from pathlib import Path
from PIL import Image, ImageChops

prefix = Path("/tmp/dora-system-ui-frame-sync")
positions = set()


def color_masks(image):
    r, g, b = image.split()
    high = lambda channel: channel.point(lambda value: 255 if value > 240 else 0)
    low = lambda channel: channel.point(lambda value: 255 if value < 15 else 0)
    red = ImageChops.multiply(ImageChops.multiply(high(r), low(g)), low(b))
    green = ImageChops.multiply(ImageChops.multiply(high(g), low(r)), low(b))
    return red, green


assert prefix.with_suffix(".result").read_text().startswith("captured:"), "native capture did not complete"
for frame in range(1, 13):
    image = Image.open(f"{prefix}-{frame}.tga").convert("RGB")
    red, green = color_masks(image)
    rb, gb = red.getbbox(), green.getbbox()
    assert rb and gb, f"frame {frame}: missing background or Sprite: {rb}, {gb}"
    for axis in (0, 1):
        assert abs((rb[axis] + rb[axis + 2]) - (gb[axis] + gb[axis + 2])) <= 2, (
            f"frame {frame}: background and Sprite disagree: {rb}, {gb}"
        )
        assert rb[axis] < gb[axis] < gb[axis + 2] < rb[axis + 2], (
            f"frame {frame}: Sprite does not remain inside background"
        )
    positions.add(rb)
assert len(positions) >= 4, "captures did not sample moving frames"
hidden = Image.open(f"{prefix}-hidden.tga").convert("RGB")
assert not any(mask.getbbox() for mask in color_masks(hidden)), "background or Sprite survived hiding"
print(f"passed: 12 moving frames, {len(positions)} positions, correct layering, no hidden-frame residue")
