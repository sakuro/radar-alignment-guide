--- Ordered storage-schema migration steps for lib/migration.lua.
--- Key = the schema version the step produces. Each step takes the storage
--- table and MUST be a no-op when the data it migrates is absent, so it is
--- safe to run against a fresh store.
return {
  --- v1 (mod 0.5.0): five parallel storage.anchor_* tables keyed by
  --- [force][surface] plus a [useful_id] reverse map.
  --- v2: one record per anchor at storage.anchors[force][surface].
  [2] = function(store)
    local useful_ids = store.anchor_useful_ids or {}
    local markers = store.anchor_markers or {}
    local chart_tags = store.anchor_chart_tags or {}
    for force_index, by_surface in pairs(store.anchors or {}) do
      for surface_index, radar in pairs(by_surface) do
        by_surface[surface_index] = {
          radar = radar,
          useful_id = useful_ids[force_index] and useful_ids[force_index][surface_index],
          marker_render_id = markers[force_index] and markers[force_index][surface_index],
          chart_tag = chart_tags[force_index] and chart_tags[force_index][surface_index],
        }
      end
    end
    store.anchor_registrations = nil
    store.anchor_useful_ids = nil
    store.anchor_markers = nil
    store.anchor_chart_tags = nil
  end,
}
