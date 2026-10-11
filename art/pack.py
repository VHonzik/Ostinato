"""Pack reviewed 32px sprites into a sheet and a JSON lookup, without ComfyUI."""

import argparse
import json
import math
from pathlib import Path
import re
import sys

from PIL import Image

# ComfyUI's embedded Python can omit the script directory from sys.path.
sys.path.insert(0, str(Path(__file__).resolve().parent))
from generate import project_path, write_json


def pack_sprites(config, inputs, destination, columns=10, only=None):
    if columns <= 0:
        raise ValueError("columns must be positive.")
    sprites = config["sprites"]
    names = [sprite["name"] for sprite in sprites]
    if len(names) != len(set(names)):
        raise ValueError("Duplicate sprite names in the catalog.")
    if any(not re.fullmatch(r"[a-z][a-z0-9_]*", name) for name in names):
        raise ValueError("Invalid sprite name in the catalog.")
    if only:
        unknown = set(only) - set(names)
        if unknown:
            raise ValueError(f"Unknown sprites: {', '.join(sorted(unknown))}")
        sprites = [sprite for sprite in sprites if sprite["name"] in only]
    if not sprites:
        raise ValueError("No sprites selected.")
    if destination.exists():
        raise ValueError(f"Refusing to overwrite existing pack: {destination}")
    size = config["sprite_size"]
    if not isinstance(size, int) or size <= 0:
        raise ValueError("sprite_size must be a positive integer.")
    sources = {}
    images = {}
    missing = []
    for sprite in sprites:
        name = sprite["name"]
        candidates = [folder / f"{name}.png" for folder in inputs]
        source = next((path for path in reversed(candidates) if path.is_file()), None)
        if source is None:
            missing.append(name)
            continue
        with Image.open(source) as image:
            if image.size != (size, size):
                raise ValueError(f"{source}: expected {size}x{size}, got {image.size}.")
            images[name] = image.convert("RGBA")
        sources[name] = source
    if missing:
        raise ValueError("Missing sprites: " + ", ".join(missing)
                         + ". Finish/resume generation, or use --only for a preview sheet.")
    columns = min(columns, len(sprites))
    rows = math.ceil(len(sprites) / columns)
    sheet = Image.new("RGBA", (columns * size, rows * size), (0, 0, 0, 0))
    frames = {}
    for index, sprite in enumerate(sprites):
        name = sprite["name"]
        x, y = index % columns * size, index // columns * size
        # Paste without an extra alpha mask: preserve source RGBA exactly.
        sheet.paste(images[name], (x, y))
        frames[name] = {"x": x, "y": y, "width": size, "height": size,
                        "column": index % columns, "row": index // columns,
                        "group": sprite.get("group", "world"),
                        "source": str(sources[name].relative_to(project_path("."))).replace("\\", "/")}
    destination.mkdir(parents=True, exist_ok=False)
    sheet.save(destination / "sprites.png")
    metadata = {"texture": "sprites.png", "cell_size": size, "columns": columns,
                "rows": rows, "sprite_count": len(sprites), "sprites": frames}
    write_json(destination / "sprites.json", metadata)
    return metadata


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", nargs="+", default=["assets/sprites/valley"],
                        help="Export folders, in order; later folders override earlier sprites")
    parser.add_argument("--config", default="art/sprites.json", help="Sprite catalog")
    parser.add_argument("--output", help="New output folder; default assets/generated/sheets/<first run>")
    parser.add_argument("--columns", type=int, default=10)
    parser.add_argument("--only", nargs="+", help="Pack an explicit subset for review")
    args = parser.parse_args()
    inputs = [project_path(value) for value in args.input]
    for folder in inputs:
        if not folder.is_dir():
            raise ValueError(f"Input folder does not exist: {folder}")
    config_path = project_path(args.config)
    config = json.loads(config_path.read_text(encoding="utf-8-sig"))
    destination = project_path(args.output or f"assets/generated/sheets/{inputs[0].name}")
    metadata = pack_sprites(config, inputs, destination, args.columns, args.only)
    print(f"Packed {metadata['sprite_count']} sprites into "
          f"{destination.relative_to(project_path('.'))}/sprites.png; "
          f"{metadata['columns']} columns, {metadata['rows']} rows.")


if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError, KeyError) as error:
        print(f"Error: {error}", file=sys.stderr)
        sys.exit(1)
