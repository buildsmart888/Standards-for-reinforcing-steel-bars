# Hook Standards

This document records the hook geometry rules used by the GoRebar SketchUp scripts.

## Notation

| Symbol | Meaning |
| --- | --- |
| `db` | Nominal reinforcing bar diameter |
| `D` | Inside bend diameter |
| `G` | Hook extension/detailing dimension from the reference table |
| `J` | Overall hook height/detailing dimension from the reference table |

## 90 Degree Hook

Rule:

```text
tail_length >= 12db
```

Implementation note:

- The hook is a right-angle bend.
- The straight tail starts after the bend.
- In centerline geometry, avoid double-counting the bend radius when converting detailing dimensions into path segments.

## 180 Degree Hook

Rule:

```text
tail_length >= max(4db, 60 mm)
```

Implementation note:

- The hook is a semicircular bend.
- The straight tail starts after the semicircular bend.
- For machine-generated geometry, create the bend on the bar centerline using `centerline_radius = (D / 2) + (db / 2)`.

## SketchUp Generator Notes

- Use a unique component definition name whenever hook type, bend diameter rule, cover, or tail length rule changes.
- Keep validation strict enough to prevent degenerate arcs or zero-length first path segments.
- Use grouped or componentized geometry for repeated stirrups to keep models lighter.

