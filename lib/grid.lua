local Grid = {}

--- Whether `chunk` lies on the square grid anchored at `anchor_chunk` with
--- the given `radius` (chunk spacing). `radius` must be a positive integer.
function Grid.is_on_grid(anchor_chunk, radius, chunk)
  local dx = chunk.x - anchor_chunk.x
  local dy = chunk.y - anchor_chunk.y
  return dx % radius == 0 and dy % radius == 0
end

local TILE_PIXELS = 32
Grid.CHUNK_TILES = 32

--- The inclusive chunk-coordinate bounding box currently on screen for a
--- player at `position` (MapPosition, in tiles) with the given
--- `display_resolution` (in pixels) and `zoom` (1 = 100%).
function Grid.visible_chunk_range(position, display_resolution, zoom)
  local tiles_wide = display_resolution.width / (TILE_PIXELS * zoom)
  local tiles_tall = display_resolution.height / (TILE_PIXELS * zoom)
  local half_wide = tiles_wide / 2
  local half_tall = tiles_tall / 2
  return {
    left = math.floor((position.x - half_wide) / Grid.CHUNK_TILES),
    right = math.floor((position.x + half_wide) / Grid.CHUNK_TILES),
    top = math.floor((position.y - half_tall) / Grid.CHUNK_TILES),
    bottom = math.floor((position.y + half_tall) / Grid.CHUNK_TILES),
  }
end

return Grid
