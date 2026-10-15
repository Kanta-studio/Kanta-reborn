#!/usr/bin/env python3
"""Generate deterministic, original lyric-bearing KAR fixtures for KANTA.

No third-party melodies, lyrics, SoundFonts, or recordings are included.
Run: python3 Tools/generate-starter-kar.py OUTPUT_DIRECTORY
"""
from pathlib import Path
import hashlib
import json
import struct
import sys

SONGS = (
    ("Morning Light", 96, ("Morning light", "We sing today", "Find your voice", "And lead the way")),
    ("Sing Together", 108, ("Sing together", "Hear the sound", "Every voice", "Can gather round")),
    ("Starlight Echo", 84, ("Stars are shining", "Through the night", "Echo softly", "Hold the light")),
)
PPQ = 480

def variable_length(value):
    result = [value & 0x7f]
    value >>= 7
    while value:
        result.insert(0, (value & 0x7f) | 0x80)
        value >>= 7
    return bytes(result)

def chunk(kind, payload):
    return kind + struct.pack(">I", len(payload)) + payload

def render(title, bpm, lines):
    events = []
    def add(tick, message, priority=1):
        events.append((tick, priority, message))
    tempo = round(60_000_000 / bpm)
    add(0, b"\xff\x51\x03" + tempo.to_bytes(3, "big"), 0)
    name = title.encode("utf-8")
    add(0, b"\xff\x03" + variable_length(len(name)) + name, 0)
    add(0, b"\xc0\x00", 0)
    notes = (60, 62, 64, 67, 65, 64, 62, 60)
    for line_index, line in enumerate(lines):
        start = line_index * PPQ * 4
        for word_index, word in enumerate(line.split()):
            lyric = (("/" if word_index == 0 else "") + word + " ").encode("utf-8")
            add(start + word_index * PPQ, b"\xff\x05" + variable_length(len(lyric)) + lyric, 0)
        for beat in range(4):
            pitch = notes[(line_index * 2 + beat) % len(notes)]
            add(start + beat * PPQ, bytes((0x90, pitch, 88)))
            add(start + (beat + 1) * PPQ - 12, bytes((0x80, pitch, 0)), 0)
    add(len(lines) * PPQ * 4, b"\xff\x2f\x00", 9)
    track = bytearray()
    previous = 0
    for tick, _, message in sorted(events, key=lambda item: (item[0], item[1])):
        track.extend(variable_length(tick - previous))
        track.extend(message)
        previous = tick
    return chunk(b"MThd", struct.pack(">HHH", 0, 1, PPQ)) + chunk(b"MTrk", bytes(track))

def soundfont():
    """SF2 2.01: original integer triangle oscillator, no external samples.

    One looping 100-frame period at 22050 Hz, root A3 (220.5 Hz,
    corrected by -4 cents). Program 0 / bank 0, mono ROM-free sample.
    """
    def riff(kind, payload):
        return kind + struct.pack("<I", len(payload)) + payload + b"\x00" * (len(payload) % 2)
    def listing(kind, parts):
        return riff(b"LIST", kind + b"".join(parts))
    def name(value):
        return value.encode("ascii").ljust(20, b"\x00")
    def gen(operation, value):
        return struct.pack("<HH", operation, value & 0xffff)
    samples = [(-10000 + 400 * i) if i < 50 else (30000 - 400 * i) for i in range(100)]
    samples += [0] * 46  # SF2 mandatory sample guard frames
    info = listing(b"INFO", [riff(b"ifil", struct.pack("<HH", 2, 1)),
        riff(b"isng", b"EMU8000\x00"), riff(b"INAM", b"KANTA Original Tone\x00"),
        riff(b"ICMT", b"Procedural triangle; no third-party samples.\x00")])
    sdta = listing(b"sdta", [riff(b"smpl", struct.pack("<" + "h" * len(samples), *samples))])
    phdr = name("KANTA Tone") + struct.pack("<HHHIII", 0, 0, 0, 0, 0, 0)
    phdr += name("EOP") + struct.pack("<HHHIII", 0, 0, 1, 0, 0, 0)
    igen = gen(34, -7973) + gen(38, -3986) + gen(54, 1) + gen(53, 0)
    shdr = name("Triangle A3") + struct.pack("<IIIIIBbHH", 0, 100, 0, 100, 22050, 57, -4, 0, 1)
    shdr += name("EOS") + struct.pack("<IIIIIBbHH", 146, 146, 146, 146, 22050, 0, 0, 0, 1)
    pdta = listing(b"pdta", [riff(b"phdr", phdr),
        riff(b"pbag", struct.pack("<HHHH", 0, 0, 1, 0)), riff(b"pmod", bytes(10)),
        riff(b"pgen", gen(41, 0) + gen(0, 0)),
        riff(b"inst", name("Triangle") + struct.pack("<H", 0) + name("EOI") + struct.pack("<H", 1)),
        riff(b"ibag", struct.pack("<HHHH", 0, 0, 4, 0)), riff(b"imod", bytes(10)),
        riff(b"igen", igen + gen(0, 0)), riff(b"shdr", shdr)])
    return riff(b"RIFF", b"sfbk" + info + sdta + pdta)


def main():
    destination = Path(sys.argv[1]) if len(sys.argv) == 2 else Path("build/starter-kar")
    destination.mkdir(parents=True, exist_ok=True)
    manifest = []
    for title, bpm, lines in SONGS:
        filename = title.lower().replace(" ", "-") + ".kar"
        data = render(title, bpm, lines)
        (destination / filename).write_bytes(data)
        manifest.append({"title": title, "file": filename, "bpm": bpm,
                         "lyrics": list(lines), "sha256": hashlib.sha256(data).hexdigest()})
    tone = soundfont()
    (destination / "kanta-tone.sf2").write_bytes(tone)
    manifest.append({"title": "KANTA Original Tone", "file": "kanta-tone.sf2",
                     "sha256": hashlib.sha256(tone).hexdigest()})
    (destination / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print(f"Generated 3 karaoke songs and an original offline tone in {destination}")

if __name__ == "__main__":
    main()

