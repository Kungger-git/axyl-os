# CLAUDE.md — Arch Linux ISO Development (bspwm dotfiles)

This file guides Claude through working in this repository. Follow every rule here precisely and consistently across all sessions.

---

## Project Overview

This repository contains:
- Custom Arch Linux ISO build configuration (based on `archiso`)
- bspwm window manager dotfiles and system configuration
- Package lists, hooks, and overlays to produce a bootable, opinionated Arch ISO

---

## Task Tracking (TODOs)

**Every task Claude performs must be tracked as a TODO.**

Rules:
- Before starting any work, write a TODO list using `TodoWrite` for the current task.
- Mark each item complete immediately when done — do not batch completions.
- Never leave a TODO open at the end of a session without noting its status.
- If a task is blocked, annotate it with the blocker inline (e.g., `[BLOCKED: missing package]`).
- TODOs must be granular: one action per item, not multi-step blobs.

Example format:
```
[ ] Scaffold archiso releng profile directory
[ ] Add bspwm to packages.x86_64
[ ] Copy bspwm config to airootfs overlay
[ ] Verify sxhkd dependency is listed
[ ] Test build with mkarchiso
```

---

## Dependency Management

**Never assume a dependency is available. Verify it.**

Rules:
- Before referencing any tool, package, or file, confirm it exists in the repo or is listed in `packages.x86_64` (or equivalent package list).
- If a dependency is required but not yet present, add it — do not silently rely on it.
- After adding any new config file, hook, or script, check whether it introduces new runtime or build-time dependencies.
- Repeat this dependency audit until you are **100% confident** no undeclared dependency exists.
- Keep a running list of external tools required to build the ISO locally (document in README under "Build Requirements").

Required build-time tools (must be present on the build host):
- `archiso`
- `mkinitcpio`
- `dosfstools`
- `e2fsprogs`
- `libisoburn` (for `xorriso`)
- `squashfs-tools`
- `git`

Dependency check process for every new feature:
1. Identify every binary, library, or config the feature calls.
2. Trace each back to its Arch package name (`pkgfile` or `pacman -F`).
3. Add any missing packages to `packages.x86_64`.
4. Verify no circular or conflicting packages are introduced.

---

## README Updates

**Update README.md for every meaningful change.**

Update triggers (update README when any of these occur):
- A new package or package group is added to the ISO
- A new dotfile or WM configuration is added or modified
- A new build step or build flag is introduced
- A new dependency (build-time or runtime) is required
- A default keybinding, theme, or behaviour changes
- A script is added to `airootfs/usr/local/bin/` or equivalent

README must always contain:
- **What this ISO is** — one-paragraph description
- **Build Requirements** — host packages needed to run `mkarchiso`
- **How to Build** — step-by-step commands
- **Key Features** — bspwm config highlights, included packages, defaults
- **Keybindings** — super key map summary (or link to sxhkdrc)
- **Changelog** — dated bullet points for significant changes

---

## File Structure Checks

**After every edit session, verify the file structure is internally consistent.**

Checks to run mentally (or with shell commands) before finishing any task:

```
archiso/
  profiledef.sh        ← must exist; defines ISO name, arch, compression
  packages.x86_64      ← all runtime packages listed here
  pacman.conf          ← mirrors and repos used during build
  airootfs/            ← root overlay copied into the live system
    etc/
      skel/            ← default user home (bspwm configs go here)
    usr/
      local/
        bin/           ← custom scripts
  efiboot/             ← EFI bootloader files
  syslinux/            ← BIOS bootloader files (if supporting legacy)
  grub/                ← GRUB config (if used)
```

Checks:
- Every file in `airootfs/etc/skel/` has a corresponding package listed in `packages.x86_64` that owns or uses it.
- Every script in `airootfs/usr/local/bin/` has its interpreter listed (e.g., `bash`, `python`, `python-gobject`).
- `profiledef.sh` references a compression method available in `squashfs-tools` on the build host.
- No config file references a binary that is not in `packages.x86_64`.

Run this check explicitly whenever:
- A new dotfile is added
- A package is added or removed
- A new script is introduced
- The airootfs overlay is reorganised

---

## Build & Test Commands

```bash
# Build the ISO (run as root or with sudo)
sudo mkarchiso -v -w /tmp/archiso-work -o /tmp/archiso-out ./archiso/

# Clean the work directory before a rebuild
sudo rm -rf /tmp/archiso-work

# Test in QEMU (BIOS)
qemu-system-x86_64 -cdrom /tmp/archiso-out/*.iso -m 2G -boot d

# Test in QEMU (UEFI, requires ovmf)
qemu-system-x86_64 -cdrom /tmp/archiso-out/*.iso -m 2G \
  -bios /usr/share/ovmf/x64/OVMF.fd
```

---

## Coding & Editing Rules

- Prefer editing existing files over creating new ones.
- Shell scripts use `#!/usr/bin/env bash` and `set -euo pipefail`.
- No comments unless the WHY is non-obvious (a hidden constraint, workaround, or subtle invariant).
- Do not add error handling for scenarios that cannot happen (trust `mkarchiso` internals).
- No placeholder or stub code — every added line must be functional.
- Keep configs minimal: do not add WM features or packages not explicitly requested.

---

## Workflow Checklist (run mentally on every task)

```
[ ] Write TODOs before starting
[ ] Identify all new dependencies
[ ] Add missing packages to packages.x86_64
[ ] Edit or create the relevant files
[ ] Verify file structure is still consistent
[ ] Update README.md if any user-facing detail changed
[ ] Mark all TODOs complete (or annotate blockers)
```
