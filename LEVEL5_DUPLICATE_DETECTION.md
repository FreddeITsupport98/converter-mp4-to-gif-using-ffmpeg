# Level 5 Duplicate Detection - Enhanced Features

## Overview

Level 5 duplicate detection is the most sophisticated filename-based analysis system designed to catch duplicates that have identical technical properties but different color tables, compression settings, or conversion timestamps.

## Detection Hierarchy

The system uses **5 progressive detection strategies** with increasing sophistication:

### Strategy 1: Prefix Matching (Timestamp-based Names)
**Best for:** Files with timestamp suffixes like `341-1760974964159.gif` and `341-1761073653683.gif`

- **15-character prefix match** → 90% confidence
- **10-character prefix match** → 75% confidence  
- **7-character prefix match** → 60% confidence
- **5-character prefix match** → 50% confidence

**Example matches:**
- `video-1234567890123.gif` ↔ `video-1234567890999.gif` (15 chars) ✓
- `anime-clip-167.gif` ↔ `anime-clip-942.gif` (10 chars) ✓

---

### Strategy 2: Core Name Extraction (Remove Timestamps)
**Best for:** Files with varying timestamp/version suffixes

Removes trailing patterns:
- Long timestamps: `-1234567890123`
- Sequential numbers: `-001`, `_42`
- Version numbers: `_v2`, `-copy`

**Example matches:**
- `my-video-1234567890.gif` ↔ `my-video-9876543210.gif`
  - Core: `my-video` ↔ `my-video` → **85% confidence** ✓
- `clip-final-001.gif` ↔ `clip-final-999.gif`
  - Core: `clip-final` ↔ `clip-final` → **85% confidence** ✓

---

### Strategy 3: Longest Common Substring (LCS)
**Best for:** Complex naming patterns with variations

Finds the longest matching prefix and calculates ratio:

**Example matches:**
- `beach-vacation-summer-2024.gif` ↔ `beach-vacation-winter-2024.gif`
  - LCS: 15 chars (`beach-vacation-`), 60% ratio → **60% confidence** ✓
- `animation-loop-v1.gif` ↔ `animation-loop-v2.gif`
  - LCS: 15 chars (`animation-loop-`), 88% ratio → **80% confidence** ✓

---

### Strategy 4: Word-based Similarity (Descriptive Names)
**Best for:** Names with spaces, dashes, underscores

Splits filenames into words, compares common meaningful words (ignores short words and numbers):

**Example matches:**
- `beautiful-sunset-beach-waves.gif` ↔ `beach-sunset-beautiful-calm.gif`
  - Common words: `beautiful`, `sunset`, `beach` (3 words) → **70% confidence** ✓
- `cat-playing-with-toy.gif` ↔ `dog-playing-with-toy.gif`
  - Common words: `playing`, `with`, `toy` (3 words) → **70% confidence** ✓

---

### Strategy 5: Character-level Similarity (Levenshtein-inspired)
**Best for:** Fallback when other strategies fail

Counts matching characters at the same positions:

**Example matches:**
- `video123.gif` ↔ `video456.gif`
  - 5 matching positions out of 8 (62%) → **55% confidence** ✓

---

## Decision Thresholds

Level 5 uses **3-tier confidence scoring** combining filename similarity with file size difference:

### High Confidence (95%)
- Filename similarity: **≥75%**
- Size difference: **<15%**
- **Action:** Flagged as duplicate

### Medium-High Confidence (80%)
- Filename similarity: **≥60%**
- Size difference: **<20%**
- **Action:** Flagged as duplicate

### Medium Confidence (70%)
- Filename similarity: **≥50%**
- Size difference: **<10%**
- **Action:** Flagged as duplicate

---

## Additional Validation

Before flagging as duplicate, Level 5 also verifies:

1. ✅ **Identical frame count**
2. ✅ **Identical duration**
3. ✅ **Identical resolution** (from content fingerprint)
4. ✅ **Non-zero properties** (valid GIF data)

---

## Real-World Examples

### Example 1: Your Case
```
File 1: 341-1760974964159.gif (104M, 121 frames, 3840x2160)
File 2: 341-1761073653683.gif (112M, 121 frames, 3840x2160)
```

**Detection:**
- Strategy 1: First 10 chars match (`341-176097` vs `341-176107`) → 75%
- Size difference: 8% (within 15% threshold)
- Properties: ✓ Same frames, duration, resolution

**Result:** ✅ **Flagged as duplicate** (High confidence: 95%)

---

### Example 2: Descriptive Names
```
File 1: sunset-beach-waves-relaxing.gif (25M, 90 frames, 1920x1080)
File 2: beach-waves-sunset-calm.gif (27M, 90 frames, 1920x1080)
```

**Detection:**
- Strategy 4: Common words: `sunset`, `beach`, `waves` (3 words) → 70%
- Size difference: 8%
- Properties: ✓ Same frames, duration, resolution

**Result:** ✅ **Flagged as duplicate** (High confidence: 95%)

---

### Example 3: Timestamped Variations
```
File 1: animation-loop-1234567890.gif (50M, 200 frames, 2560x1440)
File 2: animation-loop-9876543210.gif (52M, 200 frames, 2560x1440)
```

**Detection:**
- Strategy 2: Core name match (`animation-loop`) → 85%
- Size difference: 4%
- Properties: ✓ Same frames, duration, resolution

**Result:** ✅ **Flagged as duplicate** (High confidence: 95%)

---

## Logging

All Level 5 detections are logged to `conversions.log` with:
- Both file paths
- Name similarity percentage and method used
- Size difference percentage
- Confidence score
- Full properties (resolution, frames, duration)

**Log example:**
```
[2025-10-28 20:12:43] Level 5 Duplicate Detection:
  File 1: /path/341-1760974964159.gif
  File 2: /path/341-1761073653683.gif
  Name similarity: 75% (10-char prefix match)
  Size difference: 8%
  Confidence: 95%
  Properties: 3840x2160, 121 frames, 6s
```

---

## Performance

- **Computational complexity:** O(n²) for pairwise comparisons
- **Memory efficient:** Processes filenames in-place without external tools
- **Fast:** String operations optimized for bash
- **Scalable:** Parallel processing with configurable thread count

---

## Advantages Over Previous Detection

| Feature | Level 4 (Old) | Level 5 (Enhanced) |
|---------|---------------|-------------------|
| Requires visual hash | ✓ Required | ✗ Optional |
| Handles color table differences | ✗ No | ✓ Yes |
| Timestamp-aware | ✗ No | ✓ Yes |
| Word-based matching | ✗ No | ✓ Yes |
| Core name extraction | ✗ No | ✓ Yes |
| Confidence scoring | Basic | 3-tier |
| Detailed logging | ✗ No | ✓ Yes |

---

## Configuration

No additional configuration needed. Level 5 automatically activates when:
- Files have matching frame count and duration
- Level 1-4 detection didn't catch them
- Files have non-zero valid properties

---

## When Level 5 Activates

Level 5 is the **fallback detection** that catches duplicates missed by:

1. **Level 1** (Binary match) - Files have different color tables
2. **Level 2** (Visual hash) - Perceptual hashes differ slightly  
3. **Level 3** (Content fingerprint) - Fingerprints differ due to compression
4. **Level 4** (Near-identical) - Visual similarity check failed

Level 5 says: *"If everything technical matches (frames, duration, resolution) and filenames clearly indicate same source, they're duplicates regardless of minor differences."*
