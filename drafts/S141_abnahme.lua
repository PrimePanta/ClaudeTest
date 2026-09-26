--[[ S141-Abnahme fuer das Kind mit dem Ballon (per execute_luau, Edit-Modus).
Gibt EINEN String zurueck (execute_luau liefert nur den ersten Rueckgabewert).
Erwartet: 34 Teile, Lage 0.00..~7.7, Beruehrung nur Schnur x Knoten / Schnur x Hand
und innerhalb des Kindes (Kopf/Haar, Rumpf/Streifen usw.). Alles mit Nicht-Kind-Teilen
ist ein Fund (vor allem FairBalloons des Verkaeufers!).
]]
local CollectionService = game:GetService("CollectionService")
local Earth = workspace:FindFirstChild("Earth") or workspace:FindFirstChild("Earth", true)
local GROUND_Y = 5 -- Rahmen F: P.Y = 5

local mine, set = {}, {}
for _, p in Earth.Decor:GetChildren() do
	if p:IsA("BasePart") and p.Name:sub(1, 9) == "FairChild" then
		table.insert(mine, p)
		set[p] = true
	end
end

local lo, hi = math.huge, -math.huge
for _, p in mine do
	local y = p.Position.Y - GROUND_Y
	local h = p.Size.Y / 2 -- grob; fuer schraege Teile reicht das hier
	lo = math.min(lo, y - h)
	hi = math.max(hi, y + h)
end

local fair = 0
for _, folder in { Earth.Structure, Earth.Decor } do
	for _, c in folder:GetChildren() do
		if c.Name:sub(1, 4) == "Fair" then
			fair += 1
		end
	end
end

local op = OverlapParams.new()
op.FilterType = Enum.RaycastFilterType.Exclude
op.FilterDescendantsInstances = {}
local hits, seen = {}, {}
for _, p in mine do
	for _, q in workspace:GetPartsInPart(p, op) do
		if not set[q] then
			local key = p.Name .. " x " .. q:GetFullName()
			if not seen[key] then
				seen[key] = true
				table.insert(hits, key)
			end
		end
	end
end

return table.concat({
	"Kind-Teile " .. #mine .. " (erwartet 34)",
	"Fair " .. fair .. " (erwartet 986)",
	"SwayHub " .. #CollectionService:GetTagged("SwayHub") .. " (erwartet 29)",
	"SwayPart " .. #CollectionService:GetTagged("SwayPart") .. " (erwartet 633)",
	string.format("Lage %.2f..%.2f", lo, hi),
	"Beruehrt fremd: " .. (#hits == 0 and "keine" or table.concat(hits, "; ")),
}, "\n")
