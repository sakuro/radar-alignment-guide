local Anchor = {}

local function ensure_storage()
  storage.anchors = storage.anchors or {}
  storage.anchor_registrations = storage.anchor_registrations or {}
  storage.anchor_useful_ids = storage.anchor_useful_ids or {}
  storage.anchor_markers = storage.anchor_markers or {}
  storage.anchor_chart_tags = storage.anchor_chart_tags or {}
end

function Anchor.init()
  ensure_storage()
end

--- The current anchor radar for (force_index, surface_index), or nil if
--- there is none or it's no longer valid.
function Anchor.get(force_index, surface_index)
  local by_surface = storage.anchors[force_index]
  if not by_surface then
    return nil
  end
  local radar = by_surface[surface_index]
  if radar and radar.valid then
    return radar
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

local function destroy_marker(force_index, surface_index)
  local by_surface = storage.anchor_markers[force_index]
  local render_id = by_surface and by_surface[surface_index]
  if not render_id then
    return
  end
  local render_object = rendering.get_object_by_id(render_id)
  if render_object and render_object.valid then
    render_object.destroy()
  end
  by_surface[surface_index] = nil
end

local function create_marker(radar)
  storage.anchor_markers[radar.force.index] = storage.anchor_markers[radar.force.index] or {}
  local render_object = rendering.draw_sprite({
    sprite = "utility/reference_point",
    target = radar,
    surface = radar.surface,
    forces = {radar.force},
    only_in_alt_mode = false,
  })
  storage.anchor_markers[radar.force.index][radar.surface.index] = render_object.id
end

local function destroy_chart_tag(force_index, surface_index)
  local by_surface = storage.anchor_chart_tags[force_index]
  local tag = by_surface and by_surface[surface_index]
  if tag and tag.valid then
    tag.destroy()
  end
  if by_surface then
    by_surface[surface_index] = nil
  end
end

local function create_chart_tag(radar)
  if not settings.global["radar-alignment-guide-show-map-tag"].value then
    return
  end
  storage.anchor_chart_tags[radar.force.index] = storage.anchor_chart_tags[radar.force.index] or {}
  local tag = radar.force.add_chart_tag(radar.surface, {
    position = radar.position,
    icon = {type = "entity", name = radar.name},
    text = "Radar Alignment Guide Anchor",
  })
  if tag then
    storage.anchor_chart_tags[radar.force.index][radar.surface.index] = tag
  end
end

--- Recreate the chart tag for the current anchor at (force_index,
--- surface_index), honoring the current map-tag setting. Called when the
--- setting is toggled at runtime.
function Anchor.refresh_chart_tag(force_index, surface_index)
  destroy_chart_tag(force_index, surface_index)
  local radar = Anchor.get(force_index, surface_index)
  if radar then
    create_chart_tag(radar)
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

local function forget(force_index, surface_index)
  destroy_marker(force_index, surface_index)
  destroy_chart_tag(force_index, surface_index)
  if storage.anchors[force_index] then
    storage.anchors[force_index][surface_index] = nil
  end
  local by_surface_ids = storage.anchor_useful_ids[force_index]
  if by_surface_ids then
    local useful_id = by_surface_ids[surface_index]
    if useful_id then
      storage.anchor_registrations[useful_id] = nil
    end
    by_surface_ids[surface_index] = nil
  end
end

--- Designate `radar` as the anchor for its force/surface, replacing any
--- existing anchor there. No-op if `radar` is already the anchor. Pass
--- `silent = true` to skip the flying-text/force-print (used by
--- Anchor.on_built, which shows its own auto-designation message instead).
function Anchor.set(radar, silent)
  ensure_storage()
  local force_index = radar.force.index
  local surface_index = radar.surface.index
  local current = Anchor.get(force_index, surface_index)
  if current and current.unit_number == radar.unit_number then
    return
  end
  if current then
    forget(force_index, surface_index)
  end
  storage.anchors[force_index] = storage.anchors[force_index] or {}
  storage.anchors[force_index][surface_index] = radar
  local _, useful_id = script.register_on_object_destroyed(radar)
  storage.anchor_registrations[useful_id] = {force_index = force_index, surface_index = surface_index}
  storage.anchor_useful_ids[force_index] = storage.anchor_useful_ids[force_index] or {}
  storage.anchor_useful_ids[force_index][surface_index] = useful_id
  create_marker(radar)
  create_chart_tag(radar)
  if not silent then
    radar.force.print({"radar-alignment-guide.anchor-set-message", radar.gps_tag})
  end
end

--- Clear the anchor for (force_index, surface_index), if any.
function Anchor.clear(force_index, surface_index)
  if not Anchor.get(force_index, surface_index) then
    return
  end
  forget(force_index, surface_index)
end

--- Wire this to defines.events.on_object_destroyed. Clears the anchor and
--- notifies the force if the destroyed object was an anchor radar.
function Anchor.on_object_destroyed(event)
  local registration = storage.anchor_registrations[event.useful_id]
  if not registration then
    return
  end
  storage.anchor_registrations[event.useful_id] = nil
  local force_index = registration.force_index
  local surface_index = registration.surface_index
  local current_useful_id = storage.anchor_useful_ids[force_index] and storage.anchor_useful_ids[force_index][surface_index]
  if current_useful_id ~= event.useful_id then
    return -- stale registration; a different anchor now occupies this scope
  end
  forget(force_index, surface_index)
  local force = game.forces[force_index]
  if force and force.valid then
    force.print({"radar-alignment-guide.anchor-destroyed-message"})
  end
end

--- Call when a radar entity is built. Auto-designates it as the anchor if
--- its force/surface has none yet; otherwise warns the building player (if
--- any) if its prototype or quality differs from the current anchor's
--- (both affect the actual coverage radius, and therefore the correct grid
--- spacing).
function Anchor.on_built(radar, player)
  local current = Anchor.get(radar.force.index, radar.surface.index)
  if not current then
    Anchor.set(radar, true)
    radar.force.print({"radar-alignment-guide.anchor-auto-set-message", radar.gps_tag})
    return
  end
  local mismatched = current.name ~= radar.name or current.quality.name ~= radar.quality.name
  if mismatched and player and player.valid then
    player.create_local_flying_text({
      text = {"radar-alignment-guide.anchor-type-mismatch-flying-text"},
      position = radar.position,
    })
  end
end

return Anchor
