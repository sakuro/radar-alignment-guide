--- Minimal Factorio runtime fakes for busted specs. `require` this before the
--- module under test, and call `factorio.reset()` in `before_each`.
local factorio = {}

local forces_metatable = {
  __index = function(_, index)
    return {
      index = index,
      valid = true,
      print = function(message)
        table.insert(factorio.printed, message)
      end,
    }
  end,
}

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
  factorio._players = {}
  factorio.flying_text = {}
  factorio.show_map_tag = false
  factorio._world = {}
  factorio._radar_prototype_names = { "radar" }
  _G.game.forces = setmetatable({}, forces_metatable)
  _G.game.surfaces = {}
  _G.game.tick = 1
end

--- Build a fake force table.
function factorio.force(opts)
  opts = opts or {}
  return {
    index = opts.index or 1,
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
end

--- Build a fake radar entity usable with lib/anchor.lua.
function factorio.radar(opts)
  opts = opts or {}
  return {
    valid = true,
    type = opts.type or "radar",
    unit_number = opts.unit_number or 1,
    name = opts.name or "radar",
    quality = { name = opts.quality or "normal" },
    prototype = {
      get_max_distance_of_nearby_sector_revealed = function()
        return opts.range or 3
      end,
    },
    position = opts.position or { x = 0, y = 0 },
    surface = { index = opts.surface_index or 1 },
    force = factorio.force({ index = opts.force_index or 1 }),
    gps_tag = "[gps=0,0]",
  }
end

--- Build a fake radar ghost. Same shape as factorio.radar but type
--- "entity-ghost", with the coverage accessor under ghost_prototype and no
--- plain `prototype` -- so code that wrongly reads entity.prototype on a ghost
--- fails loudly in tests.
function factorio.radar_ghost(opts)
  local ghost = factorio.radar(opts)
  ghost.type = "entity-ghost"
  ghost.ghost_prototype = ghost.prototype
  ghost.prototype = nil
  return ghost
end

--- A force registered in game.forces so `pairs(game.forces)` sees it, with a
--- get_entity_count backed by factorio._world.
function factorio.world_force(index)
  index = index or 1
  local existing = rawget(_G.game.forces, index)
  if existing then
    return existing
  end
  local force = {
    index = index,
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
    get_entity_count = function(name)
      local count = 0
      for _, radars in pairs(factorio._world) do
        for _, radar in ipairs(radars) do
          if radar.force.index == index and radar.name == name then
            count = count + 1
          end
        end
      end
      return count
    end,
  }
  _G.game.forces[index] = force
  return force
end

--- A surface registered in game.surfaces, with find_entities_filtered backed by
--- factorio._world[index].
function factorio.world_surface(index)
  index = index or 1
  if _G.game.surfaces[index] then
    return _G.game.surfaces[index]
  end
  local surface = {
    index = index,
    find_entities_filtered = function(opts)
      local matches = {}
      for _, radar in ipairs(factorio._world[index] or {}) do
        local ok = true
        if opts.type and radar.type ~= opts.type then
          ok = false
        end
        if opts.force and radar.force.index ~= opts.force.index then
          ok = false
        end
        if ok then
          matches[#matches + 1] = radar
          if opts.limit and #matches >= opts.limit then
            break
          end
        end
      end
      return matches
    end,
  }
  _G.game.surfaces[index] = surface
  return surface
end

--- Like factorio.radar, but also placed in the world: its force is registered
--- in game.forces and it is discoverable by get_entity_count /
--- find_entities_filtered.
function factorio.world_radar(opts)
  opts = opts or {}
  local surface_index = opts.surface_index or 1
  local force = factorio.world_force(opts.force_index or 1)
  factorio.world_surface(surface_index)
  local radar = {
    valid = true,
    type = opts.type or "radar",
    unit_number = opts.unit_number or 1,
    name = opts.name or "radar",
    quality = { name = opts.quality or "normal" },
    prototype = {
      get_max_distance_of_nearby_sector_revealed = function()
        return opts.range or 3
      end,
    },
    position = opts.position or { x = 0, y = 0 },
    surface = { index = surface_index },
    force = force,
    gps_tag = opts.gps_tag or "[gps=0,0]",
  }
  factorio._world[surface_index] = factorio._world[surface_index] or {}
  table.insert(factorio._world[surface_index], radar)
  return radar
end

--- Build a fake player and register it for game.get_player.
function factorio.player(opts)
  opts = opts or {}
  local player = {
    index = opts.index or 1,
    valid = opts.valid ~= false,
    selected = opts.selected,
    create_local_flying_text = function(params)
      table.insert(factorio.flying_text, params)
    end,
  }
  factorio._players[player.index] = player
  return player
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
  get_player = function(index)
    return factorio._players[index]
  end,
}

_G.prototypes = {
  get_entity_filtered = function(_)
    local result = {}
    for _, name in ipairs(factorio._radar_prototype_names) do
      result[name] = { name = name }
    end
    return result
  end,
}

factorio.reset()

return factorio
