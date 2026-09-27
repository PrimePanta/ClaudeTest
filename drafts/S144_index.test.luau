-- Probe fuer S144_index.lua (Trockenlauf; ENTWURF = das Modul BrainrotIndex)
local Index = ENTWURF
local fails = {}
local function check(ok, msg) if not ok then table.insert(fails, msg) end end

-- Beispielkatalog (Platzhalter): 12 Gewoehnlich, 6 Ungewoehnlich, je 2 in den hoeheren Stufen
local catalog = {}
local counts = { Gewoehnlich = 12, Ungewoehnlich = 6, Selten = 2, Episch = 2, Legendaer = 2, Mythisch = 2 }
for _, r in Index.RARITIES do
	for i = counts[r.id], 1, -1 do -- absichtlich unsortiert
		table.insert(catalog, { id = r.id:sub(1, 3) .. i, name = r.label .. " " .. string.format("%02d", i), rarity = r.id })
	end
end
local idx = Index.new(catalog)

-- 1. Sortierung: Seltenheit aufsteigend, darin nach Name
for i = 2, #idx.catalog do
	local a, b = idx.catalog[i - 1], idx.catalog[i]
	local ra, rb
	for j, r in Index.RARITIES do
		if r.id == a.rarity then ra = j end
		if r.id == b.rarity then rb = j end
	end
	check(ra < rb or (ra == rb and a.name < b.name), "Sortierung bei " .. b.name)
end

-- 2. discover: neu / schon bekannt / neuer Skin
local r1 = idx:discover("Gew1", "Normal")
check(r1.isNew and r1.isNewSkin, "erster Fund nicht neu")
local r2 = idx:discover("Gew1", "Normal")
check(not r2.isNew and not r2.isNewSkin and #r2.milestones == 0, "Wiederholung als neu gemeldet")
local r3 = idx:discover("Gew1", "Gold")
check(not r3.isNew and r3.isNewSkin, "neuer Skin nicht erkannt")
check(#r3.milestones == 1 and r3.milestones[1].id == "firstSkin", "Meilenstein erster Skin")
check(idx.mask.Gew1 == 3, "Bitmaske Normal+Gold = 3, ist " .. tostring(idx.mask.Gew1))
local r4 = idx:discover("Myt1", "Galaxie")
check(r4.isNew, "Fund mit Skin zaehlt als neuer Brainrot")
check(idx:has("Myt1") and idx:has("Myt1", "Galaxie") and not idx:has("Myt1", "Normal"), "has() mit Skin")
local got = {}
for _, m in r4.milestones do got[m.id] = true end
check(got.galaxy, "Meilenstein Galaxie")

-- 3. Meilensteine: jeder genau einmal, in der richtigen Reihenfolge
local seen = { firstSkin = 1, galaxy = 1 }
local log = {}
for _, e in idx.catalog do
	if e.rarity == "Gewoehnlich" then
		for _, m in idx:discover(e.id).milestones do
			seen[m.id] = (seen[m.id] or 0) + 1
			table.insert(log, string.format("%s bei %d gefunden", m.id, idx:progress().found))
		end
	end
end
check(seen.count10 == 1, "count10 " .. tostring(seen.count10))
check(seen.all_Gewoehnlich == 1, "alle Gewoehnlichen " .. tostring(seen.all_Gewoehnlich))
check(seen.count25 == nil, "count25 zu frueh")
local p = idx:progress()
check(p.found == 13 and p.byRarity.Gewoehnlich.found == 12 and p.byRarity.Mythisch.found == 1, "Fortschritt")
check(p.skinsFound == 2 and p.skinsTotal == #catalog * 5, "Skin-Fortschritt " .. p.skinsFound .. "/" .. p.skinsTotal)

-- 4. Fehler bei unbekannten Ids und Skins
check(not pcall(function() idx:discover("gibtsnicht") end), "unbekannte Id nicht abgelehnt")
check(not pcall(function() idx:discover("Gew1", "Quatsch") end), "unbekannter Skin nicht abgelehnt")

-- 5. Speichern und Laden: gleicher Stand, alte Meilensteine nicht erneut, fremde Ids bleiben
local saved = idx:serialize()
saved.d.Entfernt7 = 5 -- Brainrot, den es im Katalog nicht mehr gibt
local idx2 = Index.deserialize(catalog, saved)
for id, m in idx.mask do check(idx2.mask[id] == m, "Laden: " .. id) end
check(idx2:serialize().d.Entfernt7 == 5, "fremde Id beim Speichern verloren")
local again = idx2:discover("Gew2")
check(#again.milestones == 0, "alter Meilenstein nach Laden erneut gemeldet")
local bad = Index.deserialize(catalog, { v = 1, d = { Gew3 = -1, Gew4 = 1.5, Gew5 = "x", [7] = 1, Gew6 = 1 } })
check(bad.mask.Gew6 == 1 and bad.mask.Gew3 == nil and bad.mask.Gew4 == nil and bad.mask.Gew5 == nil, "kaputte Werte nicht gefiltert")
check(next(Index.deserialize(catalog, nil).mask) == nil, "leerer Stand")
check(next(Index.deserialize(catalog, { v = 99 }).mask) == nil, "unbekannte Version")

-- 6. Oberflaeche
local gui = Index.buildGui(idx, D)
local cards = gui.Window.Cards
local nCards = 0
for _, c in cards:GetChildren() do if c.ClassName == "Frame" then nCards += 1 end end
check(nCards == #catalog, "Karten " .. nCards)
check(cards.Card_Gew1.Title.Text == "Gewöhnlich 01", "entdeckte Karte zeigt " .. cards.Card_Gew1.Title.Text)
check(cards.Card_Sel1.Title.Text == "???", "unentdeckte Karte zeigt Namen")
check(cards.Card_Gew1.Skins.Gold.BackgroundColor3 == Index.SKINS[2].color, "Gold-Punkt leuchtet nicht")
check(cards.Card_Gew1.Skins.Lava.BackgroundColor3 ~= Index.SKINS[4].color, "Lava-Punkt leuchtet falsch")
check(gui.Window.Progress.Gesamt.Count.Text == "13/26", "Gesamt " .. gui.Window.Progress.Gesamt.Count.Text)
check(gui.Window.Title.Text == "Index  13/26  (50 %)", "Titel " .. gui.Window.Title.Text)
idx:discover("Sel1", "Diamant")
Index.updateGui(gui, idx)
check(cards.Card_Sel1.Title.Text == "Selten 01", "Karte nach update")
check(gui.Window.Progress["Selten"].Count.Text == "1/2", "Balken Selten nach update")
check(gui.Window.Progress["Selten"].Track.Fill.Size[1] == 0.5, "Balkenbreite Selten")

print("Index:")
print("  Katalog " .. #catalog .. ", Meilensteine: " .. table.concat(log, ", "))
print("  Speicherstand: " .. (function()
	local parts = {}
	for id, m in idx:serialize().d do table.insert(parts, id .. "=" .. m) end
	table.sort(parts)
	return table.concat(parts, " ")
end)())
print("  Oberflaeche: " .. nCards .. " Karten, Titel \"" .. gui.Window.Title.Text .. "\"")
print(#fails == 0 and "PROBE OK" or ("PROBE FEHLER:\n  " .. table.concat(fails, "\n  ")))
