# SketchUp Stirrup Generators

This folder contains standalone SketchUp Ruby scripts for creating repeated stirrup systems.

## Files

| File | Hook type | Tail rule |
| --- | --- | --- |
| `stirrup_90.rb` | 90 degree | 12db |
| `stirrup_135.rb` | 135 degree | max(6db, 75 mm) |
| `stirrup_180.rb` | 180 degree | max(4db, 60 mm) |

## Usage

1. Open SketchUp.
2. Open a Ruby editor or Ruby console plugin.
3. Load one script file.
4. Fill in orientation, rebar type, section size, cover, member length, and spacing.

Each script creates a grouped stirrup system and shows an estimation report.

