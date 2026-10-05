local factorio = require("spec.support.factorio")
local Highlight = require("lib.highlight")
local Notice = require("lib.notice")
local Anchor = require("lib.anchor")

describe("Highlight", function()
  before_each(function()
    factorio.reset()
    Notice.init()
    Anchor.init()
    Highlight.init()
  end)

  describe("on_cursor_stack_changed without an anchor", function()
    local function player_holding_radar()
      local player = factorio.player({ index = 1 })
      player.cursor_stack = { valid_for_read = true, prototype = { place_result = { type = "radar" } } }
      player.position = { x = 0, y = 0 }
      player.display_resolution = { width = 1920, height = 1080 }
      player.zoom = 1
      return player
    end

    it("tells the player the first radar becomes the anchor when the surface has none", function()
      player_holding_radar()

      Highlight.on_cursor_stack_changed(1)

      assert.equals(1, #factorio.flying_text)
      assert.same({ "radar-alignment-guide.no-anchor-first-radar-flying-text" }, factorio.flying_text[1].text)
      assert.is_nil(factorio.flying_text[1].color)
    end)

    it("warns with the designation steps when the surface has radars but no anchor", function()
      factorio.world_radar({ unit_number = 1, force_index = 1, surface_index = 1 })
      player_holding_radar()

      Highlight.on_cursor_stack_changed(1)

      assert.equals(1, #factorio.flying_text)
      assert.same({ "radar-alignment-guide.no-anchor-warning" }, factorio.flying_text[1].text)
      assert.same(Notice.WARNING_COLOR, factorio.flying_text[1].color)
    end)

    it("shows nothing when the player turned hints off", function()
      player_holding_radar()
      factorio.show_hints = false

      Highlight.on_cursor_stack_changed(1)

      assert.same({}, factorio.flying_text)
    end)
  end)

  describe("on_player_removed", function()
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

    it("is a no-op for a removed player with no highlight state", function()
      assert.has_no.errors(function()
        Highlight.on_player_removed(7)
      end)

      assert.is_nil(storage.highlight_renders[7])
      assert.is_nil(storage.warned_players[7])
      assert.is_nil(storage.highlight_last_state[7])
    end)
  end)

  describe("on_player_left_game", function()
    it("clears the departed player's per-player entries and destroys their rectangles", function()
      local a = rendering.draw_rectangle()
      local b = rendering.draw_rectangle()
      storage.highlight_renders[7] = { a.id, b.id }
      storage.warned_players[7] = true
      storage.highlight_last_state[7] = { surface_index = 1, range = {}, anchor_key = false }

      Highlight.on_player_left_game(7)

      assert.is_nil(storage.highlight_renders[7])
      assert.is_nil(storage.warned_players[7])
      assert.is_nil(storage.highlight_last_state[7])
      assert.is_false(a.valid)
      assert.is_false(b.valid)
    end)

    it("is a no-op for a player with no highlight state", function()
      assert.has_no.errors(function()
        Highlight.on_player_left_game(7)
      end)

      assert.is_nil(storage.highlight_renders[7])
      assert.is_nil(storage.warned_players[7])
      assert.is_nil(storage.highlight_last_state[7])
    end)
  end)
end)
