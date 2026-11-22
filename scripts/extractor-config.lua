-- Boden-Extraktor: Spezialboeden und Schiffs-Quellen gibt es nur noch aus Fundstellen auf den Planeten.
-- Gemeinsam genutzt von prototypes/extractor.lua (Datenphase) und scripts/extractor.lua (Laufzeit).
-- Zahlen sind vorlaeufig und werden beim Testen festgelegt.
--
-- Je Fundstelle:
--   name:       Kurzname, daraus werden Fundstelle "ncs-core-<name>" und Rezept "ncs-extract-<name>"
--   planet:     Planet, auf dem die Fundstelle entsteht
--   tiles / resources: Fundstellen entstehen neben diesen Feldern bzw. Lagerstaetten
--   product:    Item, das ein Lauf liefert (Boden oder Quelle), count: wie viele pro Lauf
--   technology: Freischalt-Forschung des Bodens bzw. der Quelle; ohne sie startet kein Lauf
--   ingredients: Zutaten pro Lauf (ohne Fundament, das kommt aus count)
--   tint:       Farbe der Fundstelle auf Boden und Karte
--   challenge:  Herausforderung waehrend eines Laufs (scripts/extractor.lua): "avalanche" (Fulgora), "heat" (Vulcanus),
--               "waves" (Gleba), "cold" (Aquilo), "pollution" (Nauvis)
--   runs:       Laeufe pro Fundstelle, falls nicht config.RUNS
--   chance:     Faktor auf config.CHANCE; klein bei Feldern, die fast ueberall liegen (Lava), damit alle Arten etwa
--               gleich selten sind

local config = {}

config.EXTRACTOR = "ncs-extractor"
config.TECHNOLOGY = "ncs-extractor"
config.SCANNER = "ncs-core-scanner" -- Werkzeug, zeigt die naechsten Fundstellen
config.RUN_SECONDS = 300 -- ein Lauf dauert 5 Minuten
config.RUNS = 5          -- Laeufe pro Fundstelle (jedes Feld der Fundstelle haelt so viele), pro Art aenderbar mit runs
config.SOURCE_RUNS = 1   -- Fundstellen von Quellen (1 Quelle pro Lauf) halten nur einen Lauf
config.PATCH_RADIUS = 1  -- Fundstelle 3x3, so gross wie der Extraktor (bis 1.24.0-Entwurf 5x5)
config.CHANCE = 0.1      -- Grundchance pro passendem Chunk (mal chance der Art), steigt mit der Entfernung zum Start
config.FAR_CHUNKS = 40   -- ab dieser Entfernung (in Chunks) dreifache Chance
-- Garantie: Jede Art eines Planeten kommt mindestens einmal im Umkreis RADIUS um den Landepunkt {0, 0} vor, nicht
-- naeher als MIN_DISTANCE. Gibt es dort kein passendes Feld/Erz, waechst der Umkreis um STEP bis MAX_RADIUS.
config.GUARANTEE = {RADIUS = 400, STEP = 400, MAX_RADIUS = 1200, MIN_DISTANCE = 96, TRIES = 200}

-- Fulgora, Schrott-Lawine: Auswurf steigt von START auf END Schrott pro Sekunde (quadratisch, am Schluss extrem).
-- Bleibt der Ausgang FAIL_SECONDS lang voll, stuerzt der Schacht ein und der Lauf ist verloren.
-- 10 -> 240/s: rund 26 000 Schrott pro Lauf, am Schluss gut 4 Turbo-Baender (1.24.0: "viel mehr Schrott").
-- Es ist instabiler Schrott: explodiert nach SPOIL_SECONDS, ausser er wird vorher in einer Montagemaschine
-- stabilisiert (Rezept ncs-stabilize-scrap). Ein Kisten-Ring um den Extraktor reicht also nicht.
config.AVALANCHE = {item = "ncs-unstable-scrap", START = 10, END = 240, FAIL_SECONDS = 5, SPOIL_SECONDS = 45} -- 1.0.11: 45 s statt 120 (Wunsch des Users)

-- Vulcanus, Kuehlung: Der Extraktor zieht Wasser und gibt STEAM_PER_WATER mal so viel heissen Dampf (500 Grad) ab
-- (seit 1.24.0 3, User wollte mehr Dampf). Der Wasserbedarf steigt waehrend des Laufs stetig von START auf END pro Sekunde. Fehlt Wasser oder ist der Dampf-Ausgang voll,
-- steigt die Hitze um bis zu RISE % pro Sekunde; ist alles gut, sinkt sie um COOL % pro Sekunde.
-- Bei 100 % explodiert er: Lauf verloren, DAMAGE Schaden.
config.HEAT = {START = 20, END = 400, STEAM_PER_WATER = 3, STEAM_TEMPERATURE = 500, RISE = 10, COOL = 2, DAMAGE = 1500}

-- Gleba, Gegnerwellen: Bei Fortschritt "at" kommt eine Welle Pentapoden aus DISTANCE Feldern Entfernung und greift
-- den Extraktor an, zum Schluss ein Boss. Wird der Extraktor zerstoert, ist der Lauf verloren.
config.WAVES =
{
  DISTANCE = 150,
  {at = 0.05, units = {{"small-wriggler-pentapod", 8}, {"small-strafer-pentapod", 2}}},
  {at = 0.15, units = {{"small-wriggler-pentapod", 12}, {"small-strafer-pentapod", 4}}},
  {at = 0.25, units = {{"small-wriggler-pentapod", 10}, {"small-strafer-pentapod", 4}, {"small-stomper-pentapod", 1}}},
  {at = 0.35, units = {{"medium-wriggler-pentapod", 10}, {"medium-strafer-pentapod", 3}}},
  {at = 0.45, units = {{"medium-wriggler-pentapod", 10}, {"medium-strafer-pentapod", 5}, {"medium-stomper-pentapod", 1}}},
  {at = 0.55, units = {{"medium-strafer-pentapod", 6}, {"medium-stomper-pentapod", 2}}},
  {at = 0.65, units = {{"big-wriggler-pentapod", 12}, {"big-strafer-pentapod", 3}, {"medium-stomper-pentapod", 2}}},
  {at = 0.75, units = {{"big-wriggler-pentapod", 12}, {"big-strafer-pentapod", 5}, {"big-stomper-pentapod", 1}}},
  {at = 0.85, units = {{"big-strafer-pentapod", 6}, {"big-stomper-pentapod", 2}}},
  {at = 0.95, boss = true, units = {{"big-wriggler-pentapod", 20}, {"big-strafer-pentapod", 8}, {"big-stomper-pentapod", 3}}}
}

-- Aquilo, Waerme: Auf Aquilo bekommt der Extraktor einen Waermespeicher (Anschluesse fuer Waermerohre rundherum).
-- Waehrend des Laufs entzieht er ihm stetig mehr Waerme, von START auf END MW. Faellt der Speicher unter
-- MIN_TEMPERATURE, steigt der Frost um bis zu RISE % pro Sekunde (sonst sinkt er um THAW %); bei 100 % friert der
-- Lauf ein und ist verloren. Friert der Extraktor selbst ein (normale Aquilo-Regel), ebenso.
config.COLD = {START = 5, END = 60, MIN_TEMPERATURE = 200, RISE = 10, THAW = 2}

-- Nauvis, Verschmutzung: Der Lauf verschmutzt stark (START bis END Verschmutzung pro Sekunde) und schickt alle
-- INTERVAL Sekunden die Beisser aus SEARCH Feldern Umkreis los, immer mehr (UNITS_START bis UNITS_END).
-- Wird der Extraktor zerstoert, ist der Lauf verloren.
config.POLLUTION = {START = 20, END = 400, INTERVAL = 30, SEARCH = 400, UNITS_START = 10, UNITS_END = 80}

local function item(name, amount) return {type = "item", name = name, amount = amount} end

config.cores =
{
  -- Spezialboeden, Felder pro Lauf (seit 1.24.1 je nach Bedarf, vorher alle 3, im 1.24.0-Entwurf 10):
  --   Lava und Ammoniak 2 bei 3 Laeufen, also 6 pro Fundstelle: eine Offshore-Pumpe braucht nur 1-2 Felder.
  --   Bio-Boeden 100: ein voll genutzter Agrarturm braucht rund 440 Felder (Radius 3 x 3er-Raster = 21x21).
  {
    name = "lava", planet = "vulcanus", tiles = {"lava", "lava-hot"}, chance = 0.08, challenge = "heat",
    product = "ncs-lava-pool", count = 2, runs = 3, technology = "ncs-lava-zone",
    ingredients = {item("tungsten-plate", 100), item("tungsten-carbide", 50)},
    tint = {r = 1, g = 0.45, b = 0.15}
  },
  {
    name = "yumako", planet = "gleba", tiles = {"natural-yumako-soil", "overgrowth-yumako-soil"}, chance = 0.4, challenge = "waves",
    product = "ncs-bio-foundation", count = 100, technology = "ncs-bio-zone",
    ingredients = {item("nutrients", 200), item("bioflux", 50)},
    tint = {r = 0.55, g = 1, b = 0.35}
  },
  {
    name = "jellynut", planet = "gleba", tiles = {"natural-jellynut-soil", "overgrowth-jellynut-soil"}, chance = 0.4, challenge = "waves",
    product = "ncs-jellynut-foundation", count = 100, technology = "ncs-jellynut-zone",
    ingredients = {item("nutrients", 200), item("bioflux", 50)},
    tint = {r = 1, g = 0.35, b = 0.85}
  },
  {
    name = "ammonia", planet = "aquilo", tiles = {"ammoniacal-ocean", "ammoniacal-ocean-2"}, chance = 0.15, challenge = "cold",
    product = "ncs-ammonia-pool", count = 2, runs = 3, technology = "ncs-ammonia-zone",
    ingredients = {item("ice", 500), item("holmium-plate", 50)},
    tint = {r = 0.55, g = 0.6, b = 1}
  },
  -- Schiffs-Quellen: 1 pro Lauf
  {
    -- Herausforderung "Schrott-Lawine": waehrend des Laufs wirft er immer mehr Schrott aus (config.AVALANCHE)
    name = "scrap", planet = "fulgora", resources = {"scrap"}, challenge = "avalanche",
    product = "ncs-scrap-vein", count = 1, technology = "ncs-scrap-vein",
    ingredients = {item("holmium-plate", 500), item("supercapacitor", 100)},
    tint = {r = 0.75, g = 0.8, b = 1}
  },
  {
    name = "lithium", planet = "aquilo", resources = {"lithium-brine"}, challenge = "cold",
    product = "ncs-lithium-source", count = 1, technology = "ncs-lithium-source",
    ingredients = {item("ice", 2000), item("holmium-plate", 300), item("processing-unit", 100)},
    tint = {r = 0.85, g = 0.9, b = 1}
  },
  {
    name = "fluorine", planet = "aquilo", resources = {"fluorine-vent"}, challenge = "cold",
    product = "ncs-fluorine-source", count = 1, technology = "ncs-fluorine-source",
    ingredients = {item("ice", 2000), item("holmium-plate", 300), item("processing-unit", 100)},
    tint = {r = 0.85, g = 1, b = 0.7}
  },
  {
    name = "tungsten", planet = "vulcanus", resources = {"tungsten-ore"}, challenge = "heat",
    product = "ncs-tungsten-vein", count = 1, technology = "ncs-tungsten-vein",
    ingredients = {item("tungsten-carbide", 500), item("big-mining-drill", 5)},
    tint = {r = 0.55, g = 0.45, b = 0.75}
  },
  {
    name = "calcite", planet = "vulcanus", resources = {"calcite"}, challenge = "heat",
    product = "ncs-calcite-vein", count = 1, technology = "ncs-calcite-vein",
    ingredients = {item("refined-concrete", 500), item("big-mining-drill", 5)},
    tint = {r = 0.95, g = 0.95, b = 0.85}
  },
  {
    name = "oil", planet = "nauvis", resources = {"crude-oil"}, challenge = "pollution",
    product = "ncs-oil-source", count = 1, technology = "ncs-oil-source",
    ingredients = {item("refined-concrete", 500), item("pumpjack", 10), item("processing-unit", 100)},
    tint = {r = 0.4, g = 0.3, b = 0.45}
  },
  {
    name = "uranium", planet = "nauvis", resources = {"uranium-ore"}, challenge = "pollution",
    product = "ncs-uranium-vein", count = 1, technology = "ncs-uranium-vein",
    ingredients = {item("refined-concrete", 500), item("electric-mining-drill", 20), item("processing-unit", 100)},
    tint = {r = 0.45, g = 1, b = 0.3}
  }
}

for _, core in pairs(config.cores) do
  core.entity = "ncs-core-" .. core.name
  core.recipe = "ncs-extract-" .. core.name
  -- Jeder Lauf braucht Fundament: 1 pro Boden-Feld, 9 pro Quelle (wie bisher)
  local foundation = core.count == 1 and 9 or core.count
  -- Quellen: Fundstelle haelt nur einen Lauf (seit 1.24.1, Wunsch des Users)
  if core.count == 1 then core.runs = core.runs or config.SOURCE_RUNS end
  table.insert(core.ingredients, 1, item("space-platform-foundation", foundation))
end

return config
