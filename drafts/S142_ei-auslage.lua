--[[ S142-ENTWURF: Detaillierte Eier fuer den Shop (Ei-Auslage)

UNGEPRUEFT IN STUDIO - geschrieben ohne den Shop-Quelltext. Trockenlauf: tools/trockenlauf/run.sh.

Idee: Jedes Ei sieht nach seiner Seltenheit aus und erzaehlt das schon von weitem.
  - Echte Eiform statt Kugel: Ellipsoid + etwas breiterer Kugelbauch unten (wie ein Huehnerei).
  - Muster je Ei: Tupfen, Fliegenpilz-Punkte, Zickzack-Band, Ringe, Glutrisse, Sterne.
  - Seltenheit auf einen Blick: Sockel waechst mit der Seltenheit, Leuchtring in der Seltenheitsfarbe,
    ab "Selten" ein Licht im Ei, ab "Legendaer" Funkeln.
  - Nest aus Strohhalmen, damit das Ei nicht auf dem Sockel "klebt".
  - Schild vor jedem Sockel: Name, Seltenheit (farbig), Preis und die SCHLUPFCHANCEN.
    Spieler sehen vor dem Kauf, was drin sein kann.

Bausteine:
  makeEgg(def)                 -> Model, Pivot = Mitte der Unterkante, -Z = Vorderseite.
                                  Auch fuer eine ViewportFrame im Shop-GUI nutzbar.
  buildEggShop(parent, baseCF) -> Model "EggShop" mit allen Sockeln in einer Reihe (entlang +X),
                                  Schilder schauen nach -Z (zur Kundschaft).

ANPASSEN:
  EGG_SHOP_CF  - Standort der Auslage (unten).
  EGGS         - Preise, Waehrung und Chancen sind VORSCHLAEGE. Mit den echten Werten des Spiels
                 ersetzen; die Chancen pro Ei muessen 100 ergeben (die Probe prueft das).
  Die Teile nutzen eigene Bauhelfer. Beim Einbau koennen sie gegen block/sphere getauscht werden.
]]

local CURRENCY = "$" -- ANPASSEN: Waehrungszeichen des Spiels

local RARITY = {
	Gewoehnlich = { order = 1, color = Color3.fromRGB(190, 190, 190) },
	Ungewoehnlich = { order = 2, color = Color3.fromRGB(90, 200, 90) },
	Selten = { order = 3, color = Color3.fromRGB(70, 150, 255) },
	Episch = { order = 4, color = Color3.fromRGB(170, 80, 255) },
	Legendaer = { order = 5, color = Color3.fromRGB(255, 190, 40) },
	Mythisch = { order = 6, color = Color3.fromRGB(255, 60, 110) },
}
local RARITY_LABEL = {
	Gewoehnlich = "Gewöhnlich",
	Ungewoehnlich = "Ungewöhnlich",
	Selten = "Selten",
	Episch = "Episch",
	Legendaer = "Legendär",
	Mythisch = "Mythisch",
}

-- Muster: kind = spots (flache Scheiben) | stars (kleine Kugeln) | band (Zickzack) | rings; neon = Material Neon
local EGGS = {
	{
		id = "Wiese", name = "Wiesen-Ei", rarity = "Gewoehnlich", price = 100,
		color = Color3.fromRGB(245, 235, 210), material = Enum.Material.SmoothPlastic,
		pattern = { { kind = "spots", color = Color3.fromRGB(120, 170, 80), count = 11, size = 0.34, seed = 3 } },
		odds = { { "Gewoehnlich", 80 }, { "Ungewoehnlich", 18 }, { "Selten", 2 } },
	},
	{
		id = "Pilz", name = "Pilz-Ei", rarity = "Ungewoehnlich", price = 450,
		color = Color3.fromRGB(205, 40, 40), material = Enum.Material.SmoothPlastic,
		pattern = { { kind = "spots", color = Color3.fromRGB(250, 250, 245), count = 9, size = 0.5, seed = 7, minPhi = -0.1 } },
		odds = { { "Gewoehnlich", 55 }, { "Ungewoehnlich", 35 }, { "Selten", 9 }, { "Episch", 1 } },
	},
	{
		id = "Kristall", name = "Kristall-Ei", rarity = "Selten", price = 2000,
		color = Color3.fromRGB(150, 220, 255), material = Enum.Material.Glass, transparency = 0.15,
		pattern = {
			{ kind = "rings", color = Color3.fromRGB(235, 250, 255), phis = { -0.35, 0.15, 0.6 }, width = 0.1 },
		},
		glow = { color = Color3.fromRGB(150, 220, 255), brightness = 0.8, range = 7 },
		odds = { { "Ungewoehnlich", 50 }, { "Selten", 40 }, { "Episch", 9 }, { "Legendaer", 1 } },
	},
	{
		id = "Lava", name = "Lava-Ei", rarity = "Episch", price = 9000,
		color = Color3.fromRGB(45, 35, 35), material = Enum.Material.Basalt,
		pattern = {
			{ kind = "band", color = Color3.fromRGB(255, 110, 20), neon = true, phi = 0.05, zig = 0.22, teeth = 9, width = 0.09 },
			{ kind = "band", color = Color3.fromRGB(255, 170, 40), neon = true, phi = 0.62, zig = 0.12, teeth = 7, width = 0.06 },
		},
		glow = { color = Color3.fromRGB(255, 120, 30), brightness = 1.2, range = 8 },
		odds = { { "Selten", 55 }, { "Episch", 38 }, { "Legendaer", 6.5 }, { "Mythisch", 0.5 } },
	},
	{
		id = "Gold", name = "Gold-Ei", rarity = "Legendaer", price = 40000,
		color = Color3.fromRGB(240, 185, 50), material = Enum.Material.Foil, reflectance = 0.15,
		pattern = {
			{ kind = "band", color = Color3.fromRGB(255, 240, 170), phi = 0.1, zig = 0.18, teeth = 8, width = 0.12 },
			{ kind = "stars", color = Color3.fromRGB(255, 60, 90), count = 8, size = 0.22, seed = 11, minPhi = 0.02, maxPhi = 0.18 }, -- Steine ragen aus dem Band
		},
		glow = { color = Color3.fromRGB(255, 210, 90), brightness = 1, range = 8 },
		sparkle = true,
		odds = { { "Episch", 60 }, { "Legendaer", 36 }, { "Mythisch", 4 } },
	},
	{
		id = "Galaxie", name = "Galaxie-Ei", rarity = "Mythisch", price = 250000,
		color = Color3.fromRGB(35, 20, 70), material = Enum.Material.SmoothPlastic,
		pattern = {
			{ kind = "stars", color = Color3.fromRGB(255, 255, 255), neon = true, count = 26, size = 0.1, seed = 5 },
			{ kind = "spots", color = Color3.fromRGB(110, 60, 190), count = 7, size = 0.6, seed = 9 },
		},
		glow = { color = Color3.fromRGB(160, 100, 255), brightness = 1.3, range = 9 },
		sparkle = true,
		odds = { { "Legendaer", 75 }, { "Mythisch", 25 } },
	},
}

local EGG_SHOP_CF = CFrame.new(0, 0, 0) -- ANPASSEN: Standort der Auslage (Boden, -Z = Kundschaft)

-- Eiform: Ellipsoid (Halbachsen A, B) + Kugelbauch (Radius BR, BOFF unter der Mitte).
-- Unterkante der Kugel = y 0 im Ei-Rahmen.
local A, B = 1.0, 1.35
local BR, BOFF = 1.04, 0.35
local YC = BOFF + BR -- Mitte des Ellipsoids ueber der Unterkante

-- Punkt und Normale auf der Eischale; theta um die Hochachse (0 = +X, pi/2 = +Z), phi = Breite
local function shell(theta, phi)
	local u = Vector3.new(math.cos(phi) * math.cos(theta), math.sin(phi), math.cos(phi) * math.sin(theta))
	local te = 1 / math.sqrt(u.X * u.X / (A * A) + u.Y * u.Y / (B * B) + u.Z * u.Z / (A * A))
	local ud = u.Y * BOFF
	local ts = -ud + math.sqrt(ud * ud - BOFF * BOFF + BR * BR)
	local p, n
	if ts > te then
		p = u * ts
		n = (p + Vector3.new(0, BOFF, 0)).Unit
	else
		p = u * te
		n = Vector3.new(p.X / (A * A), p.Y / (B * B), p.Z / (A * A)).Unit
	end
	return p + Vector3.new(0, YC, 0), n
end

local function part(parent, name, size, cf, color, material, shape)
	local p = Instance.new("Part")
	p.Name = name
	if shape then
		p.Shape = shape
	end
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CastShadow = false
	p.Parent = parent
	return p
end

-- Teil mit Kugel-Mesh in beliebiger Form (Ellipsoid)
local function ellipsoid(parent, name, size, cf, color, material)
	local p = part(parent, name, size, cf, color, material)
	local m = Instance.new("SpecialMesh")
	m.MeshType = Enum.MeshType.Sphere
	m.Parent = p
	return p
end

-- flache Scheibe auf der Schale (Zylinder-Achse X = Normale)
local function patch(parent, name, rel, pos, normal, d, color, material)
	local cf = rel * CFrame.lookAt(pos + normal * 0.015, pos + normal * 2) * CFrame.Angles(0, math.rad(90), 0)
	return part(parent, name, Vector3.new(0.06, d, d), cf, color, material, Enum.PartType.Cylinder)
end

-- duennes Band von a nach b, auf der Schale anliegend
local function strip(parent, name, rel, a, na, b, nb, w, color, material)
	local n = (na + nb).Unit
	local mid = (a + b) / 2 + n * 0.02
	local cf = rel * CFrame.lookAt(mid, mid + (b - a), n)
	return part(parent, name, Vector3.new(w, 0.05, (b - a).Magnitude + w * 0.6), cf, color, material)
end

-- gleichmaessig verteilte Punkte (goldener Winkel) mit festem Versatz je seed
local function scatter(count, seed, minPhi, maxPhi)
	local out = {}
	local lo, hi = math.sin(minPhi or -0.75), math.sin(maxPhi or 1.05)
	for i = 1, count do
		local s = lo + (hi - lo) * (i - 0.5) / count
		local theta = i * 2.39996 + seed * 0.7
		table.insert(out, { theta, math.asin(s) })
	end
	return out
end

local function makeEgg(def)
	local model = Instance.new("Model")
	model.Name = "Egg_" .. def.id
	local rel = CFrame.new() -- im Ei-Rahmen bauen, am Ende mit PivotTo verschieben

	local mat = def.material or Enum.Material.SmoothPlastic
	local body = ellipsoid(model, "EggBody", Vector3.new(2 * A, 2 * B, 2 * A), rel * CFrame.new(0, YC, 0), def.color, mat)
	body.Transparency = def.transparency or 0
	body.Reflectance = def.reflectance or 0
	local belly = ellipsoid(model, "EggBelly", Vector3.new(2 * BR, 2 * BR, 2 * BR), rel * CFrame.new(0, BR, 0), def.color, mat)
	belly.Transparency = def.transparency or 0
	belly.Reflectance = def.reflectance or 0
	model.PrimaryPart = body

	for _, pat in def.pattern do
		local pmat = pat.neon and Enum.Material.Neon or Enum.Material.SmoothPlastic
		if pat.kind == "spots" or pat.kind == "stars" then
			for i, tp in scatter(pat.count, pat.seed, pat.minPhi, pat.maxPhi) do
				local pos, n = shell(tp[1], tp[2])
				local d = pat.size * (0.75 + 0.5 * ((i * 37) % 10) / 10) -- Groessen leicht gemischt
				if pat.kind == "stars" then
					part(model, "EggStar", Vector3.new(d, d, d), rel * CFrame.new(pos + n * 0.01), pat.color, pmat, Enum.PartType.Ball)
				else
					patch(model, "EggSpot", rel, pos, n, d, pat.color, pmat)
				end
			end
		elseif pat.kind == "band" then
			local steps = pat.teeth * 2
			local prev, prevN
			for i = 0, steps do
				local theta = 2 * math.pi * i / steps
				local phi = pat.phi + (i % 2 == 0 and pat.zig / 2 or -pat.zig / 2)
				local pos, n = shell(theta, phi)
				if prev then
					strip(model, "EggBand", rel, prev, prevN, pos, n, pat.width, pat.color, pmat)
				end
				prev, prevN = pos, n
			end
		elseif pat.kind == "rings" then
			for _, phi in pat.phis do
				local steps = 16
				local prev, prevN
				for i = 0, steps do
					local pos, n = shell(2 * math.pi * i / steps, phi)
					if prev then
						strip(model, "EggRing", rel, prev, prevN, pos, n, pat.width, pat.color, pmat)
					end
					prev, prevN = pos, n
				end
			end
		end
	end

	if def.glow then
		local l = Instance.new("PointLight")
		l.Color = def.glow.color
		l.Brightness = def.glow.brightness
		l.Range = def.glow.range
		l.Shadows = false
		l.Parent = body
	end
	if def.sparkle then
		local e = Instance.new("ParticleEmitter")
		e.Name = "EggSparkle"
		e.Color = ColorSequence.new(RARITY[def.rarity].color)
		e.LightEmission = 1
		e.Rate = 4
		e.Lifetime = NumberRange.new(0.8, 1.6)
		e.Speed = NumberRange.new(0.3, 0.8)
		e.SpreadAngle = Vector2.new(180, 180)
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 0) })
		e.Parent = body
	end

	model.WorldPivot = CFrame.new() -- Pivot = Unterkante, -Z = Vorderseite
	model:SetAttribute("EggId", def.id)
	model:SetAttribute("Rarity", def.rarity)
	model:SetAttribute("Price", def.price)
	return model
end

local function fmtPrice(n)
	local s = tostring(math.floor(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1."):reverse()
	return CURRENCY .. " " .. out:gsub("^%.", "")
end

local function label(parent, text, size, color, bold, order)
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.new(1, 0, 0, size + 8)
	t.Text = text
	t.TextSize = size
	t.TextColor3 = color
	t.Font = bold and Enum.Font.FredokaOne or Enum.Font.Gotham
	t.TextStrokeTransparency = 0.6
	t.LayoutOrder = order
	t.Parent = parent
	return t
end

-- Sockel mit Nest, Leuchtring und Schild; Ei obenauf
local function buildStand(parent, def, cf)
	local r = RARITY[def.rarity]
	local stand = Instance.new("Model")
	stand.Name = "EggStand_" .. def.id
	local h = 0.8 + 0.3 * (r.order - 1) -- seltener = hoeher
	local up = CFrame.Angles(0, 0, math.rad(90)) -- Zylinder-Achse X -> senkrecht

	part(stand, "EggStandBase", Vector3.new(h, 3.2, 3.2), cf * CFrame.new(0, h / 2, 0) * up,
		Color3.fromRGB(95, 65, 45), Enum.Material.Wood, Enum.PartType.Cylinder)
	part(stand, "EggStandRing", Vector3.new(0.14, 3.34, 3.34), cf * CFrame.new(0, h - 0.18, 0) * up,
		r.color, Enum.Material.Neon, Enum.PartType.Cylinder)
	part(stand, "EggStandTop", Vector3.new(0.08, 3.0, 3.0), cf * CFrame.new(0, h + 0.04, 0) * up,
		Color3.fromRGB(235, 225, 200), Enum.Material.Fabric, Enum.PartType.Cylinder)

	-- Nest: 14 Strohhalme, leicht schraeg im Kreis
	for i = 1, 14 do
		local a = 2 * math.pi * i / 14
		local pos = cf * Vector3.new(math.cos(a) * 0.95, h + 0.2, math.sin(a) * 0.95)
		local tangent = Vector3.new(-math.sin(a), 0.35 * ((i % 2) * 2 - 1), math.cos(a))
		part(stand, "EggNestStraw", Vector3.new(0.12, 0.12, 1.0),
			CFrame.lookAt(pos, pos + cf:PointToWorldSpace(tangent) - cf.Position),
			i % 3 == 0 and Color3.fromRGB(200, 165, 90) or Color3.fromRGB(175, 135, 70), Enum.Material.Grass)
	end

	local egg = makeEgg(def)
	egg.Parent = stand
	egg:PivotTo(cf * CFrame.new(0, h + 0.08, 0))

	-- Schild vorne, leicht nach hinten geneigt
	local sign = part(stand, "EggSign", Vector3.new(2.8, 1.9, 0.12),
		cf * CFrame.new(0, 1.05, -2.05) * CFrame.Angles(math.rad(-12), 0, 0),
		Color3.fromRGB(60, 40, 30), Enum.Material.Wood)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	gui.CanvasSize = Vector2.new(280, 190)
	gui.LightInfluence = 0
	gui.Parent = sign
	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.Parent = gui
	label(gui, def.name, 30, Color3.fromRGB(255, 255, 255), true, 1)
	label(gui, RARITY_LABEL[def.rarity], 20, r.color, true, 2)
	label(gui, fmtPrice(def.price), 26, Color3.fromRGB(255, 225, 90), true, 3)
	for i, o in def.odds do
		local pct = o[2] % 1 == 0 and tostring(o[2]) or string.format("%.1f", o[2])
		label(gui, RARITY_LABEL[o[1]] .. "  " .. pct .. " %", 15, RARITY[o[1]].color, false, 3 + i)
	end

	stand.Parent = parent
	return stand
end

local function buildEggShop(parent, baseCF)
	local shop = Instance.new("Model")
	shop.Name = "EggShop"
	table.sort(EGGS, function(a, b) return RARITY[a.rarity].order < RARITY[b.rarity].order end)
	local gap = 4.4
	for i, def in EGGS do
		local x = (i - (#EGGS + 1) / 2) * gap
		buildStand(shop, def, baseCF * CFrame.new(x, 0, 0))
	end
	shop.Parent = parent
	return shop
end

local shop = buildEggShop(D, EGG_SHOP_CF)
return { shop = shop, EGGS = EGGS, RARITY = RARITY, makeEgg = makeEgg, shell = shell, fmtPrice = fmtPrice }
