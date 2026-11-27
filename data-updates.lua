-- Laeuft nach Space Age (data-updates), damit die Space-Age-Werte des Raketensilos schon gesetzt sind.
require("prototypes.supply-capsule")
require("prototypes.rocket-capacity") -- Varianten von Silo und Kapsel, deshalb danach
require("prototypes.large-cargo-bay")
require("prototypes.recall")
require("prototypes.orbital-cannon")
require("prototypes.small-gun-turret") -- Variante E: kleines MG-Geschuetz ab Start
require("prototypes.robot-shells")
require("prototypes.zone-buildings")
require("prototypes.lategame")
require("prototypes.nomad-ending") -- nach lategame (setzt den Promethium-Boden voraus)
require("prototypes.ship-balance") -- Triebwerke inkl. Promethium-Triebwerk, deshalb nach lategame
require("prototypes.spacesuit")
require("prototypes.sources")
require("prototypes.extractor") -- nach floors, zone-buildings und sources (passt deren Forschungen an)
require("prototypes.space-robots")
require("prototypes.tungsten-drill") -- elektrischer Bohrer auf Wolframerz (langsame Variante, nimmt Schaden)
