local factorio = require("spec.support.factorio")
local Anchor = require("lib.anchor")

describe("Anchor", function()
  before_each(function()
    factorio.reset()
    Anchor.init()
  end)

  describe("set / replace / clear", function()
    it("stores one record per scope and leaves nothing behind after clear", function()
      local first = factorio.radar({ unit_number = 10 })
      Anchor.set(first)

      local record = storage.anchors[1][1]
      assert.equals(first, record.radar)
      assert.equals(10, record.useful_id)
      assert.is_number(record.marker_render_id)

      local second = factorio.radar({ unit_number = 20 })
      Anchor.set(second)

      assert.equals(second, storage.anchors[1][1].radar)
      assert.equals(20, storage.anchors[1][1].useful_id)

      Anchor.clear(1, 1)

      assert.is_nil(storage.anchors[1][1])
      assert.is_nil(storage.anchor_registrations)
      assert.is_nil(storage.anchor_useful_ids)
      assert.is_nil(storage.anchor_markers)
      assert.is_nil(storage.anchor_chart_tags)
    end)

    it("reaps a record whose radar went invalid and destroys its marker", function()
      local radar = factorio.radar({ unit_number = 10 })
      Anchor.set(radar)
      local render_id = storage.anchors[1][1].marker_render_id
      radar.valid = false

      Anchor.clear(1, 1)

      assert.is_nil(storage.anchors[1][1])
      assert.is_false(rendering.get_object_by_id(render_id).valid)
    end)
  end)

  describe("on_built", function()
    it("auto-designates the first radar built on a scope", function()
      local radar = factorio.radar({ unit_number = 5 })

      Anchor.on_built(radar, nil)

      assert.equals(radar, storage.anchors[1][1].radar)
      assert.same({ "radar-alignment-guide.anchor-auto-set-message", radar.gps_tag }, factorio.printed[1])
      assert.equals(1, #factorio.printed)
    end)

    it("warns the builder when the new radar out-ranges the anchor", function()
      Anchor.set(factorio.radar({ unit_number = 1, range = 3 }))
      local player = factorio.player({ index = 1 })

      Anchor.on_built(factorio.radar({ unit_number = 2, range = 5 }), player)

      assert.same({ "radar-alignment-guide.anchor-outranges-flying-text" }, factorio.flying_text[1].text)
      assert.equals(1, #factorio.flying_text)
    end)

    it("does not warn when the new radar's range is equal or smaller", function()
      Anchor.set(factorio.radar({ unit_number = 1, range = 5 }))
      local player = factorio.player({ index = 1 })

      Anchor.on_built(factorio.radar({ unit_number = 2, range = 5 }), player)
      Anchor.on_built(factorio.radar({ unit_number = 3, range = 3 }), player)

      assert.same({}, factorio.flying_text)
    end)

    it("does not warn when there is no building player", function()
      Anchor.set(factorio.radar({ unit_number = 1, range = 3 }))

      assert.has_no.errors(function()
        Anchor.on_built(factorio.radar({ unit_number = 2, range = 5 }), nil)
      end)

      assert.same({}, factorio.flying_text)
    end)
  end)

  describe("on_object_destroyed", function()
    it("clears the scope whose record matches the useful_id", function()
      Anchor.set(factorio.radar({ unit_number = 10 }))

      Anchor.on_object_destroyed({ useful_id = 10 })

      assert.is_nil(storage.anchors[1][1])
    end)

    it("ignores a useful_id no record holds (stale late event)", function()
      Anchor.set(factorio.radar({ unit_number = 10 }))
      Anchor.set(factorio.radar({ unit_number = 20 })) -- replaces scope 1,1

      Anchor.on_object_destroyed({ useful_id = 10 })

      assert.is_not_nil(storage.anchors[1][1])
      assert.equals(20, storage.anchors[1][1].useful_id)
    end)
  end)

  describe("on_forces_merged", function()
    it("moves a source anchor into an empty destination scope and rebuilds its visuals", function()
      factorio.show_map_tag = true
      local radar = factorio.radar({ unit_number = 10, force_index = 1 })
      Anchor.set(radar)
      local old_marker_id = storage.anchors[1][1].marker_render_id

      radar.force = factorio.force({ index = 2 })
      Anchor.on_forces_merged(1, 2)

      assert.is_nil(storage.anchors[1])
      local moved = storage.anchors[2][1]
      assert.equals(radar, moved.radar)
      assert.is_false(rendering.get_object_by_id(old_marker_id).valid)
      assert.is_number(moved.marker_render_id)
      assert.is_true(moved.marker_render_id ~= old_marker_id)
      assert.is_true(moved.chart_tag.valid)
    end)

    it("keeps the destination's anchor when both forces have one on the same surface", function()
      local source_radar = factorio.radar({ unit_number = 10, force_index = 1 })
      local dest_radar = factorio.radar({ unit_number = 20, force_index = 2 })
      Anchor.set(source_radar)
      Anchor.set(dest_radar)
      local source_marker_id = storage.anchors[1][1].marker_render_id

      source_radar.force = factorio.force({ index = 2 })
      Anchor.on_forces_merged(1, 2)

      assert.is_nil(storage.anchors[1])
      assert.equals(dest_radar, storage.anchors[2][1].radar)
      assert.is_false(rendering.get_object_by_id(source_marker_id).valid)
    end)

    it("merges per surface", function()
      local surface1_radar = factorio.radar({ unit_number = 10, force_index = 1, surface_index = 1 })
      local surface2_radar = factorio.radar({ unit_number = 20, force_index = 2, surface_index = 2 })
      Anchor.set(surface1_radar)
      Anchor.set(surface2_radar)

      surface1_radar.force = factorio.force({ index = 2 })
      Anchor.on_forces_merged(1, 2)

      assert.equals(surface1_radar, storage.anchors[2][1].radar)
      assert.equals(surface2_radar, storage.anchors[2][2].radar)
      assert.is_nil(storage.anchors[1])
    end)

    it("is a no-op when the source force has no anchors", function()
      local dest_radar = factorio.radar({ unit_number = 20, force_index = 2 })
      Anchor.set(dest_radar)

      Anchor.on_forces_merged(3, 2)

      assert.equals(dest_radar, storage.anchors[2][1].radar)
      assert.is_nil(storage.anchors[3])
    end)

    it("tells the destination force a merged anchor was set", function()
      local radar = factorio.radar({ unit_number = 10, force_index = 1 })
      radar.gps_tag = "SRC"
      Anchor.set(radar)
      radar.force = factorio.force({ index = 2 })
      factorio.printed = {}

      Anchor.on_forces_merged(1, 2)

      assert.same({ "radar-alignment-guide.anchor-merged-moved-message", "SRC" }, factorio.printed[1])
    end)

    it("tells the destination force a duplicate was discarded, naming the kept anchor", function()
      local source_radar = factorio.radar({ unit_number = 10, force_index = 1 })
      source_radar.gps_tag = "SRC"
      local dest_radar = factorio.radar({ unit_number = 20, force_index = 2 })
      dest_radar.gps_tag = "DST"
      Anchor.set(source_radar)
      Anchor.set(dest_radar)
      source_radar.force = factorio.force({ index = 2 })
      factorio.printed = {}

      Anchor.on_forces_merged(1, 2)

      assert.same(
        { "radar-alignment-guide.anchor-merged-dropped-message", "SRC", "DST" },
        factorio.printed[1]
      )
    end)

    it("prints nothing when the source force has no anchors", function()
      Anchor.set(factorio.radar({ unit_number = 20, force_index = 2 }))
      factorio.printed = {}

      Anchor.on_forces_merged(3, 2)

      assert.same({}, factorio.printed)
    end)
  end)

  describe("on_toggle", function()
    it("does nothing when the player is not pointing at a radar", function()
      factorio.player({ index = 1, selected = nil })

      Anchor.on_toggle(1)

      assert.is_nil(storage.anchors[1])
    end)

    it("does nothing when the player points at a non-radar entity", function()
      factorio.player({ index = 1, selected = factorio.radar({ type = "assembling-machine" }) })

      Anchor.on_toggle(1)

      assert.is_nil(storage.anchors[1])
    end)

    it("designates the radar the player points at when it is not the anchor", function()
      local radar = factorio.radar({ unit_number = 10 })
      factorio.player({ index = 1, selected = radar })

      Anchor.on_toggle(1)

      assert.equals(radar, storage.anchors[1][1].radar)
    end)

    it("clears the anchor when the player points at the current anchor radar", function()
      local radar = factorio.radar({ unit_number = 10 })
      Anchor.set(radar)
      factorio.player({ index = 1, selected = radar })
      factorio.printed = {}

      Anchor.on_toggle(1)

      assert.is_nil(storage.anchors[1][1])
      assert.same({ "radar-alignment-guide.anchor-cleared-message" }, factorio.printed[1])
    end)
  end)

  describe("on_setting_changed", function()
    it("refreshes chart tags when the map-tag setting changed", function()
      Anchor.set(factorio.radar({ unit_number = 10 }))
      factorio.show_map_tag = true

      Anchor.on_setting_changed("radar-alignment-guide-show-map-tag")

      assert.is_not_nil(storage.anchors[1][1].chart_tag)
    end)

    it("ignores other settings", function()
      Anchor.set(factorio.radar({ unit_number = 10 }))
      factorio.show_map_tag = true

      Anchor.on_setting_changed("some-other-setting")

      assert.is_nil(storage.anchors[1][1].chart_tag)
    end)
  end)

  describe("bootstrap", function()
    it("adopts one radar per (force, surface) with radars and no anchor, and notifies the force", function()
      factorio.world_radar({ unit_number = 1, force_index = 1, surface_index = 1 })
      factorio.world_radar({ unit_number = 2, force_index = 1, surface_index = 1 })

      Anchor.bootstrap()

      local record = storage.anchors[1][1]
      assert.is_not_nil(record)
      assert.is_true(record.radar.unit_number == 1 or record.radar.unit_number == 2)
      assert.is_number(record.useful_id)
      assert.is_number(record.marker_render_id)
      assert.same(
        { "radar-alignment-guide.anchor-bootstrap-message", record.radar.gps_tag },
        factorio.printed[1]
      )
      assert.equals(1, #factorio.printed)
      assert.is_true(storage.bootstrapped)
    end)

    it("sends one message per force naming every adopted anchor", function()
      factorio.world_radar({ unit_number = 1, force_index = 1, surface_index = 1, gps_tag = "[gps=1]" })
      factorio.world_radar({ unit_number = 2, force_index = 1, surface_index = 2, gps_tag = "[gps=2]" })

      Anchor.bootstrap()

      assert.is_not_nil(storage.anchors[1][1])
      assert.is_not_nil(storage.anchors[1][2])
      assert.equals(1, #factorio.printed)
      assert.equals("radar-alignment-guide.anchor-bootstrap-message", factorio.printed[1][1])
      local locations = factorio.printed[1][2]
      assert.is_truthy(locations:find("[gps=1]", 1, true))
      assert.is_truthy(locations:find("[gps=2]", 1, true))
    end)

    it("runs only once", function()
      factorio.world_radar({ unit_number = 1, force_index = 1, surface_index = 1 })
      Anchor.bootstrap()
      local printed_after_first = #factorio.printed

      factorio.world_radar({ unit_number = 2, force_index = 1, surface_index = 2 })
      Anchor.bootstrap()

      assert.is_nil(storage.anchors[1][2])
      assert.equals(printed_after_first, #factorio.printed)
    end)

    it("skips a force with no radars without scanning its surfaces", function()
      local scanned_force_indices = {}
      local surface = factorio.world_surface(1)
      local real_find = surface.find_entities_filtered
      surface.find_entities_filtered = function(opts)
        if opts.force then
          scanned_force_indices[opts.force.index] = true
        end
        return real_find(opts)
      end
      factorio.world_radar({ unit_number = 1, force_index = 1, surface_index = 1 })
      factorio.world_force(2) -- registered, no radars

      Anchor.bootstrap()

      assert.is_nil(storage.anchors[2])
      assert.is_nil(scanned_force_indices[2])
      assert.is_true(scanned_force_indices[1])
    end)

    it("skips a (force, surface) that already has an anchor", function()
      local existing = factorio.world_radar({ unit_number = 1, force_index = 1, surface_index = 1 })
      Anchor.set(existing)
      factorio.world_radar({ unit_number = 2, force_index = 1, surface_index = 1 })

      Anchor.bootstrap()

      assert.equals(existing, storage.anchors[1][1].radar)
      assert.equals(1, #factorio.printed)
      assert.same(
        { "radar-alignment-guide.anchor-set-message", existing.gps_tag },
        factorio.printed[1]
      )
    end)

    it("sets the flag and prints nothing when there are no radars", function()
      factorio.world_force(1)

      Anchor.bootstrap()

      assert.is_nil(storage.anchors[1])
      assert.is_true(storage.bootstrapped)
      assert.same({}, factorio.printed)
    end)
  end)
end)
