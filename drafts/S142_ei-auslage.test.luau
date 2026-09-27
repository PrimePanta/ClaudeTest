-- Probe fuer S142_ei-auslage.lua (laeuft im Trockenlauf nach dem Entwurf; ENTWURF = Rueckgabewert)
local E = ENTWURF
local fails = {}
local function check(ok, msg) if not ok then table.insert(fails, msg) end end

-- 1. Chancen je Ei ergeben 100, Seltenheiten existieren
for _, def in E.EGGS do
	local sum = 0
	for _, o in def.odds do
		sum += o[2]
		check(E.RARITY[o[1]] ~= nil, def.id .. ": unbekannte Seltenheit " .. tostring(o[1]))
	end
	check(math.abs(sum - 100) < 1e-6, def.id .. ": Chancen ergeben " .. sum)
end

-- 2. Schale: jeder Punkt liegt auf dem aeusseren der beiden Koerper, Unterkante bei 0
local A, B, BR, BOFF = 1.0, 1.35, 1.04, 0.35
local YC = BOFF + BR
local minY, maxY = math.huge, -math.huge
for i = 0, 40 do
	for j = 0, 24 do
		local phi = -math.pi / 2 + math.pi * i / 40
		local pos = E.shell(2 * math.pi * j / 24, phi)
		local q = pos - Vector3.new(0, YC, 0)
		local e = q.X * q.X / (A * A) + q.Y * q.Y / (B * B) + q.Z * q.Z / (A * A) -- 1 = auf Ellipsoid
		local s = (pos - Vector3.new(0, BR, 0)).Magnitude / BR -- 1 = auf Kugel
		check(math.abs(math.max(e, s * s) - 1) < 1e-6 or math.abs(math.min(e, s * s) - 1) < 1e-6, "Schale daneben bei phi " .. phi)
		check(e >= 1 - 1e-6 and s >= 1 - 1e-6, "Punkt im Innern bei phi " .. phi)
		minY, maxY = math.min(minY, pos.Y), math.max(maxY, pos.Y)
	end
end
check(math.abs(minY) < 1e-6, "Unterkante " .. minY)

-- 3. Auslage: ein Stand je Ei, Ei sitzt im Nest, Schild mit Chancen
local stands = E.shop:GetChildren()
check(#stands == #E.EGGS, "Staende " .. #stands)
local lines = {}
for _, st in stands do
	local egg, base, sign
	for _, c in st:GetChildren() do
		if c.ClassName == "Model" then egg = c end
		if c.Name == "EggStandBase" then base = c end
		if c.Name == "EggSign" then sign = c end
	end
	local id = egg:GetAttribute("EggId")
	local n, spots = 0, 0
	for _, d in egg:GetDescendants() do
		if d:IsA("BasePart") then n += 1 end
		if d.Name ~= "EggBody" and d.Name ~= "EggBelly" and d:IsA("BasePart") then spots += 1 end
	end
	local top = base.Position.Y + base.Size.X / 2
	local bottom = egg.WorldPivot.Position.Y
	check(bottom > top and bottom - top < 0.2, id .. ": Ei schwebt/sinkt (" .. bottom - top .. ")")
	local labels = 0
	for _, d in sign:GetDescendants() do if d.ClassName == "TextLabel" then labels += 1 end end
	local light = egg.PrimaryPart:FindFirstChildWhichIsA("Light") and "Licht" or "-"
	local fx = egg.PrimaryPart:FindFirstChild("EggSparkle") and "Funkeln" or "-"
	table.insert(lines, string.format("  %-8s %-13s Sockel %.1f  Ei-Teile %2d (Muster %2d)  Schild %d Zeilen  %s %s  x %.1f",
		id, egg:GetAttribute("Rarity"), top, n, spots, labels, light, fx, egg.WorldPivot.Position.X))
end
print("Auslage:")
print(table.concat(lines, "\n"))
print("Preise:", E.fmtPrice(100), E.fmtPrice(9000), E.fmtPrice(250000))
check(E.fmtPrice(250000) == "$ 250.000", "fmtPrice " .. E.fmtPrice(250000))
check(E.fmtPrice(100) == "$ 100", "fmtPrice " .. E.fmtPrice(100))

print(#fails == 0 and "PROBE OK" or ("PROBE FEHLER:\n  " .. table.concat(fails, "\n  ")))
