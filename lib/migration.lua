--- Generic storage-schema migration runner.
--- ```lua
--- local Migration = require("lib.migration")
--- local migrations = require("lib.migrations")
--- Migration.apply(storage, migrations)
--- ```
local Migration = {}

--- Current storage schema version. Bump by 1 whenever the storage layout
--- changes, and add a matching step to lib/migrations.lua. Independent of the
--- mod's semver. Schema version 1 is the mod 0.5.0 layout.
Migration.LATEST = 2

local function run_steps(store, steps)
  local from = store.schema_version or 1
  for version = from + 1, Migration.LATEST do
    steps[version](store)
  end
end

--- Bring `store` up to Migration.LATEST. Called from both on_init (where the
--- store is empty, so every step no-ops) and on_configuration_changed.
---
--- A bug in a step must not make the save unloadable: the step loop runs
--- inside pcall, and on any error the store is wiped (a half-applied in-place
--- step can leave it inconsistent, so empty is the only safe state),
--- `migration_reset` is set for control.lua to surface to players, and the
--- error text is logged for bug reports. `schema_version` is stamped either
--- way so a failed migration is not retried on the next load.
---
--- Returns true on success, false if a reset happened.
function Migration.apply(store, steps)
  local ok, err = pcall(run_steps, store, steps)
  if not ok then
    log("radar-alignment-guide: storage migration failed, mod storage was reset. " .. tostring(err))
    for key in pairs(store) do
      store[key] = nil
    end
    store.migration_reset = true
    store.schema_version = Migration.LATEST
    return false
  end
  -- Never stamp downward: a mod downgrade must not mask that the store still
  -- holds a newer shape than this version understands.
  store.schema_version = math.max(store.schema_version or 1, Migration.LATEST)
  return true
end

return Migration
