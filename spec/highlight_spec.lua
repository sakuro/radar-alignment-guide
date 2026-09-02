local factorio = require("spec.support.factorio")
local Highlight = require("lib.highlight")

describe("Highlight.on_player_removed", function()
  before_each(function()
    factorio.reset()
    Highlight.init()
  end)

  it("clears the removed player's per-player entries and destroys their rectangles", function()
    local a = rendering.draw_rectangle()
    local b = rendering.draw_rectangle()
    storage.highlight_renders[7] = { a.id, b.id }
    storage.warned_players[7] = true
    storage.highlight_last_state[7] = { surface_index = 1, range = {}, anchor_key = false }

    Highlight.on_player_removed(7)

    assert.is_nil(storage.highlight_renders[7])
    assert.is_nil(storage.warned_players[7])
    assert.is_nil(storage.highlight_last_state[7])
    assert.is_false(a.valid)
    assert.is_false(b.valid)
  end)
end)
