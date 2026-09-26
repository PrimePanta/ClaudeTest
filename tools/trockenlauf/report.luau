-- Bericht nach dem Trockenlauf: Teilezahl, Lage (Boden = y 0 des Rahmens cs), Sway-Liste, Namen
local names, lo, hi = {}, math.huge, -math.huge
for _, p in D.kids do
	names[p.Name] = (names[p.Name] or 0) + 1
	local c, s = p.CFrame, p.Size
	local ey = math.abs(c.R.Y)*s.X/2 + math.abs(c.U.Y)*s.Y/2 + math.abs(c.B.Y)*s.Z/2
	lo = math.min(lo, c.Position.Y - ey); hi = math.max(hi, c.Position.Y + ey)
end
print("Teile", #D.kids, "Lage", string.format("%.2f..%.2f", lo, hi))
local sw = calls[1][2]
print("swayGroup-Aufrufe", #calls, "Sway-Teile", #sw, "Nabe", calls[1][1].Name)
for i, s in sw do if i == 1 or i == 12 or i >= 13 then print(string.format("  %-24s amp %.3f phase %.3f slope %.3f", s.part.Name, s.amp, s.phase, s.slope)) end end
local ks = {} for k, n in names do table.insert(ks, k.." "..n) end table.sort(ks) print(table.concat(ks, ", "))
