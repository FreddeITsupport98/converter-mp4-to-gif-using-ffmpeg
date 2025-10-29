# Auto-Update System Implementation

## Overview

The Smart GIF Converter now includes a secure auto-update system that checks GitHub Releases for new versions, displays release notes, and allows users to update with SHA256 verification.

## Features Implemented

### 1. **Automatic Update Checking** ✅
- Runs silently in background on script startup
- Checks GitHub Releases API once per day (configurable)
- Non-intrusive: doesn't block script operation
- Graceful failure: network issues don't affect script functionality

### 2. **Manual Update Commands** ✅
Three new command-line options:

```bash
./convert.sh --version           # Show version and repository info
./convert.sh --check-update      # Manually check for updates
./convert.sh --update            # Download and install update
```

### 3. **Update Notification** ✅
When an update is available, users see:
- Clear notification with version numbers
- Link to view full release notes on GitHub
- Command to run the update

### 4. **SHA256 Verification** ✅
- Extracts SHA256 from release notes
- Verifies downloaded file before installation
- Aborts update if checksum fails
- Supports multiple checksum notation formats:
  - `SHA256: <hash>`
  - `sha256sum: <hash>`
  - `Checksum (SHA256): <hash>`

### 5. **Safe Update Process** ✅
- Creates timestamped backup before updating
- Syntax checks downloaded script
- Atomic file replacement
- Graceful error handling with cleanup

### 6. **Fallback Mechanisms** ✅
- Primary download: from release tag
- Fallback: main branch if tag fails
- Continues without SHA256 if not in release notes (with warning)

## Configuration

Located at the top of `convert.sh`:

```bash
# 🔄 Auto-Update System Configuration
GITHUB_REPO="FreddeITsupport98/converter-mp4-to-gif-using-ffmpeg"
GITHUB_API_URL="https://api.github.com/repos/${GITHUB_REPO}/releases/latest"
GITHUB_RELEASES_URL="https://github.com/${GITHUB_REPO}/releases"
CURRENT_VERSION="5.1"  # Script version
UPDATE_CHECK_FILE="$LOG_DIR/.last_update_check"
UPDATE_CHECK_INTERVAL=86400  # Check once per day (in seconds)
```

## Usage

### For End Users

#### Check Current Version
```bash
./convert.sh --version
```

Output:
```
Smart GIF Converter v5.1
Repository: https://github.com/FreddeITsupport98/converter-mp4-to-gif-using-ffmpeg
Releases: https://github.com/FreddeITsupport98/converter-mp4-to-gif-using-ffmpeg/releases
```

#### Manual Update Check
```bash
./convert.sh --check-update
```

If update available:
```
╔═══════════════════════════════════════════════════════════════╗
║               🎉 UPDATE AVAILABLE: v5.2                       ║
╚═══════════════════════════════════════════════════════════════╝
Current: v5.1 → New: v5.2
🔗 View release: https://github.com/[repo]/releases/tag/v5.2
🔄 Update with: ./convert.sh --update
```

#### Perform Update
```bash
./convert.sh --update
```

Interactive prompts:
1. Shows release notes preview (first 10 lines)
2. Asks for confirmation
3. Downloads and verifies with SHA256
4. Creates backup
5. Installs new version

### For Maintainers

#### Creating a Release with SHA256

When creating a new GitHub Release, include the SHA256 in the release notes:

```bash
# Generate SHA256
sha256sum convert.sh

# Example release notes format:
## What's New
- Feature 1
- Feature 2

## Installation
Download `convert.sh` from the assets below.

**SHA256 Checksum:**
```
a1b2c3d4e5f6789... (full 64-char hash)
```

**Or use inline format:**
```
SHA256: a1b2c3d4e5f6789...
```

**Or use inline format:**
```
Checksum (SHA256): a1b2c3d4e5f6789...
```

The auto-update system will automatically extract the checksum from any of these formats.

#### Version Tagging

Version tags should follow semantic versioning:
- Format: `v5.1`, `v5.2`, etc. (or without 'v': `5.1`, `5.2`)
- Tag the commit in `main` branch
- The release must include the updated `convert.sh` file

#### Versioning Best Practices

1. **Update CURRENT_VERSION** in `convert.sh`:
   ```bash
   CURRENT_VERSION="5.2"  # Update this
   ```

2. **Create Git tag**:
   ```bash
   git tag -a v5.2 -m "Release v5.2"
   git push origin v5.2
   ```

3. **Create GitHub Release**:
   - Use the tag `v5.2`
   - Add release notes
   - Include SHA256 checksum
   - Optionally attach `convert.sh` as asset

## Technical Details

### Functions Implemented

#### `check_for_updates()`
- Checks GitHub API for latest release
- Compares with current version
- Shows notification if update available
- Respects check interval to avoid rate limiting
- Always returns success (0) to avoid triggering error traps

#### `show_update_available()`
- Displays formatted notification
- Shows version comparison
- Provides update command

#### `verify_sha256()`
- Computes SHA256 of downloaded file
- Compares with expected hash
- Returns 0 on success, 1 on failure

#### `extract_sha256_from_release()`
- Parses release notes
- Finds SHA256 hash using regex
- Supports multiple notation formats

#### `perform_update()`
- Downloads new version from release tag
- Falls back to main branch if needed
- Verifies checksum
- Checks bash syntax
- Creates backup
- Replaces current script
- Sets executable permissions

#### `manual_update()`
- Interactive update process
- Shows release notes preview
- Prompts for confirmation
- Calls `perform_update()`

#### `show_version_info()`
- Displays current version
- Shows repository URLs

### Error Handling

All update functions handle errors gracefully:
- Network failures: silent ignore
- Invalid JSON: safe parsing with fallbacks
- Missing checksums: warning but continue (optional verification)
- Download failures: clear error messages
- Syntax errors: abort with cleanup

### Security Considerations

1. **SHA256 Verification**: Ensures file integrity and authenticity
2. **Syntax Checking**: Prevents installation of broken scripts
3. **Backup Creation**: Allows rollback if issues occur
4. **Atomic Operations**: File replacement is atomic (mv)
5. **Non-root**: No sudo required for update

### Background Update Check

The automatic check runs in the background:
```bash
check_for_updates &
```

This ensures:
- Script startup is not delayed
- User can continue working immediately
- Network issues don't block script operation

## Backup System

Backups are stored in:
```
~/.smart-gif-converter/backups/convert.sh.v5.1-20241029-143022
```

Format: `convert.sh.v<VERSION>-<TIMESTAMP>`

Users can manually restore:
```bash
cp ~/.smart-gif-converter/backups/convert.sh.v5.1-20241029-143022 ./convert.sh
chmod +x ./convert.sh
```

## Testing

### Test Version Display
```bash
./convert.sh --version
# Should show: Smart GIF Converter v5.1
```

### Test Update Check
```bash
./convert.sh --check-update
# Should check GitHub and display notification if update exists
```

### Test Manual Update
```bash
./convert.sh --update
# Should show interactive update prompt
```

### Test Automatic Check
```bash
# Remove check file to force check
rm ~/.smart-gif-converter/.last_update_check
./convert.sh
# Should perform update check in background on startup
```

## Future Enhancements

Possible improvements for future versions:

1. **Auto-install option**: Skip confirmation prompt with `--update --yes`
2. **Rollback command**: `--rollback` to restore previous version
3. **Update channels**: Stable vs. Beta releases
4. **Changelog display**: Show full changelog in terminal
5. **GPG signature verification**: Additional security layer
6. **Delta updates**: Download only changed portions
7. **Version history**: Track all installed versions

## Troubleshooting

### Update check not working
- Check internet connection
- Verify GitHub API is accessible: `curl https://api.github.com/repos/FreddeITsupport98/converter-mp4-to-gif-using-ffmpeg/releases/latest`
- Check if rate limited by GitHub API

### SHA256 verification fails
- Ensure checksum in release notes is correct
- Verify network didn't corrupt download
- Check file wasn't modified during download

### Update installs but script broken
1. Restore from backup:
   ```bash
   cp ~/.smart-gif-converter/backups/convert.sh.v5.1-* ./convert.sh
   chmod +x ./convert.sh
   ```
2. Report issue on GitHub

### Syntax check fails
- Downloaded script has errors
- Update will automatically abort
- Original script remains unchanged
- Check GitHub for valid release

## Integration Notes

### Changes to Main Script

1. **Added configuration** (lines 253-259):
   - GitHub repository settings
   - Version number
   - Update check interval

2. **Added update functions** (lines 397-577):
   - Complete update system implementation

3. **Added command-line options** (lines 16221-16232):
   - `--version`
   - `--check-update`
   - `--update`

4. **Added automatic check** (line 15510):
   - Background update check on startup

### No Breaking Changes

The update system:
- Doesn't modify existing functionality
- Adds only new optional features
- Fails gracefully if GitHub unavailable
- Maintains backward compatibility

## Maintainer Checklist

When releasing a new version:

- [ ] Update `CURRENT_VERSION` in script
- [ ] Test script thoroughly
- [ ] Generate SHA256: `sha256sum convert.sh`
- [ ] Create Git tag: `git tag -a vX.Y -m "Release vX.Y"`
- [ ] Push tag: `git push origin vX.Y`
- [ ] Create GitHub Release with:
  - [ ] Version tag (e.g., v5.2)
  - [ ] Release notes
  - [ ] SHA256 checksum in notes
  - [ ] Optional: attach convert.sh file
- [ ] Test auto-update from previous version
- [ ] Verify SHA256 verification works

## License

Same as main project (see LICENSE file)

## Support

For issues related to the auto-update system:
1. Check this documentation
2. Review error logs: `~/.smart-gif-converter/errors.log`
3. Open issue on GitHub
4. Include version info: `./convert.sh --version`
