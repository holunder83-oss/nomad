-- Raketen-Traglast (Daten: scripts/rocket-capacity-config.lua, Prototypen: prototypes/rocket-capacity.lua).
-- Tausch ueber scripts/variant-swap.lua. Getauscht wird nur, waehrend das Silo an Raketenteilen baut; steht eine
-- Rakete bereit oder startet sie, kommt das Silo in die Warteliste. Die Raketenteile werden uebernommen.

local config = require("scripts.rocket-capacity-config")
local variant_swap = require("scripts.variant-swap")

return variant_swap.new(config,
{
  storage_key = "capacity_pending",
  can_swap = function(entity)
    return entity.rocket_silo_status == defines.rocket_silo_status.building_rocket
  end,
  save_state = function(entity)
    return {parts = entity.rocket_parts, keep = storage.capsule_keep and storage.capsule_keep[entity.unit_number]}
  end,
  after_swap = function(state, new)
    new.rocket_parts = state.parts
    if state.keep then storage.capsule_keep[new.unit_number] = true end -- Kapsel-Haekchen (scripts/capsule-cargo.lua)
  end
})
