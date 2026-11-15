--!strict
-- The parchment card used for narrated events, island results (rest, treasure, port) and the end-of-voyage
-- summary. One card, refilled each time: a name tab, a title, text, handwritten notes and a column of buttons.
-- The content scrolls if the screen is too small for it.

local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Paper = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UI"):WaitForChild("Paper"))

export type Callbacks = {
	Choice: (index: number) -> (),
	Continue: () -> (),
	SummaryContinue: () -> (),
}

export type Card = {
	showEvent: (card: any) -> (),
	showResult: (card: any) -> (),
	showSummary: (summary: any) -> (),
	hide: () -> (),
	isOpen: () -> boolean,
}

local Cards = {}

local function usingGamepad(): boolean
	local last = UserInputService:GetLastInputType()
	return string.sub(last.Name, 1, 7) == "Gamepad"
end

local function textOr(value: any, fallback: string): string
	return if type(value) == "string" then value else fallback
end

local function numberOr(value: any, fallback: number): number
	return if type(value) == "number" and value == value then value else fallback
end

function Cards.new(gui: ScreenGui, callbacks: Callbacks): Card
	local colors = Paper.Colors

	local backdrop = Paper.frame(gui, {
		Name = "CardBackdrop",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = colors.Ink,
		BackgroundTransparency = 0.45,
		Active = true,
		Visible = false,
		ZIndex = 20,
	})
	local sheet, content = Paper.sheet(backdrop, {
		Name = "Card",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -24, 1, -24),
	})
	Paper.make("UISizeConstraint", { MaxSize = Vector2.new(580, 540) }, sheet)

	local scroll: ScrollingFrame = Paper.make("ScrollingFrame", {
		Name = "Scroll",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.fromScale(0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = colors.Ink,
		Selectable = false,
	}, content)

	local open = false
	local order = 0
	local buttons: { TextButton } = {}

	local function clear()
		sheet.Size = UDim2.new(1, -24, 1, -24) -- full height while laying out; present() shrinks it to fit
		scroll:ClearAllChildren()
		Paper.make("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 10),
		}, scroll)
		Paper.make("UIPadding", {
			PaddingTop = UDim.new(0, 14),
			PaddingBottom = UDim.new(0, 14),
			PaddingLeft = UDim.new(0, 16),
			PaddingRight = UDim.new(0, 16),
		}, scroll)
		scroll.CanvasPosition = Vector2.zero
		order = 0
		buttons = {}
	end

	local function nextOrder(): number
		order += 1
		return order
	end

	local function addTab(text: string)
		Paper.tab(scroll, text, { Size = UDim2.fromOffset(190, 24), LayoutOrder = nextOrder() })
	end

	-- A wrapped line of text that grows to fit.
	local function addText(text: string, size: number, props: { [string]: any }?): TextLabel
		local p: { [string]: any } = props or {}
		p.Size = UDim2.new(1, 0, 0, 0)
		p.AutomaticSize = Enum.AutomaticSize.Y
		p.LayoutOrder = nextOrder()
		return Paper.label(scroll, text, size, p)
	end

	local function addButton(text: string, onPressed: (button: TextButton) -> ()): TextButton
		local button = Paper.button(scroll, text, {
			Size = UDim2.new(1, 0, 0, 52),
			TextSize = 16,
			TextWrapped = true,
			LayoutOrder = nextOrder(),
		})
		button.Activated:Connect(function()
			onPressed(button)
		end)
		table.insert(buttons, button)
		return button
	end

	local function present()
		for index, button in buttons do
			button.NextSelectionUp = buttons[index - 1] or buttons[#buttons]
			button.NextSelectionDown = buttons[index + 1] or buttons[1]
		end
		open = true
		backdrop.Visible = true
		if usingGamepad() and buttons[1] then
			GuiService.SelectedObject = buttons[1]
		end
		-- Fit the card to its text instead of always using the full height (short cards had a big empty half).
		task.defer(function()
			if not open then
				return
			end
			local layout = scroll:FindFirstChildOfClass("UIListLayout")
			local contentHeight = (if layout then layout.AbsoluteContentSize.Y else 0) + 28 -- list + top/bottom padding
			local frame = sheet.AbsoluteSize.Y - content.AbsoluteSize.Y -- the sheet's borders
			sheet.Size = UDim2.new(1, -24, 0, math.ceil(contentHeight + frame + 4))
		end)
	end

	local card = {}

	-- An event waiting for a choice. card = { Title, Tag, Text, Choices = { { Label, Cost, Odds } }, CrewSize }
	function card.showEvent(data: any)
		if type(data) ~= "table" then
			return
		end
		clear()
		addTab(textOr(data.Tag, "Event"))
		addText(textOr(data.Title, "Something on the water"), 24)
		addText(textOr(data.Text, ""), 17, { TextXAlignment = Enum.TextXAlignment.Left })

		local crewSize = numberOr(data.CrewSize, 1)
		local waiting: TextLabel? = nil
		local choices: { any } = if type(data.Choices) == "table" then data.Choices else {}
		for index, choice in choices do
			if type(choice) ~= "table" then
				continue
			end
			local label = textOr(choice.Label, "...")
			local notes: { string } = {}
			local cost = numberOr(choice.Cost, 0)
			local odds = numberOr(choice.Odds, -1)
			if cost > 0 then
				table.insert(notes, ("costs %d gold"):format(cost))
			end
			if odds >= 0 then
				table.insert(notes, ("%d%% chance"):format(odds))
			end
			if #notes > 0 then
				label ..= "   (" .. table.concat(notes, ", ") .. ")"
			end
			addButton(label, function(pressed: TextButton)
				for _, other in buttons do
					other.BackgroundColor3 = if other == pressed then colors.PaperDark else colors.Paper
				end
				if waiting and crewSize > 1 then
					waiting.Text = "Vote cast. Waiting for the rest of the crew..."
				end
				callbacks.Choice(index)
			end)
		end
		waiting = addText(if crewSize > 1 then "The crew votes on this one." else "", 18, { Font = Paper.Fonts.Hand, TextColor3 = colors.Teal })
		present()
	end

	-- What happened. card = { Title, Tag, Roll ("Success" | "Failure" | ""), Text, Effects = { string }, Button }
	function card.showResult(data: any)
		if type(data) ~= "table" then
			return
		end
		clear()
		addTab(textOr(data.Tag, "Event"))
		addText(textOr(data.Title, ""), 24)
		local roll = textOr(data.Roll, "")
		if roll ~= "" then
			addText(if roll == "Success" then "The gamble pays off." else "The gamble goes against you.", 20, {
				Font = Paper.Fonts.Hand,
				TextColor3 = if roll == "Success" then colors.Teal else colors.Red,
			})
		end
		addText(textOr(data.Text, ""), 17, { TextXAlignment = Enum.TextXAlignment.Left })
		if type(data.Effects) == "table" then
			for _, line in data.Effects do
				if type(line) == "string" then
					addText(line, 20, { Font = Paper.Fonts.Hand, TextColor3 = colors.Teal })
				end
			end
		end
		addButton(textOr(data.Button, "Continue"), function(pressed: TextButton)
			pressed.BackgroundColor3 = colors.PaperDark
			callbacks.Continue()
		end)
		present()
	end

	-- The end of a voyage. summary = { Completed, Sea, SeaCount, SeaName, SeasCleared, Islands, Renown, Lines }
	function card.showSummary(data: any)
		if type(data) ~= "table" then
			return
		end
		clear()
		local completed = data.Completed == true
		local seaCount = numberOr(data.SeaCount, 3)
		addTab("Voyage's end")
		addText(if completed then "Every sea crossed" else "Lost at sea", 26)
		if completed then
			addText("You sailed every sea on the chart and beat everything it sent against you. The chart has run out of paper. Time to draw a new one.", 17, { TextXAlignment = Enum.TextXAlignment.Left })
		else
			addText(("The voyage ends in sea %d, the %s. The sea keeps the gold. The stories are yours, and so is the Renown."):format(numberOr(data.Sea, 1), textOr(data.SeaName, "open water")), 17, { TextXAlignment = Enum.TextXAlignment.Left })
		end
		addText(("Islands cleared: %d      Seas crossed: %d of %d"):format(numberOr(data.Islands, 0), numberOr(data.SeasCleared, 0), seaCount), 16)
		if type(data.Lines) == "table" then
			for _, line in data.Lines do
				if type(line) == "table" then
					addText(("%s:  +%d"):format(textOr(line.Label, "Renown"), numberOr(line.Amount, 0)), 19, { Font = Paper.Fonts.Hand })
				end
			end
		end
		addText(("Renown earned:  +%d"):format(numberOr(data.Renown, 0)), 22, { TextColor3 = colors.Gold })
		addButton("Sail again", function(pressed: TextButton)
			pressed.BackgroundColor3 = colors.PaperDark
			callbacks.SummaryContinue()
		end)
		present()
	end

	function card.hide()
		if not open then
			return
		end
		open = false
		backdrop.Visible = false
		local selected = GuiService.SelectedObject
		if selected and selected:IsDescendantOf(backdrop) then
			GuiService.SelectedObject = nil
		end
	end

	function card.isOpen(): boolean
		return open
	end

	return card
end

return Cards
