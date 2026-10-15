# Background Image Library

KANTA recognizes these conventional background-image pools:

- `BG/MOTION/`
- `BG/NATURE/`
- `BG/3D/`
- `BG/USER/`

`BG/USER` is the destination used by the in-app **Add Backgrounds**
workflow for compatible user-supplied images. Legacy `BGPHOTO/` folders
remain readable for compatibility.

User imports are copied at original quality. Gelo does not resize or
recompress them.

Do not commit distributable image assets here unless the exact file has
an `approved` entry in `ThirdParty/media-provenance.tsv`.



`BUNDLED/` contains the ten owner-selected generated PNGs shipped with KANTA.
Choose them from CONTROL > Playback > Stage visuals > Images. Xcode copies this
folder into the app bundle; no Files import or internet connection is needed.
Exact provenance and hashes: `ThirdParty/bundled-backgrounds.json`.
