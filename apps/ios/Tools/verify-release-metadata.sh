#!/usr/bin/env bash
set -euo pipefail

project_file="project.yml"
required_lines=(
  "PRODUCT_BUNDLE_IDENTIFIER: com.gelo.karaoke"
  "PRODUCT_NAME: KANTA"
  "IPHONEOS_DEPLOYMENT_TARGET: 17.0"
  "TARGETED_DEVICE_FAMILY: \"1,2\""
  "ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon"
  "archive:"
  "config: Release"
)
for required in "${required_lines[@]}"; do
  grep -Fq "$required" "$project_file" || { echo "::error::Release metadata is missing: $required"; exit 1; }
done
marketing_version="$(awk '/MARKETING_VERSION:/ { print $2; exit }' "$project_file")"
build_version="$(awk '/CURRENT_PROJECT_VERSION:/ { print $2; exit }' "$project_file")"
[[ "$marketing_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "::error::MARKETING_VERSION must be semantic x.y.z."; exit 1; }
[[ "$build_version" =~ ^[1-9][0-9]*$ ]] || { echo "::error::CURRENT_PROJECT_VERSION must be a positive integer."; exit 1; }

python3 - <<'PY'
import json, plistlib, struct
from pathlib import Path
def require(condition, message):
    if not condition:
        raise SystemExit("::error::" + message)
with open("Config/GeloKaraoke-Info.plist","rb") as f: info=plistlib.load(f)
with open("Config/KANTA.entitlements","rb") as f: ent=plistlib.load(f)
container="iCloud.com.gelo.karaoke"
require(info.get("ITSAppUsesNonExemptEncryption") is False, "Explicit exempt encryption declaration missing.")
require(
    {"UIInterfaceOrientationPortrait", "UIInterfaceOrientationLandscapeLeft", "UIInterfaceOrientationLandscapeRight"}.issubset(
        set(info.get("UISupportedInterfaceOrientations", []))
    ),
    "iPhone singing must support portrait and both landscape directions."
)
require(
    {"UIInterfaceOrientationPortrait", "UIInterfaceOrientationPortraitUpsideDown",
     "UIInterfaceOrientationLandscapeLeft", "UIInterfaceOrientationLandscapeRight"}.issubset(
        set(info.get("UISupportedInterfaceOrientations~ipad", []))
    ),
    "iPad singing must support all orientations."
)
require(container in ent.get("com.apple.developer.icloud-container-identifiers",[]), "Missing iCloud container entitlement.")
require(container in ent.get("com.apple.developer.ubiquity-container-identifiers",[]), "Missing iCloud Documents ubiquity entitlement.")
require("CloudDocuments" in ent.get("com.apple.developer.icloud-services",[]), "Missing CloudDocuments entitlement.")
require(bool(ent.get("com.apple.developer.ubiquity-kvstore-identifier")), "Missing iCloud key-value entitlement.")
catalog=Path("Sources/App/Assets.xcassets")
appicon=catalog/"AppIcon.appiconset"
icon=appicon/"AppIcon-1024.png"
require((catalog/"Contents.json").is_file(),"Missing Assets.xcassets/Contents.json.")
require((appicon/"Contents.json").is_file(),"Missing AppIcon Contents.json.")
require(icon.is_file(),"Missing AppIcon-1024.png.")
payload=json.loads((appicon/"Contents.json").read_text())
require(any(x.get("filename")=="AppIcon-1024.png" and x.get("idiom")=="universal" and x.get("platform")=="ios" and x.get("size")=="1024x1024" for x in payload.get("images",[])),"AppIcon must declare a single-size iOS 1024x1024 image.")
data=icon.read_bytes()
require(data[:8]==b"\x89PNG\r\n\x1a\n","App icon must be PNG.")
require(len(data)>=33 and data[12:16]==b"IHDR","Invalid AppIcon PNG.")
width,height,bit_depth,color_type=struct.unpack(">IIBB",data[16:26])
require((width,height)==(1024,1024),"App icon must be exactly 1024x1024.")
require(color_type in {2,3},"App icon must not have an alpha channel.")
require(b"tRNS" not in data,"App icon must not contain transparency.")
print("Release plist/entitlement/AppIcon guard passed.")
PY
echo "Release metadata guard passed: KANTA $marketing_version ($build_version)."
