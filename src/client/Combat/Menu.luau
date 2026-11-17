--!strict
-- The battle command menu (decision D17): words in cut-out "ransom note" letters beside this player's fighter, each
-- with a thin white line running back toward the fighter. No boxes. The word under the cursor gets a slanted red
-- bar behind it and grows a little.
--
-- The top level is three words, FIGHT / ITEMS / FOCUS. Picking one throws the three words back into the fighter
-- (with a white slash across the screen), drops that word in as a big header, and brings its list in one line at a
-- time, ending in BACK. BACK, the header, Backspace or the B button go back up. (Esc is listened for too, but
-- Roblox usually keeps it for its own menu.)
--
--   local menu = Menu.open(parent, groups, {
--       anchor = function() return fighterScreenPoint end,  -- Vector2 in the parent's pixels, or nil
--       onHover = function(caption) ... end,                -- the narrator line for what is under the cursor
--       onPick = function(id) ... end,                      -- an enabled entry was picked
--   })
--   menu.close("Slash")   -- the picked entry punches, the rest fade; menu.close() just fades everything
--
-- Mouse / touch: hover to light, click / tap to pick. Keyboard: Up / Down (or W / S), Enter / Space, Backspace, and
-- 1-9 to pick a line directly. Gamepad: D-pad, A, B.

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Ink = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("UI"):WaitForChild("Ink"))

local Menu = {}

export type Entry = { id: string, title: string, caption: string, enabled: boolean, note: string? }
export type Group = { title: string, caption: string, entries: { Entry } }
export type Options = {
	anchor: () -> Vector2?,
	onHover: ((caption: string) -> ())?,
	onPick: (id: string) -> (),
}
export type Handle = { close: (chosen: string?) -> () }

local BACK = "__back"

-- Layout, in pixels on a 753 px tall screen, measured from the fighter's HumanoidRootPart on screen. Scaled with
-- the screen height. (These come from the approved mockup.)
local BASE_HEIGHT = 753
local TOP_LAYOUT = { { 134, -108, 60 }, { 94, -44, 29 }, { 147, 20, 73 } } -- x, y, line length
local TOP_SIZE = 36
local HEAD_AT = Vector2.new(74, -300)
local HEAD_SIZE = 71
local LIST_X, LIST_Y = 88, -238
local LIST_ZIG = { 0, 24, 8, 32, 12, 26, 3 } -- kept small so long names stay clear of the enemies
local LIST_SIZE, BACK_SIZE = 28, 25

local FONTS = {
	Font.new("rbxasset://fonts/families/Bangers.json"),
	Font.new("rbxasset://fonts/families/LuckiestGuy.json"),
	Font.new("rbxasset://fonts/families/Oswald.json", Enum.FontWeight.Bold),
}

local make = Ink.make

local function hash(s: string): number
	local h = 7
	for i = 1, #s do
		h = (h * 31 + string.byte(s, i)) % 9973
	end
	return h
end

-- A word in cut-out letters: each letter its own label in one of three fonts, a little tilted and resized, with a
-- black outline; the first letter (and a few others) sit on a black or cream scrap instead.
local function ransom(parent: Instance, word: string, size: number, z: number, dim: boolean?): Frame
	local holder = make("Frame", {
		Name = "Word",
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.fromOffset(0, 0),
		ZIndex = z,
	}, parent) :: Frame
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, math.max(1, math.floor(size * 0.04))),
	}, holder)
	for i = 1, #word do
		local c = string.sub(word, i, i)
		if c == " " then
			make("Frame", { LayoutOrder = i, BackgroundTransparency = 1, Size = UDim2.fromOffset(size * 0.3, size * 0.5) }, holder)
			continue
		end
		local h = hash(word .. i)
		local s = math.floor(size * (0.88 + (h % 5) * 0.07) + 0.5)
		local chip = i == 1 or h % 7 == 0
		local darkChip = h % 2 == 0
		local label = make("TextLabel", {
			Name = "L" .. i,
			LayoutOrder = i,
			Text = c,
			FontFace = FONTS[h % 3 + 1],
			TextSize = s,
			AutomaticSize = Enum.AutomaticSize.XY,
			Size = UDim2.fromOffset(0, 0),
			BackgroundTransparency = if chip then 0 else 1,
			BackgroundColor3 = if darkChip then Ink.Colors.Black else Ink.Colors.Cream,
			TextColor3 = if chip and not darkChip then Ink.Colors.Black else Ink.Colors.Cream,
			Rotation = (h % 9) - 4,
			BorderSizePixel = 0,
			ZIndex = z,
		}, holder) :: TextLabel
		if dim then
			label.TextColor3 = if chip and not darkChip then Ink.Colors.Grey else Color3.fromRGB(170, 166, 160)
		end
		if chip then
			make("UIPadding", { PaddingLeft = UDim.new(0, s * 0.1), PaddingRight = UDim.new(0, s * 0.1) }, label)
		else
			make("UIStroke", { Color = Ink.Colors.Black, Thickness = math.max(1.5, s * 0.05), LineJoinMode = Enum.LineJoinMode.Round }, label)
		end
	end
	return holder
end

-- Everything in a gui that can fade, with its resting transparency, so it can fade out and back to rest.
type Fader = { inst: Instance, prop: string, base: number }
local function faders(gui: Instance): { Fader }
	local list: { Fader } = {}
	for _, inst in { gui, table.unpack(gui:GetDescendants()) } do
		if inst:IsA("TextLabel") or inst:IsA("TextButton") then
			if inst.Text ~= "" then
				table.insert(list, { inst = inst, prop = "TextTransparency", base = inst.TextTransparency })
			end
			if inst.BackgroundTransparency < 1 then
				table.insert(list, { inst = inst, prop = "BackgroundTransparency", base = inst.BackgroundTransparency })
			end
		elseif inst:IsA("Frame") and inst.BackgroundTransparency < 1 then
			table.insert(list, { inst = inst, prop = "BackgroundTransparency", base = inst.BackgroundTransparency })
		elseif inst:IsA("UIStroke") then
			table.insert(list, { inst = inst, prop = "Transparency", base = inst.Transparency })
		end
	end
	return list
end

-- t = 0 is resting, 1 is gone. With no seconds it jumps there.
local function fade(list: { Fader }, t: number, seconds: number?, delay: number?)
	for _, f in list do
		local goal = f.base + (1 - f.base) * t
		if seconds then
			local info = TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, delay or 0)
			TweenService:Create(f.inst, info, { [f.prop] = goal }):Play()
		else
			(f.inst :: any)[f.prop] = goal
		end
	end
end

type Item = {
	holder: Frame,
	button: TextButton,
	word: Frame,
	wordScale: UIScale,
	fades: { Fader },
	size: number,
	enabled: boolean,
	id: string,
	caption: string,
	home: Vector2,
}

function Menu.open(parent: GuiObject, groups: { Group }, options: Options): Handle
	local root = make("Frame", {
		Name = "CommandMenu",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 3,
	}, parent) :: Frame

	-- the highlight bar: slanted red, an arrow at its left end, a dash at its right, a thin underline
	local bar = make("Frame", {
		Name = "Highlight",
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = Ink.Colors.Red,
		BorderSizePixel = 0,
		Rotation = -3,
		Visible = false,
		ZIndex = 3,
	}, root) :: Frame
	local arrow = make("TextLabel", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 4, 0.45, 0),
		Size = UDim2.fromScale(0.08, 0.5),
		SizeConstraint = Enum.SizeConstraint.RelativeYY,
		BackgroundTransparency = 1,
		Text = "▶",
		TextScaled = true,
		TextColor3 = Ink.Colors.Black,
		Font = Enum.Font.GothamBold,
		ZIndex = 3,
	}, bar) :: TextLabel
	arrow.Size = UDim2.fromScale(0.42, 0.42)
	make("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.42, 0),
		Size = UDim2.fromScale(0.05, 0.1),
		BackgroundColor3 = Ink.Colors.Black,
		BorderSizePixel = 0,
		Rotation = -14,
		ZIndex = 3,
	}, bar)
	make("Frame", {
		Name = "Underline",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0.07, 0, 0.93, 0),
		Size = UDim2.new(0.86, 0, 0, 2),
		BackgroundColor3 = Ink.Colors.Black,
		BorderSizePixel = 0,
		Rotation = 1.5,
		ZIndex = 4,
	}, bar)
	local barT = Instance.new("NumberValue")

	local items: { Item } = {}
	local header: Frame? = nil
	local headerFades: { Fader } = {}
	local hov = 1
	local group: Group? = nil
	local busy = false
	local open = true
	local k = 1
	local listDrop = 0

	local function scaleNow(): number
		local camera = workspace.CurrentCamera
		local h = if camera then camera.ViewportSize.Y else BASE_HEIGHT
		return math.clamp(h / BASE_HEIGHT, 0.55, 1.4)
	end

	local function anchorPoint(): Vector2
		local a = options.anchor()
		if a then
			return a
		end
		local camera = workspace.CurrentCamera
		local view = if camera then camera.ViewportSize else Vector2.new(1324, 753)
		return Vector2.new(view.X * 0.37, view.Y * 0.66)
	end

	local function clearItems()
		for _, item in items do
			item.holder:Destroy()
		end
		table.clear(items)
		if header then
			header:Destroy()
			header = nil
		end
		bar.Visible = false
	end

	local function light(i: number, announce: boolean)
		hov = i
		for n, item in items do
			local on = n == i
			TweenService:Create(item.wordScale, TweenInfo.new(0.14, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = if on then 1.12 else 1 }):Play()
		end
		local item = items[i]
		barT.Value = 0
		if item and item.enabled then
			TweenService:Create(barT, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Value = 1 }):Play()
		end
		if announce and item and options.onHover then
			options.onHover(item.caption)
		end
	end

	local choose: (i: number) -> ()

	local function addItem(entry: Entry, at: Vector2, size: number, lineLength: number, order: number): Item
		local holder = make("Frame", { Name = "Line" .. order, BackgroundTransparency = 1, Size = UDim2.fromOffset(0, 0), ZIndex = 4 }, root) :: Frame
		local button = make("TextButton", {
			Name = entry.id,
			Text = "",
			AutoButtonColor = false,
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0, 0.5),
			AutomaticSize = Enum.AutomaticSize.XY,
			Size = UDim2.fromOffset(0, 0),
			Selectable = false,
			ZIndex = 4,
		}, holder) :: TextButton
		make("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, size * 0.22),
		}, button)
		local pad = math.max(4, math.floor((44 - size) / 2 + 0.5)) -- keep the tap target at least 44 px tall
		make("UIPadding", { PaddingTop = UDim.new(0, pad), PaddingBottom = UDim.new(0, pad), PaddingRight = UDim.new(0, 10) }, button)
		local line = make("Frame", {
			Name = "Rule",
			LayoutOrder = 1,
			Size = UDim2.fromOffset(lineLength, math.max(2, math.floor(size * 0.09))),
			BackgroundColor3 = Ink.Colors.Cream,
			BorderSizePixel = 0,
			ZIndex = 4,
		}, button)
		make("UIStroke", { Color = Ink.Colors.Black, Thickness = 1 }, line)
		local word = ransom(button, entry.title, size, 5, not entry.enabled)
		word.LayoutOrder = 2
		local wordScale = make("UIScale", { Scale = 1 }, word) :: UIScale
		if entry.note then
			Ink.text(button, string.upper(entry.note), math.floor(size * 0.45), {
				LayoutOrder = 3,
				AutomaticSize = Enum.AutomaticSize.XY,
				Size = UDim2.fromOffset(0, 0),
				FontFace = Ink.Fonts.Body,
				TextColor3 = Color3.fromRGB(200, 196, 190),
				ZIndex = 5,
			})
		end
		local item: Item = {
			holder = holder,
			button = button,
			word = word,
			wordScale = wordScale,
			fades = faders(button),
			size = size,
			enabled = entry.enabled,
			id = entry.id,
			caption = entry.caption,
			home = at,
		}
		table.insert(items, item)
		local index = #items
		button.MouseEnter:Connect(function()
			if not busy and hov ~= index then
				light(index, true)
			end
		end)
		button.Activated:Connect(function()
			if not busy then
				if hov ~= index then
					light(index, true)
				end
				choose(index)
			end
		end)
		return item
	end

	-- every frame: follow the fighter, keep the highlight bar under the lit word
	local function place()
		local a = anchorPoint()
		local origin = root.AbsolutePosition
		local shiftY = 0
		if group then
			local top = a.Y + (HEAD_AT.Y + listDrop - HEAD_SIZE * 0.6) * k
			local camera = workspace.CurrentCamera
			local minTop = (if camera then camera.ViewportSize.Y else BASE_HEIGHT) * 0.04
			if top < minTop then
				shiftY = minTop - top
			end
		end
		for _, item in items do
			item.holder.Position = UDim2.fromOffset(a.X + item.home.X * k - origin.X, a.Y + item.home.Y * k + shiftY - origin.Y)
		end
		if header then
			header.Position = UDim2.fromOffset(a.X + HEAD_AT.X * k - origin.X, a.Y + (HEAD_AT.Y + listDrop) * k + shiftY - origin.Y)
		end
		local item = items[hov]
		if item and item.enabled and barT.Value > 0.01 then
			local wp = item.word.AbsolutePosition - origin
			local ws = item.word.AbsoluteSize
			local s = item.size * k
			bar.Position = UDim2.fromOffset(wp.X - s * 0.45, wp.Y + ws.Y * 0.5)
			bar.Size = UDim2.fromOffset((ws.X + s * 0.95) * barT.Value, ws.Y * 0.86)
			bar.Visible = true
		else
			bar.Visible = false
		end
	end

	local function stagger(list: { Item }, from: Vector2, step: number, delay: number)
		for n, item in list do
			item.button.Position = UDim2.fromOffset(from.X, from.Y)
			fade(item.fades, 1)
			local d = delay + (n - 1) * step
			TweenService:Create(item.button, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, false, d), { Position = UDim2.fromOffset(0, 0) }):Play()
			fade(item.fades, 0, 0.14, d)
		end
	end

	local function buildTop(enter: boolean)
		clearItems()
		group = nil
		k = scaleNow()
		for i, g in groups do
			local spot = TOP_LAYOUT[i] or { 120, -108 + (i - 1) * 64, 40 }
			addItem({ id = g.title, title = g.title, caption = g.caption, enabled = true }, Vector2.new(spot[1], spot[2]), math.floor(TOP_SIZE * k), spot[3] * k, i)
		end
		if enter then
			stagger(items, Vector2.new(-120 * k, 30 * k), 0.05, 0)
		end
		place()
	end

	local function buildGroup(g: Group)
		clearItems()
		group = g
		k = scaleNow()
		local head = make("TextButton", {
			Name = "Header",
			Text = "",
			AutoButtonColor = false,
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0, 0.5),
			AutomaticSize = Enum.AutomaticSize.XY,
			Size = UDim2.fromOffset(0, 0),
			Rotation = -4,
			Selectable = false,
			ZIndex = 4,
		}, root) :: TextButton
		ransom(head, g.title, math.floor(HEAD_SIZE * k), 5)
		local headScale = make("UIScale", { Scale = 1.6 }, head) :: UIScale
		header = head
		headerFades = faders(head)
		fade(headerFades, 1)
		head.Rotation = -12
		TweenService:Create(headScale, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		TweenService:Create(head, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Rotation = -4 }):Play()
		fade(headerFades, 0, 0.12)
		head.Activated:Connect(function()
			if not busy then
				choose(0)
			end
		end)

		local rows = table.clone(g.entries)
		table.insert(rows, { id = BACK, title = "BACK", caption = "Back to Fight, Items and Focus.", enabled = true })
		local gap = if #rows > 5 then 42 else 53
		-- A short list hangs lower, nearer the fighter, instead of up in the sky.
		listDrop = math.max(0, 7 - #rows) * gap * 0.5
		for i, entry in rows do
			local zig = LIST_ZIG[(i - 1) % #LIST_ZIG + 1]
			local size = if entry.id == BACK then BACK_SIZE else LIST_SIZE
			addItem(entry, Vector2.new(LIST_X + zig, LIST_Y + listDrop + (i - 1) * gap), math.floor(size * k), (26 + ((i - 1) * 22) % 53) * k, i)
		end
		stagger(items, Vector2.new(106 * k, 0), 0.04, 0.09)
		local first = 1
		for i, item in items do
			if item.enabled then
				first = i
				break
			end
		end
		place()
		light(first, true)
	end

	-- The current words fly back into the fighter, a white slash crosses the screen, then `after` builds the next.
	local function swap(after: () -> ())
		busy = true
		barT.Value = 0
		for n, item in items do
			if n == hov then
				TweenService:Create(item.wordScale, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1.3 }):Play()
				fade(item.fades, 1, 0.14, 0.06)
			else
				local info = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, (n - 1) * 0.03)
				TweenService:Create(item.button, info, { Position = UDim2.fromOffset(-185 * k, 20 * k) }):Play()
				fade(item.fades, 1, 0.16, (n - 1) * 0.03)
			end
		end
		if header then
			fade(headerFades, 1, 0.12)
		end
		local camera = workspace.CurrentCamera
		local viewY = if camera then camera.ViewportSize.Y else BASE_HEIGHT
		local streak = make("Frame", {
			Name = "Slash",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(-0.6, 0.46),
			Size = UDim2.new(1.6, 0, 0, math.floor(viewY * 0.035)),
			Rotation = -14,
			BackgroundColor3 = Ink.Colors.Cream,
			BorderSizePixel = 0,
			ZIndex = 9,
		}, root) :: Frame
		make("UIGradient", {
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.35, 0.05),
				NumberSequenceKeypoint.new(0.8, 0),
				NumberSequenceKeypoint.new(1, 0.6),
			}),
		}, streak)
		TweenService:Create(streak, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = UDim2.fromScale(1.2, 0.4), BackgroundTransparency = 1 }):Play()
		local flash = make("Frame", { Name = "Flash", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Ink.Colors.Cream, BackgroundTransparency = 0.7, BorderSizePixel = 0, ZIndex = 8 }, root) :: Frame
		TweenService:Create(flash, TweenInfo.new(0.18), { BackgroundTransparency = 1 }):Play()
		task.delay(0.32, function()
			streak:Destroy()
			flash:Destroy()
		end)
		task.delay(0.23, function()
			if open then
				after()
				busy = false
			end
		end)
	end

	local function back()
		if not group or busy then
			return
		end
		local from = group
		swap(function()
			buildTop(true)
			for i, g in groups do
				if g == from then
					light(i, false)
				end
			end
			if options.onHover then
				options.onHover(from.caption)
			end
		end)
	end

	choose = function(i: number)
		if busy or not open then
			return
		end
		if i == 0 then
			back()
			return
		end
		local item = items[i]
		if not item then
			return
		end
		if not group then
			local g = groups[i]
			if g then
				swap(function()
					buildGroup(g)
				end)
			end
			return
		end
		if item.id == BACK then
			back()
		elseif item.enabled then
			options.onPick(item.id)
		else
			local home = item.button.Position
			task.spawn(function()
				for step = 1, 6 do
					if not item.button.Parent then
						return
					end
					item.button.Position = home + UDim2.fromOffset(if step % 2 == 0 then -5 else 5, 0)
					task.wait(0.03)
				end
				item.button.Position = home
			end)
		end
	end

	local follow = RunService.RenderStepped:Connect(place)

	local KEYS: { [Enum.KeyCode]: number } = {
		[Enum.KeyCode.One] = 1,
		[Enum.KeyCode.Two] = 2,
		[Enum.KeyCode.Three] = 3,
		[Enum.KeyCode.Four] = 4,
		[Enum.KeyCode.Five] = 5,
		[Enum.KeyCode.Six] = 6,
		[Enum.KeyCode.Seven] = 7,
		[Enum.KeyCode.Eight] = 8,
		[Enum.KeyCode.Nine] = 9,
	}
	local input = UserInputService.InputBegan:Connect(function(io: InputObject, processed: boolean)
		if processed or busy or not open then
			return
		end
		local key = io.KeyCode
		local n = #items
		if n == 0 then
			return
		end
		if key == Enum.KeyCode.Down or key == Enum.KeyCode.S or key == Enum.KeyCode.DPadDown then
			light(hov % n + 1, true)
		elseif key == Enum.KeyCode.Up or key == Enum.KeyCode.W or key == Enum.KeyCode.DPadUp then
			light((hov - 2) % n + 1, true)
		elseif key == Enum.KeyCode.Return or key == Enum.KeyCode.KeypadEnter or key == Enum.KeyCode.Space or key == Enum.KeyCode.ButtonA then
			choose(hov)
		elseif key == Enum.KeyCode.Escape or key == Enum.KeyCode.Backspace or key == Enum.KeyCode.ButtonB then
			back()
		elseif KEYS[key] and items[KEYS[key]] then
			light(KEYS[key], true)
			choose(KEYS[key])
		end
	end)

	buildTop(true)
	light(1, false)

	local handle = {} :: Handle
	function handle.close(chosen: string?)
		if not open then
			return
		end
		open = false
		follow:Disconnect()
		input:Disconnect()
		bar.Visible = false
		for _, item in items do
			if chosen and item.id == chosen then
				item.wordScale.Scale = 1.35
				TweenService:Create(item.wordScale, TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1.12 }):Play()
				fade(item.fades, 1, 0.12, 0.14)
			else
				fade(item.fades, 1, 0.12)
			end
		end
		if header then
			fade(headerFades, 1, 0.12, 0.08)
		end
		task.delay(0.3, function()
			barT:Destroy()
			root:Destroy()
		end)
	end
	return handle
end

return Menu
