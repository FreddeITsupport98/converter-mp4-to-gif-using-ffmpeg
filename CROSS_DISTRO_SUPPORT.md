# Cross-Distribution Support

## Overview

The Smart GIF Converter now includes comprehensive cross-distribution support with automatic dependency detection and installation across all major Linux distributions.

## Supported Distributions

### ✅ Fully Tested & Supported

1. **Debian-based**
   - Debian (stable, testing, sid)
   - Ubuntu (all versions, including LTS)
   - Linux Mint
   - Pop!_OS
   - Elementary OS
   - KDE Neon
   - Zorin OS
   - MX Linux
   - Raspbian
   - Kali Linux

2. **Red Hat-based**
   - Fedora
   - RHEL (Red Hat Enterprise Linux)
   - CentOS
   - Rocky Linux
   - AlmaLinux
   - Oracle Linux

3. **Arch-based**
   - Arch Linux
   - Manjaro
   - EndeavourOS
   - Garuda Linux
   - CachyOS
   - Artix
   - Parabola
   - BlackArch
   - ArcoLinux

4. **SUSE-based**
   - openSUSE Tumbleweed ✨ (Primary development platform)
   - openSUSE Leap
   - SLES (SUSE Linux Enterprise Server)

5. **Other Distributions**
   - Alpine Linux
   - Gentoo
   - Void Linux
   - NixOS (manual configuration required)

## Dependencies

### Required Dependencies
The script requires these tools to function:

1. **ffmpeg** - Video processing and conversion
2. **git** - Version control (for auto-update system)
3. **curl** - HTTP client (for auto-update system)

### Optional Dependencies
These enhance functionality but are not required:

1. **gifsicle** - GIF optimization and compression
2. **jq** - Advanced JSON processing for auto-detection
3. **ImageMagick (convert)** - AI perceptual hashing for duplicate detection

## Auto-Installation Features

### 1. Automatic Detection

The script automatically detects your Linux distribution using:
- `/etc/os-release` (primary method)
- `ID` field for exact match
- `ID_LIKE` field for derivative distributions
- Package manager command detection (fallback)

### 2. Interactive Installation

When missing dependencies are detected:

```
🔧 DEPENDENCY INSTALLER
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Detected OS: suse-based
Package Manager: zypper
Missing Tools: git curl

The following packages will be installed:
  • git
  • curl

Install command:
  sudo zypper install -y git curl

Would you like to install these dependencies now? [Y/n]:
```

### 3. Verification After Installation

After installing packages, the script verifies:
- Each tool is accessible via `command -v`
- Tool version information
- Provides troubleshooting if verification fails

### 4. Manual Installation Guidance

If automatic installation fails, comprehensive manual instructions are provided for ALL supported distributions:

```
📝 MANUAL INSTALLATION REQUIRED

Missing dependencies:
  • git
  • curl

Installation commands by distribution:

Debian/Ubuntu/Linux Mint/Pop!_OS:
  sudo apt update && sudo apt install -y git curl

Fedora/RHEL/CentOS/Rocky/AlmaLinux:
  sudo dnf install -y git curl

Arch Linux/Manjaro/EndeavourOS:
  sudo pacman -S --needed git curl

openSUSE Tumbleweed/Leap:
  sudo zypper install -y git curl

Alpine Linux:
  sudo apk add git curl

Gentoo:
  sudo emerge -av dev-vcs/git net-misc/curl

Void Linux:
  sudo xbps-install -y git curl

NixOS:
  nix-env -iA nixos.git curl
  Or add to configuration.nix: environment.systemPackages

───────────────────────────────────────────────────────────────
💡 After installing, restart your terminal or run: hash -r
🔗 Official package search:
  - Debian/Ubuntu: https://packages.debian.org/ or https://packages.ubuntu.com/
  - Arch: https://archlinux.org/packages/
  - Fedora: https://packages.fedoraproject.org/
  - openSUSE: https://software.opensuse.org/
```

## Package Name Mapping

### ffmpeg
| Distribution | Package Name |
|--------------|--------------|
| Debian/Ubuntu | `ffmpeg` |
| Fedora/RHEL | `ffmpeg` |
| Arch | `ffmpeg` |
| openSUSE | `ffmpeg-4` |
| Alpine | `ffmpeg` |
| Gentoo | `media-video/ffmpeg` |
| Void | `ffmpeg` |

### git
| Distribution | Package Name |
|--------------|--------------|
| Debian/Ubuntu | `git` |
| Fedora/RHEL | `git` |
| Arch | `git` |
| openSUSE | `git` |
| Alpine | `git` |
| Gentoo | `dev-vcs/git` |
| Void | `git` |

### curl
| Distribution | Package Name |
|--------------|--------------|
| Debian/Ubuntu | `curl` |
| Fedora/RHEL | `curl` |
| Arch | `curl` |
| openSUSE | `curl` |
| Alpine | `curl` |
| Gentoo | `net-misc/curl` |
| Void | `curl` |

### gifsicle (optional)
| Distribution | Package Name |
|--------------|--------------|
| Debian/Ubuntu | `gifsicle` |
| Fedora/RHEL | `gifsicle` |
| Arch | `gifsicle` |
| openSUSE | `gifsicle` |
| Alpine | `gifsicle` |
| Gentoo | `media-gfx/gifsicle` |
| Void | `gifsicle` |

### jq (optional)
| Distribution | Package Name |
|--------------|--------------|
| Debian/Ubuntu | `jq` |
| Fedora/RHEL | `jq` |
| Arch | `jq` |
| openSUSE | `jq` |
| Alpine | `jq` |
| Gentoo | `app-misc/jq` |
| Void | `jq` |

### ImageMagick (optional)
| Distribution | Package Name |
|--------------|--------------|
| Debian/Ubuntu | `imagemagick` |
| Fedora/RHEL | `ImageMagick` |
| Arch | `imagemagick` |
| openSUSE | `ImageMagick` |
| Alpine | `imagemagick` |
| Gentoo | `media-gfx/imagemagick` |
| Void | `ImageMagick` |

## Testing on Different Distributions

### On openSUSE Tumbleweed (Your System)

```bash
# Test dependency detection
./convert.sh --version

# Force re-check (ignores cache)
rm ~/.smart-gif-converter/.dependency_cache
./convert.sh --version
```

### Testing Distribution Detection

You can manually test the detection logic:

```bash
# Check your distribution detection
if [[ -f /etc/os-release ]]; then
    source /etc/os-release
    echo "ID: $ID"
    echo "ID_LIKE: $ID_LIKE"
    echo "NAME: $NAME"
    echo "VERSION: $VERSION"
fi
```

Expected output on openSUSE Tumbleweed:
```
ID: opensuse-tumbleweed
ID_LIKE: suse opensuse
NAME: openSUSE Tumbleweed
VERSION: current_snapshot
```

## Troubleshooting

### Issue: Package manager not detected

**Solution:**
1. Check if `/etc/os-release` exists: `cat /etc/os-release`
2. Manually identify your package manager
3. Use manual installation commands from the script output

### Issue: Package names different on your system

**Solution:**
1. Search your distribution's package repository
2. Install manually using the correct package name
3. Report the issue on GitHub so we can update the mapping

### Issue: Automatic installation fails

**Possible causes:**
- Insufficient permissions (missing `sudo`)
- Network issues
- Package not available in repositories
- Repository needs updating first

**Solution:**
```bash
# Update repositories first
sudo zypper refresh  # openSUSE
sudo apt update      # Debian/Ubuntu
sudo dnf check-update  # Fedora

# Then try manual installation
sudo zypper install -y ffmpeg git curl  # openSUSE
```

### Issue: Tool installed but not found

**Solution:**
```bash
# Refresh shell's command cache
hash -r

# Or restart terminal
exit
# Open new terminal

# Or reload PATH
source ~/.bashrc  # or ~/.zshrc, ~/.config/fish/config.fish
```

## Contributing

### Adding Support for New Distributions

1. **Update `detect_distro()` function** (line ~8830):
   - Add distribution ID to appropriate case statement
   - Or add new case if it's a unique distribution family

2. **Update `get_package_names()` function** (line ~8903):
   - Add package names for the new distribution

3. **Update `show_manual_install_instructions()` function** (line ~8973):
   - Add installation command example

4. **Test thoroughly**:
   - Test automatic detection
   - Test automatic installation
   - Test manual installation instructions

5. **Submit Pull Request** with:
   - Distribution name and version tested
   - Screenshot of successful installation
   - Notes about any special considerations

## Distribution-Specific Notes

### openSUSE

- FFmpeg package is `ffmpeg-4` (not `ffmpeg`)
- ImageMagick package is `ImageMagick` (capital I and M)
- Packman repository may be needed for some codecs
- Use `zypper addrepo` to add Packman if needed

### Gentoo

- Packages use category/name format (e.g., `media-video/ffmpeg`)
- Compilation time depends on USE flags
- May require `--autounmask-write` for dependency resolution

### Alpine

- Uses `apk` package manager
- Smaller package selection than mainstream distributions
- May need to enable community repository

### NixOS

- Declarative package management
- Add packages to `configuration.nix`
- Or use `nix-env -iA` for per-user installation
- Package names may differ from other distributions

### Void Linux

- Uses `xbps` package manager
- Rolling release like Arch
- Musl and glibc variants available

## Auto-Update System Compatibility

The auto-update system requires:
- **git**: For repository operations (future use)
- **curl**: For GitHub API access and file downloads

These are now checked as required dependencies, ensuring the auto-update feature works across all distributions.

## Security Considerations

### Package Installation

- Always uses `sudo` for system package installation
- User is prompted before any installation
- Installation commands are displayed before execution
- Verification performed after installation

### Repository Trust

The script uses your system's configured repositories:
- No third-party repositories added automatically
- User must manually add repos if packages unavailable
- Package signatures verified by your package manager

## Future Enhancements

Planned improvements for distribution support:

1. **BSD Support**: FreeBSD, OpenBSD, NetBSD
2. **Package Source Detection**: Snap, Flatpak, AppImage fallbacks
3. **Container Detection**: Docker, Podman environments
4. **WSL Support**: Windows Subsystem for Linux
5. **ARM Support**: Raspberry Pi specific optimizations

## Feedback

If you encounter issues on your distribution:

1. **Check existing issues**: https://github.com/FreddeITsupport98/converter-mp4-to-gif-using-ffmpeg/issues
2. **Create new issue** with:
   - Distribution name and version
   - Output of `/etc/os-release`
   - Package manager used
   - Error messages encountered
3. **Include logs**: `~/.smart-gif-converter/errors.log`

## License

Same as main project (see LICENSE file)
