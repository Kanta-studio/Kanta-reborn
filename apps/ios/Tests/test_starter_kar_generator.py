#!/usr/bin/env python3
"""Offline deterministic fixture checks; does not invoke GitHub Actions."""
import importlib.util
import struct
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("starter_kar", ROOT / "Tools/generate-starter-kar.py")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

def read_vlq(data, offset):
    value = 0
    for _ in range(4):
        byte = data[offset]
        offset += 1
        value = (value << 7) | (byte & 0x7f)
        if byte < 0x80:
            return value, offset
    raise AssertionError("Invalid variable-length quantity")

def lyrics(data):
    assert data[:4] == b"MThd"
    assert struct.unpack(">HHH", data[8:14]) == (0, 1, 480)
    assert data[14:18] == b"MTrk"
    size = struct.unpack(">I", data[18:22])[0]
    assert len(data) == 22 + size
    offset = 22
    tick = 0
    words = []
    running = None
    while offset < len(data):
        delta, offset = read_vlq(data, offset)
        tick += delta
        status = data[offset]
        if status < 0x80:
            assert running is not None
            status = running
        else:
            offset += 1
            if status < 0xf0:
                running = status
        if status == 0xff:
            kind = data[offset]
            offset += 1
            length, offset = read_vlq(data, offset)
            payload = data[offset:offset + length]
            offset += length
            if kind == 5:
                words.append((tick, payload.decode("utf-8").strip().lstrip("/")))
            if kind == 0x2f:
                assert offset == len(data)
                break
        elif status in (0xf0, 0xf7):
            length, offset = read_vlq(data, offset)
            offset += length
        else:
            offset += 1 if status & 0xf0 in (0xc0, 0xd0) else 2
    return words

class StarterKARTests(unittest.TestCase):
    def test_three_distinct_deterministic_lyric_tracks(self):
        hashes = set()
        for title, bpm, lines in module.SONGS:
            first = module.render(title, bpm, lines)
            self.assertEqual(first, module.render(title, bpm, lines))
            hashes.add(first)
            actual = lyrics(first)
            expected = [
                (line_index * module.PPQ * 4 + word_index * module.PPQ, word)
                for line_index, line in enumerate(lines)
                for word_index, word in enumerate(line.split())
            ]
            self.assertEqual(actual, expected)
        self.assertEqual(len(hashes), 3)

class CommittedStarterTests(unittest.TestCase):
    def test_committed_bytes_and_checksums(self):
        import runpy
        verify = runpy.run_path(str(ROOT / "Tools/verify-starter-resources.py"))["verify"]
        verify()

    def test_track_notes_tempo_and_end_time(self):
        for title, bpm, lines in module.SONGS:
            data = module.render(title, bpm, lines)
            tick, offset, active, ons, tempos = 0, 22, set(), 0, []
            while offset < len(data):
                delta, offset = read_vlq(data, offset)
                tick += delta
                status = data[offset]
                offset += 1
                if status == 0xff:
                    kind = data[offset]
                    length, offset = read_vlq(data, offset + 1)
                    payload = data[offset:offset+length]
                    self.assertEqual(len(payload), length)
                    offset += length
                    if kind == 0x51:
                        self.assertEqual(length, 3)
                        tempos.append((tick, int.from_bytes(payload, "big")))
                    if kind == 0x2f:
                        self.assertFalse(active)
                        self.assertEqual(tick, 16 * module.PPQ)
                        self.assertEqual(offset, len(data))
                elif status == 0xc0:
                    offset += 1
                else:
                    self.assertIn(status, (0x80, 0x90))
                    key, velocity = data[offset:offset+2]
                    offset += 2
                    self.assertLess(key, 128)
                    self.assertLess(velocity, 128)
                    if status == 0x90:
                        self.assertNotIn(key, active)
                        active.add(key)
                        ons += 1
                    else:
                        self.assertIn(key, active)
                        active.remove(key)
            self.assertEqual(ons, 16)
            self.assertEqual(tempos, [(0, round(60_000_000 / bpm))])

    def test_soundfont_riff_hydra_and_original_sample(self):
        data = module.soundfont()
        self.assertEqual(data[:4], b"RIFF")
        self.assertEqual(data[8:12], b"sfbk")
        self.assertEqual(struct.unpack("<I", data[4:8])[0], len(data) - 8)
        def chunks(blob, start, end):
            result = {}
            while start < end:
                name = blob[start:start+4]
                size = struct.unpack("<I", blob[start+4:start+8])[0]
                self.assertLessEqual(start + 8 + size, end)
                result[name] = blob[start+8:start+8+size]
                start += 8 + size + size % 2
            self.assertEqual(start, end)
            return result
        offset, lists = 12, {}
        while offset < len(data):
            size = struct.unpack("<I", data[offset+4:offset+8])[0]
            self.assertEqual(data[offset:offset+4], b"LIST")
            lists[data[offset+8:offset+12]] = chunks(data, offset+12, offset+8+size)
            offset += size + 8 + size % 2
        pdta = lists[b"pdta"]
        self.assertEqual(set(pdta), {b"phdr", b"pbag", b"pmod", b"pgen", b"inst", b"ibag", b"imod", b"igen", b"shdr"})
        self.assertEqual(len(pdta[b"phdr"]), 76)
        self.assertEqual(len(pdta[b"shdr"]), 92)
        samples = struct.unpack("<146h", lists[b"sdta"][b"smpl"])
        self.assertGreater(max(samples), 0)
        self.assertLess(min(samples), 0)
        self.assertEqual(samples[-46:], (0,) * 46)


if __name__ == "__main__":
    unittest.main()

