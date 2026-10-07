import plistlib
import struct
import tempfile
import unittest
import zlib
from pathlib import Path

import xcursor_to_cape as x2c


def xcursor_bytes(images):
    """Build an XCursor file from (nominal, width, xhot, yhot, delay, argb) tuples."""
    header = 16 + 12 * len(images)
    toc, body = b"", b""
    for nominal, width, xhot, yhot, delay, argb in images:
        toc += struct.pack("<III", x2c.IMAGE_CHUNK, nominal, header + len(body))
        body += struct.pack("<9I", 36, x2c.IMAGE_CHUNK, nominal, 1, width, width, xhot, yhot, delay)
        body += struct.pack(f"<{width * width}I", *([argb] * width * width))
    return b"Xcur" + struct.pack("<III", 16, 0x10000, len(images)) + toc + body


def png_size(png):
    return struct.unpack(">II", png[16:24])


def png_first_pixel(png):
    (length,) = struct.unpack(">I", png[33:37])
    return zlib.decompress(png[41:41 + length])[1:5]


class XcursorToCapeTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.theme = Path(self.tmp.name)

    def tearDown(self):
        self.tmp.cleanup()

    def write(self, name, images):
        (self.theme / name).write_bytes(xcursor_bytes(images))

    def test_static_cursor_uses_1x_and_2x_images_and_1x_hotspot(self):
        self.write("left_ptr", [(24, 24, 5, 1, 0, 0xFF000000), (48, 48, 10, 2, 0, 0xFF000000)])
        cape = x2c.build_cape(self.theme, "Test", 24)
        arrow = cape["Cursors"]["com.apple.coregraphics.Arrow"]
        self.assertEqual((arrow["HotSpotX"], arrow["HotSpotY"]), (5.0, 1.0))
        self.assertEqual((arrow["PointsWide"], arrow["FrameCount"]), (24.0, 1))
        self.assertEqual([png_size(r) for r in arrow["Representations"]], [(24, 24), (48, 48)])

    def test_animation_is_subsampled_to_mousecape_frame_limit_keeping_loop_length(self):
        self.write("left_ptr", [(24, 24, 0, 0, 0, 0xFF000000), (48, 48, 0, 0, 0, 0xFF000000)])
        self.write("wait", [(24, 24, 12, 12, 40, 0xFF000000)] * 54 + [(48, 48, 24, 24, 40, 0xFF000000)] * 54)
        wait = x2c.build_cape(self.theme, "Test", 24)["Cursors"]["com.apple.coregraphics.Wait"]
        self.assertLessEqual(wait["FrameCount"], x2c.MAX_FRAMES)
        self.assertAlmostEqual(wait["FrameCount"] * wait["FrameDuration"], 54 * 0.040)
        self.assertEqual(png_size(wait["Representations"][0]), (24, 24 * wait["FrameCount"]))

    def test_premultiplied_pixels_are_unpremultiplied(self):
        self.assertEqual(x2c.unpremultiply_row([0x80404040]), bytes((0x7F, 0x7F, 0x7F, 0x80)))

    def test_png_holds_unpremultiplied_rgba(self):
        self.write("left_ptr", [(24, 24, 0, 0, 0, 0x80404040), (48, 48, 0, 0, 0, 0x80404040)])
        arrow = x2c.build_cape(self.theme, "Test", 24)["Cursors"]["com.apple.coregraphics.Arrow"]
        self.assertEqual(png_first_pixel(arrow["Representations"][0]), bytes((0x7F, 0x7F, 0x7F, 0x80)))

    def test_falls_back_to_later_xcursor_name(self):
        self.write("left_ptr", [(24, 24, 0, 0, 0, 0xFF000000), (48, 48, 0, 0, 0, 0xFF000000)])
        self.write("hand2", [(24, 24, 9, 1, 0, 0xFF000000), (48, 48, 18, 2, 0, 0xFF000000)])
        cursors = x2c.build_cape(self.theme, "Test", 24)["Cursors"]
        self.assertEqual(cursors["com.apple.cursor.13"]["HotSpotX"], 9.0)

    def test_missing_2x_size_names_the_file_and_available_sizes(self):
        self.write("left_ptr", [(24, 24, 0, 0, 0, 0xFF000000)])
        with self.assertRaisesRegex(ValueError, r"left_ptr: needs 24px and 48px images, has \[24\]"):
            x2c.build_cape(self.theme, "Test", 24)

    def test_theme_without_arrow_is_rejected(self):
        self.write("xterm", [(24, 24, 0, 0, 0, 0xFF000000), (48, 48, 0, 0, 0, 0xFF000000)])
        with self.assertRaisesRegex(ValueError, "no arrow cursor"):
            x2c.build_cape(self.theme, "Test", 24)

    def test_non_xcursor_file_is_rejected(self):
        (self.theme / "left_ptr").write_bytes(b"nope")
        with self.assertRaisesRegex(ValueError, "not an XCursor file"):
            x2c.read_xcursor(self.theme / "left_ptr")

    def test_truncated_file_names_the_file(self):
        (self.theme / "left_ptr").write_bytes(xcursor_bytes([(24, 24, 0, 0, 0, 0xFF000000)])[:60])
        with self.assertRaisesRegex(ValueError, "left_ptr: truncated XCursor file"):
            x2c.read_xcursor(self.theme / "left_ptr")

    def test_differing_frame_counts_between_sizes_are_rejected(self):
        self.write("left_ptr", [(24, 24, 0, 0, 0, 0xFF000000)] * 2 + [(48, 48, 0, 0, 0, 0xFF000000)])
        with self.assertRaisesRegex(ValueError, "24px has 2 frames but 48px has 1"):
            x2c.build_cape(self.theme, "Test", 24)

    def test_animation_frames_of_different_widths_are_rejected(self):
        frames = [x2c.Frame(24, 24, 0, 0, 0, [0] * 576), x2c.Frame(32, 24, 0, 0, 0, [0] * 768)]
        with self.assertRaisesRegex(ValueError, "differ in width: 32 != 24"):
            x2c.frame_strip_png(frames)

    def test_main_writes_an_xml_plist_named_after_the_theme(self):
        theme = self.theme / "My-Theme"
        (theme / "cursors").mkdir(parents=True)
        (theme / "cursors" / "left_ptr").write_bytes(
            xcursor_bytes([(24, 24, 0, 0, 0, 0xFF000000), (48, 48, 0, 0, 0, 0xFF000000)]))
        out = self.theme / "out.cape"
        x2c.main([str(theme), str(out)])
        self.assertEqual(plistlib.loads(out.read_bytes())["CapeName"], "My-Theme")


if __name__ == "__main__":
    unittest.main()
