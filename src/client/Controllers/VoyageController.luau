--!strict
-- VoyageController: the client side of the voyage (sea chart, event cards, end-of-voyage summary).
-- It only draws what VoyageService sends and reports what the player wants: open or close the chart, pick an
-- island, ready up, an event choice, continue. Everything is decided on the server.
--
-- Messages on ReplicatedStorage.VoyageRemote are listed at the top of VoyageService.
-- Ways to open the chart: the chart table on the ship (ShipService), the "Sea chart" button on the right edge of
-- the screen, M on a keyboard, D-pad right on a gamepad. Gamepad B closes it.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Paper = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UI"):WaitForChild("Paper"))

local VoyageFolder = (script.Parent :: Instance).Parent:WaitForChild("Voyage")
local ChartSheet = require(VoyageFolder:WaitForChild("ChartSheet"))
local Cards = require(VoyageFolder:WaitForChild("Cards"))

local VoyageController = {}

local NOTICE_SECONDS = 4

local player = Players.LocalPlayer
local started = false

function VoyageController.start()
	if started then
		return
	end
	started = true

	local remote = ReplicatedStorage:WaitForChild("VoyageRemote") :: RemoteEvent
	local colors = Paper.Colors

	local gui = Paper.screen("VoyageGui", Paper.Layers.Card)
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	local function locationOf(): string?
		local value = player:GetAttribute("Location")
		return if type(value) == "string" then value else nil
	end

	local function send(...: any)
		remote:FireServer(...)
	end

	-- Sheets ----------------------------------------------------------------------------------------------------------
	local chart = ChartSheet.new(gui, {
		Pick = function(nodeId: number)
			send("PickNode", nodeId)
		end,
		Ready = function(ready: boolean)
			send("Ready", ready)
		end,
		Close = function()
			send("CloseChart")
		end,
	})
	local card = Cards.new(gui, {
		Choice = function(index: number)
			send("EventChoice", index)
		end,
		Continue = function()
			send("EventContinue")
		end,
		SummaryContinue = function()
			send("SummaryContinue")
		end,
	})

	-- "Sea chart" button, shown at camp ------------------------------------------------------------------------------
	local chartButton = Paper.button(gui, if UserInputService.KeyboardEnabled then "Sea chart (M)" else "Sea chart", {
		Name = "OpenChart",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.fromOffset(136, 44),
		Visible = false,
		ZIndex = 1,
	})
	chartButton.Activated:Connect(function()
		send("OpenChart")
	end)

	-- Notice strip: short messages from the voyage ("You set sail", "Spoils: +14 gold") -------------------------------
	local noticeSheet, noticeContent = Paper.sheet(gui, {
		Name = "Notice",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 70),
		Size = UDim2.new(1, -40, 0, 58),
		Visible = false,
		ZIndex = 30,
	})
	Paper.make("UISizeConstraint", { MaxSize = Vector2.new(520, 58) }, noticeSheet)
	local noticeLabel = Paper.label(noticeContent, "", 20, {
		Size = UDim2.fromScale(1, 1),
		Font = Paper.Fonts.Hand,
		TextColor3 = colors.Ink,
		TextScaled = true,
	})
	Paper.make("UITextSizeConstraint", { MaxTextSize = 20, MinTextSize = 11 }, noticeLabel)
	local noticeToken = 0
	local function showNotice(text: string)
		noticeToken += 1
		local token = noticeToken
		noticeLabel.Text = text
		noticeSheet.Visible = true
		task.delay(NOTICE_SECONDS, function()
			if noticeToken == token then
				noticeSheet.Visible = false
			end
		end)
	end

	-- Location decides what may be on screen --------------------------------------------------------------------------
	local function refreshLocation()
		local location = locationOf()
		chartButton.Visible = location == "Ship"
		if location ~= "Chart" and chart.isOpen() then
			chart.hide()
		end
		if location ~= "Event" and card.isOpen() then
			card.hide()
		end
	end
	player:GetAttributeChangedSignal("Location"):Connect(refreshLocation)

	-- Server messages -------------------------------------------------------------------------------------------------
	remote.OnClientEvent:Connect(function(action: any, data: any)
		if action == "ChartOpen" then
			card.hide()
			chart.show(data)
			chartButton.Visible = false
		elseif action == "ChartUpdate" then
			chart.update(data)
		elseif action == "ChartClose" then
			chart.hide()
			chartButton.Visible = locationOf() == "Ship"
		elseif action == "Event" then
			chart.hide()
			card.showEvent(data)
		elseif action == "EventResult" then
			chart.hide()
			card.showResult(data)
		elseif action == "Summary" then
			chart.hide()
			card.showSummary(data)
		elseif action == "Notice" then
			if type(data) == "string" then
				showNotice(data)
			end
		end
	end)

	-- Keyboard and gamepad --------------------------------------------------------------------------------------------
	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		local key = input.KeyCode
		if key == Enum.KeyCode.M or key == Enum.KeyCode.DPadRight then
			if processed then
				return -- typing in chat, or the D-pad is moving the selection
			end
			if chart.isOpen() then
				send("CloseChart")
			elseif locationOf() == "Ship" and not card.isOpen() and GuiService.SelectedObject == nil then
				send("OpenChart")
			end
		elseif key == Enum.KeyCode.ButtonB then
			if chart.isOpen() then
				send("CloseChart")
			end
		end
	end)

	refreshLocation()
end

return VoyageController
