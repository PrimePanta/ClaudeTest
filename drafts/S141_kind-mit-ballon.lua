--[[ S141-ENTWURF: Das Kind mit dem Ballon (Rummel, neben dem Ballonverkaeufer)

UNGEPRUEFT - geschrieben ohne Studio-Zugriff und ohne den WorldBuilder-Quelltext.
Vor dem Einbau mit drafts/S141_abnahme.lua pruefen.

Einbau: als Abschnitt "7. Das Kind mit dem Ballon (S141)" in buildFair(), direkt nach
Abschnitt 6 (Ballonverkaeufer) und vor dem Aufruf buildFair(). Er braucht aus Abschnitt 6:
  D     - Earth.Decor (Parameter von buildFair)
  cs    - Standrahmen des Verkaeufers, lookAt(F(16,0,-27), F(8,0,-40))
  WIND  - der eigene local WIND aus Abschnitt 6. Steckt er dort in einem do-Block,
          nach aussen ziehen. Vector3 oder Winkel (Grad) gehen beide, siehe W unten.
  swayGroup - wie beim Strauss (Zeile ~9387). Die SIGNATUR IST GERATEN und muss an den
          echten Aufruf swayGroup(tie, ...) angepasst werden (Markierung ANPASSEN).

Idee: ein Kind (ca. 3.2 hoch) steht rechts vom Verkaeufer auf der Strauss-Seite, hat gerade
einen roten Ballon bekommen und schaut zum Verkaeufer. Aus der Stadt F(9,5,-36) sieht man es
im Profil; der Verkaeufer bleibt frei (NICHT vor ihn stellen, siehe Nachtrag 317).
Nabe = die Hand (gleicher Baukasten wie FairBalloons): lookAt(H, H+up, WIND), AMP linear
entlang der Schnur (0 an der Hand, AMP am Knoten), Stuecke ~0.3, slope = amp*K, Kugeln slope 0.

Erwartete Zahlen: 34 neue Teile in D (19 Kind + 12 Schnur + Knoten + 2 Kugeln),
Fair 952 -> 986, SwayHub 28 -> 29, SwayPart 618 -> 633. Hoechster Punkt ca. 7.7 (Strauss 10.82).
]]
do
	local CHILD_POS = (cs * CFrame.new(3.2, 0, -1.6)).Position -- rechts vom Verkaeufer
	local LOOK_AT = cs * Vector3.new(0.8, 0, -0.6) -- zum Strauss / Verkaeufer
	local AMP = 0.35 -- Ausschlag am Knoten (Strauss 0.45; kuerzere Schnur)
	local K = 2 * math.pi / 10 -- wie Strauss
	local L = 3.6 -- Schnurlaenge Hand -> Knoten
	local SEG = 0.3 -- Stueckelaenge (Falle 327)
	local LEAN = 0.25 -- waagrecht pro Hoehe, mit dem Wind

	-- WIND als Vector3 oder als Winkel in Grad. Bei Winkel: Konvention aus Abschnitt 6 pruefen!
	local W = typeof(WIND) == "Vector3" and WIND
		or Vector3.new(math.cos(math.rad(WIND)), 0, -math.sin(math.rad(WIND)))
	local WINDH = Vector3.new(W.X, 0, W.Z).Unit

	local cc = CFrame.lookAt(CHILD_POS, Vector3.new(LOOK_AT.X, CHILD_POS.Y, LOOK_AT.Z))

	local SKIN = Color3.fromRGB(234, 190, 160)
	local HAIR = Color3.fromRGB(120, 75, 40)
	local NAVY = Color3.fromRGB(35, 50, 95)
	local STRIPE = Color3.fromRGB(240, 240, 235)
	local SHORTS = Color3.fromRGB(70, 95, 60)
	local SOCK = Color3.fromRGB(240, 240, 235)
	local SHOE = Color3.fromRGB(70, 45, 30)
	local EYE = Color3.fromRGB(25, 25, 25)
	local RED = Color3.fromRGB(200, 30, 35)
	local STRING = Color3.fromRGB(225, 225, 220)

	local function part(name, size, cf, color, shape)
		local p = Instance.new("Part")
		p.Name = name
		if shape then
			p.Shape = shape
		end
		p.Size = size
		p.CFrame = cf
		p.Color = color
		p.Material = Enum.Material.SmoothPlastic
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Anchored = true
		p.CanCollide = false
		p.CanTouch = false
		p.Parent = D
		return p
	end

	-- Quader im Kinderrahmen cc
	local function box(name, sx, sy, sz, x, y, z, color)
		return part(name, Vector3.new(sx, sy, sz), cc * CFrame.new(x, y, z), color)
	end

	-- Kugel an einem Weltpunkt
	local function ball(name, d, pos, color)
		return part(name, Vector3.new(d, d, d), CFrame.new(pos), color, Enum.PartType.Ball)
	end

	-- Quader von Weltpunkt a nach b (Laenge entlang Z)
	local function limb(name, a, b, t, color)
		local dir = b - a
		local up = math.abs(dir.Unit.Y) > 0.99 and Vector3.xAxis or Vector3.yAxis
		return part(name, Vector3.new(t, t, dir.Magnitude), CFrame.lookAt((a + b) / 2, b, up), color)
	end

	-- Kind: -Z = Blickrichtung, X = rechts, Boden y 0
	for _, sx in { -1, 1 } do
		box("FairChildShoe", 0.3, 0.22, 0.5, 0.2 * sx, 0.11, -0.06, SHOE)
		box("FairChildSock", 0.27, 0.3, 0.27, 0.2 * sx, 0.37, 0, SOCK)
		box("FairChildLeg", 0.25, 0.45, 0.25, 0.2 * sx, 0.745, 0, SKIN) -- Knie sichtbar: Beine lesen sich als Beine
	end
	box("FairChildShorts", 0.78, 0.5, 0.42, 0, 1.2, 0, SHORTS)
	box("FairChildTorso", 0.8, 0.8, 0.42, 0, 1.85, 0, NAVY)
	box("FairChildStripe", 0.82, 0.08, 0.44, 0, 1.7, 0, STRIPE)
	box("FairChildStripe", 0.82, 0.08, 0.44, 0, 1.95, 0, STRIPE)
	box("FairChildNeck", 0.25, 0.12, 0.25, 0, 2.31, 0, SKIN)
	ball("FairChildHead", 0.75, cc * Vector3.new(0, 2.72, 0), SKIN)
	ball("FairChildHair", 0.79, cc * Vector3.new(0, 2.82, 0.07), HAIR) -- nach hinten versetzt, Gesicht frei
	ball("FairChildEye", 0.07, cc * Vector3.new(-0.13, 2.76, -0.355), EYE)
	ball("FairChildEye", 0.07, cc * Vector3.new(0.13, 2.76, -0.355), EYE)

	-- linker Arm haengt
	limb("FairChildArm", cc * Vector3.new(-0.51, 2.15, 0), cc * Vector3.new(-0.56, 1.45, 0.02), 0.22, NAVY)
	ball("FairChildHand", 0.24, cc * Vector3.new(-0.57, 1.35, 0.02), SKIN)

	-- rechter Arm hoch, Hand = Nabe
	local H = cc * Vector3.new(0.6, 3.0, -0.12)
	limb("FairChildArm", cc * Vector3.new(0.51, 2.15, 0), H, 0.22, NAVY)
	local hand = ball("FairChildBalloonHand", 0.24, H, SKIN)
	hand.CFrame = CFrame.lookAt(H, H + Vector3.yAxis, WINDH) -- Look nach oben, Y = Wind, X = Auslenkung

	-- Schnur und Ballon
	local sway = {}
	local d = (Vector3.yAxis + WINDH * LEAN).Unit
	local n = math.max(1, math.round(L / SEG))
	for i = 1, n do
		local a = H + d * (L * (i - 1) / n)
		local b = H + d * (L * i / n)
		local v = L * (i - 0.5) / n
		local amp = AMP * v / L -- LINEAR, 0 an der Hand
		local p = limb("FairChildBalloonString", a, b, 0.05, STRING)
		table.insert(sway, { part = p, amp = amp, phase = -K * v, slope = amp * K })
	end
	local knot = H + d * L
	for _, s in {
		{ "FairChildBalloonKnot", 0.14, 0 },
		{ "FairChildBalloonDrop", 0.64, 0.3 }, -- r 0.32
		{ "FairChildBalloon", 1.0, 0.72 }, -- r 0.5
	} do
		local p = ball(s[1], s[2], knot + d * s[3], RED)
		table.insert(sway, { part = p, amp = AMP, phase = -K * L, slope = 0 })
	end

	-- ANPASSEN: Signatur wie beim Strauss (Abschnitt 6, swayGroup(tie, ...)).
	-- sway: je Teil {part, amp, phase, slope}; Takt 95 Grad/s (leichter als der Strauss), Sichtweite 260.
	swayGroup(hand, sway, { name = "FairChildBalloon", speed = 95, range = 260 })
end
