-- Probe fuer S143_schluepfen.lua (Trockenlauf; ENTWURF = das Modul Hatch)
local Hatch = ENTWURF
local fails = {}
local function check(ok, msg) if not ok then table.insert(fails, msg) end end
local FPS = 60

-- 1. Zeitleiste je Seltenheit: Schuebe, Dauer, Stetigkeit Bild fuer Bild
local rows = {}
local prevDur = 0
for r = 1, 6 do
	local tl = Hatch.timeline(r)
	check(tl.duration >= prevDur, "Dauer faellt bei Seltenheit " .. r)
	prevDur = tl.duration
	local last, maxStep, maxRot, maxScale, prevCr = tl.pose(0), 0, 0, 0, 0
	for i = 1, math.ceil(tl.duration * FPS) do
		local t = i / FPS
		local s = tl.pose(t)
		if s.eggVisible and last.eggVisible then
			maxStep = math.max(maxStep, math.abs(s.rotZ - last.rotZ), math.abs(s.rotX - last.rotX))
			check(math.abs(s.lift - last.lift) < 0.05, string.format("r%d: Hopser springt bei %.2f", r, t))
		end
		if s.scale > 0 and last.scale > 0 then
			check(math.abs(s.scale - last.scale) < 0.12, string.format("r%d: Wachsen springt bei %.2f", r, t))
		end
		check(s.cracks >= prevCr, string.format("r%d: Risse nehmen ab bei %.2f", r, t))
		prevCr = s.cracks
		maxRot = math.max(maxRot, math.abs(s.rotZ))
		maxScale = math.max(maxScale, s.scale)
		last = s
	end
	local fin = tl.pose(tl.duration)
	check(fin.scale == 1 and fin.banner == 1 and not fin.eggVisible and fin.flash == 0, "r" .. r .. ": Endbild")
	check(fin.cracks == tl.bursts, "r" .. r .. ": Risse am Ende " .. fin.cracks)
	check(maxStep < math.rad(10), string.format("r%d: Wackeln springt %.1f Grad pro Bild", r, math.deg(maxStep)))
	check(maxRot <= math.rad(20) + 1e-9, "r" .. r .. ": Wackeln zu stark")
	check(maxScale < 1.12, "r" .. r .. ": Ueberschwingen " .. maxScale)
	table.insert(rows, string.format("  Seltenheit %d: %d Schuebe, Aufplatzen %.2f s, Ende %.2f s, Wackeln max %.1f Grad (%.1f Grad/Bild), Ueberschwingen %.2f",
		r, tl.bursts, tl.pop, tl.duration, math.deg(maxRot), math.deg(maxStep), maxScale))
end

-- 2. Szene mit Instanzen: Ei (Pivot Unterkante) + Brainrot (Pivot in der Mitte, 4 hoch)
local function makeEggModel()
	local m = Instance.new("Model")
	m.Name = "Egg_Test"
	local body = Instance.new("Part")
	body.Name = "EggBody"
	body.Size = Vector3.new(2, 2.7, 2)
	body.CFrame = CFrame.new(0, 1.39, 0)
	body.Color = Color3.fromRGB(245, 235, 210)
	body.Parent = m
	m.PrimaryPart = body
	m.WorldPivot = CFrame.new()
	return m
end
local function makeBrainrot()
	local m = Instance.new("Model")
	m.Name = "Brainrot_Test"
	for i, spec in { { "Body", 1.5, 3 }, { "Head", 3.4, 1.2 } } do
		local p = Instance.new("Part")
		p.Name = spec[1]
		p.Size = Vector3.new(2, spec[3], 2)
		p.CFrame = CFrame.new(50, 20 + spec[2], 50) -- irgendwo in der Welt
		p.Parent = m
	end
	m.WorldPivot = CFrame.new(50, 22, 50) -- Pivot 2 ueber der Unterkante (Unterkante y 20)
	return m
end

local base = CFrame.new(10, 5, -4) * CFrame.Angles(0, math.rad(30), 0)
for _, case in {
	{ rarity = "Gewoehnlich", order = 1, skin = "Normal" },
	{ rarity = "Mythisch", order = 6, skin = "Gold", isNew = true },
} do
	local egg, rot = makeEggModel(), makeBrainrot()
	local counts, order = {}, {}
	local h = Hatch.new(egg, rot, {
		name = "Test", rarity = case.rarity, rarityOrder = case.order, rarityColor = Color3.fromRGB(255, 60, 110),
		skin = case.skin, isNew = case.isNew, skinName = "Gold", skinColor = Color3.fromRGB(255, 200, 50), skinChance = "1 zu 23",
	}, {
		parent = D, cframe = base,
		sounds = { crack = "rbxassetid://1", pop = "rbxassetid://2" },
		onEvent = function(ev) counts[ev.kind] = (counts[ev.kind] or 0) + 1 table.insert(order, ev.at) end,
	})
	local tag = case.rarity .. ": "
	check(egg.Parent == nil and egg.WorldPivot.Position.Y == 0, tag .. "Original-Ei angefasst")

	-- Bild fuer Bild; Risse sichtbar == Knack-Ereignisse bisher
	local crackMismatch = 0
	for i = 0, math.ceil(h.duration * FPS) do
		local t = math.min(i / FPS, h.duration)
		local s = h:apply(t)
		if s.eggVisible then
			local shown = 0
			for k, segs in h.cracks do
				if segs[1].Transparency == 0 then shown += 1 end
			end
			if shown ~= (counts.crack or 0) then crackMismatch += 1 end
		end
	end
	check(crackMismatch == 0, tag .. "Risse passen nicht zu Knack-Ereignissen (" .. crackMismatch .. " Bilder)")
	check(counts.crack == h.tl.bursts and counts.pop == 1 and counts.banner == 1, tag .. "Ereignisse " ..
		tostring(counts.crack) .. "/" .. tostring(counts.pop) .. "/" .. tostring(counts.banner))
	for i = 2, #order do check(order[i] >= order[i - 1], tag .. "Ereignisse ausser Reihe") end

	-- Endbild: Ergebnis steht in voller Groesse auf dem Boden, Ei und Scherben weg, Schild sichtbar
	local bbCF, bbSize = h.result:GetBoundingBox()
	local bottom = bbCF.Position.Y - bbSize.Y / 2
	check(math.abs(bottom - 5) < 1e-6, tag .. "Brainrot-Unterkante " .. bottom)
	check(math.abs(bbSize.Y - 4) < 1e-6, tag .. "Brainrot-Hoehe " .. bbSize.Y)
	check(math.abs(h.result:GetScale() - 1) < 1e-9, tag .. "Skalierung am Ende")
	for _, e in h.eggParts do check(e.part.Transparency == 1, tag .. "Ei noch sichtbar") end
	for _, sh in h.shards do check(sh.part.Transparency == 1, tag .. "Scherbe noch sichtbar") end
	for _, l in h.labels do check(l.TextTransparency == 0, tag .. "Schild nicht sichtbar") end
	check(#h.labels == (case.skin == "Normal" and 2 or 3) + (case.isNew and 1 or 0), tag .. "Schildzeilen " .. #h.labels)
	if h.confetti then check(rawget(h.confetti, "_emitted") == 40 + 20 * (case.order - 4), tag .. "Konfetti") end
	check((h.confetti ~= nil) == (case.order >= 4), tag .. "Konfetti ab Episch")

	-- idempotent (nach dem Durchlauf, sonst zaehlen die Ereignisse doppelt)
	h:apply(0.7)
	local p1 = h.egg:GetPivot().Position
	h:apply(0.7)
	check((h.egg:GetPivot().Position - p1).Magnitude < 1e-9, tag .. "apply nicht idempotent")

	-- Vorspulen: von 0 direkt ans Ende feuert jedes Ereignis genau einmal
	local egg2, rot2 = makeEggModel(), makeBrainrot()
	local n2 = 0
	local h2 = Hatch.new(egg2, rot2, { name = "x", rarity = case.rarity, rarityOrder = case.order,
		rarityColor = Color3.fromRGB(1, 2, 3) }, { parent = D, cframe = base, onEvent = function() n2 += 1 end })
	h2:apply(h2.duration)
	h2:apply(h2.duration)
	check(n2 == #h2.tl.events, tag .. "Vorspulen: " .. n2 .. " Ereignisse statt " .. #h2.tl.events)

	local nParts = 0
	for _, d in h.stage:GetDescendants() do if d:IsA("BasePart") then nParts += 1 end end
	table.insert(rows, string.format("  Szene %s: %d Teile, %d Risse, Knack %d, Aufplatzen %d, Schild %d Zeilen%s",
		case.rarity, nParts, h.tl.bursts, counts.crack, counts.pop, #h.labels, h.confetti and ", Konfetti" or ""))
	h:destroy()
	h2:destroy()
	check(h.stage.Parent == nil, tag .. "Buehne nicht aufgeraeumt")
end

print("Schluepfen:")
print(table.concat(rows, "\n"))
print(#fails == 0 and "PROBE OK" or ("PROBE FEHLER:\n  " .. table.concat(fails, "\n  ")))
