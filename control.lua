local Anchor = require("lib.anchor")
local Highlight = require("lib.highlight")

local function init()
  Anchor.init()
  Highlight.init()
end

script.on_init(init)
script.on_configuration_changed(init)

script.on_event("radar-alignment-guide-toggle-anchor", function(event)
  local player = game.get_player(event.player_index)
  if not (player and player.selected and player.selected.type == "radar") then
    return
  end
  local radar = player.selected
  if Anchor.is_anchor(radar) then
    Anchor.clear(radar.force.index, radar.surface.index)
    radar.force.print({"radar-alignment-guide.anchor-cleared-message"})
  else
    Anchor.set(radar)
  end
end)

local radar_filter = {{filter = "type", type = "radar"}}

local function on_built(event)
  local entity = event.entity
  if entity and entity.valid and entity.type == "radar" then
    local player = event.player_index and game.get_player(event.player_index)
    Anchor.on_built(entity, player)
  end
end

script.on_event(defines.events.on_built_entity, on_built, radar_filter)
script.on_event(defines.events.on_robot_built_entity, on_built, radar_filter)
script.on_event(defines.events.on_space_platform_built_entity, on_built, radar_filter)
script.on_event(defines.events.script_raised_built, on_built, radar_filter)
script.on_event(defines.events.script_raised_revive, on_built, radar_filter)

script.on_event(defines.events.on_object_destroyed, Anchor.on_object_destroyed)

script.on_event(defines.events.on_runtime_mod_setting_changed, function(event)
  if event.setting == "radar-alignment-guide-show-map-tag" then
    Anchor.refresh_all_chart_tags()
  end
end)

script.on_event(defines.events.on_player_cursor_stack_changed, function(event)
  local player = game.get_player(event.player_index)
  if player and player.valid then
    Highlight.on_cursor_stack_changed(player)
  end
end)

script.on_event(defines.events.on_tick, Highlight.on_tick)
