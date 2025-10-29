# Auto-Update Quick Reference

## User Commands

```bash
# Check current version
./convert.sh --version
./convert.sh -v

# Check for updates manually
./convert.sh --check-update

# Update to latest version
./convert.sh --update
```

## Maintainer Release Checklist

### 1. Prepare Release
```bash
# Update version in script
nano convert.sh  # Change CURRENT_VERSION="5.2"

# Test script
./convert.sh --version
bash -n convert.sh
```

### 2. Generate SHA256
```bash
sha256sum convert.sh
```

### 3. Create Git Tag
```bash
git add convert.sh
git commit -m "Release v5.2"
git tag -a v5.2 -m "Release v5.2: Description"
git push origin main
git push origin v5.2
```

### 4. Create GitHub Release
1. Go to: https://github.com/FreddeITsupport98/converter-mp4-to-gif-using-ffmpeg/releases/new
2. Choose tag: `v5.2`
3. Title: `v5.2 - Release Name`
4. Description:
```markdown
## What's New
- Feature 1
- Feature 2
- Bug fix 3

## Installation
Download `convert.sh` or update with:
```bash
./convert.sh --update
```

**SHA256 Checksum:**
```
<paste-sha256-here>
```

## Changelog
See [CHANGELOG.md](link) for full details.
```

5. Optionally attach `convert.sh` file
6. Click "Publish release"

### 5. Test Update
```bash
# From previous version
./convert.sh --check-update
./convert.sh --update
```

## Configuration Variables

In `convert.sh`:
```bash
GITHUB_REPO="FreddeITsupport98/converter-mp4-to-gif-using-ffmpeg"
CURRENT_VERSION="5.1"
UPDATE_CHECK_INTERVAL=86400  # 24 hours in seconds
```

## Backup Location
```
~/.smart-gif-converter/backups/convert.sh.v5.1-20241029-143022
```

## Manual Restore
```bash
# List backups
ls -lh ~/.smart-gif-converter/backups/

# Restore specific backup
cp ~/.smart-gif-converter/backups/convert.sh.v5.1-20241029-143022 ./convert.sh
chmod +x ./convert.sh
```

## Troubleshooting

### Force update check
```bash
rm ~/.smart-gif-converter/.last_update_check
./convert.sh --check-update
```

### Test GitHub API
```bash
curl -s https://api.github.com/repos/FreddeITsupport98/converter-mp4-to-gif-using-ffmpeg/releases/latest | jq
```

### Check SHA256 manually
```bash
sha256sum convert.sh
```

## SHA256 Format Examples

All formats work - the system auto-detects:

```markdown
SHA256: a1b2c3d4e5f6...

sha256sum: a1b2c3d4e5f6...

Checksum (SHA256): a1b2c3d4e5f6...

**Checksum:**
```
a1b2c3d4e5f6...
```
```

## Update Flow Diagram

```
User runs: ./convert.sh --update
    ↓
Fetch GitHub API
    ↓
Show release notes
    ↓
User confirms [Y/n]
    ↓
Download from tag (or fallback to main)
    ↓
Verify SHA256 checksum
    ↓
Check bash syntax
    ↓
Create timestamped backup
    ↓
Replace script atomically
    ↓
Set executable permission
    ↓
Done! Restart to use new version
```

## Error Messages

| Message | Meaning | Action |
|---------|---------|--------|
| `Cannot fetch releases` | GitHub API unreachable | Check network |
| `Cannot parse version` | Invalid release format | Check release tag |
| `Already latest` | No update needed | Nothing to do |
| `Download failed` | Network issue | Retry later |
| `SHA256 FAILED` | Checksum mismatch | Don't use, report bug |
| `Syntax error` | Downloaded script broken | Update aborted safely |

## Security Notes

✅ SHA256 verification ensures file integrity  
✅ Bash syntax check prevents broken updates  
✅ Automatic backup before replacement  
✅ Atomic file operations  
✅ No sudo/root required  
✅ Falls back gracefully on errors  
✅ Original script never modified until verified  

## Update Frequency

- **Automatic check**: Once per day (configurable)
- **Manual check**: Anytime with `--check-update`
- **Update**: Only when user confirms with `--update`

## Version Number Format

Follows semantic versioning:
- `5.1` → Major.Minor
- `5.2.1` → Major.Minor.Patch
- Can use `v` prefix: `v5.1` or without: `5.1`
