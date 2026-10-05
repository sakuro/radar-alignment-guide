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

  describe("wider-radar warning icons", function()
    local function player_holding_radar()
      local player = factorio.player({ index = 1 })
      player.cursor_stack = { valid_for_read = true, prototype = { place_result = { type = "radar" } } }
      player.position = { x = 0, y = 0 }
      player.display_resolution = { width = 1920, height = 1080 }
      player.zoom = 1
      return player
    end

    local function set_anchor(range)
      local anchor = factorio.world_radar({ unit_number = 1, range = range })
      Anchor.set(anchor, { name = "setter", valid = true })
      return anchor
    end

    -- The anchor's own marker is a sprite too; only the warning icons are wanted.
    local function warning_icons()
      local icons = {}
      for _, object in ipairs(factorio.live_render_objects("sprite")) do
        if object.params.sprite == "utility/warning_icon" then
          icons[#icons + 1] = object
        end
      end
      return icons
    end

    it("marks a radar with wider coverage than the anchor, for the holding player only", function()
      set_anchor(3)
      local wider = factorio.world_radar({ unit_number = 2, range = 5 })
      local player = player_holding_radar()

      Highlight.on_cursor_stack_changed(1)

      local icons = warning_icons()
      assert.equals(1, #icons)
      assert.equals(wider, icons[1].params.target)
      assert.same({ player }, icons[1].params.players)
      assert.equals(30, icons[1].params.blink_interval)
    end)

    it("leaves the anchor and radars with equal or narrower coverage unmarked", function()
      set_anchor(5)
      factorio.world_radar({ unit_number = 2, range = 5 })
      factorio.world_radar({ unit_number = 3, range = 3 })
      player_holding_radar()

      Highlight.on_cursor_stack_changed(1)

      assert.same({}, warning_icons())
    end)

    it("draws no icons when the player turned hints off", function()
      set_anchor(3)
      factorio.world_radar({ unit_number = 2, range = 5 })
      player_holding_radar()
      factorio.show_hints = false

      Highlight.on_cursor_stack_changed(1)

      assert.same({}, warning_icons())
    end)

    it("removes the icons when the player stops holding a radar", function()
      set_anchor(3)
      factorio.world_radar({ unit_number = 2, range = 5 })
      local player = player_holding_radar()
      Highlight.on_cursor_stack_changed(1)

      player.cursor_stack = { valid_for_read = false }
      Highlight.on_cursor_stack_changed(1)

      assert.same({}, warning_icons())
    end)
  end)

  describe("request_redraw", function()
    it("drops the redraw-skip state of players on the surface only", function()
      factorio.player({ index = 1, surface = factorio.world_surface(1) })
      factorio.player({ index = 2, surface = factorio.world_surface(2) })
      storage.highlight_last_state[1] = { surface_index = 1, range = {}, anchor_key = false }
      storage.highlight_last_state[2] = { surface_index = 2, range = {}, anchor_key = false }

      Highlight.request_redraw(1)

      assert.is_nil(storage.highlight_last_state[1])
      assert.is_not_nil(storage.highlight_last_state[2])
    end)
  end)

  describe("on_setting_changed", function()
    local function remember_state(player_index)
      storage.highlight_last_state[player_index] = { surface_index = 1, range = {}, anchor_key = false }
    end

    it("drops the changing player's redraw-skip state for the color and hint settings", function()
      remember_state(1)
      Highlight.on_setting_changed("radar-alignment-guide-highlight-color", 1)
      assert.is_nil(storage.highlight_last_state[1])

      remember_state(1)
      Highlight.on_setting_changed("radar-alignment-guide-show-hints", 1)
      assert.is_nil(storage.highlight_last_state[1])
    end)

    it("ignores other settings and changes without a player", function()
      remember_state(1)

      Highlight.on_setting_changed("radar-alignment-guide-show-map-tag", 1)
      Highlight.on_setting_changed("radar-alignment-guide-show-hints", nil)

      assert.is_not_nil(storage.highlight_last_state[1])
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
