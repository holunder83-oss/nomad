-- Tipps und Tricks: eigene Kategorie "Nomad" (seit 1.24.1, Wunsch des Users). Texte in locale/*/locale.cfg unter
-- [tips-and-tricks-item-name] und [tips-and-tricks-item-description]. Alle Eintraege sind sofort freigeschaltet
-- (keine Benachrichtigung), der Titel-Eintrag zeigt die Kategorie.

local CATEGORY = "nomad"

-- {name, Symbol (Rich Text vor dem Namen)}
local ENTRIES =
{
  {"nomad-start", "[item=space-platform-hub]"},
  {"nomad-research", "[item=lab]"},
  {"nomad-spacesuit", "[item=modular-armor]"},
  {"nomad-planets", "[item=rocket-silo]"},
  {"nomad-supply", "[item=ncs-supply-capsule]"},
  {"nomad-extractor", "[item=ncs-extractor]"},
  {"nomad-floors", "[item=ncs-lava-pool]"},
  {"nomad-cannon", "[item=ncs-orbital-cannon]"},
  {"nomad-lategame", "[item=ncs-promethium-foundation]"},
  -- Schwere Regel-Varianten (1.0.17, Wunsch des Users: im Spiel ausfuehrlicher beschreiben)
  {"nomad-variant-d", "[item=stone-furnace]"},
  {"nomad-variant-e", "[item=burner-inserter]"},
  {"nomad-variant-f", "[item=burner-mining-drill]"}
}

local list =
{
  {type = "tips-and-tricks-item-category", name = CATEGORY, order = "0-nomad"},
  {
    type = "tips-and-tricks-item",
    name = CATEGORY,
    category = CATEGORY,
    order = "a",
    is_title = true,
    starting_status = "unlocked",
    tag = "[item=space-platform-foundation]"
  }
}
for i, entry in pairs(ENTRIES) do
  table.insert(list,
  {
    type = "tips-and-tricks-item",
    name = entry[1],
    category = CATEGORY,
    order = "b" .. string.format("%02d", i),
    indent = 1,
    starting_status = "unlocked",
    tag = entry[2]
  })
end

data:extend(list)
