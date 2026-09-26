local Grid = {}

--- True when chunk lies on the square grid anchored at anchor_chunk.
---@param anchor_chunk ChunkPosition
---@param radius integer  chunk spacing; must be positive
---@param chunk ChunkPosition
---@return boolean
function Grid.is_on_grid(anchor_chunk, radius, chunk)
  local dx = chunk.x - anchor_chunk.x
  local dy = chunk.y - anchor_chunk.y
  return dx % radius == 0 and dy % radius == 0
end

local TILE_PIXELS = 32
Grid.CHUNK_TILES = 32

-- Unconditional safety bound on the half-extent visible_chunk_range reports.
-- No normal-view zoom comes near it; the cap keeps draw_player_highlight's
-- work bounded if player.zoom goes small anyway -- chart view, or a mod that
-- raises the zoom-out limit.
local MAX_HALF_EXTENT_TILES = 64 * Grid.CHUNK_TILES

--- Returns the inclusive chunk-coordinate bounding box on screen for a player.
---@param position MapPosition  in tiles
---@param display_resolution DisplayResolution  in pixels
---@param zoom number  1 = 100%
---@return table  {left, right, top, bottom} in chunk coordinates
function Grid.visible_chunk_range(position, display_resolution, zoom)
  local tiles_wide = display_resolution.width / (TILE_PIXELS * zoom)
  local tiles_tall = display_resolution.height / (TILE_PIXELS * zoom)
  local half_wide = tiles_wide / 2
  local half_tall = tiles_tall / 2
  half_wide = math.min(half_wide, MAX_HALF_EXTENT_TILES)
  half_tall = math.min(half_tall, MAX_HALF_EXTENT_TILES)
  return {
    left = math.floor((position.x - half_wide) / Grid.CHUNK_TILES),
    right = math.floor((position.x + half_wide) / Grid.CHUNK_TILES),
    top = math.floor((position.y - half_tall) / Grid.CHUNK_TILES),
    bottom = math.floor((position.y + half_tall) / Grid.CHUNK_TILES),
  }
end

return Grid
