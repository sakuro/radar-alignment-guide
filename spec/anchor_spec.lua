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
end)
