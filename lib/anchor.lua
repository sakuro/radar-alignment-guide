local Anchor = {}

local MAP_TAG_SETTING = "radar-alignment-guide-show-map-tag"

local function ensure_storage()
  storage.anchors = storage.anchors or {}
end

function Anchor.init()
  ensure_storage()
  -- Per-player game.tick of the last build warning: a transient debounce cache
  -- (see Anchor.on_built). Anchor.init clears it on on_init / on_configuration_changed;
  -- a stale tick from an earlier session never equals a future game.tick, so it
  -- needs no migration and is kept out of the storage schema.
  storage.anchor_build_warned = {}
end

--- The raw anchor record for (force_index, surface_index), or nil. Does not
--- check radar validity.
local function get_record(force_index, surface_index)
  local by_surface = storage.anchors[force_index]
  return by_surface and by_surface[surface_index]
end

--- The current anchor radar for (force_index, surface_index), or nil if there
--- is none or it's no longer valid.
function Anchor.get(force_index, surface_index)
  local record = get_record(force_index, surface_index)
  if record and record.radar and record.radar.valid then
    return record.radar
  end
  return nil
end

function Anchor.is_anchor(entity)
  if not (entity and entity.valid) then
    return false
  end
  local current = Anchor.get(entity.force.index, entity.surface.index)
  return current ~= nil and current.unit_number == entity.unit_number
end

local function destroy_marker(record)
  local render_id = record.marker_render_id
  if not render_id then
    return
  end
  local render_object = rendering.get_object_by_id(render_id)
  if render_object and render_object.valid then
    render_object.destroy()
  end
  record.marker_render_id = nil
end

local function create_marker(record, radar)
  local render_object = rendering.draw_sprite({
    sprite = "utility/reference_point",
    target = radar,
    surface = radar.surface,
    forces = {radar.force},
    only_in_alt_mode = false,
  })
  record.marker_render_id = render_object.id
end

local function destroy_chart_tag(record)
  local tag = record.chart_tag
  if tag and tag.valid then
    tag.destroy()
  end
  record.chart_tag = nil
end

local function create_chart_tag(record, radar)
  if not settings.global[MAP_TAG_SETTING].value then
    return
  end
  local tag = radar.force.add_chart_tag(radar.surface, {
    position = radar.position,
    icon = {type = "entity", name = radar.name},
    -- add_chart_tag's `text` is a plain string, not a LocalisedString, so this
    -- one label cannot be localized.
    text = "Radar Alignment Guide Anchor",
  })
  if tag then
    record.chart_tag = tag
  end
end

--- Drop the anchor record for (force_index, surface_index), destroying its
--- marker and chart tag. Safe to call when there is no record.
local function forget(force_index, surface_index)
  local by_surface = storage.anchors[force_index]
  local record = by_surface and by_surface[surface_index]
  if not record then
    return
  end
  destroy_marker(record)
  destroy_chart_tag(record)
  by_surface[surface_index] = nil
end

--- Recreate the chart tag for the current anchor at (force_index,
--- surface_index), honoring the current map-tag setting. Called when the
--- setting is toggled at runtime.
function Anchor.refresh_chart_tag(force_index, surface_index)
  local record = get_record(force_index, surface_index)
  if not record then
    return
  end
  destroy_chart_tag(record)
  if record.radar and record.radar.valid then
    create_chart_tag(record, record.radar)
  end
end

--- Recreate chart tags for every known anchor. Call this when the
--- show-map-tag setting changes at runtime.
function Anchor.refresh_all_chart_tags()
  for force_index, by_surface in pairs(storage.anchors) do
    for surface_index in pairs(by_surface) do
      Anchor.refresh_chart_tag(force_index, surface_index)
    end
  end
end

--- Register `radar` as the anchor record for its force/surface, replacing any
--- existing one. Returns false (and does nothing) when `radar` is already the
--- anchor there. Callers run only after on_init, so storage.anchors exists.
local function designate(radar)
  local force_index = radar.force.index
  local surface_index = radar.surface.index
  local current = Anchor.get(force_index, surface_index)
  if current and current.unit_number == radar.unit_number then
    return false
  end
  -- Unconditional: drops a replaced anchor and also reaps a record whose radar
  -- went invalid without an on_object_destroyed (no-op when there is no record).
  forget(force_index, surface_index)
  local _, useful_id = script.register_on_object_destroyed(radar)
  local record = {radar = radar, useful_id = useful_id}
  storage.anchors[force_index] = storage.anchors[force_index] or {}
  storage.anchors[force_index][surface_index] = record
  create_marker(record, radar)
  create_chart_tag(record, radar)
  return true
end

--- Designate `radar` as the anchor for its force/surface, announcing it to the
--- force. No-op if `radar` is already the anchor.
function Anchor.set(radar)
  if designate(radar) then
    radar.force.print({"radar-alignment-guide.anchor-set-message", radar.gps_tag})
  end
end

--- Clear the anchor for (force_index, surface_index), if any.
function Anchor.clear(force_index, surface_index)
  forget(force_index, surface_index)
end

--- Wire this to defines.events.on_object_destroyed. Clears the anchor and
--- notifies the force if the destroyed object was an anchor radar. The event
--- carries only numeric ids, so the affected scope is found by scanning for a
--- record whose useful_id matches; a stale late event for a replaced anchor
--- matches nothing and is ignored.
function Anchor.on_object_destroyed(event)
  for force_index, by_surface in pairs(storage.anchors) do
    for surface_index, record in pairs(by_surface) do
      if record.useful_id == event.useful_id then
        forget(force_index, surface_index)
        local force = game.forces[force_index]
        if force and force.valid then
          force.print({"radar-alignment-guide.anchor-destroyed-message"})
        end
        return
      end
    end
  end
end

--- Wire to defines.events.on_forces_merged. The source force is gone and its
--- entities (anchor radars included) now belong to the destination force, but
--- storage still keys their records under the old source index. Move each
--- source record to the destination scope, per surface. Where the destination
--- already has an anchor on that surface it wins and the source record is
--- dropped. A moved record's marker and chart tag are rebuilt, since the
--- originals reference the now-invalid source force. The destination force is
--- told about each surface that changed -- an anchor being set, or a duplicate
--- being discarded (naming the anchor that stays).
function Anchor.on_forces_merged(source_index, destination_index)
  -- Guarded: another mod merging forces from its own on_init can raise this
  -- before our on_init has created storage.anchors.
  ensure_storage()
  local moving = storage.anchors[source_index]
  if not moving then
    return
  end
  storage.anchors[source_index] = nil
  local destination_force = game.forces[destination_index]
  local force_valid = destination_force and destination_force.valid
  for surface_index, record in pairs(moving) do
    destroy_marker(record)
    destroy_chart_tag(record)
    local record_gps = record.radar and record.radar.valid and record.radar.gps_tag
    local destination = storage.anchors[destination_index]
    local kept = destination and destination[surface_index]
    if kept then
      local kept_gps = kept.radar and kept.radar.valid and kept.radar.gps_tag
      if force_valid and record_gps and kept_gps then
        destination_force.print(
          {"radar-alignment-guide.anchor-merged-dropped-message", record_gps, kept_gps}
        )
      end
    else
      storage.anchors[destination_index] = storage.anchors[destination_index] or {}
      storage.anchors[destination_index][surface_index] = record
      if record.radar and record.radar.valid then
        create_marker(record, record.radar)
        create_chart_tag(record, record.radar)
      end
      if force_valid and record_gps then
        destination_force.print(
          {"radar-alignment-guide.anchor-merged-moved-message", record_gps}
        )
      end
    end
  end
end

--- Coverage radius in chunks for a radar entity or a radar ghost. For a ghost,
--- entity.prototype is the "entity-ghost" prototype, so the radar's own
--- prototype is reached via entity.ghost_prototype; entity.quality is the
--- quality it will be built at either way.
local function coverage_range(entity)
  if entity.type == "entity-ghost" then
    return entity.ghost_prototype.get_max_distance_of_nearby_sector_revealed(entity.quality)
  end
  return entity.prototype.get_max_distance_of_nearby_sector_revealed(entity.quality)
end

--- Call when a radar entity or radar ghost is built. For a real radar with no
--- anchor yet on its force/surface, auto-designates it and announces it to the
--- force. For a ghost, or when an anchor already exists: if a building player
--- is present and the new radar/ghost covers more area than the anchor, shows
--- them a flying text -- at most once per player per tick, since one blueprint
--- stamp fires this once per radar ghost on the same tick. A narrower radar
--- leaves a gap already visible on the grid and re-anchoring to it would only
--- tighten the grid, so that case is left unwarned. A ghost is never
--- auto-designated as the anchor (it cannot be registered for
--- on_object_destroyed); when a bot revives it, on_robot_built_entity handles
--- the real entity.
function Anchor.on_built(entity, player)
  local is_ghost = entity.type == "entity-ghost"
  local current = Anchor.get(entity.force.index, entity.surface.index)
  if not current then
    if is_ghost then
      return
    end
    designate(entity)
    entity.force.print({"radar-alignment-guide.anchor-auto-set-message", entity.gps_tag})
    return
  end
  if not (player and player.valid) then
    return
  end
  if storage.anchor_build_warned[player.index] == game.tick then
    return
  end
  if coverage_range(entity) > coverage_range(current) then
    storage.anchor_build_warned[player.index] = game.tick
    player.create_local_flying_text({
      text = {"radar-alignment-guide.anchor-outranges-flying-text"},
      position = entity.position,
    })
  end
end

--- One-time pass for a save the mod was just added to: adopt an existing radar
--- as the anchor for each (force, surface) that has radars but no anchor, and
--- tell each affected force once. Gated by storage.bootstrapped so it runs once.
--- A save that already ran it keeps the flag even across a migration reset
--- (control.lua preserves it), so wiped anchors are re-designated by hand via
--- the migration-reset notice, not silently re-adopted here.
function Anchor.bootstrap()
  if storage.bootstrapped then
    return
  end
  storage.bootstrapped = true

  local radar_names = {}
  for name in pairs(prototypes.get_entity_filtered({{filter = "type", type = "radar"}})) do
    radar_names[#radar_names + 1] = name
  end

  for _, force in pairs(game.forces) do
    -- get_entity_count is an O(1) maintained counter, force-wide across all
    -- surfaces. A force with no radars (enemy, neutral, empty player forces)
    -- is skipped before any per-surface chunk scan.
    local total = 0
    for _, name in ipairs(radar_names) do
      total = total + force.get_entity_count(name)
    end
    if total > 0 then
      local adopted = {}
      for _, surface in pairs(game.surfaces) do
        if not Anchor.get(force.index, surface.index) then
          local found = surface.find_entities_filtered({
            type = "radar",
            force = force,
            limit = 1,
          })
          if found[1] then
            designate(found[1])
            adopted[#adopted + 1] = found[1].gps_tag
          end
        end
      end
      if #adopted > 0 then
        -- One line per force. Each adopted anchor's gps_tag stays a clickable
        -- link inside the joined string, but the "how to change it" hint is
        -- shown once instead of repeating per surface.
        force.print({
          "radar-alignment-guide.anchor-bootstrap-message",
          table.concat(adopted, " "),
        })
      end
    end
  end
end

--- Wire to the "radar-alignment-guide-toggle-anchor" custom input. Toggles the
--- anchor designation of the radar the player is pointing at.
function Anchor.on_toggle(player_index)
  local player = game.get_player(player_index)
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
end

--- Wire to defines.events.on_runtime_mod_setting_changed.
function Anchor.on_setting_changed(setting_name)
  if setting_name == MAP_TAG_SETTING then
    Anchor.refresh_all_chart_tags()
  end
end

return Anchor
