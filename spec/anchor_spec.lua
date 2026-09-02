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
      Anchor.set(first, true)

      local record = storage.anchors[1][1]
      assert.equals(first, record.radar)
      assert.equals(10, record.useful_id)
      assert.is_number(record.marker_render_id)

      local second = factorio.radar({ unit_number = 20 })
      Anchor.set(second, true)

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
      Anchor.set(radar, true)
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
    end)
  end)

  describe("on_object_destroyed", function()
    it("clears the scope whose record matches the useful_id", function()
      Anchor.set(factorio.radar({ unit_number = 10 }), true)

      Anchor.on_object_destroyed({ useful_id = 10 })

      assert.is_nil(storage.anchors[1][1])
    end)

    it("ignores a useful_id no record holds (stale late event)", function()
      Anchor.set(factorio.radar({ unit_number = 10 }), true)
      Anchor.set(factorio.radar({ unit_number = 20 }), true) -- replaces scope 1,1

      Anchor.on_object_destroyed({ useful_id = 10 })

      assert.is_not_nil(storage.anchors[1][1])
      assert.equals(20, storage.anchors[1][1].useful_id)
    end)
  end)

  describe("on_forces_merged", function()
    it("moves a source anchor into an empty destination scope and rebuilds its visuals", function()
      factorio.show_map_tag = true
      local radar = factorio.radar({ unit_number = 10, force_index = 1 })
      Anchor.set(radar, true)
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
      Anchor.set(source_radar, true)
      Anchor.set(dest_radar, true)
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
      Anchor.set(surface1_radar, true)
      Anchor.set(surface2_radar, true)

      surface1_radar.force = factorio.force({ index = 2 })
      Anchor.on_forces_merged(1, 2)

      assert.equals(surface1_radar, storage.anchors[2][1].radar)
      assert.equals(surface2_radar, storage.anchors[2][2].radar)
      assert.is_nil(storage.anchors[1])
    end)

    it("is a no-op when the source force has no anchors", function()
      local dest_radar = factorio.radar({ unit_number = 20, force_index = 2 })
      Anchor.set(dest_radar, true)

      Anchor.on_forces_merged(3, 2)

      assert.equals(dest_radar, storage.anchors[2][1].radar)
      assert.is_nil(storage.anchors[3])
    end)
  end)
end)
