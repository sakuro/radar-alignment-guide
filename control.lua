local Anchor = require("lib.anchor")
local Highlight = require("lib.highlight")
local Migration = require("lib.migration")
local migrations = require("lib.migrations")

local function init()
  Anchor.init()
  Highlight.init()
end

script.on_init(function()
  Migration.apply(storage, migrations)
  -- A fresh game has nothing to report; drop any flag a no-op step set so a
  -- later unrelated on_configuration_changed does not surface a stale notice.
  storage.migration_reset = nil
  init()
end)

script.on_configuration_changed(function()
  Migration.apply(storage, migrations)
  init()
  if storage.migration_reset then
    storage.migration_reset = nil
    game.print({"radar-alignment-guide.migration-reset-message"})
  end
end)

script.on_event("radar-alignment-guide-toggle-anchor", function(event)
  Anchor.on_toggle(event.player_index)
end)

local radar_filter = {{filter = "type", type = "radar"}}

local function on_built(event)
  local entity = event.entity
  -- All five wired events carry radar_filter, so no type recheck is needed.
  if entity and entity.valid then
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

script.on_event(defines.events.on_forces_merged, function(event)
  Anchor.on_forces_merged(event.source_index, event.destination.index)
end)

script.on_event(defines.events.on_runtime_mod_setting_changed, function(event)
  Anchor.on_setting_changed(event.setting)
end)

script.on_event(defines.events.on_player_cursor_stack_changed, function(event)
  Highlight.on_cursor_stack_changed(event.player_index)
end)

script.on_event(defines.events.on_player_removed, function(event)
  Highlight.on_player_removed(event.player_index)
end)

script.on_event(defines.events.on_player_left_game, function(event)
  Highlight.on_player_left_game(event.player_index)
end)

script.on_event(defines.events.on_tick, Highlight.on_tick)
