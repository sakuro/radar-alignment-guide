local Grid = require("lib.grid")

describe("Grid.is_on_grid", function()
  it("is true at the anchor chunk itself", function()
    assert.is_true(Grid.is_on_grid({x = 5, y = -3}, 7, {x = 5, y = -3}))
  end)

  it("is true at a positive multiple of the radius on both axes", function()
    assert.is_true(Grid.is_on_grid({x = 0, y = 0}, 7, {x = 14, y = -21}))
  end)

  it("is false when the x offset is not a multiple of the radius", function()
    assert.is_false(Grid.is_on_grid({x = 0, y = 0}, 7, {x = 3, y = 0}))
  end)

  it("is false when the y offset is not a multiple of the radius", function()
    assert.is_false(Grid.is_on_grid({x = 0, y = 0}, 7, {x = 0, y = 5}))
  end)

  it("handles negative offsets on both axes", function()
    assert.is_true(Grid.is_on_grid({x = 2, y = 2}, 5, {x = -3, y = 7}))
  end)
end)

describe("Grid.visible_chunk_range", function()
  it("computes chunk bounds centered on the player at zoom 1", function()
    local range = Grid.visible_chunk_range({x = 0, y = 0}, {width = 1920, height = 1080}, 1)
    assert.are.same({left = -1, right = 0, top = -1, bottom = 0}, range)
  end)

  it("widens the range as zoom decreases", function()
    local range = Grid.visible_chunk_range({x = 0, y = 0}, {width = 1920, height = 1080}, 0.5)
    assert.are.same({left = -2, right = 1, top = -2, bottom = 1}, range)
  end)

  it("shifts the range with a non-origin player position", function()
    local range = Grid.visible_chunk_range({x = 100, y = -50}, {width = 1920, height = 1080}, 1)
    assert.are.same({left = 2, right = 4, top = -3, bottom = -2}, range)
  end)
end)
