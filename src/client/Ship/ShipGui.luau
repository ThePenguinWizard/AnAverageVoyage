--!strict
-- The ship camp's screen ("ShipGui"), drawn with the Paper kit: the inventory panel (stash and crew chests), the
-- short station note, and the small ready indicator. ShipController decides when each one shows; this module only
-- builds and updates them. Only one panel (note or inventory) is open at a time.

local GuiService = game:GetService("GuiService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Paper = require(Shared:WaitForChild("UI"):WaitForChild("Paper"))
local ItemLookup = require(Shared:WaitForChild("Ship"):WaitForChild("ItemLookup"))

export type Callbacks = {
	UseItem: (itemId: string) -> (), -- the player pressed "Use" on an item
	Closed: (panel: string) -> (), -- a panel ("Note" or "Inventory") was closed or replaced
}

local ShipGui = {}

local ROW_HEIGHT = 64
local USE_COOLDOWN = 0.3

local player = Players.LocalPlayer

local built = false
local callbacks: Callbacks? = nil
local openPanel: string? = nil
local lastUse = 0

local gui: ScreenGui
local noteSheet: Frame
local noteTitle: TextLabel
local noteBody: TextLabel
local noteClose: TextButton
local invSheet: Frame
local invTitle: TextLabel
local invVitals: TextLabel
local invList: ScrollingFrame
local invEmpty: TextLabel
local invStatus: TextLabel
local invClose: TextButton
local readyChip: Frame
local readyDot: Frame
local readyLabel: TextLabel

-- ------------------------------------------------------------------ helpers

local function usingGamepad(): boolean
	local last = UserInputService:GetLastInputType()
	return string.sub(last.Name, 1, 7) == "Gamepad"
end

local function selectForGamepad(target: GuiObject?)
	if target and usingGamepad() then
		GuiService.SelectedObject = target
	end
end

local function clearSelection()
	local selected = GuiService.SelectedObject
	if selected and selected:IsDescendantOf(gui) then
		GuiService.SelectedObject = nil
	end
end

local function setPanel(name: string?)
	local previous = openPanel
	openPanel = name
	noteSheet.Visible = name == "Note"
	invSheet.Visible = name == "Inventory"
	if previous and previous ~= name then
		clearSelection()
		if callbacks then
			callbacks.Closed(previous)
		end
	end
end

local function numberAttribute(name: string): number?
	local value = player:GetAttribute(name)
	if type(value) == "number" and value == value then
		return value
	end
	return nil
end

-- The player's items from the InventoryJson attribute: { [itemId]: count }.
local function readInventory(): { [string]: number }
	local result: { [string]: number } = {}
	local raw = player:GetAttribute("InventoryJson")
	if type(raw) ~= "string" or raw == "" then
		return result
	end
	local ok, decoded = pcall(function(): any
		return HttpService:JSONDecode(raw)
	end)
	if not ok or type(decoded) ~= "table" then
		return result
	end
	for id, count in decoded do
		if type(id) == "string" and type(count) == "number" and count >= 1 then
			result[id] = math.floor(count)
		end
	end
	return result
end

-- Item ids to list: the catalogue's display order first, then anything it doesn't know, by id.
local function sortedIds(inventory: { [string]: number }): { string }
	local ids: { string } = {}
	local seen: { [string]: boolean } = {}
	local order = ItemLookup.order()
	if order then
		for _, id in order do
			if type(id) == "string" and inventory[id] and not seen[id] then
				seen[id] = true
				table.insert(ids, id)
			end
		end
	end
	local rest: { string } = {}
	for id in inventory do
		if not seen[id] then
			table.insert(rest, id)
		end
	end
	table.sort(rest)
	for _, id in rest do
		table.insert(ids, id)
	end
	return ids
end

local function effectText(itemId: string): string
	local heal, resolve = ItemLookup.effects(itemId)
	local parts: { string } = {}
	if heal > 0 then
		table.insert(parts, ("+%d HP"):format(math.floor(heal + 0.5)))
	end
	if resolve < 0 then
		table.insert(parts, ("Resolve -%d"):format(math.floor(-resolve + 0.5)))
	elseif resolve > 0 then
		table.insert(parts, ("Resolve +%d"):format(math.floor(resolve + 0.5)))
	end
	return table.concat(parts, ", ")
end

local function buildRow(itemId: string, count: number, order: number): TextButton?
	local row = Paper.frame(invList, {
		Name = "Item",
		Size = UDim2.new(1, -12, 0, ROW_HEIGHT),
		BackgroundColor3 = Paper.Colors.PaperDark,
		LayoutOrder = order,
	})
	Paper.make("UIStroke", { Color = Paper.Colors.Pale, Thickness = 1 }, row)

	Paper.label(row, ("%s  x%d"):format(ItemLookup.name(itemId), count), 16, {
		Name = "ItemName",
		Position = UDim2.fromOffset(8, 4),
		Size = UDim2.new(1, -116, 0, 20),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = false,
		TextTruncate = Enum.TextTruncate.AtEnd,
	})

	local description = ItemLookup.description(itemId)
	local effects = effectText(itemId)
	if effects ~= "" then
		description = if description ~= "" then effects .. ". " .. description else effects
	end
	Paper.label(row, description, 14, {
		Name = "Description",
		Font = Paper.Fonts.Hand,
		Position = UDim2.fromOffset(8, 25),
		Size = UDim2.new(1, -116, 0, 35),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextTruncate = Enum.TextTruncate.AtEnd,
	})

	if not ItemLookup.isUsable(itemId) then
		Paper.label(row, ItemLookup.kind(itemId), 14, {
			Name = "Kind",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -8, 0.5, 0),
			Size = UDim2.fromOffset(92, 44),
			TextTransparency = 0.35,
			TextWrapped = false,
		})
		return nil
	end

	local use: TextButton = Paper.button(row, "Use", {
		Name = "Use",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
		Size = UDim2.fromOffset(92, 44),
	})
	use:SetAttribute("ItemId", itemId)
	use.Activated:Connect(function()
		local now = os.clock()
		if now - lastUse < USE_COOLDOWN then
			return
		end
		lastUse = now
		if callbacks then
			callbacks.UseItem(itemId)
		end
	end)
	return use
end

-- ------------------------------------------------------------------ building

local function buildNote()
	local sheet, content = Paper.sheet(gui, {
		Name = "Note",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0.9, 0, 0, 250),
		Active = true,
		Visible = false,
	})
	Paper.make("UISizeConstraint", { MaxSize = Vector2.new(460, 250) }, sheet)
	noteSheet = sheet

	noteTitle = Paper.tab(content, "", {
		Name = "Title",
		Position = UDim2.fromOffset(10, 10),
		Size = UDim2.fromOffset(0, 24),
		AutomaticSize = Enum.AutomaticSize.X,
		TextWrapped = false,
	})
	Paper.make("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }, noteTitle)

	noteBody = Paper.label(content, "", 19, {
		Name = "Body",
		Font = Paper.Fonts.Hand,
		Position = UDim2.fromOffset(14, 44),
		Size = UDim2.new(1, -28, 1, -110),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextScaled = true,
	})
	Paper.make("UITextSizeConstraint", { MinTextSize = 12, MaxTextSize = 20 }, noteBody)

	noteClose = Paper.button(content, "Close", {
		Name = "Close",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -10),
		Size = UDim2.fromOffset(150, 44),
	})
	noteClose.Activated:Connect(function()
		ShipGui.close()
	end)
end

local function buildInventory()
	local sheet, content = Paper.sheet(gui, {
		Name = "Inventory",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.92, 0.84),
		Active = true,
		Visible = false,
	})
	Paper.make("UISizeConstraint", { MaxSize = Vector2.new(560, 520) }, sheet)
	invSheet = sheet

	invTitle = Paper.tab(content, "", {
		Name = "Title",
		Position = UDim2.fromOffset(10, 10),
		Size = UDim2.fromOffset(0, 24),
		AutomaticSize = Enum.AutomaticSize.X,
		TextWrapped = false,
	})
	Paper.make("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }, invTitle)

	invVitals = Paper.label(content, "", 14, {
		Name = "Vitals",
		Position = UDim2.fromOffset(12, 38),
		Size = UDim2.new(1, -24, 0, 20),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = false,
	})

	invList = Paper.make("ScrollingFrame", {
		Name = "Items",
		Position = UDim2.fromOffset(10, 64),
		Size = UDim2.new(1, -20, 1, -128),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Paper.Colors.Ink,
		Selectable = false,
	}, content)
	Paper.make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, invList)
	Paper.make("UIPadding", {
		PaddingLeft = UDim.new(0, 2),
		PaddingTop = UDim.new(0, 2),
		PaddingBottom = UDim.new(0, 2),
	}, invList)

	invEmpty = Paper.label(content, "Nothing stowed here yet.", 18, {
		Name = "Empty",
		Font = Paper.Fonts.Hand,
		Position = UDim2.fromOffset(10, 64),
		Size = UDim2.new(1, -20, 0, 60),
		Visible = false,
	})

	invStatus = Paper.label(content, "", 15, {
		Name = "Status",
		Font = Paper.Fonts.Hand,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 12, 1, -10),
		Size = UDim2.new(1, -154, 0, 44),
		TextXAlignment = Enum.TextXAlignment.Left,
	})

	invClose = Paper.button(content, "Close", {
		Name = "Close",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -10, 1, -10),
		Size = UDim2.fromOffset(120, 44),
	})
	invClose.Activated:Connect(function()
		ShipGui.close()
	end)
end

local function buildReady()
	readyChip = Paper.frame(gui, {
		Name = "Ready",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 64),
		Size = UDim2.fromOffset(250, 34),
		BackgroundColor3 = Paper.Colors.Paper,
		Visible = false,
	})
	Paper.make("UIStroke", { Color = Paper.Colors.Ink, Thickness = 2 }, readyChip)
	readyDot = Paper.frame(readyChip, {
		Name = "Dot",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 10, 0.5, 0),
		Size = UDim2.fromOffset(14, 14),
		BackgroundColor3 = Paper.Colors.Pale,
	})
	Paper.make("UIStroke", { Color = Paper.Colors.Ink, Thickness = 2 }, readyDot)
	readyLabel = Paper.label(readyChip, "", 15, {
		Name = "Text",
		Position = UDim2.fromOffset(34, 0),
		Size = UDim2.new(1, -42, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = false,
	})
end

-- ------------------------------------------------------------------ public

-- Builds the ScreenGui. Yields until PlayerGui exists. Safe to call once.
function ShipGui.build(newCallbacks: Callbacks)
	if built then
		return
	end
	built = true
	callbacks = newCallbacks
	gui = Paper.screen("ShipGui", Paper.Layers.Panel)
	buildReady()
	buildNote()
	buildInventory()
end

-- Which panel is open: "Note", "Inventory" or nil.
function ShipGui.current(): string?
	return openPanel
end

-- Closes whichever panel is open.
function ShipGui.close()
	if built and openPanel ~= nil then
		setPanel(nil)
	end
end

function ShipGui.showNote(title: string, body: string)
	if not built then
		return
	end
	noteTitle.Text = string.upper(title)
	noteBody.Text = body
	setPanel("Note")
	selectForGamepad(noteClose)
end

-- Redraws the item list and the HP / Resolve line from the player's attributes (only while the panel is open).
function ShipGui.refreshInventory()
	if not built or openPanel ~= "Inventory" then
		return
	end

	-- Remember which item the gamepad had selected, so using an item doesn't throw the selection away.
	local selectedId: string? = nil
	local selected = GuiService.SelectedObject
	if selected and selected:IsDescendantOf(invSheet) then
		local id = selected:GetAttribute("ItemId")
		if type(id) == "string" then
			selectedId = id
		end
	end

	for _, child in invList:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	local inventory = readInventory()
	local ids = sortedIds(inventory)
	local firstButton: TextButton? = nil
	local sameButton: TextButton? = nil
	for index, id in ids do
		local button = buildRow(id, inventory[id], index)
		if button then
			firstButton = firstButton or button
			if id == selectedId then
				sameButton = button
			end
		end
	end
	invEmpty.Visible = #ids == 0

	local hp = numberAttribute("HP")
	local maxHp = numberAttribute("MaxHP")
	local resolve = numberAttribute("Resolve")
	local vitals: { string } = {}
	if hp and maxHp then
		table.insert(vitals, ("HP %d / %d"):format(math.floor(hp + 0.5), math.floor(maxHp + 0.5)))
	end
	if resolve then
		table.insert(vitals, ("Resolve %d"):format(math.floor(resolve + 0.5)))
	end
	invVitals.Text = table.concat(vitals, "     ")

	selectForGamepad(sameButton or firstButton or invClose)
end

function ShipGui.openInventory(title: string)
	if not built then
		return
	end
	invTitle.Text = string.upper(title)
	invStatus.Text = ""
	setPanel("Inventory")
	ShipGui.refreshInventory() -- also picks the gamepad selection: the first usable item, or Close
end

-- The line at the bottom of the inventory panel (what using an item did, or why it didn't work).
function ShipGui.setStatus(text: string, good: boolean)
	if not built then
		return
	end
	invStatus.Text = text
	invStatus.TextColor3 = if good then Paper.Colors.Teal else Paper.Colors.Red
end

-- The small ready indicator at the top of the screen.
function ShipGui.setReady(visible: boolean, ready: boolean, count: number, total: number)
	if not built then
		return
	end
	count = math.max(0, math.floor(count + 0.5))
	total = math.max(0, math.floor(total + 0.5))
	readyChip.Visible = visible
	readyDot.BackgroundColor3 = if ready then Paper.Colors.Teal else Paper.Colors.Pale
	readyLabel.TextColor3 = if ready then Paper.Colors.Teal else Paper.Colors.Ink
	if ready then
		readyLabel.Text = ("Ready to sail   %d / %d"):format(count, total)
	else
		readyLabel.Text = ("Ring the bell when ready   %d / %d"):format(count, total)
	end
end

return ShipGui
