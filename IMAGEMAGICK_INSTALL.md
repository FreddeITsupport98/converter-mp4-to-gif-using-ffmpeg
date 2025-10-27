# ImageMagick Installation Guide

ImageMagick is an optional dependency for **AI-powered perceptual hashing** in duplicate detection (Level 4). Without it, the script will still work but Level 4 duplicate detection will use basic size/frame comparison only.

## Quick Install by Distribution

### Debian/Ubuntu/Linux Mint/Pop!_OS
```bash
sudo apt update
sudo apt install -y imagemagick
```

### Fedora/RHEL/CentOS/Rocky Linux/AlmaLinux
```bash
# Fedora
sudo dnf install -y ImageMagick

# RHEL/CentOS (Enable EPEL repository first)
sudo yum install -y epel-release
sudo yum install -y ImageMagick
```

### Arch Linux/Manjaro/EndeavourOS
```bash
sudo pacman -S --needed imagemagick
```

### openSUSE Tumbleweed/Leap
```bash
sudo zypper install -y ImageMagick
```

### Alpine Linux
```bash
sudo apk add imagemagick
```

### Gentoo
```bash
sudo emerge media-gfx/imagemagick
```

### Void Linux
```bash
sudo xbps-install -S ImageMagick
```

### NixOS
```bash
nix-env -iA nixpkgs.imagemagick
# Or add to configuration.nix:
# environment.systemPackages = [ pkgs.imagemagick ];
```

## Verify Installation

After installation, verify that ImageMagick is available:

```bash
convert -version
```

You should see output like:
```
Version: ImageMagick 7.1.1-29 Q16-HDRI x86_64
```

## What Does ImageMagick Enable?

When ImageMagick is installed, the script gains:

### 🧠 AI-Powered Perceptual Hashing
- **Visual similarity detection** - Detects duplicates even if files are re-encoded
- **Average hash (aHash) algorithm** - Creates fingerprints of image content
- **False positive reduction** - Dramatically reduces incorrect duplicate flagging

### Level 4 Duplicate Detection Enhancement
Without ImageMagick:
- ✓ Compares frame count, duration, and file size
- ✗ Cannot detect visually similar content

With ImageMagick:
- ✓ Compares frame count, duration, and file size
- ✓ **Extracts middle frame and creates perceptual hash**
- ✓ **Detects re-encoded duplicates with different sizes**
- ✓ **Verifies visual similarity before flagging as duplicate**

## Example Use Case

### Without ImageMagick:
```
File A: waifu.gif (8.5MB, 120 frames, 6s)
File B: waifu-reencoded.gif (8.0MB, 120 frames, 6s)
Result: Flagged as "near-identical" based on frames/duration/size
Issue: Could be false positive if content differs
```

### With ImageMagick:
```
File A: waifu.gif (8.5MB, 120 frames, 6s, hash: 0.456)
File B: waifu-reencoded.gif (8.0MB, 120 frames, 6s, hash: 0.458)
Result: Flagged as "near-identical" - hashes match (< 5% difference)
Confidence: HIGH - visual content is actually similar ✓

File A: waifu.gif (8.5MB, 120 frames, 6s, hash: 0.456)
File C: different-waifu.gif (8.3MB, 120 frames, 6s, hash: 0.721)
Result: NOT flagged - hashes differ significantly
Confidence: Content is different despite similar timing ✓
```

## Performance Impact

- **Frame extraction**: ~2 seconds per GIF (with 2s timeout)
- **Perceptual hashing**: < 0.1 seconds per frame
- **Caching**: Results cached to avoid re-analysis
- **Overall**: Minimal performance impact with major accuracy improvement

## Troubleshooting

### ImageMagick Policy Issues

Some distributions restrict ImageMagick's permissions. If you get policy errors:

```bash
# Check policy file
cat /etc/ImageMagick-7/policy.xml
# or
cat /etc/ImageMagick-6/policy.xml

# Edit policy to allow operations
sudo nano /etc/ImageMagick-7/policy.xml

# Find and comment out restrictive policies:
<!--
  <policy domain="path" rights="none" pattern="@*"/>
-->
```

### Binary Name Differences

On some systems, the binary might be:
- `convert` (most common)
- `magick convert` (ImageMagick 7+)

The script automatically detects `convert` command.

## Alternative: Install from Source

If your distribution doesn't have ImageMagick in repositories:

```bash
# Install dependencies
sudo apt install -y build-essential pkg-config libpng-dev libjpeg-dev

# Download and compile
wget https://imagemagick.org/archive/ImageMagick.tar.gz
tar xvzf ImageMagick.tar.gz
cd ImageMagick-7.*
./configure
make
sudo make install
sudo ldconfig
```

## Script Auto-Detection

The script will automatically:
1. Check for ImageMagick during dependency scan
2. Offer to install it if missing (interactive mode)
3. Gracefully degrade if unavailable
4. Show a notice that perceptual hashing is disabled

No manual configuration needed!

## Recommended for

✅ **Collections with many GIFs** - Prevents mass false positives
✅ **Re-encoded content** - Detects duplicates across quality settings  
✅ **AI-powered workflows** - Full duplicate detection accuracy
✅ **Batch processing** - Automated cleanup with confidence

## Optional but Highly Recommended

While ImageMagick is optional, it's **highly recommended** for:
- Large GIF collections (100+ files)
- Automated duplicate cleanup
- Re-encoded content detection
- Maximum AI accuracy

The script works fine without it, but Level 4 detection will be less accurate.
