"""Behavior checks using temporary external files; no live panel or game writes."""
from argparse import Namespace
from contextlib import redirect_stdout
import io
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from PIL import Image, ImageDraw
import external_pixel as workflow


class ExternalWorkflowTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="picxel-external-test-")
        self.root = Path(self.temp.name)
        self.refs, self.out = self.root / "refs", self.root / "work"
        self.refs.mkdir()
        self.old_job = workflow.panel.JOB_FILE
        workflow.panel.JOB_FILE = self.root / "isolated-panel-job.json"
        self.name = "sample_\u8868\u60c5"
        image = Image.new("RGBA", (512, 512))
        draw = ImageDraw.Draw(image)
        draw.rounded_rectangle((90, 70, 420, 445), radius=40, fill="#728648")
        draw.rectangle((120, 100, 200, 350), fill="#141b20")
        draw.rectangle((220, 160, 380, 215), fill="#e2c180")
        self.source = self.refs / (self.name + ".png")
        image.save(self.source)
        workflow.write(self.refs / (self.name + ".anchor.json"), {
            "kind": "sprite", "size": 128, "keep": ["colored test shape"],
            "faces": [], "palette": ["#728648", "#141b20", "#e2c180"]})
        self.args = Namespace(refs=self.refs, out=self.out, sizes=[128, 64],
                              prepared_dir=None, background="none")

    def tearDown(self):
        workflow.panel.JOB_FILE = self.old_job
        self.temp.cleanup()

    def build(self):
        with redirect_stdout(io.StringIO()), patch("socket.create_connection", side_effect=AssertionError("No network")):
            self.assertEqual(workflow.build(self.args), 0)

    def select_all(self):
        with redirect_stdout(io.StringIO()):
            for size in self.args.sizes:
                workflow.select(Namespace(out=self.out, name=self.name, size=size,
                                          sheet=self.out / f"{self.name}-{size}.pxg", note="Test fixture review"))

    def test_external_multi_size_review_and_delivery(self):
        before = self.source.read_bytes()
        self.build()
        report = workflow.read(self.out / "batch-report.json")
        self.assertEqual(report["provider"], "external-file")
        self.assertFalse(report["image_model_used"])
        with self.assertRaisesRegex(ValueError, "visual review"):
            workflow.finish(Namespace(out=self.out))
        self.select_all()
        with redirect_stdout(io.StringIO()):
            workflow.finish(Namespace(out=self.out))
        self.assertEqual(self.source.read_bytes(), before)
        for size in self.args.sizes:
            with Image.open(self.out / workflow.panel.FINISHED_DIR / f"{self.name}-{size}.png") as image:
                self.assertEqual(image.size, (size, size))
                self.assertEqual(set(image.getchannel("A").tobytes()), {0, 255})
                self.assertLessEqual(len(image.convert("RGB").getcolors(65536)), 17)
        self.assertEqual(workflow.panel.load_status(self.out)["state"], "done")
        self.assertEqual(workflow.panel.scan_results(workflow.panel.load_job())["done"], 1)

    def test_existing_outputs_and_changed_sources_are_protected(self):
        self.build()
        with self.assertRaisesRegex(ValueError, "already contains"):
            workflow.build(self.args)
        self.select_all()
        with Image.open(self.source) as image:
            changed = image.copy()
        changed.putpixel((250, 250), (255, 0, 0, 255))
        changed.save(self.source)
        with self.assertRaisesRegex(ValueError, "Input changed"):
            workflow.finish(Namespace(out=self.out))

    def test_prepared_key_background_including_enclosed_hole(self):
        prepared = self.root / "prepared"
        prepared.mkdir()
        image = Image.new("RGB", (512, 512), "#ff00ff")
        draw = ImageDraw.Draw(image)
        draw.rectangle((70, 70, 440, 440), fill="#728648")
        draw.rectangle((180, 180, 320, 320), fill="#ff00ff")
        image.save(prepared / (self.name + ".png"))
        original = self.source.read_bytes()
        self.args.prepared_dir = prepared
        self.args.background = "key:#ff00ff"
        self.build()
        with Image.open(self.out / (self.name + ".concept.png")) as result:
            self.assertEqual(result.getpixel((250, 250))[3], 0)
            self.assertEqual(result.getpixel((100, 100))[3], 255)
        self.assertEqual(self.source.read_bytes(), original)

    def test_final_png_tampering_is_detected(self):
        self.build()
        self.select_all()
        target = self.out / f"{self.name}-128.png"
        with Image.open(target) as image:
            changed = image.copy()
        changed.putpixel((60, 60), (250, 0, 0, 255))
        changed.save(target)
        with self.assertRaisesRegex(ValueError, "PNG differs"):
            workflow.finish(Namespace(out=self.out))

    def test_refinement_is_used_by_panel_and_review(self):
        self.build()
        original = self.out / f"{self.name}-128.pxg"
        sheet = workflow.px.load(original)
        replacement = dict(sheet.colors)
        symbol = next(iter(replacement))
        row = list(sheet.rows[60])
        row[60] = symbol
        sheet.rows[60] = "".join(row)
        refined = self.out / f"{self.name}-128-detail.pxg"
        # No pre-render: selection must create both the panel and review PNG.
        refined.write_text(sheet.dump(), encoding="utf-8")
        with redirect_stdout(io.StringIO()):
            workflow.select(Namespace(out=self.out, name=self.name, size=128, sheet=refined, note="Checked edit"))
        with Image.open(refined.with_suffix(".png")) as preview, Image.open(self.out / f"{self.name}-128.png") as final:
            self.assertEqual(preview.tobytes(), final.tobytes())
        self.assertTrue((self.out / "base" / original.name).is_file())


if __name__ == "__main__":
    unittest.main()
