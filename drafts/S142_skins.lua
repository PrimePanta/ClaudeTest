--[[ S142-ENTWURF: Skins fuer Brainrots (ModuleScript "Skins", z. B. in ReplicatedStorage)

UNGEPRUEFT IN STUDIO - geschrieben ohne den Brainrot-Quelltext. Trockenlauf: tools/trockenlauf/run.sh.

Idee: Ein Skin ist eine seltene Variante eines Brainrots (Gold, Diamant, Lava, Regenbogen, Galaxie).
Er faerbt JEDES Modell um, ohne dessen Aufbau zu kennen: Die Helligkeit jedes Teils bleibt erhalten,
damit Form und Schattierung lesbar bleiben; nur Farbe/Material wechseln. Gesichter bleiben unberuehrt.

  Skins.roll(rng)          -> Skin-Id beim Schluepfen ("Normal" in den meisten Faellen)
  Skins.apply(model, id)   -> faerbt um; "Normal" stellt den Originalzustand exakt wieder her.
                              Beliebig oft umschaltbar (Original liegt in Attributen am Teil).
  Skins.get(id)            -> Daten (name, mult, uiColor, ...) fuer Namensschild, Shop, Index
  Skins.multiplier(id)     -> Einkommens-Faktor

Unberuehrt bleiben: Teile mit Attribut SkinKeep = true und Teile, deren Name nach Gesicht klingt
(Eye/Auge/Pupil/Mouth/Mund/Teeth/Zahn/Face/Gesicht). Decals (oft Gesichter) bleiben immer.
MeshParts: TextureID wird fuer den Skin geleert und bei "Normal" zurueckgesetzt; eine SurfaceAppearance
wird in einen Ordner "SkinStash" am Teil geparkt (dort wirkt sie nicht) und bei "Normal" zurueckgeholt.

ANPASSEN: CHANCE, weight und mult sind VORSCHLAEGE und muessen zur Wirtschaft des Spiels passen.
Serverseitig wuerfeln (roll) und die Id speichern; apply kann Server oder Client ausfuehren.
]]

local Skins = {}

-- Chance, dass ein geschluepfter Brainrot ueberhaupt einen Skin bekommt
Skins.CHANCE = 0.08

Skins.LIST = {
	{ id = "Normal", name = "Normal", weight = 0, mult = 1, uiColor = Color3.fromRGB(200, 200, 200) },
	{ id = "Gold", name = "Gold", weight = 55, mult = 2, uiColor = Color3.fromRGB(255, 200, 50) },
	{ id = "Diamant", name = "Diamant", weight = 25, mult = 3, uiColor = Color3.fromRGB(140, 225, 255) },
	{ id = "Lava", name = "Lava", weight = 12, mult = 4, uiColor = Color3.fromRGB(255, 110, 30) },
	{ id = "Regenbogen", name = "Regenbogen", weight = 6, mult = 6, uiColor = Color3.fromRGB(255, 90, 200) },
	{ id = "Galaxie", name = "Galaxie", weight = 2, mult = 10, uiColor = Color3.fromRGB(150, 90, 255) },
}

local BY_ID = {}
for _, s in Skins.LIST do
	BY_ID[s.id] = s
end

function Skins.get(id)
	return BY_ID[id] or BY_ID.Normal
end

function Skins.multiplier(id)
	return Skins.get(id).mult
end

-- Wahrscheinlichkeit eines Skins beim Schluepfen (fuer Anzeige "1 zu N" im Index)
function Skins.chanceOf(id)
	local total = 0
	for _, s in Skins.LIST do
		total += s.weight
	end
	if id == "Normal" then
		return 1 - Skins.CHANCE
	end
	return Skins.CHANCE * Skins.get(id).weight / total
end

function Skins.roll(rng)
	rng = rng or Random.new()
	if rng:NextNumber() >= Skins.CHANCE then
		return "Normal"
	end
	local total = 0
	for _, s in Skins.LIST do
		total += s.weight
	end
	local x = rng:NextNumber() * total
	for _, s in Skins.LIST do
		x -= s.weight
		if s.weight > 0 and x < 0 then
			return s.id
		end
	end
	return Skins.LIST[#Skins.LIST].id
end

local FACE_WORDS = { "eye", "auge", "pupil", "mouth", "mund", "teeth", "zahn", "face", "gesicht" }

local function keep(p)
	if p:GetAttribute("SkinKeep") then
		return true
	end
	local n = string.lower(p.Name)
	for _, w in FACE_WORDS do
		if string.find(n, w, 1, true) then
			return true
		end
	end
	return false
end

local function lum(c)
	return 0.299 * c.R + 0.587 * c.G + 0.114 * c.B
end

-- Original einmal sichern (beim ersten Skin), danach nie ueberschreiben
local function saveBase(p)
	if p:GetAttribute("SkinBaseColor") ~= nil then
		return
	end
	p:SetAttribute("SkinBaseColor", p.Color)
	p:SetAttribute("SkinBaseMaterial", p.Material.Name)
	p:SetAttribute("SkinBaseTransparency", p.Transparency)
	p:SetAttribute("SkinBaseReflectance", p.Reflectance)
	if p:IsA("MeshPart") then
		p:SetAttribute("SkinBaseTexture", p.TextureID)
	end
end

local function restore(p)
	local c = p:GetAttribute("SkinBaseColor")
	if c == nil then
		return
	end
	p.Color = c
	p.Material = Enum.Material[p:GetAttribute("SkinBaseMaterial")]
	p.Transparency = p:GetAttribute("SkinBaseTransparency")
	p.Reflectance = p:GetAttribute("SkinBaseReflectance")
	if p:IsA("MeshPart") then
		p.TextureID = p:GetAttribute("SkinBaseTexture") or ""
		local stash = p:FindFirstChild("SkinStash")
		if stash then
			for _, sa in stash:GetChildren() do
				sa.Parent = p
			end
			stash:Destroy()
		end
	end
end

-- MeshPart-Texturen aus dem Weg, damit die Skin-Farbe sichtbar wird
local function clearTexture(p)
	if not p:IsA("MeshPart") then
		return
	end
	p.TextureID = ""
	local sa = p:FindFirstChildWhichIsA("SurfaceAppearance")
	if sa then
		local stash = p:FindFirstChild("SkinStash")
		if not stash then
			stash = Instance.new("Folder")
			stash.Name = "SkinStash"
			stash.Parent = p
		end
		sa.Parent = stash
	end
end

-- Umfaerben je Skin: base = Originalfarbe, l = Helligkeit 0..1, h = Hoehe im Modell 0..1
local PAINT = {
	Gold = function(p, base, l)
		p.Color = Color3.fromRGB(150, 95, 15):Lerp(Color3.fromRGB(255, 225, 110), l)
		p.Material = Enum.Material.Metal
		p.Reflectance = 0.25
	end,
	Diamant = function(p, base, l)
		p.Color = Color3.fromRGB(70, 170, 230):Lerp(Color3.fromRGB(235, 250, 255), l)
		p.Material = Enum.Material.Glass
		p.Transparency = math.max(p:GetAttribute("SkinBaseTransparency"), 0.2)
		p.Reflectance = 0.3
	end,
	Lava = function(p, base, l)
		if l < 0.5 then
			p.Color = Color3.fromRGB(30, 22, 22):Lerp(Color3.fromRGB(80, 55, 50), l * 2)
			p.Material = Enum.Material.Basalt
		else
			p.Color = Color3.fromRGB(255, 80, 10):Lerp(Color3.fromRGB(255, 200, 60), (l - 0.5) * 2)
			p.Material = Enum.Material.Neon
		end
	end,
	Regenbogen = function(p, base, l, h)
		p.Color = Color3.fromHSV(h * 0.85, 0.75, 0.6 + 0.4 * l)
		p.Material = Enum.Material.SmoothPlastic
	end,
	Galaxie = function(p, base, l, h)
		p.Color = Color3.fromRGB(25, 10, 60):Lerp(Color3.fromRGB(90, 60, 200), l * 0.7 + h * 0.3)
		p.Material = Enum.Material.SmoothPlastic
		p.Reflectance = 0.1
	end,
}

-- Effekte am groessten Teil: Licht (optional) + Funkeln, Namen SkinFxLight / SkinFxSparkle
local FX = {
	Gold = { light = Color3.fromRGB(255, 210, 90), sparkle = Color3.fromRGB(255, 235, 150), rate = 3 },
	Diamant = { sparkle = Color3.fromRGB(220, 250, 255), rate = 5 },
	Lava = { light = Color3.fromRGB(255, 110, 30), sparkle = Color3.fromRGB(255, 140, 40), rate = 4, rise = true },
	Regenbogen = { sparkle = Color3.fromRGB(255, 255, 255), rate = 4, rainbow = true },
	Galaxie = { light = Color3.fromRGB(150, 90, 255), sparkle = Color3.fromRGB(255, 255, 255), rate = 8 },
}

local function addFx(host, fx)
	-- Licht und Emitter haengen direkt am Teil (nur dort wirken sie); removeFx findet sie am Namen
	if fx.light then
		local l = Instance.new("PointLight")
		l.Name = "SkinFxLight"
		l.Color = fx.light
		l.Brightness = 0.8
		l.Range = 8
		l.Shadows = false
		l.Parent = host
	end
	local e = Instance.new("ParticleEmitter")
	e.Name = "SkinFxSparkle"
	e.LightEmission = 1
	e.Rate = fx.rate
	e.Lifetime = NumberRange.new(0.8, 1.6)
	e.Speed = fx.rise and NumberRange.new(1, 2) or NumberRange.new(0.2, 0.6)
	e.SpreadAngle = fx.rise and Vector2.new(20, 20) or Vector2.new(180, 180)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 0) })
	if fx.rainbow then
		local keys = {}
		for i = 0, 6 do
			table.insert(keys, ColorSequenceKeypoint.new(i / 6, Color3.fromHSV(i / 6, 0.8, 1)))
		end
		e.Color = ColorSequence.new(keys)
	else
		e.Color = ColorSequence.new(fx.sparkle)
	end
	e.Parent = host
end

local function removeFx(parts)
	for _, p in parts do
		for _, c in p:GetChildren() do
			if c.Name == "SkinFxLight" or c.Name == "SkinFxSparkle" then
				c:Destroy()
			end
		end
	end
end

function Skins.apply(model, id)
	id = BY_ID[id] and id or "Normal"
	local parts = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and not keep(d) then
			table.insert(parts, d)
		end
	end
	removeFx(parts)

	-- immer vom Original aus faerben, damit Skins nicht aufeinander aufbauen
	for _, p in parts do
		restore(p)
	end
	model:SetAttribute("Skin", id)
	if id == "Normal" then
		return model
	end

	local minY, maxY, biggest, bigVol = math.huge, -math.huge, nil, -1
	for _, p in parts do
		local y = p.Position.Y
		minY, maxY = math.min(minY, y), math.max(maxY, y)
		local vol = p.Size.X * p.Size.Y * p.Size.Z
		if vol > bigVol then
			biggest, bigVol = p, vol
		end
	end
	local span = math.max(maxY - minY, 1e-3)

	for _, p in parts do
		saveBase(p)
		local base = p:GetAttribute("SkinBaseColor")
		clearTexture(p)
		PAINT[id](p, base, lum(base), (p.Position.Y - minY) / span)
	end
	if biggest and FX[id] then
		addFx(biggest, FX[id])
	end
	return model
end

return Skins
