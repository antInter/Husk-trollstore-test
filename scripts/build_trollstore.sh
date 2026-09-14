#!/bin/bash
# Experimental iOS 15 software-renderer build. Requires macOS and Xcode.
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT="$PWD"
export SDKMINVER=15.0 HUSK_TROLLSTORE=1
mkdir -p build/logs build/artifacts
python3 scripts/fetch_guest_seeds.py
bash scripts/fetch_sources.sh
bash scripts/build_ios.sh libffi glib pixman libucontext libslirp qemupatch
bash scripts/integrate_husk.sh
bash scripts/build_ios.sh qemu
bash scripts/fetch_phase0_guest.sh
python3 - <<'PY'
import json, plistlib, pathlib, yaml, os, subprocess, datetime
p=pathlib.Path('src/app')
s=yaml.safe_load((p/'project.yml').read_text())
s['options']['deploymentTarget']['iOS']='15.0'
t=s['targets']['Husk']
t['settings']['base'].update(IPHONEOS_DEPLOYMENT_TARGET='15.0', PRODUCT_BUNDLE_IDENTIFIER='com.husk.app.ts15', SWIFT_ACTIVE_COMPILATION_CONDITIONS='$(inherited) HUSK_TROLLSTORE', INFOPLIST_FILE='Info-TrollStore.plist', CODE_SIGN_ENTITLEMENTS='TrollStore.entitlements', ENABLE_USER_SCRIPT_SANDBOXING='NO')
t['dependencies']=[d for d in t['dependencies'] if 'ANGLE' not in d.get('framework','')]
(p/'project-trollstore.json').write_text(json.dumps(s))
i=plistlib.loads((p/'Husk/Info.plist').read_bytes())
i['CFBundleDisplayName']='Husk TS15'
i['CFBundleVersion']=os.environ.get('GITHUB_RUN_NUMBER','2')
try:
    commit=subprocess.check_output(['git','rev-parse','--short','HEAD'],text=True).strip()
except (subprocess.CalledProcessError, FileNotFoundError):
    commit='source-zip'
i['HuskBuildCommit']='seedfix-r2-'+commit
i['HuskBuildDate']=datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%d %H:%M UTC')
i['LSApplicationQueriesSchemes']=['apple-magnifier']
(p/'Info-TrollStore.plist').write_bytes(plistlib.dumps(i))
# Never include dynamic-codesigning or the private debugger/library-validation
# entitlements: TrollStore documents these as banned on iOS 15 A12+.
e={'get-task-allow':True,'com.apple.developer.kernel.increased-memory-limit':True,'com.apple.developer.kernel.extended-virtual-addressing':True}
(p/'TrollStore.entitlements').write_bytes(plistlib.dumps(e))
PY
(cd src/app && xcodegen generate --spec project-trollstore.json)
DD="$ROOT/build/ts15-derived"
rm -rf "$DD/Build/Products"
xcodebuild -project src/app/Husk.xcodeproj -scheme Husk -sdk iphoneos \
 -destination 'generic/platform=iOS' -configuration Release -derivedDataPath "$DD" \
 IPHONEOS_DEPLOYMENT_TARGET=15.0 CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO \
 build 2>&1 | tee build/logs/xcode-ts15.log
APP="$DD/Build/Products/Release-iphoneos/Husk.app"
python3 scripts/fetch_guest_seeds.py --verify-only "$APP"
python3 - "$APP" <<'PY'
import pathlib,plistlib,subprocess,sys,re
app=pathlib.Path(sys.argv[1]); info=plistlib.loads((app/'Info.plist').read_bytes())
assert info['CFBundleIdentifier']=='com.husk.app.ts15'
def ver(s): return (tuple(map(int,s.split('.')))+(0,0,0))[:3]
assert ver(info['MinimumOSVersion'])<=ver('15.0')
for n in [info['CFBundleExecutable'],'Frameworks/libqemu-aarch64-softmmu.dylib','vmlinuz-virt','initramfs-virt','edk2-aarch64-code.fd','lineage-efi-vars-seed.fd','lineage-vdb-seed.qcow2','default.metallib']:
 assert (app/n).is_file() and (app/n).stat().st_size, 'Missing bundle file: '+n
assert not list(app.rglob('*ANGLE*'))
for f in [app/info['CFBundleExecutable'],*app.rglob('*.dylib')]:
 subprocess.run(['xcrun','lipo',str(f),'-verify_arch','arm64'],check=True)
 text=subprocess.check_output(['xcrun','otool','-l',str(f)],text=True)
 versions=re.findall(r'\bminos\s+([\d.]+)',text)
 if not versions: versions=re.findall(r'cmd LC_VERSION_MIN_IPHONEOS\s+cmdsize \d+\s+version ([\d.]+)',text)
 assert versions and all(ver(v)<=ver('15.0') for v in versions), 'Incompatible minimum OS: '+str(f)
 platforms=re.findall(r'\bplatform\s+(\S+)',text)
 assert all(p in ('2','IOS') for p in platforms), 'Non-iOS library: '+str(f)
 print('Deployment target checked:',f.name)
PY
# Ad-hoc signing embeds entitlements. TrollStore re-signs on installation.
# This needs no Apple certificate. Nested libraries get no app entitlements.
while IFS= read -r -d '' lib; do codesign --force --sign - "$lib"; done < <(find "$APP/Frameworks" -name '*.dylib' -type f -print0)
codesign --force --sign - --generate-entitlement-der --entitlements src/app/TrollStore.entitlements "$APP"
codesign --verify --strict "$APP"
codesign -d --entitlements :- "$APP" > build/logs/embedded-entitlements.plist
python3 - <<'PY'
import plistlib
with open('build/logs/embedded-entitlements.plist','rb') as f: e=plistlib.load(f)
assert e.get('get-task-allow') is True
assert not {'dynamic-codesigning','com.apple.private.cs.debugger','com.apple.private.skip-library-validation'}.intersection(e)
PY
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
mkdir -p "$STAGE/Payload"
cp -R "$APP" "$STAGE/Payload/"
(cd "$STAGE" && zip -qry Husk-TS15.ipa Payload)
mv "$STAGE/Husk-TS15.ipa" build/artifacts/
(cd build/artifacts && shasum -a 256 Husk-TS15.ipa > Husk-TS15.ipa.sha256)
