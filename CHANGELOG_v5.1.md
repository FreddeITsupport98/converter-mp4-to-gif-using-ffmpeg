# Changelog - Version 5.1

**Release Date:** October 29, 2025  
**Focus:** Output Directory Management & Configuration Persistence

---

## 🎯 Major Improvements

### 📁 Output Directory Persistence (FIXED)
**Problem:** Output directory selection was not persisting after Ctrl+C or script restart  
**Solution:** Fixed configuration flow and settings save/load mechanism

**Changes:**
- Output directory now correctly saved to `~/.smart-gif-converter/settings.conf`
- Settings properly restored on script restart
- Fixed issue where settings file was missing OUTPUT_DIRECTORY and OUTPUT_DIR_MODE fields
- All directory selection options now call `save_settings --silent` immediately after selection

**User Impact:**
- ✅ Select output directory once, never worry about it resetting
- ✅ Ctrl+C during conversion? Your directory choice is safe
- ✅ No more surprise directory changes after interruptions

---

## 🎨 Enhanced Menu System

### Improved Output Directory Configuration
**File:** `convert.sh` - Lines 9807-10086

**Enhancements:**
1. **Fixed Option Numbering**: Corrected menu option to action mappings
   - Option 1: `./converted_gifs` (default subfolder)
   - Option 2: `$HOME/Pictures/GIFs` (Pictures folder)
   - Option 3: `$(pwd)` (current directory) - **FIXED**
   - Option 4: Script directory - **FIXED**
   - Option 5: Custom path - **FIXED**
   - Option 6: Back to main menu

2. **Real-time Path Preview**: Shows exact path where GIFs will be saved
   - Preview updates based on selected option
   - Clickable paths in supported terminals
   - Clear visual feedback of current selection

3. **Consistent Variable Naming**: Renamed `current_dir` to `current_dir_path` for clarity

---

## 🔧 Technical Details

### Files Modified
- **convert.sh**:
  - Lines 9807-10086: `configure_output_directory()` function
  - Lines 13581-13582: `save_settings()` - OUTPUT_DIRECTORY and OUTPUT_DIR_MODE saved
  - Lines 13646-13647: `load_settings()` - OUTPUT_DIRECTORY and OUTPUT_DIR_MODE loaded
  - Lines 110, 13218, 13387: Version bumped to 5.1

- **settings.conf** (user file):
  - Added: `OUTPUT_DIRECTORY="<path>"`
  - Added: `OUTPUT_DIR_MODE="<mode>"`

- **README.md**:
  - Updated version badge to 5.1
  - Added v5.1 changelog section
  - Updated architecture overview

### Settings Persistence Flow

```
1. User selects output directory
   ↓
2. OUTPUT_DIRECTORY and OUTPUT_DIR_MODE set
   ↓
3. save_settings --silent called immediately
   ↓
4. Settings written to ~/.smart-gif-converter/settings.conf
   ↓
5. On script restart:
   ↓
6. load_settings() reads OUTPUT_DIRECTORY and OUTPUT_DIR_MODE
   ↓
7. Variables restored to saved values
```

---

## 🐛 Bug Fixes

### Fixed Output Directory Reset Issue
**Before v5.1:**
```bash
# User selects: ~/Insync/.../Waifu gifs
OUTPUT_DIRECTORY: ~/Insync/.../Waifu gifs

# After Ctrl+C and restart:
OUTPUT_DIRECTORY: ~/Insync/.../Waifu gifs/converted_gifs  # WRONG!
```

**After v5.1:**
```bash
# User selects: ~/Insync/.../Waifu gifs
OUTPUT_DIRECTORY: ~/Insync/.../Waifu gifs

# After Ctrl+C and restart:
OUTPUT_DIRECTORY: ~/Insync/.../Waifu gifs  # CORRECT!
```

**Root Cause:** Settings file from v5.0 was missing OUTPUT_DIRECTORY fields, causing fallback to default values.

**Fix:** 
1. Enhanced save_settings() to always include OUTPUT_DIRECTORY and OUTPUT_DIR_MODE
2. Fixed load_settings() to properly read these fields
3. Verified all 5 directory selection options save settings correctly

---

## ✅ Verification

### Syntax Check
```bash
bash -n convert.sh
# Exit code: 0 (no errors)
```

### Tested Scenarios
- ✅ Select each of the 5 output directory options
- ✅ Verify immediate save to settings.conf
- ✅ Interrupt with Ctrl+C
- ✅ Restart script
- ✅ Confirm directory persists correctly
- ✅ Change directory multiple times
- ✅ Settings file updates properly

---

## 📊 Statistics

- **Lines Modified:** ~50 lines across multiple functions
- **New Lines Added:** ~15 lines
- **Files Changed:** 3 (convert.sh, settings.conf template, README.md)
- **Bugs Fixed:** 1 major configuration persistence issue
- **Testing Time:** Full verification across all 5 directory options

---

## 🎓 Lessons Learned

1. **Settings File Completeness**: Always ensure settings template includes ALL configuration variables
2. **Backward Compatibility**: Check for missing fields in user settings files from previous versions
3. **Save Immediately**: Don't defer settings saves - call `save_settings` right after value changes
4. **Test Interruptions**: Always test Ctrl+C scenarios to verify persistence

---

## 🚀 Upgrade Instructions

### For Existing Users

**Option 1: Automatic (Recommended)**
```bash
# Just update the script - it will work with existing settings
git pull origin main
chmod +x convert.sh
./convert.sh
```

**Option 2: Fresh Config (if issues persist)**
```bash
# Backup old settings
cp ~/.smart-gif-converter/settings.conf ~/.smart-gif-converter/settings.conf.backup

# Add missing fields manually
echo 'OUTPUT_DIRECTORY="./converted_gifs"' >> ~/.smart-gif-converter/settings.conf
echo 'OUTPUT_DIR_MODE="default"' >> ~/.smart-gif-converter/settings.conf

# Or let script recreate via menu
./convert.sh  # Select "Configure Output Directory"
```

---

## 📝 Migration Notes

### From v5.0 to v5.1
- **Breaking Changes:** None
- **Config Changes:** Added OUTPUT_DIRECTORY and OUTPUT_DIR_MODE to settings.conf
- **Behavior Changes:** Output directory now persists correctly (this is the intended behavior)

### Compatibility
- ✅ Backward compatible with v5.0 settings files
- ✅ Settings auto-upgrade on first run
- ✅ No manual migration required

---

## 🔜 Future Enhancements

Potential improvements for future releases:
- [ ] Remember last 5 output directories for quick switching
- [ ] Per-project output directory profiles
- [ ] Auto-detect optimal output location based on video source
- [ ] Integration with cloud storage paths

---

**Version:** 5.1  
**Build Date:** October 29, 2025  
**Total Lines:** 16,200+  
**Language:** Bash 4.0+  
**License:** MIT
