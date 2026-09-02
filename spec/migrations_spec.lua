_G.log = function() end -- lib/migration.lua calls log() on failure

local Migration = require("lib.migration")
local migrations = require("lib.migrations")

describe("migrations[2] (five tables -> per-anchor records)", function()
  it("folds the auxiliary tables into one record per anchor", function()
    local store = {
      anchors = { [1] = { [1] = "RADAR_A" } },
      anchor_registrations = { [42] = { force_index = 1, surface_index = 1 } },
      anchor_useful_ids = { [1] = { [1] = 42 } },
      anchor_markers = { [1] = { [1] = 7 } },
      anchor_chart_tags = { [1] = { [1] = "TAG" } },
    }

    migrations[2](store)

    assert.same(
      { radar = "RADAR_A", useful_id = 42, marker_render_id = 7, chart_tag = "TAG" },
      store.anchors[1][1]
    )
    assert.is_nil(store.anchor_registrations)
    assert.is_nil(store.anchor_useful_ids)
    assert.is_nil(store.anchor_markers)
    assert.is_nil(store.anchor_chart_tags)
  end)

  it("is a no-op on a store with no anchor data", function()
    local store = {}
    migrations[2](store)
    assert.same({}, store)
  end)
end)

describe("Migration.apply", function()
  it("treats a nil schema_version as 1 and runs up to LATEST", function()
    local store = {
      anchors = { [1] = { [1] = "R" } },
      anchor_useful_ids = {}, anchor_markers = {}, anchor_chart_tags = {},
    }

    local ok = Migration.apply(store, migrations)

    assert.is_true(ok)
    assert.equals(Migration.LATEST, store.schema_version)
    assert.equals("R", store.anchors[1][1].radar)
  end)

  it("is a no-op the second time", function()
    local store = { anchors = {} }
    Migration.apply(store, migrations)
    local anchors_ref = store.anchors
    Migration.apply(store, migrations)
    assert.equals(anchors_ref, store.anchors)
    assert.equals(Migration.LATEST, store.schema_version)
  end)

  it("resets the store and flags migration_reset when a step raises", function()
    local store = { anchors = { keep = true }, schema_version = 1 }

    local ok = Migration.apply(store, { [2] = function() error("boom") end })

    assert.is_false(ok)
    assert.is_nil(store.anchors)
    assert.is_true(store.migration_reset)
    assert.equals(Migration.LATEST, store.schema_version)
  end)
end)
