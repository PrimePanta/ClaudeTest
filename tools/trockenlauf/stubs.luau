-- Minimal-Nachbau von Vector3/CFrame/Color3/Instance fuer einen Trockenlauf ausserhalb von Studio.
-- Kein Ersatz fuer die Abnahme in Studio: keine Physik, keine Beruehrungen, keine Sway-Laufzeit.
local V = {}
V.__index = function(t, k)
	if k == "Magnitude" then return math.sqrt(t.X*t.X + t.Y*t.Y + t.Z*t.Z) end
	if k == "Unit" then local m = math.sqrt(t.X*t.X + t.Y*t.Y + t.Z*t.Z); return setmetatable({X=t.X/m,Y=t.Y/m,Z=t.Z/m}, V) end
	if k == "Cross" then return function(a, b) return setmetatable({X=a.Y*b.Z-a.Z*b.Y, Y=a.Z*b.X-a.X*b.Z, Z=a.X*b.Y-a.Y*b.X}, V) end end
	if k == "Dot" then return function(a, b) return a.X*b.X+a.Y*b.Y+a.Z*b.Z end end
end
local function v(x, y, z) return setmetatable({X=x, Y=y, Z=z}, V) end
V.__add = function(a, b) return v(a.X+b.X, a.Y+b.Y, a.Z+b.Z) end
V.__sub = function(a, b) return v(a.X-b.X, a.Y-b.Y, a.Z-b.Z) end
V.__mul = function(a, b) if type(a) == "number" then a, b = b, a end return v(a.X*b, a.Y*b, a.Z*b) end
V.__div = function(a, b) return v(a.X/b, a.Y/b, a.Z/b) end
V.__unm = function(a) return v(-a.X, -a.Y, -a.Z) end
Vector3 = { new = v, xAxis = v(1,0,0), yAxis = v(0,1,0), zAxis = v(0,0,1) }

local C = {}
local function cf(p, r, u, b) return setmetatable({Position=p, R=r, U=u, B=b}, C) end -- Spalten X,Y,Z
C.__index = function(t, k) if k == "LookVector" then return -t.B end if k == "UpVector" then return t.U end end
C.__mul = function(a, b)
	if getmetatable(b) == V then return a.Position + a.R*b.X + a.U*b.Y + a.B*b.Z end
	local function rot(x) return a.R*x.X + a.U*x.Y + a.B*x.Z end
	return cf(a.Position + rot(b.Position), rot(b.R), rot(b.U), rot(b.B))
end
CFrame = {
	new = function(x, y, z) local p = type(x) == "number" and v(x, y, z) or x; return cf(p, v(1,0,0), v(0,1,0), v(0,0,1)) end,
	lookAt = function(at, target, up)
		up = up or v(0,1,0)
		local look = (target - at).Unit
		local right = look:Cross(up).Unit
		local up2 = right:Cross(look)
		return cf(at, right, up2, -look)
	end,
}
Color3 = { fromRGB = function(r,g,b) return {r,g,b} end }
Enum = setmetatable({}, { __index = function(_, e) return setmetatable({}, { __index = function(_, n) return e.."."..n end }) end })
local rtypeof = typeof
typeof = function(x) if getmetatable(x) == V then return "Vector3" end return rtypeof(x) end

D = { kids = {} }
Instance = { new = function(cls)
	return setmetatable({ClassName = cls}, { __newindex = function(t, k, val)
		rawset(t, k, val)
		if k == "Parent" and val == D then table.insert(D.kids, t) end
	end })
end }

local calls = {}
function swayGroup(...) table.insert(calls, {...}) end

cs = CFrame.lookAt(v(16,0,-27), v(8,0,-40))
WIND = WIND_IN -- wird von run.sh ersetzt
