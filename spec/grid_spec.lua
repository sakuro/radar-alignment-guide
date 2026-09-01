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
