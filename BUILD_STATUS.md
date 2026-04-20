# MiniBrowser Gradient Build Status

## Problem Summary
The MiniBrowser gradient marketing build is failing due to a WebKit baseline issue in `Source/bmalloc/bmalloc/Logging.cpp`.

## Root Cause
The WebKit baseline has a compiler warning (`-Wmissing-format-attribute`) being treated as an error when compiling `Logging.cpp` on Windows with clang-cl.

## Patches Created
1. **0034-windows-minibrowser-webkitium-toolbar-gradient.patch** - The main MiniBrowser gradient patch ( marketing requirement)
2. **0090-windows-minibrowser-bmalloc-logging-fix.patch** - Fix for the baseline Logging.cpp issue

## Issue Encountered
The patch filter `*-minibrowser-*.patch` matches multiple patches but the orchestrator only includes some of them in the bundle. The 0090 bmalloc fix patch is not being bundled.

## Build History
- Build 20260420T013205-43151: Failed with bmalloc Logging.cpp error (patch not applied)
- Build 20260420T015503-46559: Failed with bmalloc Logging.cpp error (patch not applied)
- Build 20260420T020042-50829: Running (only gradient patch applied, expected to fail)

## Next Steps Needed
1. Combine both patches into a single file that can be matched with exact filename filter
2. Or use a different patch selection mechanism
3. Or fix the baseline WebKit source before building
