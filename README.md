# Husk

Android app launcher for iOS.

Drop in an APK, tap it, and the Android app opens full-screen.

## Licence

GPL-2.0-or-later. Husk links QEMU, which is GPLv2, so the shipped binary is a
combined GPLv2 work and the full source is public. It cannot go on the App
Store — both because of that and because it needs `get-task-allow` plus a
debugger attaching at runtime. See [docs/01-licensing.md](docs/01-licensing.md).

## TS15 seed-fix r2

This revision addresses the observed QEMU exit caused by a missing
`lineage-efi-vars.fd`. The original TS15 IPA omitted both seed disks.
It does not claim that Android has been device-tested after the fix.

### Rebuild and install
1. Upload this source into your existing fork, including hidden `.github/`.
2. Run **Actions -> iOS 15 TrollStore IPA - seed fix r2 -> Run workflow**.
3. Download **Husk-TS15-seedfix-r2**, unzip, and install `Husk-TS15.ipa`
   over the existing app in TrollStore. Keep bundle ID `com.husk.app.ts15`.
4. Back up important guest data first; do not uninstall the old app or delete
   the downloaded disks/snapshot. Preparation now preserves existing userdata
   even when its `.seed` marker is absent or old.
5. The log build identifier must start with `seedfix-r2-`. Try Full screen Android.

If preparation fails, the setup screen shows the filename/error instead of
entering QEMU. Current and three previous app/serial logs are available in
Files and through View logs -> Share. The previous app log is `husk.log.1`.
JIT allocation is unchanged. The installed 4096 MiB snapshot configuration is
also unchanged; memory pressure may be a subsequent issue, but was not the
cause of the supplied missing-file error.

### Seed provenance and verification
`scripts/fetch_guest_seeds.py` extracts only two guest-data files from the
checksum-pinned upstream `Leviidev/Husk` release **0.2.0**. No upstream native
executable, framework, signature, or entitlement is reused. Both seeds are
QCOW2, including the `.fd` file (64 MiB virtual UEFI variables); userdata is
16 GiB virtual. Hashes and sizes are pinned in the script. The small seeds
are included here under `src/app/Husk/Resources`; the script recovers them
from upstream if absent and rejects incorrect content. Build-time validation
checks the final app bundle before signing/packaging. Existing GPL licensing
remains applicable; see LICENSE and docs/01-licensing.md.

Local checks: real seed hashes/headers, tamper rejection, shell syntax,
preflight ordering, and no userdata deletion in preparation. Apple SDK
compilation and device boot still require the workflow and your phone.
