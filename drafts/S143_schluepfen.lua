--[[ S143-ENTWURF: Schluepf-Animation (ModuleScript "Hatch", Client, z. B. in ReplicatedStorage)

UNGEPRUEFT IN STUDIO - Trockenlauf: tools/trockenlauf/run.sh (Probe: S143_schluepfen.test.luau).

Idee: Das Schluepfen ist DER Moment im Spiel, er soll sich verdient anfuehlen und die Seltenheit
schon vor dem Ergebnis spuerbar machen:
  1. Wackeln in Schueben: jeder Schub staerker, nach jedem Schub ein Riss mehr in der Schale.
     Seltenere Eier wackeln oefter (3 Schuebe bei Gewoehnlich, 5 bei Mythisch).
  2. Anspannen: das Ei zittert und gluet in der Seltenheitsfarbe; bei Mythisch eine Extra-Pause.
  3. Aufplatzen: Blitz in der Seltenheitsfarbe, Schalenstuecke fliegen weg (mit Schwerkraft),
     ab Episch Konfetti.
  4. Ergebnis: waechst mit Ueberschwingen aus der Mitte und dreht sich einmal.
  5. Schild darueber: Name, Seltenheit und - falls vorhanden - der Skin ("GOLD!") mit "1 zu N".

Aufbau: Die ganze Szene haengt NUR von der Zeit t ab (Hatch.new(...):apply(t)). Dadurch laesst
sie sich Bild fuer Bild pruefen, ueberspringt bei Rucklern nichts und kann vorgespult werden.
Hatch.play(...) spielt sie per RenderStepped ab.

  local h = Hatch.play(eggModel, brainrotModel, {
      name = "Tung Tung Sahur", rarity = "Episch", rarityOrder = 4, rarityColor = Color3...,
      skin = "Gold", skinName = "Gold", skinColor = Color3..., skinChance = "1 zu 23",
  }, { cframe = standCF, onDone = function() ... end, sounds = { crack = "rbxassetid://..." } })

  eggModel      - z. B. makeEgg(def) aus S142 (Pivot = Unterkante, -Z = zur Kamera). Wird GEKLONT.
  brainrotModel - das geschluepfte Modell (Skin vorher mit Skins.apply setzen). Wird GEKLONT.
  opts.cframe   - wo das Ei steht; ohne Angabe 9 Studs vor der Kamera, zur Kamera gedreht.

ANPASSEN: Zeiten und Staerken unten sind Vorschlaege; Sounds haben keine Voreinstellung.
Die Eiform (A, B, BR, BOFF) ist die aus S142 - beim Einbau beide aus einem Modul EggShape holen.
]]

local Hatch = {}
Hatch.__index = Hatch

-- Zeitleiste (Sekunden)
local BURST = 0.45 -- Dauer eines Wackel-Schubs
local GAP = 0.18 -- Pause zwischen Schueben
local CHARGE = 0.4 -- Anspannen vor dem Aufplatzen
local MYTHIC_PAUSE = 0.5 -- Extra-Spannung bei Mythisch
local FLASH = 0.35
local SHARDS = 0.9
local GROW = 0.55
local SPIN = 0.8
local BANNER_AT = 0.35 -- nach dem Aufplatzen
local BANNER_FADE = 0.3
local END_AFTER = 1.4 -- Ende der Zeitleiste nach dem Aufplatzen

-- Eiform wie S142
local A, B = 1.0, 1.35
local BR, BOFF = 1.04, 0.35
local YC = BOFF + BR

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

local function clamp01(x)
	return math.clamp(x, 0, 1)
end

local function easeOutBack(x) -- Ueberschwingen ca. 10 %
	local c1 = 1.70158
	local c3 = c1 + 1
	return 1 + c3 * (x - 1) ^ 3 + c1 * (x - 1) ^ 2
end

local function easeOutCubic(x)
	return 1 - (1 - x) ^ 3
end

-- Reine Zeitleiste: was zu Zeitpunkt t zu sehen ist. Keine Instanzen, nur Zahlen.
function Hatch.timeline(rarityOrder)
	local r = math.clamp(rarityOrder or 1, 1, 6)
	local bursts = 2 + math.ceil(r / 2) -- 3, 3, 4, 4, 5, 5
	local wobbleEnd = bursts * BURST + (bursts - 1) * GAP
	local charge = CHARGE + (r >= 6 and MYTHIC_PAUSE or 0)
	local pop = wobbleEnd + charge
	local tl = { bursts = bursts, wobbleEnd = wobbleEnd, pop = pop, duration = pop + END_AFTER, rarity = r }

	function tl.pose(t)
		local s = {
			rotZ = 0, rotX = 0, lift = 0, cracks = 0, glow = 0,
			eggVisible = t < pop, flash = 0, shard = 0,
			scale = 0, spin = 0, banner = 0,
		}
		if t < wobbleEnd then
			local k = math.floor(t / (BURST + GAP)) -- 0-basiert
			local tau = t - k * (BURST + GAP)
			s.cracks = k + (tau >= BURST and 1 or 0) -- ein Riss am Ende jedes Schubs (= Ereignis "crack")
			if tau < BURST then
				local amp = math.rad(math.min(6 + 4.5 * k, 20))
				local f = 2.5 + 0.4 * k
				local env = math.sin(math.pi * tau / BURST) -- weich rein und raus
				s.rotZ = amp * env * math.sin(2 * math.pi * f * tau)
				s.rotX = 0.35 * amp * env * math.sin(2 * math.pi * f * 0.5 * tau)
				if k == bursts - 1 then
					s.lift = 0.3 * env -- letzter Schub: kleiner Hopser
				end
			end
		elseif t < pop then
			s.cracks = bursts
			local g = clamp01((t - wobbleEnd) / charge)
			s.glow = g
			local tremble = math.rad(1.5) * g
			s.rotZ = tremble * math.sin(2 * math.pi * 18 * (t - wobbleEnd))
			s.rotZ *= math.sin(math.pi * g) -- zittert, endet ruhig im Blitz
		else
			local dt = t - pop
			s.cracks = bursts
			s.flash = dt < FLASH and 1 - dt / FLASH or 0
			s.shard = clamp01(dt / SHARDS)
			s.scale = dt >= GROW and 1 or 0.2 + 0.8 * easeOutBack(dt / GROW)
			s.spin = 2 * math.pi * easeOutCubic(clamp01(dt / SPIN))
			s.banner = clamp01((dt - BANNER_AT) / BANNER_FADE)
		end
		return s
	end

	-- Einmal-Ereignisse (Sound, Konfetti) mit Zeitpunkt
	tl.events = {}
	for k = 0, bursts - 1 do
		table.insert(tl.events, { at = k * (BURST + GAP) + BURST, kind = "crack", index = k + 1 })
	end
	table.insert(tl.events, { at = pop, kind = "pop" })
	table.insert(tl.events, { at = pop + BANNER_AT, kind = "banner" })
	return tl
end

local function mkPart(parent, name, size, cf, color, material, shape)
	local p = Instance.new("Part")
	p.Name = name
	if shape then
		p.Shape = shape
	end
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	p.Parent = parent
	return p
end

local function label(parent, text, size, color, order)
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.new(1, 0, 0, size + 6)
	t.Text = text
	t.TextSize = size
	t.TextColor3 = color
	t.Font = Enum.Font.FredokaOne
	t.TextStrokeTransparency = 0.3
	t.TextTransparency = 1
	t.LayoutOrder = order
	t.Parent = parent
	return t
end

local function defaultCFrame()
	local cam = workspace.CurrentCamera
	local look = cam.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z).Unit
	local pos = cam.CFrame.Position + flat * 9 - Vector3.new(0, 3.5, 0)
	return CFrame.lookAt(pos, pos - flat) -- -Z zeigt zur Kamera
end

function Hatch.new(eggModel, resultModel, info, opts)
	opts = opts or {}
	local self = setmetatable({}, Hatch)
	self.info = info
	self.opts = opts
	self.base = opts.cframe or defaultCFrame()
	self.tl = Hatch.timeline(info.rarityOrder)
	self.duration = self.tl.duration
	self.lastT = -1
	self.fired = {}

	local stage = Instance.new("Model")
	stage.Name = "HatchStage"
	self.stage = stage

	-- Ei (Klon), Pivot = Unterkante
	local egg = eggModel:Clone()
	egg.Parent = stage
	self.egg = egg
	self.eggParts = {}
	for _, d in egg:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(self.eggParts, { part = d, t0 = d.Transparency })
		end
	end
	local body = egg.PrimaryPart or self.eggParts[1].part
	local shellColor = body.Color
	egg:PivotTo(self.base)

	-- Risse: je Schub ein Zickzack-Riss an anderer Stelle, im Ei-Rahmen gebaut und mitbewegt
	self.cracks = {}
	local crackFolder = Instance.new("Model")
	crackFolder.Name = "HatchCracks"
	crackFolder.Parent = egg -- haengt am Ei und wackelt mit
	for k = 1, self.tl.bursts do
		local segs = {}
		local theta0 = -math.pi / 2 + (k - 1) * 2.1 -- erster Riss vorne (-Z = zur Kamera)
		local prev, prevN
		for i = 0, 4 do
			local theta = theta0 + (i % 2 == 0 and -0.12 or 0.12)
			local phi = 0.55 - i * 0.22
			local pos, n = shell(theta, phi)
			if prev then
				local mid = (prev + pos) / 2 + (prevN + n).Unit * 0.02
				local cf = self.base * CFrame.lookAt(mid, mid + (pos - prev), (prevN + n).Unit)
				local seg = mkPart(crackFolder, "HatchCrack", Vector3.new(0.07, 0.05, (pos - prev).Magnitude + 0.04),
					cf, Color3.fromRGB(25, 20, 20))
				seg.Transparency = 1
				table.insert(segs, seg)
			end
			prev, prevN = pos, n
		end
		self.cracks[k] = segs
	end

	-- Leuchten beim Anspannen
	local light = Instance.new("PointLight")
	light.Name = "HatchGlow"
	light.Color = info.rarityColor
	light.Brightness = 0
	light.Range = 12
	light.Shadows = false
	light.Parent = body
	self.light = light

	-- Blitz
	self.flash = mkPart(stage, "HatchFlash", Vector3.new(1, 1, 1), self.base * CFrame.new(0, YC, 0),
		info.rarityColor, Enum.Material.Neon, Enum.PartType.Ball)
	self.flash.Transparency = 1

	-- Schalenstuecke: 10 Stueck rundum, fliegen entlang der Normale + nach oben
	self.shards = {}
	for i = 1, 10 do
		local theta = 2 * math.pi * i / 10
		local phi = (i % 2 == 0) and 0.45 or -0.1
		local pos, n = shell(theta, phi)
		local v0 = n * (6 + (i % 3)) + Vector3.new(0, 7, 0)
		local spinAxis = Vector3.new(math.sin(i), 1, math.cos(i)).Unit
		local p = mkPart(stage, "HatchShard", Vector3.new(0.55, 0.08, 0.45), self.base * CFrame.new(pos),
			shellColor, body.Material)
		p.Transparency = 1
		table.insert(self.shards, { part = p, pos = pos, n = n, v0 = v0, axis = spinAxis })
	end

	-- Konfetti ab Episch
	if (info.rarityOrder or 1) >= 4 then
		local att = mkPart(stage, "HatchConfettiSource", Vector3.new(0.2, 0.2, 0.2), self.base * CFrame.new(0, YC, 0),
			info.rarityColor)
		att.Transparency = 1
		local e = Instance.new("ParticleEmitter")
		e.Name = "HatchConfetti"
		e.Rate = 0
		e.Speed = NumberRange.new(8, 14)
		e.SpreadAngle = Vector2.new(70, 70)
		e.Acceleration = Vector3.new(0, -18, 0)
		e.Lifetime = NumberRange.new(1.2, 2)
		e.Rotation = NumberRange.new(0, 360)
		e.RotSpeed = NumberRange.new(-300, 300)
		e.Size = NumberSequence.new(0.25)
		local keys = {}
		for j = 0, 4 do
			local h, s, v = info.rarityColor:ToHSV()
			table.insert(keys, ColorSequenceKeypoint.new(j / 4, Color3.fromHSV((h + j * 0.12) % 1, math.max(s, 0.6), v)))
		end
		e.Color = ColorSequence.new(keys)
		e.Parent = att
		self.confetti = e
	end

	-- Ergebnis (Klon), unsichtbar klein bis zum Aufplatzen
	local result = resultModel:Clone()
	result.Parent = stage
	self.result = result
	local piv = result:GetPivot()
	local bbCF, bbSize = result:GetBoundingBox()
	self.resultLift = piv.Position.Y - (bbCF.Position.Y - bbSize.Y / 2) -- Pivot ueber der Unterkante
	self.resultHeight = bbSize.Y
	self.resultParts = {}
	for _, d in result:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(self.resultParts, { part = d, t0 = d.Transparency })
		end
	end

	-- Schild
	local anchor = mkPart(stage, "HatchBannerAnchor", Vector3.new(0.2, 0.2, 0.2), self.base, info.rarityColor)
	anchor.Transparency = 1
	local gui = Instance.new("BillboardGui")
	gui.Name = "HatchBanner"
	gui.Size = UDim2.new(0, 320, 0, 130)
	gui.StudsOffsetWorldSpace = Vector3.new(0, self.resultHeight + 1.8, 0)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Parent = anchor
	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.Parent = gui
	self.labels = {
		label(gui, info.name, 34, Color3.fromRGB(255, 255, 255), 1),
		label(gui, info.rarityLabel or info.rarity, 24, info.rarityColor, 2),
	}
	if info.skin and info.skin ~= "Normal" then
		local skinText = string.upper(info.skinName or info.skin) .. "!"
		if info.skinChance then
			skinText ..= "  (" .. info.skinChance .. ")"
		end
		table.insert(self.labels, label(gui, skinText, 28, info.skinColor or Color3.fromRGB(255, 220, 80), 3))
	end

	stage.Parent = opts.parent or workspace
	self:apply(0)
	return self
end

function Hatch:_fire(ev)
	local sounds = self.opts.sounds or {}
	local id = sounds[ev.kind]
	if id then
		local snd = Instance.new("Sound")
		snd.SoundId = id
		snd.Volume = ev.kind == "pop" and 0.9 or 0.6
		snd.PlaybackSpeed = ev.kind == "crack" and (0.9 + 0.08 * (ev.index or 1)) or 1
		snd.Parent = self.stage
		snd:Play()
	end
	if ev.kind == "pop" and self.confetti then
		self.confetti:Emit(40 + 20 * (self.tl.rarity - 4))
	end
	if self.opts.onEvent then
		self.opts.onEvent(ev)
	end
end

-- Szene auf Zeitpunkt t stellen. Idempotent; Ereignisse feuern genau einmal beim Ueberschreiten.
function Hatch:apply(t)
	local s = self.tl.pose(t)
	for _, ev in self.tl.events do
		if not self.fired[ev] and t >= ev.at and self.lastT < ev.at then
			self.fired[ev] = true
			self:_fire(ev)
		end
	end
	self.lastT = t

	-- Ei
	self.egg:PivotTo(self.base * CFrame.new(0, s.lift, 0) * CFrame.Angles(s.rotX, 0, s.rotZ))
	for _, e in self.eggParts do
		e.part.Transparency = s.eggVisible and e.t0 or 1
	end
	for k, segs in self.cracks do
		for _, seg in segs do
			seg.Transparency = (s.eggVisible and k <= s.cracks) and 0 or 1
		end
	end
	self.light.Brightness = s.eggVisible and 3 * s.glow or 0

	-- Blitz
	local fs = 1 + 7 * (1 - s.flash)
	self.flash.Size = Vector3.new(fs, fs, fs)
	self.flash.Transparency = s.flash > 0 and 1 - 0.8 * s.flash or 1

	-- Schalenstuecke: Wurf mit Schwerkraft, drehen, ausblenden
	local ts = s.shard * SHARDS
	for i, sh in self.shards do
		if s.shard > 0 and s.shard < 1 then
			local p = sh.pos + sh.v0 * ts + Vector3.new(0, -0.5 * 30 * ts * ts, 0)
			sh.part.CFrame = self.base * CFrame.lookAt(p, p + sh.n) * CFrame.Angles(ts * 9, ts * 5 * (i % 2 == 0 and 1 or -1), 0)
			sh.part.Transparency = 0.2 + 0.8 * s.shard
		else
			sh.part.Transparency = 1
		end
	end

	-- Ergebnis
	local visible = s.scale > 0
	for _, r in self.resultParts do
		r.part.Transparency = visible and r.t0 or 1
	end
	local scale = math.max(s.scale, 0.05)
	self.result:ScaleTo(scale)
	self.result:PivotTo(self.base * CFrame.new(0, self.resultLift * scale, 0) * CFrame.Angles(0, s.spin, 0))

	-- Schild
	for _, l in self.labels do
		l.TextTransparency = 1 - s.banner
		l.TextStrokeTransparency = 1 - 0.7 * s.banner
	end
	return s
end

function Hatch:destroy()
	self.stage:Destroy()
end

function Hatch.play(eggModel, resultModel, info, opts)
	opts = opts or {}
	local RunService = game:GetService("RunService")
	local h = Hatch.new(eggModel, resultModel, info, opts)
	local t0 = os.clock()
	local hold = opts.hold or 1.5 -- so lange bleibt das Ergebnis nach der Zeitleiste stehen
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - t0
		h:apply(math.min(t, h.duration))
		if t >= h.duration + hold then
			conn:Disconnect()
			h:destroy()
			if opts.onDone then
				opts.onDone()
			end
		end
	end)
	return h
end

return Hatch
