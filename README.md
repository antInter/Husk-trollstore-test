# Husk - Trollstore (iOS 15+)

attempting to intergrate ios 15 trollstore support

## Licence

GPL-2.0-or-later. Husk links QEMU, which is GPLv2, so the shipped binary is a
combined GPLv2 work and the full source is public. It cannot go on the App
Store — both because of that and because it needs `get-task-allow` plus a
debugger attaching at runtime. See [docs/01-licensing.md](docs/01-licensing.md).

## TS15 seed-fix r2

This revision addresses the observed QEMU exit caused by a missing
`lineage-efi-vars.fd`. The original TS15 IPA omitted both seed disks.
It does not claim that Android has been device-tested after the fix.

