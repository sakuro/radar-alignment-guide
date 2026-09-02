local Anchor = {}

local function ensure_storage()
  storage.anchors = storage.anchors or {}
end

function Anchor.init()
  ensure_storage()
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
  if not settings.global["radar-alignment-guide-show-map-tag"].value then
    return
  end
  local tag = radar.force.add_chart_tag(radar.surface, {
    position = radar.position,
    icon = {type = "entity", name = radar.name},
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

--- Designate `radar` as the anchor for its force/surface, replacing any
--- existing anchor there. No-op if `radar` is already the anchor. Pass
--- `silent = true` to skip the force-print (used by Anchor.on_built, which
--- shows its own auto-designation message instead).
function Anchor.set(radar, silent)
  ensure_storage()
  local force_index = radar.force.index
  local surface_index = radar.surface.index
  local current = Anchor.get(force_index, surface_index)
  if current and current.unit_number == radar.unit_number then
    return
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
  if not silent then
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
--- originals reference the now-invalid source force.
function Anchor.on_forces_merged(source_index, destination_index)
  local moving = storage.anchors[source_index]
  if not moving then
    return
  end
  storage.anchors[source_index] = nil
  for surface_index, record in pairs(moving) do
    destroy_marker(record)
    destroy_chart_tag(record)
    local destination = storage.anchors[destination_index]
    if not (destination and destination[surface_index]) then
      storage.anchors[destination_index] = storage.anchors[destination_index] or {}
      storage.anchors[destination_index][surface_index] = record
      if record.radar and record.radar.valid then
        create_marker(record, record.radar)
        create_chart_tag(record, record.radar)
      end
    end
  end
end

--- Call when a radar entity is built. Auto-designates it as the anchor if its
--- force/surface has none yet; otherwise warns the building player (if any) if
--- its prototype or quality differs from the current anchor's (both affect the
--- actual coverage radius, and therefore the correct grid spacing).
function Anchor.on_built(radar, player)
  local current = Anchor.get(radar.force.index, radar.surface.index)
  if not current then
    Anchor.set(radar, true)
    radar.force.print({"radar-alignment-guide.anchor-auto-set-message", radar.gps_tag})
    return
  end
  local type_mismatched = current.name ~= radar.name
  local quality_mismatched = current.quality.name ~= radar.quality.name
  if (type_mismatched or quality_mismatched) and player and player.valid then
    local message_key = type_mismatched
      and "radar-alignment-guide.anchor-type-mismatch-flying-text"
      or "radar-alignment-guide.anchor-quality-mismatch-flying-text"
    player.create_local_flying_text({
      text = {message_key},
      position = radar.position,
    })
  end
end

return Anchor
