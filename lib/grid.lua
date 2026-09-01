local Grid = {}

--- Whether `chunk` lies on the square grid anchored at `anchor_chunk` with
--- the given `radius` (chunk spacing). `radius` must be a positive integer.
function Grid.is_on_grid(anchor_chunk, radius, chunk)
  local dx = chunk.x - anchor_chunk.x
  local dy = chunk.y - anchor_chunk.y
  return dx % radius == 0 and dy % radius == 0
end

return Grid
