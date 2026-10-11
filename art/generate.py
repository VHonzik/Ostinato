"""Headless ComfyUI sprite generation; the client needs Python 3.8+ and Pillow."""

import argparse
from collections import deque
from datetime import datetime, timezone
from io import BytesIO
import json
from pathlib import Path
import re
import sys
import time
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode, urlparse
from urllib.request import Request, urlopen
import uuid

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent


class ComfyClient:
    def __init__(self, server):
        parsed = urlparse(server)
        if parsed.scheme not in ("http", "https") or not parsed.netloc:
            raise ValueError("Server must be an http(s) URL.")
        self.server = server.rstrip("/")

    def request(self, path, data=None, content_type="application/json", binary=False):
        request = Request(self.server + path, data=data,
                          headers={"Content-Type": content_type} if data is not None else {})
        try:
            with urlopen(request, timeout=30) as response:
                body = response.read()
        except HTTPError as error:
            raise RuntimeError(f"ComfyUI HTTP {error.code}: "
                               + error.read().decode("utf-8", "replace")[:2000]) from error
        except (URLError, TimeoutError) as error:
            raise RuntimeError(f"Cannot reach ComfyUI at {self.server}: {error}") from error
        return body if binary else json.loads(body)

    def upload(self, image, name):
        buffer = BytesIO()
        image.save(buffer, format="PNG")
        boundary = uuid.uuid4().hex
        body = (f'--{boundary}\r\nContent-Disposition: form-data; name="image"; '
                f'filename="{name}"\r\nContent-Type: image/png\r\n\r\n').encode()
        body += buffer.getvalue() + f"\r\n--{boundary}--\r\n".encode()
        result = self.request("/upload/image", body, f"multipart/form-data; boundary={boundary}")
        return "/".join(filter(None, (result.get("subfolder"), result["name"])))

    def submit(self, workflow):
        result = self.request("/prompt", json.dumps({"prompt": workflow}).encode())
        if result.get("node_errors") or "prompt_id" not in result:
            raise RuntimeError(f"ComfyUI rejected the workflow: {json.dumps(result)[:2000]}")
        return result["prompt_id"]

    def wait(self, prompt_id, timeout):
        deadline = time.monotonic() + timeout
        next_update = time.monotonic() + 30
        while time.monotonic() < deadline:
            entry = self.request(f"/history/{prompt_id}").get(prompt_id)
            if entry:
                status = entry.get("status", {})
                failure = [message for message in status.get("messages", []) if message[0] in
                           ("execution_error", "execution_interrupted")]
                if status.get("status_str") == "error" or failure:
                    raise RuntimeError(f"Generation failed: {json.dumps(failure or status)[:2000]}")
                images = entry.get("outputs", {}).get("9", {}).get("images", [])
                if status.get("completed") and images:
                    return images[0]
                if status.get("completed"):
                    raise RuntimeError("ComfyUI completed without a saved image.")
            if time.monotonic() >= next_update:
                print(f"  Waiting for prompt {prompt_id}...", flush=True)
                next_update = time.monotonic() + 30
            time.sleep(2)
        raise RuntimeError(f"Timed out waiting for {prompt_id}; it may still be queued/running. "
                           "No jobs were cancelled. Retrieve it with --resume and the run folder.")

    def download(self, descriptor):
        query = urlencode({key: descriptor.get(key, "") for key in
                           ("filename", "subfolder", "type")})
        return self.request("/view?" + query, binary=True)


def project_path(value):
    path = (ROOT / value).resolve()
    if path != ROOT and ROOT not in path.parents:
        raise ValueError(f"Path must stay inside the project: {value}")
    return path


def sprite_settings(config, sprite):
    settings = dict(config)
    settings.update(config.get("styles", {}).get(sprite.get("style"), {}))
    settings.update(sprite)
    return settings


def prepare_reference(config, sprite):
    config = sprite_settings(config, sprite)
    with Image.open(project_path(config["reference"])) as source:
        source = source.convert("RGBA")
    cell = config["reference_cell_size"]
    x, y = (coordinate * cell for coordinate in sprite["reference_cell"])
    if x < 0 or y < 0 or x + cell > source.width or y + cell > source.height:
        raise ValueError(f"Reference cell outside spritesheet: {sprite['name']}")
    crop = source.crop((x, y, x + cell, y + cell))
    size = config["generation_size"]
    extent = size if config.get("opaque") or config.get("reference_fill") else (size * 7 // 8 // cell) * cell
    rotation = config.get("reference_rotate", 0)
    if rotation:
        crop = crop.rotate(rotation, resample=Image.Resampling.NEAREST)
    scale = config.get("reference_scale", [1, 1])
    dimensions = tuple(max(1, int(extent * factor)) for factor in scale)
    crop = crop.resize(dimensions, Image.Resampling.NEAREST)
    canvas = Image.new("RGBA", (size, size), tuple(config["background"]) + (255,))
    canvas.alpha_composite(crop, ((size - crop.width) // 2, (size - crop.height) // 2))
    return canvas.convert("RGB")


def build_workflow(config, sprite, uploaded):
    config = sprite_settings(config, sprite)
    def node(kind, **inputs):
        return {"class_type": kind, "inputs": inputs}
    positive = ", ".join(filter(None, (config["positive"], config.get("prompt_prefix"),
                                      sprite["prompt"])))
    negative = ", ".join(filter(None, (config["negative"], config.get("negative_extra"))))
    workflow = {
        "1": node("CheckpointLoaderSimple", ckpt_name=config["checkpoint"]),
        "2": node("LoraLoader", model=["1", 0], clip=["1", 1],
                  lora_name=config["lora"], strength_model=config["lora_strength"],
                  strength_clip=config["lora_strength"]),
        "3": node("LoadImage", image=uploaded),
        "4": node("VAEEncode", pixels=["3", 0], vae=["1", 2]),
        "5": node("CLIPTextEncode", clip=["2", 1], text=positive),
        "6": node("CLIPTextEncode", clip=["2", 1], text=negative),
        "7": node("KSampler", model=["2", 0], seed=sprite["seed"],
                  steps=config["steps"], cfg=config["cfg"],
                  sampler_name=config["sampler"], scheduler=config["scheduler"],
                  positive=["5", 0], negative=["6", 0], latent_image=["4", 0],
                  denoise=config["denoise"]),
        "8": node("VAEDecode", samples=["7", 0], vae=["1", 2]),
        "9": node("SaveImage", images=["8", 0], filename_prefix="ostinato/" + sprite["name"]),
    }
    return workflow


def make_sprite(raw, config):
    image = raw.convert("RGB")
    pixels = image.load()
    width, height = image.size
    mask = Image.new("L", image.size, 255)
    if not config.get("opaque", False):
        corners = [pixels[x, y] for x, y in
                   ((0, 0), (width - 1, 0), (0, height - 1), (width - 1, height - 1))]
        background = tuple(sorted(color[c] for color in corners)[len(corners) // 2]
                           for c in range(3))
        tolerance = config["background_tolerance"]
        alpha = mask.load()
        queue = deque()

        def matches(x, y):
            return max(abs(pixels[x, y][c] - background[c]) for c in range(3)) <= tolerance

        def visit(x, y):
            if alpha[x, y] and matches(x, y):
                alpha[x, y] = 0
                queue.append((x, y))

        for x in range(width):
            visit(x, 0)
            visit(x, height - 1)
        for y in range(height):
            visit(0, y)
            visit(width - 1, y)
        while queue:
            x, y = queue.popleft()
            for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                if 0 <= nx < width and 0 <= ny < height:
                    visit(nx, ny)
        # Sparse reference art uses transparent eye/mouth holes. This is optional
        # because enclosed dark regions may be solid material in other art styles.
        if config.get("remove_interior_background", False):
            for y in range(height):
                for x in range(width):
                    if matches(x, y):
                        alpha[x, y] = 0
    size = config["sprite_size"]
    image = image.resize((size, size), Image.Resampling.NEAREST)
    mask = mask.resize((size, size), Image.Resampling.NEAREST)
    if not mask.getbbox():
        raise RuntimeError("Background removal erased the entire sprite; adjust tolerance.")
    if not config.get("opaque", False) and mask.getextrema()[0] == 255:
        raise RuntimeError("No transparent background was found; inspect the raw image.")
    colors = config.get("foreground_palette")
    if colors:
        palette = Image.new("P", (1, 1))
        values = [channel for index in range(256) for channel in colors[index % len(colors)]]
        palette.putpalette(values)
        image = image.quantize(palette=palette, dither=Image.Dither.NONE).convert("RGBA")
    else:
        image.putalpha(mask)
        image = image.quantize(colors=config["palette_colors"], method=Image.Quantize.FASTOCTREE,
                               dither=Image.Dither.NONE).convert("RGBA")
    image.putalpha(mask)
    return image


def check_server(client, config):
    nodes = client.request("/object_info")
    required = {"CheckpointLoaderSimple", "LoraLoader", "LoadImage", "VAEEncode",
                "CLIPTextEncode", "KSampler", "VAEDecode", "SaveImage"}
    for kind in sorted(required):
        if kind not in nodes:
            raise ValueError(f"ComfyUI is missing node {kind}.")
    for kind, field, value in (
        ("CheckpointLoaderSimple", "ckpt_name", config["checkpoint"]),
        ("LoraLoader", "lora_name", config["lora"]),
        ("KSampler", "sampler_name", config["sampler"]),
        ("KSampler", "scheduler", config["scheduler"]),
    ):
        choices = nodes[kind]["input"]["required"][field][0]
        if value not in choices:
            raise ValueError(f"{field} {value!r} unavailable. Choices: {choices}")


def finish(client, config, name, run, timeout):
    output = project_path(config["output"]) / run.name
    destination = output / f"{name}.png"
    if destination.exists():
        raise ValueError(f"Refusing to overwrite {destination}")
    raw_path = run / f"{name}.raw.png"
    if not raw_path.exists():
        job = json.loads((run / f"{name}.job.json").read_text(encoding="utf-8-sig"))
        descriptor = client.wait(job["prompt_id"], timeout)
        write_bytes_atomic(raw_path, client.download(descriptor))
    sprite = next(sprite for sprite in config["sprites"] if sprite["name"] == name)
    with Image.open(raw_path) as raw:
        result = make_sprite(raw, sprite_settings(config, sprite))
    output.mkdir(parents=True, exist_ok=True)
    recipe = output / "generation.json"
    if not recipe.exists():
        write_json(recipe, config)
    buffer = BytesIO()
    result.save(buffer, format="PNG")
    write_bytes_atomic(destination, buffer.getvalue())
    print(f"  Saved {destination.relative_to(ROOT)}", flush=True)


def run_batch(client, config, sprites, run, timeout):
    output = project_path(config["output"]) / run.name
    output.mkdir(parents=True, exist_ok=True)
    recipe = output / "generation.json"
    if not recipe.exists():
        write_json(recipe, config)
    for index, sprite in enumerate(sprites):
        name = sprite["name"]
        if (output / f"{name}.png").exists():
            print(f"[{index + 1}/{len(sprites)}] {name}: already exported", flush=True)
            continue
        job_path = run / f"{name}.job.json"
        if not job_path.exists() and not (run / f"{name}.raw.png").exists():
            reference = prepare_reference(config, sprite)
            reference.save(run / f"{name}.reference.png")
            uploaded = client.upload(reference, f"ostinato_{run.name}_{name}.png")
            workflow = build_workflow(config, sprite, uploaded)
            write_json(run / f"{name}.workflow.json", workflow)
            prompt_id = client.submit(workflow)
            write_json(job_path, {"prompt_id": prompt_id})
            print(f"[{index + 1}/{len(sprites)}] {name}: queued {prompt_id} "
                  f"(seed {sprite['seed']})", flush=True)
        else:
            print(f"[{index + 1}/{len(sprites)}] {name}: retrieving saved job", flush=True)
        finish(client, config, name, run, timeout)


def write_bytes_atomic(path, data):
    temporary = path.with_name(path.name + ".tmp-" + uuid.uuid4().hex)
    try:
        temporary.write_bytes(data)
        temporary.replace(path)
    finally:
        if temporary.exists():
            temporary.unlink()


def write_json(path, value):
    write_bytes_atomic(path, (json.dumps(value, indent=2) + "\n").encode("utf-8"))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", default="art/sprites.json")
    parser.add_argument("--server", help="Override the configured ComfyUI URL")
    parser.add_argument("--only", nargs="+", help="Generate selected sprite names")
    parser.add_argument("--group", nargs="+", help="Generate selected groups")
    parser.add_argument("--seed", type=int, help="Override each selected sprite's seed")
    parser.add_argument("--timeout", type=float, default=1200, help="Seconds per job including queue time")
    parser.add_argument("--check", action="store_true", help="Check without queuing")
    parser.add_argument("--list", action="store_true", help="List catalog names/groups without ComfyUI")
    parser.add_argument("--resume", help="Continue a saved batch, retrieving existing jobs first")
    args = parser.parse_args()
    if args.timeout <= 0:
        parser.error("--timeout must be positive")
    if args.seed is not None and not 0 <= args.seed < 2 ** 64:
        parser.error("--seed must be an unsigned 64-bit integer")
    run = project_path(args.resume) if args.resume else None
    config_path = run / "config.json" if run else project_path(args.config)
    config = json.loads(config_path.read_text(encoding="utf-8-sig"))
    if args.server:
        config["server"] = args.server
    sprites = config["sprites"]
    names = [sprite["name"] for sprite in sprites]
    if len(names) != len(set(names)):
        raise ValueError("Duplicate sprite names in the catalog.")
    for sprite in sprites:
        if not re.fullmatch(r"[a-z][a-z0-9_]*", sprite["name"]):
            raise ValueError("Sprite names must use lowercase letters, numbers, and underscores.")
    if args.list:
        for sprite in sprites:
            print(f"{sprite.get('group', 'world')}: {sprite['name']}")
        return
    if run and not args.only and not args.group:
        selected = set(config.get("selected_names", names))
        sprites = [sprite for sprite in sprites if sprite["name"] in selected]
    if args.only:
        unknown = set(args.only) - set(names)
        if unknown:
            parser.error(f"Unknown sprites: {', '.join(sorted(unknown))}")
        sprites = [sprite for sprite in sprites if sprite["name"] in args.only]
    if args.group:
        unknown = set(args.group) - {sprite.get("group") for sprite in config["sprites"]}
        if unknown:
            parser.error(f"Unknown groups: {', '.join(sorted(unknown))}")
        sprites = [sprite for sprite in sprites if sprite.get("group") in args.group]
    if not sprites:
        raise ValueError("No sprites selected.")
    if args.seed is not None:
        if run:
            parser.error("--seed cannot change a resumed batch")
        for sprite in sprites:
            sprite["seed"] = args.seed
    for sprite in sprites:
        if sprite.get("style") and sprite["style"] not in config.get("styles", {}):
            raise ValueError(f"Unknown style: {sprite['style']}")
        settings = sprite_settings(config, sprite)
        if settings["generation_size"] < 64 or settings["generation_size"] % 8:
            raise ValueError("generation_size must be >= 64 and divisible by 8.")
        if not 0 < settings["denoise"] <= 1 or settings["sprite_size"] <= 0:
            raise ValueError("denoise must be in (0, 1] and sprite_size must be positive.")
        palette = settings.get("foreground_palette")
        if palette is not None and (not palette or len(palette) > 256 or any(
                len(color) != 3 or any(not isinstance(c, int) or not 0 <= c <= 255 for c in color)
                for color in palette)):
            raise ValueError("foreground_palette must contain 1-256 RGB colors in 0-255.")
        scale = settings.get("reference_scale", [1, 1])
        if len(scale) != 2 or any(not 0 < factor <= 1 for factor in scale):
            raise ValueError("reference_scale must contain two factors in (0, 1].")
        if settings.get("reference_rotate", 0) not in (0, 90, 180, 270):
            raise ValueError("reference_rotate must be 0, 90, 180, or 270 degrees.")
        prepare_reference(config, sprite)
    project_path(config["output"])
    project_path(config["work"])
    client = ComfyClient(config["server"])
    check_server(client, config)
    if args.check:
        print(f"Ready: {config['checkpoint']} + {config['lora']}; {len(sprites)} sprites.")
        return
    if not run:
        run_id = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ") + "-" + uuid.uuid4().hex[:6]
        run = project_path(config["work"]) / run_id
        run.mkdir(parents=True)
        config["selected_names"] = [sprite["name"] for sprite in sprites]
        write_json(run / "config.json", config)
    print(f"Run: {run.relative_to(ROOT)}", flush=True)
    run_batch(client, config, sprites, run, args.timeout)
    print("Batch complete. Pack separately with art/pack.py --input "
          + str((project_path(config["output"]) / run.name).relative_to(ROOT)), flush=True)


if __name__ == "__main__":
    try:
        main()
    except (ValueError, RuntimeError, OSError, KeyError) as error:
        print(f"Error: {error}", file=sys.stderr)
        sys.exit(1)
