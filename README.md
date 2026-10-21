# xanmod-kernel-WSL2

![XanMod MAIN](https://github.com/schw3i/xanmod-kernel-WSL2/actions/workflows/MAIN.yml/badge.svg?branch=main)
![Release](https://img.shields.io/github/v/release/schw3i/xanmod-kernel-WSL2)

An unofficial [XanMod](https://gitlab.com/xanmod/linux) kernel for WSL2, based on [Locietta's port](https://github.com/Locietta/xanmod-kernel-WSL2). This fork automatically builds the latest released **MAIN** kernel with **MZEN3** optimization for AMD Zen3/Zen4.

`/dev/dri/card0` and `/dev/dri/renderD128` are virtual DRM devices created by built-in VGEM. Their presence does not prove hardware rendering; WSL GPU acceleration also depends on dxgkrnl, the Windows GPU driver, Linux userspace, and the application's graphics backend. See [WSL issue #41792](https://github.com/microsoft/WSL/issues/41792).

## Releases

Download from [this fork's releases](https://github.com/schw3i/xanmod-kernel-WSL2/releases/latest):

| File | Contents |
| --- | --- |
| `bzImage-zen3` | MAIN kernel image for AMD Zen3/Zen4 |
| `bzImage-zen3-addons.vhdx.7z` | Optional modules, prepared external-module headers, userspace API headers, and kernel documentation |

The upstream Scoop bucket installs upstream releases. Use this fork's release assets for the configuration described here.

## Install manually

Keep a known-good kernel and its matching addon VHDX for rollback. Installing a custom kernel affects all WSL2 distributions on the Windows host.

1. Download `bzImage-zen3` and place it at a Windows path such as `C:\WSL\kernels\bzImage-zen3`.
2. Create or edit `%UserProfile%\.wslconfig`:

   ```ini
   [wsl2]
   kernel=C:\\WSL\\kernels\\bzImage-zen3
   ```

3. If you need the addon package, extract `bzImage-zen3-addons.vhdx.7z` beside the kernel. Under the same `[wsl2]` section, add:

   ```ini
   kernelModules=C:\\WSL\\kernels\\bzImage-zen3-addons.vhdx
   ```

   The addon must match the kernel release. WSL 2.5.1 or later is required for `kernelModules`. Remove an old `kernelModules` entry if you are installing only the kernel image.

4. Save your work in WSL, then run in PowerShell:

   ```powershell
   wsl --shutdown
   ```

5. Start the distribution and check (`uname -r` reports the `-schw3i-WSL2` suffix):

   ```bash
   uname -r
   ls -l /dev/dri
   test -c /dev/dri/card0 && test -c /dev/dri/renderD128
   ```

There is no automatic Windows installation or WSL restart. To roll back, restore the previous `kernel` and matching `kernelModules` paths, or remove both overrides to use Microsoft's kernel, then shut down and restart WSL.

See Microsoft's [.wslconfig documentation](https://learn.microsoft.com/en-us/windows/wsl/wsl-config#configure-global-options-with-wslconfig) for other settings.

## Automated builds

The MAIN workflow runs daily at 14:25 UTC, on pushes and pull requests to `main`, and through `workflow_dispatch`. Automatic builds target only `MZEN3`.

Source setup checks out the newest release tag from XanMod's MAIN feed. A new upstream release or builder commit creates a build; an existing release skips compilation. Pull requests verify the build and never publish releases.

MAIN releases publish as GitHub's latest release. LTS is available through manual dispatch only and does not replace the latest MAIN release.

## Build locally

Use an x86-64 Linux environment with the Clang/LLVM toolchain, kernel build dependencies, ccache, Python, rsync, `mke2fs`, `qemu-img`, and 7-Zip. The CI container and dependency installation are defined in [build-core.yml](.github/workflows/build-core.yml).

From a fresh checkout:

```bash
./scripts/setup.sh --branch MAIN --arch MZEN3
cd linux
../scripts/build.sh --branch MAIN --jobs 4
../scripts/post-build.sh --name bzImage-zen3
```

Choose a job count that fits available memory. The final image and addon archive appear in the repository root. Packaging also compiles an external module and a userspace-header consumer against the prepared headers.

Setup refuses to overwrite an existing `linux/` directory. `--no-download` uses an existing clean, unpatched source tree; it still applies the WSL patches and configuration. Preserve any work in a previous source tree before replacing it.

The addon VHDX exposes these paths beneath `/lib/modules/$(uname -r)` in WSL:

- `build/`: the prepared kbuild tree for external modules.
- `build/usr/include/`: sanitized userspace API headers, separate from the distribution's libc headers.
- `build/Documentation/`: documentation from the matching kernel source.

## Credits

- Locietta and contributors for the original XanMod WSL2 port.
- The Linux community for the kernel.
- Microsoft for WSL2 and dxgkrnl.
- XanMod for its kernel patches and configuration.
- LLVM/Clang for the compiler toolchain.
