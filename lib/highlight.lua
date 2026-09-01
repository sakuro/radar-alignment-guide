local Grid = require("lib.grid")
local Anchor = require("lib.anchor")

local Highlight = {}

local COLOR_SETTING = "radar-alignment-guide-highlight-color"

local function ensure_storage()
  storage.highlight_renders = storage.highlight_renders or {}
  storage.warned_players = storage.warned_players or {}
end

function Highlight.init()
  ensure_storage()
  -- Reset unconditionally rather than `or {}`: this is a pure redraw-skip
  -- cache, not user-facing data, and its entry shape has changed between
  -- mod versions before (raw position -> chunk range) — a stale entry
  -- from an older version would otherwise crash the comparison in
  -- Highlight.on_tick on the very next tick. Losing the cache just costs
  -- one extra harmless redraw for players currently holding a radar item.
  storage.highlight_last_state = {}
end

local function is_radar_item_prototype(item_prototype)
  if not item_prototype then
    return false
  end
  local place_result = item_prototype.place_result
  return place_result ~= nil and place_result.type == "radar"
end

local function is_radar_item(item_stack)
  if not (item_stack and item_stack.valid_for_read) then
    return false
  end
  return is_radar_item_prototype(item_stack.prototype)
end

local function is_holding_radar(player)
  if is_radar_item(player.cursor_stack) then
    return true
  end
  local cursor_ghost = player.cursor_ghost
  return cursor_ghost ~= nil and is_radar_item_prototype(cursor_ghost.name)
end

local function clear_player_highlight(player_index)
  local render_ids = storage.highlight_renders[player_index]
  if not render_ids then
    return
  end
  for _, render_id in ipairs(render_ids) do
    local render_object = rendering.get_object_by_id(render_id)
    if render_object and render_object.valid then
      render_object.destroy()
    end
  end
  storage.highlight_renders[player_index] = nil
end

--- The player's current surface and visible chunk range. Two states with
--- the same range produce the same set of highlighted chunks, even if the
--- underlying position/zoom differ slightly, so callers compare ranges
--- (not raw position/zoom) to decide whether a redraw is needed.
local function current_highlight_state(player)
  return {
    surface_index = player.surface.index,
    range = Grid.visible_chunk_range(player.position, player.display_resolution, player.zoom),
  }
end

local function highlight_state_changed(a, b)
  if not b then
    return true
  end
  local ar, br = a.range, b.range
  return a.surface_index ~= b.surface_index
    or ar.left ~= br.left
    or ar.right ~= br.right
    or ar.top ~= br.top
    or ar.bottom ~= br.bottom
end

--- `state` (from current_highlight_state) is optional; callers that already
--- computed it for the change-detection check (Highlight.on_tick) pass it
--- through to avoid recomputing Grid.visible_chunk_range.
local function draw_player_highlight(player, state)
  clear_player_highlight(player.index)
  state = state or current_highlight_state(player)
  local anchor = Anchor.get(player.force.index, player.surface.index)
  if not anchor then
    if not storage.warned_players[player.index] then
      storage.warned_players[player.index] = true
      player.create_local_flying_text({
        text = {"radar-alignment-guide.no-anchor-warning"},
        create_at_cursor = true,
      })
    end
    storage.highlight_last_state[player.index] = state
    return
  end
  local radius = anchor.prototype.get_max_distance_of_nearby_sector_revealed(anchor.quality)
  local spacing = 2 * radius + 1
  local anchor_chunk = {
    x = math.floor(anchor.position.x / Grid.CHUNK_TILES),
    y = math.floor(anchor.position.y / Grid.CHUNK_TILES),
  }
  local range = state.range
  local color = settings.get_player_settings(player)[COLOR_SETTING].value
  local render_ids = {}
  for chunk_x = range.left, range.right do
    for chunk_y = range.top, range.bottom do
      if Grid.is_on_grid(anchor_chunk, spacing, {x = chunk_x, y = chunk_y}) then
        local render_object = rendering.draw_rectangle({
          color = color,
          filled = true,
          left_top = {chunk_x * Grid.CHUNK_TILES, chunk_y * Grid.CHUNK_TILES},
          right_bottom = {(chunk_x + 1) * Grid.CHUNK_TILES, (chunk_y + 1) * Grid.CHUNK_TILES},
          surface = player.surface,
          players = {player},
        })
        table.insert(render_ids, render_object.id)
      end
    end
  end
  storage.highlight_renders[player.index] = render_ids
  storage.highlight_last_state[player.index] = state
end

--- Wire to defines.events.on_player_cursor_stack_changed.
function Highlight.on_cursor_stack_changed(player)
  if is_holding_radar(player) then
    draw_player_highlight(player)
  else
    storage.warned_players[player.index] = nil
    clear_player_highlight(player.index)
  end
end

--- Wire to defines.events.on_tick. Keeps the highlight following the
--- player's position (not the actual camera/view position, which Factorio's
--- API doesn't expose) for every player currently holding a radar item or
--- radar ghost. Scans all connected players (not just ones already
--- highlighting) since on_player_cursor_stack_changed is not guaranteed to
--- fire for every cursor_ghost change. Skips the redraw when the visible
--- chunk range (surface + range, not raw position/zoom) hasn't changed
--- since the last draw, since destroying and recreating every visible
--- rectangle every tick regardless of sub-chunk movement is wasted render
--- churn. This also applies to the no-anchor case (draw_player_highlight
--- caches that state too): a stationary player holding a radar item on a
--- surface with no anchor is skipped on repeat ticks, at the cost of not
--- noticing an anchor becoming available until this player's cached state
--- changes (they move, re-pick the item, or the highlight is otherwise
--- redrawn) — an acceptable tradeoff since the same staleness already
--- applies to an anchor being replaced while this player stays still.
function Highlight.on_tick()
  for _, player in pairs(game.connected_players) do
    if player.valid and is_holding_radar(player) then
      local state = current_highlight_state(player)
      if highlight_state_changed(state, storage.highlight_last_state[player.index]) then
        draw_player_highlight(player, state)
      end
    else
      storage.highlight_last_state[player.index] = nil
      clear_player_highlight(player.index)
    end
  end
end

return Highlight
