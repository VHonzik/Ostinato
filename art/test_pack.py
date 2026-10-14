"""Structural atlas checks; appearance remains a human judgment."""
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from PIL import Image

from pack import pack_sprites


class PackingTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.first = self.root / 'first'
        self.second = self.root / 'second'
        self.first.mkdir()
        self.second.mkdir()
        patcher = patch('generate.ROOT', self.root)
        patcher.start()
        self.addCleanup(patcher.stop)
        self.config = {'sprite_size': 4, 'sprites': [
            {'name': 'warrior', 'group': 'players'},
            {'name': 'wolf', 'group': 'enemies'},
            {'name': 'grass_a', 'group': 'ground'}]}
        for name, color in [('warrior', (220,220,170,255)),
                            ('wolf', (180,170,120,128)), ('grass_a', (30,55,30,255))]:
            image = Image.new('RGBA', (4,4), color)
            if name == 'warrior':
                image.putpixel((0,0), (0,0,0,0))
            image.save(self.first / (name + '.png'))

    def test_named_frames_preserve_rgba_and_leave_unused_cells_transparent(self):
        dest = self.root / 'sheet'
        metadata = pack_sprites(self.config, [self.first], dest, columns=2)
        saved = json.loads((dest / 'sprites.json').read_text())
        self.assertEqual(saved, metadata)
        with Image.open(dest / 'sprites.png') as sheet:
            for name, frame in metadata['sprites'].items():
                with Image.open(self.first / (name + '.png')) as original:
                    crop = sheet.crop((frame['x'],frame['y'],frame['x']+4,frame['y']+4))
                    self.assertEqual(crop.tobytes(), original.tobytes())
            self.assertEqual(sheet.getpixel((7,7))[3], 0)

    def test_explicit_later_input_overrides_only_its_retake(self):
        Image.new('RGBA', (4,4), (1,2,3,255)).save(self.second / 'wolf.png')
        dest = self.root / 'sheet'
        metadata = pack_sprites(self.config, [self.first,self.second], dest, columns=2)
        self.assertEqual(metadata['sprites']['wolf']['source'], 'second/wolf.png')
        self.assertEqual(metadata['sprites']['warrior']['source'], 'first/warrior.png')
        with Image.open(dest / 'sprites.png') as sheet:
            self.assertEqual(sheet.getpixel((4,0)), (1,2,3,255))

    def test_missing_sprite_refuses_to_write_an_incomplete_full_sheet(self):
        (self.first / 'wolf.png').unlink()
        dest = self.root / 'sheet'
        with self.assertRaisesRegex(ValueError, 'Missing sprites: wolf'):
            pack_sprites(self.config, [self.first], dest)
        self.assertFalse(dest.exists())

    def test_existing_output_is_preserved(self):
        dest = self.root / 'sheet'
        dest.mkdir()
        (dest / 'sprites.png').write_bytes(b'keep existing output')
        with self.assertRaisesRegex(ValueError, 'Refusing to overwrite'):
            pack_sprites(self.config, [self.first], dest)
        self.assertEqual((dest / 'sprites.png').read_bytes(), b'keep existing output')

    def test_subset_sheet_requires_only_explicitly_selected_sprites(self):
        (self.first / 'wolf.png').unlink()
        metadata = pack_sprites(self.config, [self.first], self.root / 'sheet', only=['warrior'])
        self.assertEqual(set(metadata['sprites']), {'warrior'})

    def test_wrong_cell_size_fails_before_creating_output(self):
        Image.new('RGBA', (3,4)).save(self.first / 'wolf.png')
        dest = self.root / 'sheet'
        with self.assertRaisesRegex(ValueError, 'expected 4x4'):
            pack_sprites(self.config, [self.first], dest)
        self.assertFalse(dest.exists())


if __name__ == '__main__':
    unittest.main()
