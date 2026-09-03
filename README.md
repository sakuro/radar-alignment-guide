# Radar Alignment Guide

[![Downloads](https://img.shields.io/badge/dynamic/json.svg?label=Downloads&url=https%3A%2F%2Fmods.factorio.com%2Fapi%2Fmods%2Fradar-alignment-guide&query=%24.downloads_count)](https://mods.factorio.com/mod/radar-alignment-guide)

Helps you place radars without overlapping coverage by highlighting placement chunks while you hold a radar, based on the coverage of a designated anchor radar.

## Features

- **Anchor designation**: the first radar built on a surface is auto-designated as that force's anchor. Point at any radar and press the toggle-anchor keybind (default `Ctrl+Shift+A`, rebindable in Settings > Controls) to make it the anchor instead, or clear it. When the mod is added to a save that already has radars, one radar per force and surface is adopted the same way.
- **Chunk highlight**: while holding a radar item or ghost, chunks aligned with the anchor's coverage are tinted; the highlight color is configurable per player.
- **Wider-coverage warning**: placing a radar — or a radar ghost, e.g. from a blueprint — that covers more area than the current anchor shows a flying-text hint to re-anchor to it, since its extra range is otherwise wasted against the anchor's tighter spacing. A shorter-range radar is not flagged — the gap it leaves is already visible on the grid.
- **Map tag** (off by default): optionally marks the anchor radar's location on the map and remote view.
