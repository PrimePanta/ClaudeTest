-- Bericht nach dem Trockenlauf: Teilezahl unter D, Lage (Boden = y 0), Sway-Liste, Namen
local parts, names, lo, hi = 0, {}, math.huge, -math.huge
for _, p in D:GetDescendants() do
	if p:IsA("BasePart") then
		parts += 1
		names[p.Name] = (names[p.Name] or 0) + 1
		local c, s = p.CFrame, p.Size
		local ey = math.abs(c.R.Y) * s.X / 2 + math.abs(c.U.Y) * s.Y / 2 + math.abs(c.B.Y) * s.Z / 2
		lo = math.min(lo, c.Position.Y - ey)
		hi = math.max(hi, c.Position.Y + ey)
	end
end
if parts > 0 then
	print("Teile", parts, "Lage", string.format("%.2f..%.2f", lo, hi))
	local ks = {}
	for k, n in names do table.insert(ks, k .. " " .. n) end
	table.sort(ks)
	print(table.concat(ks, ", "))
end
local calls = TROCKEN_SWAY
if #calls > 0 then
	local sw = calls[1][2]
	print("swayGroup-Aufrufe", #calls, "Sway-Teile", #sw, "Nabe", calls[1][1].Name)
	for i, s in sw do
		if i == 1 or i >= #sw - 3 then
			print(string.format("  %-24s amp %.3f phase %.3f slope %.3f", s.part.Name, s.amp, s.phase, s.slope))
		end
	end
end
