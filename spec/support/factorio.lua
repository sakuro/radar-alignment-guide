--- Minimal Factorio runtime fakes for busted specs. `require` this before the
--- module under test, and call `factorio.reset()` in `before_each`.
local factorio = {}

local next_render_id
local render_objects

local function new_render_object()
  next_render_id = next_render_id + 1
  local object = { id = next_render_id, valid = true }
  function object.destroy()
    object.valid = false
  end
  render_objects[object.id] = object
  return object
end

function factorio.reset()
  _G.storage = {}
  next_render_id = 0
  render_objects = {}
  factorio.printed = {}
  factorio.registered = {}
  factorio.show_map_tag = false
end

--- Build a fake radar entity usable with lib/anchor.lua.
function factorio.radar(opts)
  opts = opts or {}
  local force = {
    index = opts.force_index or 1,
    valid = true,
    print = function(message)
      table.insert(factorio.printed, message)
    end,
    add_chart_tag = function()
      if not factorio.show_map_tag then
        return nil
      end
      local tag = { valid = true }
      function tag.destroy()
        tag.valid = false
      end
      return tag
    end,
  }
  return {
    valid = true,
    unit_number = opts.unit_number or 1,
    name = opts.name or "radar",
    quality = { name = opts.quality or "normal" },
    position = opts.position or { x = 0, y = 0 },
    surface = { index = opts.surface_index or 1 },
    force = force,
    gps_tag = "[gps=0,0]",
  }
end

_G.log = function() end

_G.script = {
  -- returns registration_number, useful_id, type
  register_on_object_destroyed = function(entity)
    table.insert(factorio.registered, entity)
    return #factorio.registered, entity.unit_number, "entity"
  end,
}

_G.rendering = {
  draw_sprite = function()
    return new_render_object()
  end,
  draw_rectangle = function()
    return new_render_object()
  end,
  get_object_by_id = function(id)
    return render_objects[id]
  end,
}

_G.settings = {
  global = setmetatable({}, {
    __index = function(_, key)
      if key == "radar-alignment-guide-show-map-tag" then
        return { value = factorio.show_map_tag }
      end
      return { value = nil }
    end,
  }),
}

_G.game = {
  forces = setmetatable({}, {
    __index = function(_, index)
      return {
        index = index,
        valid = true,
        print = function(message)
          table.insert(factorio.printed, message)
        end,
      }
    end,
  }),
}

factorio.reset()

return factorio
