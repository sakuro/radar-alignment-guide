local Notice = {}

local HINT_SETTING = "radar-alignment-guide-show-hints"

--- Color for messages that ask players to act (e.g. re-designate a lost anchor).
Notice.WARNING_COLOR = { r = 1, g = 0.7, b = 0.3 }

--- Print settings for a chat message that asks players to act.
Notice.WARNING_PRINT_SETTINGS = { color = Notice.WARNING_COLOR }

--- Creates the pending-notice storage.
function Notice.init()
  storage.pending_notices = storage.pending_notices or {}
end

--- Prints a message to each player now if connected, or queues it until they
--- next join.
---
--- For one-off announcements raised from on_init / on_configuration_changed: on
--- a dedicated server nobody is connected when the mod is added or updated, and
--- a plain force.print would then reach no one.
---@param players LuaPlayer[]|LuaCustomTable<uint, LuaPlayer>
---@param message LocalisedString
---@param print_settings PrintSettings|nil
function Notice.deliver(players, message, print_settings)
  for _, player in pairs(players) do
    if player.connected then
      player.print(message, print_settings)
    else
      local queue = storage.pending_notices[player.index] or {}
      queue[#queue + 1] = { message = message, print_settings = print_settings }
      storage.pending_notices[player.index] = queue
    end
  end
end

--- Prints and drops the joining player's queued notices; wire to
--- defines.events.on_player_joined_game.
---@param player_index uint
function Notice.on_player_joined_game(player_index)
  local queue = storage.pending_notices[player_index]
  if not queue then
    return
  end
  storage.pending_notices[player_index] = nil
  local player = game.get_player(player_index)
  if not (player and player.valid) then
    return
  end
  for _, notice in ipairs(queue) do
    player.print(notice.message, notice.print_settings)
  end
end

--- Drops a removed player's queued notices; wire to
--- defines.events.on_player_removed.
---@param player_index uint
function Notice.on_player_removed(player_index)
  storage.pending_notices[player_index] = nil
end

--- The player's name for a message, as "Player <name>".
---
--- LuaPlayer::name is documented as always a string, but it is nil in
--- single-player when not logged in to a Factorio account. Wrapping the name in
--- the game's own fallback label keeps the sentence readable either way: a
--- missing name leaves just "Player" instead of a gap. The nil is replaced
--- explicitly, since a nil in a LocalisedString array would drop the parameter.
---@param player LuaPlayer
---@return LocalisedString
function Notice.player_name(player)
  return { "multiplayer.player-fallback", player.name or "" }
end

--- True when the player wants hints (flying texts and alerts).
---@param player LuaPlayer
---@return boolean
function Notice.hints_enabled(player)
  return settings.get_player_settings(player)[HINT_SETTING].value
end

--- Shows a flying text to the player unless they turned hints off.
---@param player LuaPlayer
---@param params table  as LuaPlayer::create_local_flying_text takes
function Notice.flying_text(player, params)
  if Notice.hints_enabled(player) then
    player.create_local_flying_text(params)
  end
end

return Notice
