# Radar Alignment Guide

[![Downloads](https://img.shields.io/badge/dynamic/json.svg?label=Downloads&url=https%3A%2F%2Fmods.factorio.com%2Fapi%2Fmods%2Fradar-alignment-guide&query=%24.downloads_count)](https://mods.factorio.com/mod/radar-alignment-guide)

Helps you place radars without overlapping coverage by highlighting placement chunks while you hold a radar, based on the coverage of a designated anchor radar.

## Features

- The first radar built on a surface becomes that force's anchor. To make another radar the anchor, or to clear it, point at it and press the toggle-anchor key (default `Ctrl+Shift+A`, rebindable in Settings > Controls). When the mod is added to a save that already has radars, one radar per force and surface is adopted the same way.
- While you hold a radar item or ghost, chunks aligned with the anchor's coverage are tinted. Each player can set the highlight color.
- Placing a radar, or a radar ghost from a blueprint, that covers more area than the current anchor shows a flying-text hint to re-anchor to it, because its extra range is otherwise wasted on the anchor's tighter spacing. A shorter-range radar is not flagged, since the gap it leaves is already visible on the grid.
- An optional map tag (off by default) marks the anchor radar's location on the map and in remote view.
