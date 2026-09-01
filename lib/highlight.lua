local Grid = require("lib.grid")
local Anchor = require("lib.anchor")

local Highlight = {}

local COLOR_SETTING = "radar-alignment-guide-highlight-color"

local function ensure_storage()
  storage.highlight_renders = storage.highlight_renders or {}
  storage.warned_players = storage.warned_players or {}
  storage.highlight_last_state = storage.highlight_last_state or {}
end

function Highlight.init()
  ensure_storage()
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

local function current_highlight_state(player)
  return {
    surface_index = player.surface.index,
    x = player.position.x,
    y = player.position.y,
    zoom = player.zoom,
  }
end

local function highlight_state_changed(a, b)
  return not b
    or a.surface_index ~= b.surface_index
    or a.x ~= b.x
    or a.y ~= b.y
    or a.zoom ~= b.zoom
end

local function draw_player_highlight(player)
  clear_player_highlight(player.index)
  local anchor = Anchor.get(player.force.index, player.surface.index)
  if not anchor then
    if not storage.warned_players[player.index] then
      storage.warned_players[player.index] = true
      player.create_local_flying_text({
        text = {"radar-alignment-guide.no-anchor-warning"},
        create_at_cursor = true,
      })
    end
    return
  end
  local radius = anchor.prototype.get_max_distance_of_nearby_sector_revealed(anchor.quality)
  local spacing = 2 * radius + 1
  local anchor_chunk = {
    x = math.floor(anchor.position.x / Grid.CHUNK_TILES),
    y = math.floor(anchor.position.y / Grid.CHUNK_TILES),
  }
  local range = Grid.visible_chunk_range(player.position, player.display_resolution, player.zoom)
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
  storage.highlight_last_state[player.index] = current_highlight_state(player)
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
--- fire for every cursor_ghost change. Skips the redraw when nothing
--- (surface, position, zoom) has changed since the last draw, since
--- destroying and recreating every visible rectangle every tick regardless
--- of movement is wasted render churn.
function Highlight.on_tick()
  for _, player in pairs(game.connected_players) do
    if player.valid and is_holding_radar(player) then
      local state = current_highlight_state(player)
      if highlight_state_changed(state, storage.highlight_last_state[player.index]) then
        draw_player_highlight(player)
      end
    else
      storage.highlight_last_state[player.index] = nil
      clear_player_highlight(player.index)
    end
  end
end

return Highlight
