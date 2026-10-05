local factorio = require("spec.support.factorio")
local Notice = require("lib.notice")

describe("Notice", function()
  before_each(function()
    factorio.reset()
    Notice.init()
  end)

  describe("deliver", function()
    it("prints to connected players and queues for the others", function()
      local online = factorio.player({ index = 1 })
      local offline = factorio.player({ index = 2, connected = false })

      Notice.deliver({ online, offline }, { "msg" }, Notice.WARNING_PRINT_SETTINGS)

      assert.same({ { message = { "msg" }, print_settings = Notice.WARNING_PRINT_SETTINGS } }, online.printed)
      assert.same({}, offline.printed)
      assert.is_nil(storage.pending_notices[1])
      assert.equals(1, #storage.pending_notices[2])
    end)
  end)

  describe("on_player_joined_game", function()
    it("prints the queued notices in order and clears the queue", function()
      local player = factorio.player({ index = 1, connected = false })
      Notice.deliver({ player }, { "first" })
      Notice.deliver({ player }, { "second" }, Notice.WARNING_PRINT_SETTINGS)

      Notice.on_player_joined_game(1)

      assert.same({ "first" }, player.printed[1].message)
      assert.same({ "second" }, player.printed[2].message)
      assert.same(Notice.WARNING_PRINT_SETTINGS, player.printed[2].print_settings)
      assert.is_nil(storage.pending_notices[1])
    end)

    it("is a no-op for a player with nothing queued", function()
      local player = factorio.player({ index = 1 })

      Notice.on_player_joined_game(1)

      assert.same({}, player.printed)
    end)
  end)

  describe("on_player_removed", function()
    it("drops the removed player's queue", function()
      local player = factorio.player({ index = 1, connected = false })
      Notice.deliver({ player }, { "msg" })

      Notice.on_player_removed(1)

      assert.is_nil(storage.pending_notices[1])
    end)
  end)

  describe("player_name", function()
    it("wraps the name in the game's player label", function()
      assert.same({ "multiplayer.player-fallback", "alice" }, Notice.player_name(factorio.player({ name = "alice" })))
    end)

    it("passes an empty name when the player has none", function()
      assert.same({ "multiplayer.player-fallback", "" }, Notice.player_name(factorio.player({ name = false })))
    end)
  end)

  describe("flying_text", function()
    it("shows the flying text only while hints are on", function()
      local player = factorio.player({ index = 1 })

      Notice.flying_text(player, { text = { "on" } })
      factorio.show_hints = false
      Notice.flying_text(player, { text = { "off" } })

      assert.equals(1, #factorio.flying_text)
      assert.same({ "on" }, factorio.flying_text[1].text)
    end)
  end)
end)
