-- Probe fuer S142_skins.lua (laeuft im Trockenlauf nach dem Entwurf; ENTWURF = das Modul)
local Skins = ENTWURF
local fails = {}
local function check(ok, msg) if not ok then table.insert(fails, msg) end end

-- Ein Beispiel-Brainrot: Koerper, Kopf, Beine, Augen, Mund-Decal, MeshPart mit Textur + SurfaceAppearance
local model = Instance.new("Model")
model.Name = "TestBrainrot"
local function mk(cls, name, y, color, size)
	local p = Instance.new(cls)
	p.Name = name
	p.CFrame = CFrame.new(0, y, 0)
	p.Size = size or Vector3.new(2, 2, 2)
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.Parent = model
	return p
end
local body = mk("Part", "Body", 3, Color3.fromRGB(120, 170, 80), Vector3.new(3, 3, 2))
local head = mk("Part", "Head", 5.5, Color3.fromRGB(240, 220, 190))
local leg = mk("Part", "LegL", 0.8, Color3.fromRGB(40, 40, 40), Vector3.new(0.8, 1.6, 0.8))
local eye = mk("Part", "EyeL", 5.7, Color3.fromRGB(255, 255, 255), Vector3.new(0.4, 0.4, 0.1))
local shoe = mk("MeshPart", "Shoe", 0.2, Color3.fromRGB(200, 50, 50), Vector3.new(1, 0.4, 1.4))
shoe.TextureID = "rbxassetid://123"
local sa = Instance.new("SurfaceAppearance")
sa.Parent = shoe
local mouth = Instance.new("Decal")
mouth.Name = "Mouth"
mouth.Parent = head
local all = { body, head, leg, eye, shoe }
local function snap()
	local t = {}
	for _, p in all do
		t[p] = { p.Color, p.Material, p.Transparency, p.Reflectance, p.TextureID }
	end
	return t
end
local function same(a, b, p)
	for i = 1, 5 do
		if a[p][i] ~= b[p][i] then return false end
	end
	return true
end
local function fxCount()
	local n = 0
	for _, d in model:GetDescendants() do
		if d.Name == "SkinFxLight" or d.Name == "SkinFxSparkle" then n += 1 end
	end
	return n
end
local orig = snap()

-- 1. Jeder Skin: Augen bleiben, Rest aendert sich, hoechstens 1 Licht + 1 Funkeln, Textur weg
local rows = {}
for _, s in Skins.LIST do
	Skins.apply(model, s.id)
	local now = snap()
	check(same(orig, now, eye), s.id .. ": Auge veraendert")
	check(model:GetAttribute("Skin") == s.id, s.id .. ": Attribut Skin")
	if s.id ~= "Normal" then
		check(not same(orig, now, body), s.id .. ": Koerper unveraendert")
		check(shoe.TextureID == "", s.id .. ": Textur nicht geleert")
		check(shoe:FindFirstChildWhichIsA("SurfaceAppearance") == nil, s.id .. ": SurfaceAppearance noch aktiv")
		check(fxCount() >= 1 and fxCount() <= 2, s.id .. ": Effekte " .. fxCount())
	end
	table.insert(rows, string.format("  %-10s Koerper %-16s Kopf %-16s Bein %-16s %-12s Fx %d  x%d  %s",
		s.id, tostring(body.Color), tostring(head.Color), tostring(leg.Color), body.Material.Name, fxCount(), s.mult,
		s.id == "Normal" and "" or string.format("1 zu %d", math.floor(1 / Skins.chanceOf(s.id) + 0.5))))
end

-- 2. Hin und her schalten, dann Normal: exakt das Original, keine Effekte, SurfaceAppearance zurueck
for _, id in { "Gold", "Lava", "Diamant", "Galaxie", "Regenbogen", "Gold", "Normal" } do
	Skins.apply(model, id)
end
local back = snap()
for _, p in all do
	check(same(orig, back, p), p.Name .. ": nach Normal nicht wie vorher")
end
check(fxCount() == 0, "Effekte nach Normal: " .. fxCount())
check(sa.Parent == shoe, "SurfaceAppearance nicht zurueck")
check(shoe:FindFirstChild("SkinStash") == nil, "SkinStash liegt noch da")
check(mouth.Parent == head, "Decal angefasst")

-- 3. Unbekannte Id -> Normal
Skins.apply(model, "Quatsch")
check(model:GetAttribute("Skin") == "Normal", "unbekannte Id")

-- 4. Wuerfeln: Verteilung passt zu CHANCE und weight
local rng = Random.new(42)
local N, got = 200000, {}
for _ = 1, N do
	local id = Skins.roll(rng)
	got[id] = (got[id] or 0) + 1
end
local dist = {}
for _, s in Skins.LIST do
	local want = Skins.chanceOf(s.id)
	local have = (got[s.id] or 0) / N
	check(math.abs(have - want) < 0.004 + want * 0.1, string.format("%s: %.4f statt %.4f", s.id, have, want))
	table.insert(dist, string.format("%s %.2f%%", s.id, have * 100))
end
local sum = 0
for _, s in Skins.LIST do sum += Skins.chanceOf(s.id) end
check(math.abs(sum - 1) < 1e-9, "Chancen ergeben " .. sum)

print("Skins am Beispiel:")
print(table.concat(rows, "\n"))
print("Wuerfeln (" .. N .. "x): " .. table.concat(dist, ", "))
print(#fails == 0 and "PROBE OK" or ("PROBE FEHLER:\n  " .. table.concat(fails, "\n  ")))
