-- Minimal-Nachbau der Roblox-API fuer einen Trockenlauf ausserhalb von Studio.
-- Kein Ersatz fuer die Abnahme in Studio: keine Physik, keine Beruehrungen, kein Rendering, keine Laufzeit-Bewegung.
-- Abgedeckt: Vector3, CFrame (new, lookAt, Angles, *, +), Color3 (new, fromRGB, fromHSV, Lerp, ToHSV),
-- Instance (Parent/Kinder, IsA, Attribute, Find*, GetDescendants, Destroy), Enum, Random, UDim2 & Co. als Platzhalter.

-- Vector3
local V = {}
local function v(x, y, z) return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, V) end
V.__index = function(t, k)
	if k == "Magnitude" then return math.sqrt(t.X * t.X + t.Y * t.Y + t.Z * t.Z) end
	if k == "Unit" then
		local m = math.sqrt(t.X * t.X + t.Y * t.Y + t.Z * t.Z)
		return v(t.X / m, t.Y / m, t.Z / m)
	end
	if k == "Cross" then return function(a, b) return v(a.Y * b.Z - a.Z * b.Y, a.Z * b.X - a.X * b.Z, a.X * b.Y - a.Y * b.X) end end
	if k == "Dot" then return function(a, b) return a.X * b.X + a.Y * b.Y + a.Z * b.Z end end
	if k == "Lerp" then return function(a, b, s) return a + (b - a) * s end end
end
V.__add = function(a, b) return v(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
V.__sub = function(a, b) return v(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
V.__mul = function(a, b)
	if type(a) == "number" then a, b = b, a end
	if type(b) == "number" then return v(a.X * b, a.Y * b, a.Z * b) end
	return v(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
V.__div = function(a, b) return v(a.X / b, a.Y / b, a.Z / b) end
V.__unm = function(a) return v(-a.X, -a.Y, -a.Z) end
V.__tostring = function(a) return string.format("%.2f, %.2f, %.2f", a.X, a.Y, a.Z) end
Vector3 = { new = v, zero = v(0, 0, 0), one = v(1, 1, 1), xAxis = v(1, 0, 0), yAxis = v(0, 1, 0), zAxis = v(0, 0, 1) }

-- CFrame: Position + Spalten R (X), U (Y), B (Z)
local C = {}
local function cf(p, r, u, b) return setmetatable({ Position = p, R = r, U = u, B = b }, C) end
C.__index = function(t, k)
	if k == "LookVector" then return -t.B end
	if k == "UpVector" then return t.U end
	if k == "RightVector" then return t.R end
	if k == "X" then return t.Position.X end
	if k == "Y" then return t.Position.Y end
	if k == "Z" then return t.Position.Z end
	if k == "PointToWorldSpace" then return function(a, p) return a * p end end
end
C.__mul = function(a, b)
	if getmetatable(b) == V then return a.Position + a.R * b.X + a.U * b.Y + a.B * b.Z end
	local function rot(x) return a.R * x.X + a.U * x.Y + a.B * x.Z end
	return cf(a.Position + rot(b.Position), rot(b.R), rot(b.U), rot(b.B))
end
C.__add = function(a, b) return cf(a.Position + b, a.R, a.U, a.B) end
C.__sub = function(a, b) return cf(a.Position - b, a.R, a.U, a.B) end
local function ident(p) return cf(p, v(1, 0, 0), v(0, 1, 0), v(0, 0, 1)) end
local function rx(a) return cf(v(), v(1, 0, 0), v(0, math.cos(a), math.sin(a)), v(0, -math.sin(a), math.cos(a))) end
local function ry(a) return cf(v(), v(math.cos(a), 0, -math.sin(a)), v(0, 1, 0), v(math.sin(a), 0, math.cos(a))) end
local function rz(a) return cf(v(), v(math.cos(a), math.sin(a), 0), v(-math.sin(a), math.cos(a), 0), v(0, 0, 1)) end
CFrame = {
	identity = ident(v()),
	new = function(x, y, z)
		if x == nil then return ident(v()) end
		return ident(type(x) == "number" and v(x, y, z) or x)
	end,
	lookAt = function(at, target, up)
		up = up or v(0, 1, 0)
		local look = (target - at).Unit
		local right = look:Cross(up).Unit
		return cf(at, right, right:Cross(look), -look)
	end,
	Angles = function(x, y, z) return rx(x) * ry(y) * rz(z) end, -- wie Roblox: X, dann Y, dann Z
}
CFrame.fromEulerAnglesXYZ = CFrame.Angles

-- Color3 (Kanaele 0..1)
local K3 = {}
K3.__index = K3
local function c3(r, g, b) return setmetatable({ R = r or 0, G = g or 0, B = b or 0 }, K3) end
function K3.Lerp(a, b, s) return c3(a.R + (b.R - a.R) * s, a.G + (b.G - a.G) * s, a.B + (b.B - a.B) * s) end
function K3.ToHSV(c)
	local mx, mn = math.max(c.R, c.G, c.B), math.min(c.R, c.G, c.B)
	local d, h = mx - mn, 0
	if d > 0 then
		if mx == c.R then h = ((c.G - c.B) / d) % 6
		elseif mx == c.G then h = (c.B - c.R) / d + 2
		else h = (c.R - c.G) / d + 4 end
		h /= 6
	end
	return h, mx > 0 and d / mx or 0, mx
end
K3.__eq = function(a, b) return math.abs(a.R - b.R) < 1e-6 and math.abs(a.G - b.G) < 1e-6 and math.abs(a.B - b.B) < 1e-6 end
K3.__tostring = function(c) return string.format("rgb(%d,%d,%d)", c.R * 255 + 0.5, c.G * 255 + 0.5, c.B * 255 + 0.5) end
local function hsv(h, s, val)
	h = (h % 1) * 6
	local i, f = math.floor(h), h - math.floor(h)
	local p, q, t = val * (1 - s), val * (1 - s * f), val * (1 - s * (1 - f))
	local rgb = ({ { val, t, p }, { q, val, p }, { p, val, t }, { p, q, val }, { t, p, val }, { val, p, q } })[i + 1]
	return c3(rgb[1], rgb[2], rgb[3])
end
Color3 = { new = c3, fromRGB = function(r, g, b) return c3(r / 255, g / 255, b / 255) end, fromHSV = hsv, toHSV = K3.ToHSV }

-- Platzhalter-Datentypen
local function box(name) return function(...) return { __type = name, ... } end end
UDim2 = { new = box("UDim2"), fromScale = box("UDim2"), fromOffset = box("UDim2") }
UDim = { new = box("UDim") }
Vector2 = { new = box("Vector2") }
NumberRange = { new = box("NumberRange") }
NumberSequence = { new = box("NumberSequence") }
NumberSequenceKeypoint = { new = box("NumberSequenceKeypoint") }
ColorSequence = { new = box("ColorSequence") }
ColorSequenceKeypoint = { new = box("ColorSequenceKeypoint") }
-- Enum: Eintraege sind feste Tabellen (Gleichheit per ==), mit Name/EnumType wie in Roblox
local ENUM_ITEM = { __tostring = function(i) return "Enum." .. i.EnumType .. "." .. i.Name end }
local enumCache = {}
Enum = setmetatable({}, {
	__index = function(_, e)
		enumCache[e] = enumCache[e] or setmetatable({}, {
			__index = function(t, n)
				local item = setmetatable({ Name = n, EnumType = e }, ENUM_ITEM)
				rawset(t, n, item)
				return item
			end,
		})
		return enumCache[e]
	end,
})

-- Random (deterministisch, eigener LCG)
local RND = {}
RND.__index = RND
function RND:NextNumber(a, b)
	self.s = (self.s * 1103515245 + 12345) % 2147483648
	local x = self.s / 2147483648
	return a and (a + (b - a) * x) or x
end
function RND:NextInteger(a, b) return math.floor(self:NextNumber(a, b + 1)) end
Random = { new = function(seed) return setmetatable({ s = (seed or 1) % 2147483648 }, RND) end }

-- Instance
local PART_CLASSES = { Part = true, WedgePart = true, MeshPart = true, CornerWedgePart = true, TrussPart = true }
local IM = {} -- Methoden
local IMeta = {}
IMeta.__index = function(t, k)
	if IM[k] then return IM[k] end
	local p = rawget(t, "_p")
	if p[k] ~= nil then return p[k] end
	if k == "Position" and p.CFrame then return p.CFrame.Position end
	for _, c in rawget(t, "_c") do
		if c.Name == k then return c end
	end
	return nil
end
IMeta.__newindex = function(t, k, val)
	local p = rawget(t, "_p")
	if k == "Position" and p.CFrame then
		p.CFrame = p.CFrame + (val - p.CFrame.Position)
		return
	end
	if k == "Parent" then
		local old = p.Parent
		if old then
			local oc = rawget(old, "_c")
			for i, c in oc do
				if c == t then table.remove(oc, i) break end
			end
		end
		if val then table.insert(rawget(val, "_c"), t) end
	end
	p[k] = val
end
IMeta.__tostring = function(t) return t.Name end
function IM.IsA(t, cls)
	local c = t.ClassName
	if c == cls then return true end
	if cls == "BasePart" then return PART_CLASSES[c] == true end
	if cls == "Instance" then return true end
	if cls == "PVInstance" then return PART_CLASSES[c] == true or c == "Model" end
	if cls == "GuiObject" then return c == "TextLabel" or c == "Frame" or c == "ImageLabel" end
	if cls == "Light" then return c == "PointLight" or c == "SpotLight" or c == "SurfaceLight" end
	return false
end
function IM.GetChildren(t) return table.clone(rawget(t, "_c")) end
function IM.GetDescendants(t)
	local out = {}
	local function walk(x)
		for _, c in rawget(x, "_c") do
			table.insert(out, c)
			walk(c)
		end
	end
	walk(t)
	return out
end
function IM.FindFirstChild(t, name, recursive)
	for _, c in (recursive and IM.GetDescendants(t) or rawget(t, "_c")) do
		if c.Name == name then return c end
	end
	return nil
end
function IM.FindFirstChildWhichIsA(t, cls)
	for _, c in rawget(t, "_c") do
		if c:IsA(cls) then return c end
	end
	return nil
end
function IM.SetAttribute(t, k, val) rawget(t, "_a")[k] = val end
function IM.GetAttribute(t, k) return rawget(t, "_a")[k] end
function IM.GetAttributes(t) return table.clone(rawget(t, "_a")) end
function IM.Destroy(t)
	for _, c in IM.GetChildren(t) do IM.Destroy(c) end
	t.Parent = nil
	rawset(t, "_dead", true)
end
function IM.ClearAllChildren(t)
	for _, c in IM.GetChildren(t) do IM.Destroy(c) end
end
function IM.GetFullName(t)
	local p = t.Parent
	return p and (IM.GetFullName(p) .. "." .. t.Name) or t.Name
end
function IM.PivotTo(t, target)
	-- Modell: alle Teile relativ zur WorldPivot mitbewegen (wie Roblox)
	local piv = t.WorldPivot or (t.PrimaryPart and t.PrimaryPart.CFrame) or CFrame.new()
	local function inv(c) -- Inverse einer orthonormalen CFrame
		local r, u, b = c.R, c.U, c.B
		local nr, nu, nb = v(r.X, u.X, b.X), v(r.Y, u.Y, b.Y), v(r.Z, u.Z, b.Z)
		local ip = -(nr * c.Position.X + nu * c.Position.Y + nb * c.Position.Z)
		return cf(ip, nr, nu, nb)
	end
	local delta = target * inv(piv)
	for _, d in IM.GetDescendants(t) do
		if d:IsA("BasePart") then d.CFrame = delta * d.CFrame end
	end
	if t.ClassName == "Model" then t.WorldPivot = target else t.CFrame = target end
end
function IM.GetPivot(t) return t.WorldPivot or t.CFrame end

local ALL = {}
Instance = {
	new = function(cls, parent)
		local t = setmetatable({ _p = {}, _c = {}, _a = {} }, IMeta)
		t.ClassName = cls
		t.Name = cls
		if PART_CLASSES[cls] then
			t.Size = v(4, 1, 2)
			t.CFrame = CFrame.new()
			t.Color = c3(0.64, 0.64, 0.64)
			t.Transparency = 0
			t.Reflectance = 0
			t.Material = Enum.Material.Plastic
			if cls == "MeshPart" then t.TextureID = "" end
		end
		table.insert(ALL, t)
		if parent then t.Parent = parent end
		return t
	end,
}
TROCKEN_ALL = ALL

local rtypeof = typeof
typeof = function(x)
	local m = getmetatable(x)
	if m == V then return "Vector3" end
	if m == C then return "CFrame" end
	if m == K3 then return "Color3" end
	if m == IMeta then return "Instance" end
	if m == RND then return "Random" end
	return rtypeof(x)
end

-- Umgebung wie in buildFair(): D = Earth.Decor, cs = Standrahmen des Verkaeufers
D = Instance.new("Folder")
D.Name = "Decor"
local SWAY_CALLS = {}
TROCKEN_SWAY = SWAY_CALLS
function swayGroup(...) table.insert(SWAY_CALLS, { ... }) end
cs = CFrame.lookAt(v(16, 0, -27), v(8, 0, -40))
WIND = WIND_IN -- wird von run.sh ersetzt
