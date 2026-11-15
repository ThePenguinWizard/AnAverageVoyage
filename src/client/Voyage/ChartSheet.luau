--!strict
-- The sea chart sheet: the current sea's islands as markers joined by dashed lanes, a ship on the current island,
-- the islands in reach highlighted and clickable, fog ("?") over islands too far ahead, the sea's name, a legend,
-- a "Set sail" (ready) button and a close button. Built with the Paper kit; drawn with frames and text only.
--
-- The view table comes from VoyageService (see buildView there). The map is redrawn from scratch on every update
-- and whenever the sheet changes size, which keeps the drawing code simple.

local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Paper = require(Shared:WaitForChild("UI"):WaitForChild("Paper"))
local Config = require(Shared:WaitForChild("Voyage"):WaitForChild("VoyageConfig"))
local Icons = require(script.Parent:WaitForChild("Icons"))

export type Callbacks = {
	Pick: (nodeId: number) -> (),
	Ready: (ready: boolean) -> (),
	Close: () -> (),
}

export type Sheet = {
	show: (view: any) -> (),
	update: (view: any) -> (),
	hide: () -> (),
	isOpen: () -> boolean,
}

local ChartSheet = {}

local HEADER = 56
local FOOTER = 64
local DASH = 8
local GAP = 6
local MIN_TOUCH = 44
local START_X = 0.035 -- where the ship waits before the first island

local function usingGamepad(): boolean
	local last = UserInputService:GetLastInputType()
	return string.sub(last.Name, 1, 7) == "Gamepad"
end

local function numberOr(value: any, fallback: number): number
	return if type(value) == "number" and value == value then value else fallback
end

function ChartSheet.new(gui: ScreenGui, callbacks: Callbacks): Sheet
	local colors = Paper.Colors

	local backdrop = Paper.frame(gui, {
		Name = "ChartBackdrop",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = colors.Ink,
		BackgroundTransparency = 0.45,
		Active = true, -- swallow clicks so the world behind is not clicked through
		Visible = false,
		ZIndex = 10,
	})
	local sheet, content = Paper.sheet(backdrop, {
		Name = "ChartSheet",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -24, 1, -24),
	})
	Paper.make("UISizeConstraint", { MaxSize = Vector2.new(1100, 680) }, sheet)

	local title = Paper.tab(content, "Sea chart", { Position = UDim2.fromOffset(10, 10), Size = UDim2.fromOffset(250, 26) })
	local status = Paper.label(content, "", 20, {
		Position = UDim2.fromOffset(270, 6),
		Size = UDim2.new(1, -270 - 60, 0, 44),
		Font = Paper.Fonts.Hand,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	local closeButton = Paper.button(content, "X", {
		Name = "Close",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 6),
		Size = UDim2.fromOffset(44, 44),
	})

	local map = Paper.frame(content, {
		Name = "Map",
		Position = UDim2.fromOffset(8, HEADER),
		Size = UDim2.new(1, -16, 1, -HEADER - FOOTER),
		BackgroundTransparency = 1,
	})

	local legend = Paper.frame(content, {
		Name = "Legend",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 10, 1, -8),
		Size = UDim2.new(1, -190, 0, 48),
		BackgroundTransparency = 1,
	})
	Paper.make("UIGridLayout", {
		CellSize = UDim2.fromOffset(98, 22),
		CellPadding = UDim2.fromOffset(4, 2),
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
	}, legend)
	local legendKinds = table.clone(Config.KindOrder)
	table.insert(legendKinds, "Fog")
	for order, kind in legendKinds do
		local info = Config.Kinds[kind]
		local entry = Paper.frame(legend, { Name = kind, BackgroundTransparency = 1, LayoutOrder = order })
		local dark = kind == "Boss"
		local swatch = Paper.frame(entry, {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.fromScale(0, 0.5),
			Size = UDim2.fromOffset(20, 20),
			BackgroundColor3 = if dark then colors.Ink else colors.Paper,
		})
		Paper.make("UICorner", { CornerRadius = UDim.new(1, 0) }, swatch)
		Paper.make("UIStroke", { Color = if kind == "Fog" then colors.Pale else colors.Ink, Thickness = 1 }, swatch)
		Icons.draw(swatch, kind, if dark then colors.Ink else colors.Paper)
		Paper.label(entry, if info then info.Label else kind, 13, {
			Position = UDim2.fromOffset(25, 0),
			Size = UDim2.new(1, -25, 1, 0),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextWrapped = false,
		})
	end

	local sailButton = Paper.button(content, "Set sail", {
		Name = "SetSail",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -10, 1, -8),
		Size = UDim2.fromOffset(160, 46),
		TextSize = 18,
	})

	local open = false
	local view: any = nil
	local voteDeadline: number? = nil
	local hint: string? = nil -- a one-off message shown in place of the usual status
	local renderQueued = false
	local tickToken = 0

	local function refreshStatus()
		if not view then
			return
		end
		local crewSize = numberOr(view.CrewSize, 1)
		local pick = numberOr(view.Pick, 0)
		local solo = crewSize <= 1
		local text: string
		if hint then
			text = hint
		elseif view.CanPick ~= true then
			text = "The ship is under way."
		elseif solo then
			text = if pick == 0 then "Pick your heading: tap an island ringed in teal." else "Heading set. Set sail, or ring the ready bell."
		elseif pick ~= 0 then
			text = ("The crew has a heading. Ready: %d of %d."):format(numberOr(view.ReadyCount, 0), crewSize)
		elseif voteDeadline then
			local left = math.max(0, math.ceil(voteDeadline - os.clock()))
			text = if numberOr(view.MyVote, 0) == 0 then ("Vote for a heading (%ds left)."):format(left) else ("Vote cast. Waiting for the crew (%ds)."):format(left)
		else
			text = "Vote for a heading: tap an island ringed in teal."
		end
		status.Text = text

		if solo then
			sailButton.Text = "Set sail"
			sailButton.TextColor3 = if pick ~= 0 then colors.Ink else colors.Pale
		else
			sailButton.Text = if view.Ready == true then "Ready (tap to undo)" else "Ready up"
			sailButton.TextColor3 = colors.Ink
		end
		sailButton.BackgroundColor3 = if view.Ready == true then colors.PaperDark else colors.Paper
	end

	-- A straight lane from a to b, stopping short of both markers. Dashed unless `solid`.
	local function drawLane(a: Vector2, b: Vector2, inset: number, color: Color3, thickness: number, transparency: number, solid: boolean)
		local delta = b - a
		local length = delta.Magnitude
		if length <= inset * 2 + 2 then
			return
		end
		local direction = delta / length
		local from = a + direction * inset
		local usable = length - inset * 2
		local rotation = math.deg(math.atan2(delta.Y, delta.X))
		local function segment(startAt: number, segmentLength: number)
			local middle = from + direction * (startAt + segmentLength / 2)
			Paper.frame(map, {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromOffset(middle.X, middle.Y),
				Size = UDim2.fromOffset(segmentLength, thickness),
				Rotation = rotation,
				BackgroundColor3 = color,
				BackgroundTransparency = transparency,
				ZIndex = 1,
			})
		end
		if solid then
			segment(0, usable)
			return
		end
		local at = 0
		while at < usable do
			segment(at, math.min(DASH, usable - at))
			at += DASH + GAP
		end
	end

	local function drawShip(at: Vector2, lift: number)
		local ship = Paper.frame(map, {
			Name = "Ship",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.fromOffset(at.X, at.Y - lift),
			Size = UDim2.fromOffset(26, 22),
			BackgroundTransparency = 1,
			ZIndex = 4,
		})
		local hull = Paper.frame(ship, {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.fromScale(0.5, 1),
			Size = UDim2.fromOffset(24, 6),
			BackgroundColor3 = colors.Ink,
		})
		Paper.make("UICorner", { CornerRadius = UDim.new(0, 3) }, hull)
		Paper.frame(ship, { Position = UDim2.fromOffset(11, 0), Size = UDim2.fromOffset(2, 16), BackgroundColor3 = colors.Ink })
		Paper.frame(ship, { Position = UDim2.fromOffset(14, 2), Size = UDim2.fromOffset(9, 10), BackgroundColor3 = colors.Teal })
	end

	local function render()
		renderQueued = false
		map:ClearAllChildren()
		if not open or not view or type(view.Nodes) ~= "table" then
			return
		end
		local size = map.AbsoluteSize
		if size.X < 40 or size.Y < 40 then
			return -- not laid out yet; the size-changed signal will call again
		end

		local nodes: { any } = view.Nodes
		local current = numberOr(view.Node, 0)
		local pick = numberOr(view.Pick, 0)
		local myVote = numberOr(view.MyVote, 0)
		local crewSize = numberOr(view.CrewSize, 1)
		local canPick = view.CanPick == true
		local reachable: { any } = if type(view.Reachable) == "table" then view.Reachable else {}
		local voteCounts: { any } = if type(view.VoteCounts) == "table" then view.VoteCounts else {}
		local path: { any } = if type(view.Path) == "table" then view.Path else {}

		local markerSize = math.clamp(math.floor(size.Y * 0.12), 28, 46)
		local showLabels = size.Y >= 300
		local inset = markerSize / 2 + 3

		local function place(node: any): Vector2
			return Vector2.new(numberOr(node.X, 0.5) * size.X, numberOr(node.Y, 0.5) * size.Y)
		end
		local startAt = Vector2.new(START_X * size.X, 0.5 * size.Y)

		local visited: { [number]: boolean } = {}
		local sailed: { [string]: boolean } = {} -- lanes already travelled, as "from>to"
		local previous = 0
		for _, id in path do
			if type(id) == "number" then
				visited[id] = true
				sailed[previous .. ">" .. id] = true
				previous = id
			end
		end
		local inReach: { [number]: number } = {} -- island id -> its index in Reachable
		for index, id in reachable do
			if type(id) == "number" then
				inReach[id] = index
			end
		end

		-- Lanes first, so the markers sit on top of them.
		if current == 0 then
			for _, id in reachable do
				local node = nodes[id]
				if node then
					drawLane(startAt, place(node), inset, colors.Ink, 3, 0, false)
				end
			end
		else
			local first = nodes[path[1]]
			if first then
				drawLane(startAt, place(first), inset, colors.Ink, 3, 0, true)
			end
		end
		for _, node in nodes do
			if type(node) == "table" and type(node.Next) == "table" then
				for _, nextId in node.Next do
					local nextNode = nodes[nextId]
					if nextNode then
						local a, b = place(node), place(nextNode)
						if sailed[node.Id .. ">" .. nextId] then
							drawLane(a, b, inset, colors.Ink, 3, 0, true)
						elseif node.Id == current then
							drawLane(a, b, inset, colors.Ink, 3, 0, false)
						elseif nextNode.Kind == "Fog" or node.Kind == "Fog" then
							drawLane(a, b, inset, colors.Pale, 2, 0, false)
						else
							drawLane(a, b, inset, colors.Ink, 2, 0.5, false)
						end
					end
				end
			end
		end

		-- Islands.
		local buttons: { TextButton } = {}
		local pickedButton: TextButton? = nil
		for _, node in nodes do
			if type(node) ~= "table" then
				continue
			end
			local id: number = node.Id
			local kind: string = if type(node.Kind) == "string" then node.Kind else "Fog"
			local at = place(node)
			local reachIndex = inReach[id]
			local clickable = canPick and reachIndex ~= nil
			local hit = math.max(MIN_TOUCH, markerSize + 8)
			local holderProps = {
				Name = "Island" .. id,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromOffset(at.X, at.Y),
				Size = UDim2.fromOffset(hit, hit),
				BackgroundTransparency = 1,
				ZIndex = 2,
			}
			local holder: GuiObject
			if clickable then
				local button: TextButton = Paper.make("TextButton", holderProps, map)
				button.Text = ""
				button.AutoButtonColor = false
				button.BorderSizePixel = 0
				button.Activated:Connect(function()
					hint = nil
					callbacks.Pick(id)
				end)
				table.insert(buttons, button)
				if id == pick or (pick == 0 and id == myVote) then
					pickedButton = button
				end
				holder = button
			else
				holder = Paper.frame(map, holderProps)
			end

			local dark = kind == "Boss"
			local faded = visited[id] == true or kind == "Fog"
			local fill = if dark then colors.Ink elseif faded then colors.PaperDark else colors.Paper
			local marker = Paper.frame(holder, {
				Name = "Marker",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromOffset(markerSize, markerSize),
				BackgroundColor3 = fill,
			})
			Paper.make("UICorner", { CornerRadius = UDim.new(1, 0) }, marker)
			local stroke: UIStroke = Paper.make("UIStroke", { Color = colors.Ink, Thickness = 2 }, marker)
			if id == pick then
				stroke.Color = colors.Gold
				stroke.Thickness = 5
			elseif reachIndex ~= nil then
				stroke.Color = colors.Teal
				stroke.Thickness = if id == myVote then 5 else 3
				if canPick and id ~= myVote then
					-- A slow pulse marks the islands you can sail to.
					TweenService:Create(stroke, TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Transparency = 0.6 }):Play()
				end
			elseif kind == "Fog" then
				stroke.Color = colors.Pale
			elseif dark then
				stroke.Color = colors.Red
				stroke.Thickness = 3
			end
			Icons.draw(marker, kind, fill)

			if showLabels and kind ~= "Fog" then
				local info = Config.Kinds[kind]
				Paper.label(holder, if info then info.Label else kind, 12, {
					AnchorPoint = Vector2.new(0.5, 0),
					Position = UDim2.new(0.5, 0, 0.5, markerSize / 2 + 3),
					Size = UDim2.fromOffset(90, 14),
					TextWrapped = false,
				})
			end
			if id == pick then
				Paper.label(holder, "Heading", 15, {
					AnchorPoint = Vector2.new(0.5, 1),
					Position = UDim2.new(0.5, 0, 0.5, -markerSize / 2 - 3),
					Size = UDim2.fromOffset(90, 16),
					Font = Paper.Fonts.Hand,
					TextColor3 = colors.Red,
					TextWrapped = false,
				})
			end
			local votes = if reachIndex then numberOr(voteCounts[reachIndex], 0) else 0
			if crewSize > 1 and votes > 0 then
				Paper.tab(holder, tostring(votes), {
					AnchorPoint = Vector2.new(0, 1),
					Position = UDim2.new(0.5, markerSize / 2 - 4, 0.5, -markerSize / 2 + 8),
					Size = UDim2.fromOffset(20, 18),
				})
			end
		end

		-- The ship sits on the island it is at (or at the edge of the sea), unless a heading label is there.
		local shipNode = nodes[current]
		drawShip(if shipNode then place(shipNode) else startAt, markerSize / 2 + 4)

		-- Gamepad order: up and down between the islands in reach, right to "Set sail", left to the close button.
		table.sort(buttons, function(a, b)
			return a.Position.Y.Offset < b.Position.Y.Offset
		end)
		for index, button in buttons do
			button.NextSelectionUp = buttons[index - 1] or closeButton
			button.NextSelectionDown = buttons[index + 1] or sailButton
			button.NextSelectionRight = sailButton
			button.NextSelectionLeft = closeButton
		end
		local focus: GuiObject = pickedButton or buttons[1] or sailButton
		sailButton.NextSelectionLeft = focus
		sailButton.NextSelectionUp = buttons[#buttons] or closeButton
		closeButton.NextSelectionDown = focus
		closeButton.NextSelectionLeft = focus
		if usingGamepad() then
			local selected = GuiService.SelectedObject
			if selected == nil or selected.Parent == nil or not selected:IsDescendantOf(backdrop) or selected:IsDescendantOf(map) then
				GuiService.SelectedObject = focus
			end
		end
	end

	local function queueRender()
		if renderQueued then
			return
		end
		renderQueued = true
		task.defer(render)
	end

	local function apply(newView: any)
		if type(newView) ~= "table" then
			return
		end
		view = newView
		hint = nil
		local left = numberOr(newView.VoteSecondsLeft, -1)
		voteDeadline = if left >= 0 then os.clock() + left else nil
		title.Text = string.upper(("Sea %d of %d  ·  %s"):format(numberOr(newView.Sea, 1), numberOr(newView.SeaCount, 3), tostring(newView.SeaName or "")))
		refreshStatus()
		queueRender()
	end

	local sheetApi = {}

	function sheetApi.show(newView: any)
		apply(newView)
		if open then
			return
		end
		open = true
		backdrop.Visible = true
		queueRender()
		-- Keeps the vote countdown ticking while the chart is open.
		tickToken += 1
		local token = tickToken
		task.spawn(function()
			while open and tickToken == token do
				task.wait(0.5)
				if open and tickToken == token and voteDeadline then
					refreshStatus()
				end
			end
		end)
	end

	function sheetApi.update(newView: any)
		if open then
			apply(newView)
		end
	end

	function sheetApi.hide()
		if not open then
			return
		end
		open = false
		tickToken += 1
		backdrop.Visible = false
		local selected = GuiService.SelectedObject
		if selected and selected:IsDescendantOf(backdrop) then
			GuiService.SelectedObject = nil
		end
		map:ClearAllChildren()
	end

	function sheetApi.isOpen(): boolean
		return open
	end

	closeButton.Activated:Connect(function()
		callbacks.Close()
	end)

	sailButton.Activated:Connect(function()
		if not view or view.CanPick ~= true then
			return
		end
		local solo = numberOr(view.CrewSize, 1) <= 1
		if solo then
			if numberOr(view.Pick, 0) == 0 then
				hint = "Pick a heading first: tap an island ringed in teal."
				refreshStatus()
				return
			end
			callbacks.Ready(true)
		else
			callbacks.Ready(view.Ready ~= true)
		end
	end)

	map:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		if open then
			queueRender()
		end
	end)

	return sheetApi
end

return ChartSheet
