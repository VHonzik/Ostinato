"""Behavior checks for job failures and the simple alpha matte; no GPU required."""
from io import BytesIO
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import Mock, patch

from PIL import Image

from generate import ComfyClient, make_sprite, project_path, run_batch, write_bytes_atomic


class GenerationTests(unittest.TestCase):
    def test_execution_failure_is_not_reported_as_success(self):
        client = ComfyClient("http://127.0.0.1:8188")
        response = {"job": {"status": {"completed": True, "status_str": "error",
                    "messages": [["execution_error", {"exception_message": "out of memory"}]]}}}
        with patch.object(client, "request", return_value=response):
            with self.assertRaisesRegex(RuntimeError, "out of memory"):
                client.wait("job", 10)

    def test_completed_without_saved_image_fails(self):
        client = ComfyClient("http://127.0.0.1:8188")
        with patch.object(client, "request", return_value={"job": {"status": {"completed": True}}}):
            with self.assertRaisesRegex(RuntimeError, "without a saved image"):
                client.wait("job", 10)

    def test_timeout_does_not_cancel_or_delete_jobs(self):
        client = ComfyClient("http://127.0.0.1:8188")
        with patch.object(client, "request") as request:
            with patch("generate.time.monotonic", side_effect=[0, 0, 2]):
                with self.assertRaisesRegex(RuntimeError, "No jobs were cancelled"):
                    client.wait("job", 1)
            request.assert_not_called()

    def test_rejected_prompt_fails_before_waiting(self):
        client = ComfyClient("http://127.0.0.1:8188")
        with patch.object(client, "request", return_value={"node_errors": {"2": "missing lora"}}):
            with self.assertRaisesRegex(RuntimeError, "rejected"):
                client.submit({})

    def test_matte_removes_connected_background_but_preserves_enclosed_dark_details(self):
        image = Image.new("RGB", (8, 8), (30, 32, 42))
        for y in range(2, 6):
            for x in range(2, 6):
                image.putpixel((x, y), (240, 240, 190))
        image.putpixel((3, 3), (30, 32, 42))
        result = make_sprite(image, {"sprite_size": 8, "background_tolerance": 10,
                                     "palette_colors": 8})
        self.assertEqual(result.getpixel((0, 0))[3], 0)
        self.assertEqual(result.getpixel((3, 3))[3], 255)

    def test_empty_matte_fails_instead_of_exporting_an_invisible_sprite(self):
        with self.assertRaisesRegex(RuntimeError, "entire sprite"):
            make_sprite(Image.new("RGB", (8, 8), (30, 32, 42)),
                        {"sprite_size": 8, "background_tolerance": 10, "palette_colors": 8})

    def test_output_paths_cannot_escape_project(self):
        with self.assertRaisesRegex(ValueError, "inside the project"):
            project_path("../outside.png")


class BatchTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        patcher = patch("generate.ROOT", self.root)
        patcher.start()
        self.addCleanup(patcher.stop)
        self.run = self.root / "runs" / "batch"
        self.run.mkdir(parents=True)
        self.output = self.root / "exports" / "batch"
        self.output.mkdir(parents=True)
        self.config = {
            "checkpoint": "test.safetensors", "lora": "test-lora.safetensors",
            "lora_strength": 1.0, "steps": 2, "cfg": 1.0, "denoise": 0.7,
            "sampler": "euler", "scheduler": "normal", "background": [30,32,42],
            "background_tolerance": 10, "palette_colors": 8,
            "positive": "flat sprite", "negative": "shadow",
        }
        self.config.update(reference="reference.png", reference_cell_size=4,
                           generation_size=64, sprite_size=8, output="exports")
        self.config["sprites"] = [{"name": name, "reference_cell": [0,0],
                                  "seed": index, "prompt": name}
                                 for index, name in enumerate(("warrior", "wolf", "grass_a"))]
        source = Image.new("RGBA", (4,4), (0,0,0,0))
        source.putpixel((1,1), (240,240,190,255))
        source.save(self.root / "reference.png")
        raw = Image.new("RGB", (8,8), (30,32,42))
        for y in range(2,6):
            for x in range(2,6):
                raw.putpixel((x,y), (240,240,190))
        buffer = BytesIO()
        raw.save(buffer, format="PNG")
        self.raw_bytes = buffer.getvalue()
        self.client = Mock()
        self.client.upload.return_value = "uploaded.png"
        self.client.submit.return_value = "new-job"
        self.client.wait.return_value = {"filename": "raw.png"}
        self.client.download.return_value = self.raw_bytes

    def test_resume_preserves_finished_sprite_retrieves_pending_and_submits_unstarted(self):
        existing = Image.new("RGBA", (8,8), (1,2,3,255))
        existing.save(self.output / "warrior.png")
        preserved = (self.output / "warrior.png").read_bytes()
        (self.run / "wolf.job.json").write_text(json.dumps({"prompt_id": "queued-job"}))
        with patch("builtins.print"):
            run_batch(self.client, self.config, self.config["sprites"], self.run, 10)
        self.assertEqual((self.output / "warrior.png").read_bytes(), preserved)
        self.assertEqual([call.args[0] for call in self.client.wait.call_args_list],
                         ["queued-job", "new-job"])
        self.client.submit.assert_called_once()
        self.assertTrue((self.output / "grass_a.png").is_file())
        self.client.reset_mock()
        with patch("builtins.print"):
            run_batch(self.client, self.config, self.config["sprites"], self.run, 10)
        self.client.submit.assert_not_called()
        self.client.wait.assert_not_called()
        self.client.download.assert_not_called()

    def test_failed_atomic_write_preserves_previous_file_and_removes_partial_temp(self):
        target = self.root / "recipe.json"
        target.write_bytes(b"previous recipe")
        original_write = Path.write_bytes
        def fail_after_partial_write(path, data):
            original_write(path, data[:2])
            raise OSError("disk full")
        with patch.object(Path, "write_bytes", fail_after_partial_write):
            with self.assertRaisesRegex(OSError, "disk full"):
                write_bytes_atomic(target, b"new recipe")
        self.assertEqual(target.read_bytes(), b"previous recipe")
        self.assertEqual(list(self.root.glob("recipe.json.tmp-*")), [])

    def test_cached_raw_can_be_exported_without_server_history(self):
        (self.run / "wolf.raw.png").write_bytes(self.raw_bytes)
        wolf = self.config["sprites"][1]
        with patch("builtins.print"):
            run_batch(self.client, self.config, [wolf], self.run, 10)
        self.assertTrue((self.output / "wolf.png").is_file())
        self.client.submit.assert_not_called()
        self.client.wait.assert_not_called()
        self.client.download.assert_not_called()


class FlatPaletteTests(unittest.TestCase):
    def test_opaque_floor_retains_background_instead_of_becoming_a_cutout(self):
        result = make_sprite(Image.new("RGB", (8,8), (30,32,42)),
                             {"sprite_size": 8, "opaque": True,
                              "foreground_palette": [[40,55,40],[60,70,50]]})
        self.assertEqual(result.getchannel("A").getextrema(), (255,255))

    def test_flat_palette_preserves_transparency_and_uses_only_chosen_colors(self):
        raw = Image.new("RGB", (8,8), (30,32,42))
        for y in range(2,6):
            for x in range(2,6):
                raw.putpixel((x,y), (150+x*10,150+y*10,110))
        chosen = [[238,237,200],[153,151,118]]
        result = make_sprite(raw, {"sprite_size": 8, "background_tolerance": 10,
                                   "foreground_palette": chosen})
        pixels = [result.getpixel((x,y)) for y in range(result.height) for x in range(result.width)]
        colors = {pixel[:3] for pixel in pixels if pixel[3]}
        self.assertTrue(colors.issubset({tuple(color) for color in chosen}))
        self.assertEqual(result.getpixel((0,0))[3], 0)

    def test_optional_interior_removal_creates_reference_style_eye_holes(self):
        raw = Image.new("RGB", (8,8), (30,32,42))
        for y in range(2,6):
            for x in range(2,6):
                raw.putpixel((x,y), (240,240,190))
        raw.putpixel((3,3), (30,32,42))
        result = make_sprite(raw, {"sprite_size": 8, "background_tolerance": 10,
                                   "foreground_palette": [[238,237,200]],
                                   "remove_interior_background": True})
        self.assertEqual(result.getpixel((3,3))[3], 0)
        self.assertEqual(result.getpixel((2,2))[3], 255)


if __name__ == "__main__":
    unittest.main()
