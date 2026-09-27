--[[ S144-ENTWURF: Sammel-Index fuer Brainrots und Skins (ModuleScript "BrainrotIndex")

UNGEPRUEFT IN STUDIO - Trockenlauf: tools/trockenlauf/run.sh (Probe: S144_index.test.luau).

Idee: Ein Sammelbuch gibt dem Schluepfen ein langfristiges Ziel.
  - Jeder Brainrot hat eine Karte: unentdeckt als "???" mit Seltenheitsrahmen, entdeckt mit Namen.
  - Unter jeder Karte eine Punktreihe fuer die Skins: gefundene leuchten in der Skin-Farbe.
  - Fortschritt oben: gesamt und je Seltenheit als Balken.
  - Meilensteine mit Belohnung (Vorschlaege): 10/25/50 Brainrots, jede komplette Seltenheit,
    erster Skin, erster Galaxie-Skin. discover() meldet neu erreichte Meilensteine -> der Server
    vergibt die Belohnung, die Schluepf-Animation zeigt "NEU im Index!" (info.isNew in S143).

Aufteilung:
  Index.new(catalog, data?)   -> Sammelstand eines Spielers (Server). catalog = Liste {id, name, rarity}
  idx:discover(id, skin)      -> { isNew, isNewSkin, milestones = {...} }
  idx:has(id, skin?) / idx:progress() / idx:serialize() (fuer DataStore) / Index.deserialize(...)
  Index.buildGui(idx, parent) -> ScreenGui "IndexGui" (Client, aus dem vom Server gesendeten Stand)
  Index.updateGui(gui, idx)   -> Karten, Punkte und Balken auf den aktuellen Stand bringen

Speicherformat (DataStore): { v = 1, d = { [brainrotId] = Bitmaske der Skins } }.
SKIN_BITS sind FEST: neue Skins nur hinten anhaengen, nie umsortieren, sonst verschieben sich alte Staende.
Unbekannte Ids/Bits (z. B. entfernte Brainrots) bleiben beim Speichern erhalten.

ANPASSEN: MILESTONES (Belohnungen), Farben; SKINS muss zu S142_skins.lua passen.
]]

local Index = {}
Index.__index = Index

-- Feste Bitpositionen je Skin (nur hinten anhaengen!)
local SKIN_BITS = { Normal = 0, Gold = 1, Diamant = 2, Lava = 3, Regenbogen = 4, Galaxie = 5 }
-- Anzeige-Reihenfolge und Farben (wie S142_skins.lua)
local SKINS = {
	{ id = "Normal", color = Color3.fromRGB(200, 200, 200) },
	{ id = "Gold", color = Color3.fromRGB(255, 200, 50) },
	{ id = "Diamant", color = Color3.fromRGB(140, 225, 255) },
	{ id = "Lava", color = Color3.fromRGB(255, 110, 30) },
	{ id = "Regenbogen", color = Color3.fromRGB(255, 90, 200) },
	{ id = "Galaxie", color = Color3.fromRGB(150, 90, 255) },
}
Index.SKINS = SKINS

local RARITIES = {
	{ id = "Gewoehnlich", label = "Gewöhnlich", color = Color3.fromRGB(190, 190, 190) },
	{ id = "Ungewoehnlich", label = "Ungewöhnlich", color = Color3.fromRGB(90, 200, 90) },
	{ id = "Selten", label = "Selten", color = Color3.fromRGB(70, 150, 255) },
	{ id = "Episch", label = "Episch", color = Color3.fromRGB(170, 80, 255) },
	{ id = "Legendaer", label = "Legendär", color = Color3.fromRGB(255, 190, 40) },
	{ id = "Mythisch", label = "Mythisch", color = Color3.fromRGB(255, 60, 110) },
}
local RARITY_BY_ID = {}
for i, r in RARITIES do
	r.order = i
	RARITY_BY_ID[r.id] = r
end
Index.RARITIES = RARITIES

-- Meilensteine (Vorschlaege). reward wird nur gemeldet, vergeben muss der Server.
Index.MILESTONES = {
	{ id = "count10", text = "10 Brainrots entdeckt", test = function(p) return p.found >= 10 end, reward = { coins = 1000 } },
	{ id = "count25", text = "25 Brainrots entdeckt", test = function(p) return p.found >= 25 end, reward = { coins = 10000 } },
	{ id = "count50", text = "50 Brainrots entdeckt", test = function(p) return p.found >= 50 end, reward = { coins = 100000 } },
	{ id = "firstSkin", text = "Erster Skin", test = function(p) return p.skinsFound > 0 end, reward = { coins = 2500 } },
	{ id = "galaxy", text = "Galaxie-Skin gefunden", test = function(p) return p.bySkin.Galaxie > 0 end, reward = { title = "Sternenkind" } },
}
for _, r in RARITIES do
	table.insert(Index.MILESTONES, {
		id = "all_" .. r.id,
		text = "Alle " .. r.label .. "en entdeckt",
		test = function(p)
			local t = p.byRarity[r.id]
			return t.total > 0 and t.found == t.total
		end,
		reward = { income = 0.05 }, -- +5 % Einkommen dauerhaft
	})
end

local function bit(skin)
	local b = SKIN_BITS[skin]
	return b and bit32.lshift(1, b) or nil
end

function Index.new(catalog, data)
	local self = setmetatable({}, Index)
	self.catalog = {}
	self.byId = {}
	for _, e in catalog do
		assert(RARITY_BY_ID[e.rarity], "unbekannte Seltenheit: " .. tostring(e.rarity))
		local entry = { id = e.id, name = e.name, rarity = e.rarity }
		table.insert(self.catalog, entry)
		self.byId[e.id] = entry
	end
	-- innerhalb der Seltenheit alphabetisch, Seltenheiten aufsteigend
	table.sort(self.catalog, function(a, b)
		local ra, rb = RARITY_BY_ID[a.rarity].order, RARITY_BY_ID[b.rarity].order
		if ra ~= rb then
			return ra < rb
		end
		return a.name < b.name
	end)
	self.mask = {} -- [id] = Bitmaske (auch unbekannte Ids aus altem Stand)
	if data then
		for id, m in data do
			self.mask[id] = m
		end
	end
	self.reached = {}
	local p = self:progress()
	for _, ms in Index.MILESTONES do
		if ms.test(p) then
			self.reached[ms.id] = true -- schon erreicht -> nicht erneut melden
		end
	end
	return self
end

function Index:has(id, skin)
	local m = self.mask[id] or 0
	if skin == nil then
		return m ~= 0
	end
	local b = bit(skin)
	return b ~= nil and bit32.band(m, b) ~= 0
end

function Index:progress()
	local p = { found = 0, total = #self.catalog, skinsFound = 0, skinsTotal = 0, byRarity = {}, bySkin = {} }
	for _, r in RARITIES do
		p.byRarity[r.id] = { found = 0, total = 0 }
	end
	for _, s in SKINS do
		p.bySkin[s.id] = 0
	end
	for _, e in self.catalog do
		local t = p.byRarity[e.rarity]
		t.total += 1
		if self:has(e.id) then
			p.found += 1
			t.found += 1
		end
		for _, s in SKINS do
			if s.id ~= "Normal" then
				p.skinsTotal += 1
				if self:has(e.id, s.id) then
					p.skinsFound += 1
				end
			end
			if self:has(e.id, s.id) then
				p.bySkin[s.id] += 1
			end
		end
	end
	return p
end

function Index:discover(id, skin)
	skin = skin or "Normal"
	local b = bit(skin)
	assert(self.byId[id], "unbekannter Brainrot: " .. tostring(id))
	assert(b, "unbekannter Skin: " .. tostring(skin))
	local res = { isNew = not self:has(id), isNewSkin = not self:has(id, skin), milestones = {} }
	self.mask[id] = bit32.bor(self.mask[id] or 0, b)
	if res.isNewSkin then
		local p = self:progress()
		for _, ms in Index.MILESTONES do
			if not self.reached[ms.id] and ms.test(p) then
				self.reached[ms.id] = true
				table.insert(res.milestones, ms)
			end
		end
	end
	return res
end

function Index:serialize()
	local d = {}
	for id, m in self.mask do
		if m ~= 0 then
			d[id] = m
		end
	end
	return { v = 1, d = d }
end

function Index.deserialize(catalog, saved)
	if type(saved) ~= "table" or saved.v ~= 1 or type(saved.d) ~= "table" then
		return Index.new(catalog) -- leer oder unbekanntes Format: frisch anfangen
	end
	local clean = {}
	for id, m in saved.d do
		if type(id) == "string" and type(m) == "number" and m >= 0 and m % 1 == 0 then
			clean[id] = m
		end
	end
	return Index.new(catalog, clean)
end

---------------------------------------------------------------------------------------------------
-- Oberflaeche

local BG = Color3.fromRGB(28, 24, 40)
local CARD = Color3.fromRGB(45, 40, 62)
local CARD_LOCKED = Color3.fromRGB(34, 31, 46)
local TEXT = Color3.fromRGB(255, 255, 255)
local DIM = Color3.fromRGB(120, 115, 140)

local function new(cls, props, parent)
	local o = Instance.new(cls)
	for k, v in props do
		o[k] = v
	end
	o.Parent = parent
	return o
end

local function round(parent, r)
	return new("UICorner", { CornerRadius = UDim.new(0, r) }, parent)
end

local function text(parent, props)
	props.BackgroundTransparency = 1
	props.Font = props.Font or Enum.Font.FredokaOne
	props.TextColor3 = props.TextColor3 or TEXT
	return new("TextLabel", props, parent)
end

local function bar(parent, name, color, order)
	local row = new("Frame", { Name = name, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 22), LayoutOrder = order }, parent)
	text(row, { Name = "Label", Size = UDim2.new(0.34, 0, 1, 0), TextXAlignment = Enum.TextXAlignment.Left, TextSize = 16, Text = name, TextColor3 = color })
	local track = new("Frame", { Name = "Track", BackgroundColor3 = CARD_LOCKED, Position = UDim2.new(0.35, 0, 0.25, 0), Size = UDim2.new(0.45, 0, 0.5, 0) }, row)
	round(track, 6)
	local fill = new("Frame", { Name = "Fill", BackgroundColor3 = color, Size = UDim2.new(0, 0, 1, 0) }, track)
	round(fill, 6)
	text(row, { Name = "Count", Position = UDim2.new(0.82, 0, 0, 0), Size = UDim2.new(0.18, 0, 1, 0), TextXAlignment = Enum.TextXAlignment.Right, TextSize = 16, Text = "" })
	return row
end

function Index.buildGui(idx, parent)
	local gui = new("ScreenGui", { Name = "IndexGui", ResetOnSpawn = false, Enabled = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, nil)
	local win = new("Frame", {
		Name = "Window", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0.7, 0, 0.8, 0), BackgroundColor3 = BG,
	}, gui)
	round(win, 16)
	new("UISizeConstraint", { MaxSize = Vector2.new(900, 640), MinSize = Vector2.new(320, 360) }, win)
	new("UIPadding", { PaddingTop = UDim.new(0, 14), PaddingBottom = UDim.new(0, 14), PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 16) }, win)

	text(win, { Name = "Title", Size = UDim2.new(1, -40, 0, 34), TextSize = 30, TextXAlignment = Enum.TextXAlignment.Left, Text = "Index" })
	local close = new("TextButton", {
		Name = "Close", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.new(0, 34, 0, 34),
		BackgroundColor3 = Color3.fromRGB(220, 70, 80), Text = "X", TextColor3 = TEXT, Font = Enum.Font.FredokaOne, TextSize = 20,
	}, win)
	round(close, 10)

	-- Fortschritt: gesamt + je Seltenheit + Skins
	local head = new("Frame", { Name = "Progress", BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, 40), Size = UDim2.new(0.42, 0, 1, -40) }, win)
	new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4) }, head)
	bar(head, "Gesamt", TEXT, 0)
	for i, r in RARITIES do
		bar(head, r.label, r.color, i)
	end
	bar(head, "Skins", SKINS[2].color, #RARITIES + 1)

	-- Karten
	local list = new("ScrollingFrame", {
		Name = "Cards", BackgroundTransparency = 1, Position = UDim2.new(0.44, 0, 0, 40), Size = UDim2.new(0.56, 0, 1, -40),
		CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 6,
	}, win)
	new("UIGridLayout", { CellSize = UDim2.new(0, 116, 0, 92), CellPadding = UDim2.new(0, 8, 0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, list)
	for i, e in idx.catalog do
		local r = RARITY_BY_ID[e.rarity]
		local card = new("Frame", { Name = "Card_" .. e.id, BackgroundColor3 = CARD_LOCKED, LayoutOrder = i }, list)
		round(card, 10)
		new("UIStroke", { Name = "Border", Color = r.color, Thickness = 2 }, card)
		text(card, { Name = "Title", Position = UDim2.new(0, 6, 0, 6), Size = UDim2.new(1, -12, 0, 44), TextWrapped = true, TextSize = 15, Text = "???" })
		text(card, { Name = "Rarity", Position = UDim2.new(0, 6, 0, 48), Size = UDim2.new(1, -12, 0, 16), TextSize = 12, Text = r.label, TextColor3 = r.color })
		local dots = new("Frame", { Name = "Skins", BackgroundTransparency = 1, Position = UDim2.new(0, 6, 1, -20), Size = UDim2.new(1, -12, 0, 14) }, card)
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, dots)
		for j, s in SKINS do
			local d = new("Frame", { Name = s.id, BackgroundColor3 = CARD, Size = UDim2.new(0, 12, 0, 12), LayoutOrder = j }, dots)
			round(d, 6)
		end
	end

	Index.updateGui(gui, idx)
	gui.Parent = parent
	return gui
end

function Index.updateGui(gui, idx)
	local win = gui.Window
	local p = idx:progress()
	local function setBar(name, found, total)
		local row = win.Progress[name]
		local f = total > 0 and found / total or 0
		row.Track.Fill.Size = UDim2.new(f, 0, 1, 0)
		row.Count.Text = found .. "/" .. total
	end
	setBar("Gesamt", p.found, p.total)
	for _, r in RARITIES do
		setBar(r.label, p.byRarity[r.id].found, p.byRarity[r.id].total)
	end
	setBar("Skins", p.skinsFound, p.skinsTotal)
	win.Title.Text = string.format("Index  %d/%d  (%d %%)", p.found, p.total, p.total > 0 and math.floor(100 * p.found / p.total) or 0)

	for _, e in idx.catalog do
		local card = win.Cards["Card_" .. e.id]
		local known = idx:has(e.id)
		card.BackgroundColor3 = known and CARD or CARD_LOCKED
		card.Title.Text = known and e.name or "???"
		card.Title.TextColor3 = known and TEXT or DIM
		for _, s in SKINS do
			card.Skins[s.id].BackgroundColor3 = idx:has(e.id, s.id) and s.color or CARD
		end
	end
end

return Index
