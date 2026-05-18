# Standards for Reinforcing Steel Bars

Practical reference data for reinforcing steel bar detailing, with a focus on hook geometry used by local SketchUp rebar generators.

This repository is a working engineering reference, not a replacement for an official standard. Verify dimensions against the governing code and project specification before construction use.

## Contents

- `docs/hook-standards.md` - 90 degree, 135 degree, and 180 degree hook rules.
- `docs/bending-dimensions.md` - Bend diameter and recommended G/J dimensions captured from the provided reference images.
- `sketchup/` - Ready-to-load SketchUp Ruby generators for 90, 135, and 180 degree stirrups.
- `data/rebar-specs.json` - Bar diameter and unit weight data used by GoRebar scripts.
- `data/hook-rules.json` - Machine-readable hook length and bend rules.
- `data/bending-dimensions.json` - Machine-readable bending dimension table.
- `src/reinforcing_steel_standards.rb` - Small Ruby helper for SketchUp/Ruby generators.

## Core Rules

### 90 degree standard hook

The bent portion is a right angle, followed by a straight tail of at least:

```text
12db
```

where `db` is the nominal bar diameter.

### 135 degree standard hook

The bent portion is a 135 degree hook, followed by a straight tail of at least:

```text
max(6db, 75 mm)
```

### 180 degree standard hook

The bent portion is a semicircle, followed by a straight tail of at least:

```text
max(4db, 60 mm)
```

## Bend Diameter Rule Used Here

For regular reinforcing bars other than vertical bar/dowel exclusions in the source diagram:

| Bar diameter range | Minimum inside bend diameter D |
| --- | --- |
| 6 mm to 25 mm | 6db |
| 28 mm to 36 mm | 8db |
| 44 mm to 57 mm | 10db |

For centerline geometry in SketchUp, convert inside bend diameter to centerline radius:

```text
centerline_radius = (D / 2) + (db / 2)
```

## Source Notes

Initial values are based on the reference images supplied in the project conversation. The images cite Thai reinforced concrete detailing guidance and include recommended bend dimensions for RB9 through DB32.

## SketchUp Scripts

Load one of these files in SketchUp's Ruby editor:

- `sketchup/stirrup_90.rb`
- `sketchup/stirrup_135.rb`
- `sketchup/stirrup_180.rb`

Each script creates a dialog for beam or column orientation, bar type, section size, cover, member length, and spacing.
