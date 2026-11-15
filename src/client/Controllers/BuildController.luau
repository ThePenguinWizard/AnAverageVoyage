--!strict
-- BuildController: the "Crew papers" panel, where a player picks a weapon style and a crew role (decision D7) and
-- buys the next ship tier with Renown (decision D11). Opened with the on-screen button, the B key or DPadUp, and
-- only while the Player attribute `Location` is "Ship" or not set. Choices are sent to ProfileService through
-- ReplicatedStorage.ProfileRemote; the server validates everything and answers with (action, ok, message).

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Paper = require(Shared:WaitForChild("UI"):WaitForChild("Paper"))
local Data = Shared:WaitForChild("Data")
local Weapons = require(Data:WaitForChild("Weapons"))
local Roles = require(Data:WaitForChild("Roles"))
local Ships = require(Data:WaitForChild("Ships"))

local clientRoot = (script.Parent :: Instance).Parent :: Instance
local Layout = require(clientRoot:WaitForChild("Profile"):WaitForChild("Layout"))

-- Design size of the panel; a UIScale shrinks it to fit small screens.
local PANEL_WIDTH = 780
local PANEL_HEIGHT = 520
local CONTENT_WIDTH = PANEL_WIDTH - 26 -- Paper.sheet's borders take 13 px on each side
local PAD = 14
local TOP = 62 -- top of the three columns
local FOOTER = 408 -- the rule above the ship row

local WEAPON_X, WEAPON_WIDTH = PAD, 180
local ROLE_X, ROLE_WIDTH = 208, 250
local DETAIL_X = 472
local DETAIL_WIDTH = CONTENT_WIDTH - PAD - DETAIL_X

local NO_ROLE = ""
local DEFAULT_STATUS = "Choose how you fight and how you help the crew."
local SEND_COOLDOWN = 0.35
local CONFIRM_SECONDS = 4

local DIM = Paper.Colors.Ink:Lerp(Paper.Colors.Paper, 0.5)

local player = Players.LocalPlayer

local BuildController = {}

local function numberAttribute(name: string): number?
	local value = player:GetAttribute(name)
	if type(value) == "number" and value == value then
		return value
	end
	return nil
end

local function stringAttribute(name: string): string?
	local value = player:GetAttribute(name)
	if type(value) == "string" then
		return value
	end
	return nil
end

local function isAboard(): boolean
	local location = player:GetAttribute("Location")
	return location == nil or location == "Ship"
end

local function currentWeapon(): string
	local weaponId = stringAttribute("Weapon")
	if weaponId then
		local def = Weapons.get(weaponId)
		if def and def.Available then
			return weaponId
		end
	end
	return Weapons.Default
end

local function currentRole(): string
	local roleId = stringAttribute("CrewRole")
	if roleId and Roles.get(roleId) then
		return roleId
	end
	return NO_ROLE
end

-- Another player in the crew who already holds this role, if any.
local function roleHolder(roleId: string): Player?
	if roleId == NO_ROLE then
		return nil
	end
	for _, other in Players:GetPlayers() do
		if other ~= player and other:GetAttribute("CrewRole") == roleId then
			return other
		end
	end
	return nil
end

local function usingGamepad(): boolean
	local last = UserInputService:GetLastInputType()
	return string.sub(last.Name, 1, 7) == "Gamepad"
end

function BuildController.start()
	local found = ReplicatedStorage:WaitForChild("ProfileRemote", 30)
	if not found or not found:IsA("RemoteEvent") then
		warn("[BuildController] ProfileRemote is missing, so the Crew papers panel is unavailable")
		return
	end
	local remote: RemoteEvent = found

	local gui = Paper.screen("BuildGui", Paper.Layers.Panel)

	-- The small button beside the HUD strip -------------------------------------------------------------------------
	local toggle = Paper.button(gui, if UserInputService.KeyboardEnabled then "Crew papers (B)" else "Crew papers", {
		Name = "ToggleButton",
		Size = UDim2.fromOffset(Layout.ButtonWidth, Layout.ButtonHeight),
		TextSize = 14,
	})
	local toggleScale: UIScale = Paper.make("UIScale", {}, toggle)

	-- The panel -------------------------------------------------------------------------------------------------------
	local panel, content = Paper.sheet(gui, {
		Name = "CrewPapers",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(PANEL_WIDTH, PANEL_HEIGHT),
		Active = true, -- clicks on the paper don't fall through to the world
		Visible = false,
	})
	local panelScale: UIScale = Paper.make("UIScale", {}, panel)

	Layout.onViewport(function()
		local scale = Layout.hudScale()
		toggleScale.Scale = scale
		toggle.Position = UDim2.fromOffset(Layout.Margin + Layout.HudWidth * scale + 8, Layout.hudTop())
		panelScale.Scale = Layout.panelScale(PANEL_WIDTH + 8, PANEL_HEIGHT + 8)
	end)

	-- Header
	Paper.label(content, "Crew papers", 24, {
		Position = UDim2.fromOffset(PAD, 6),
		Size = UDim2.fromOffset(200, 36),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = false,
	})
	local status = Paper.label(content, DEFAULT_STATUS, 17, {
		Name = "Status",
		Position = UDim2.fromOffset(220, 8),
		Size = UDim2.fromOffset(CONTENT_WIDTH - 220 - PAD - 44 - 8, 34),
		Font = Paper.Fonts.Hand,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = false,
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
	local closeButton = Paper.button(content, "X", {
		Name = "CloseButton",
		Position = UDim2.fromOffset(CONTENT_WIDTH - PAD - 44, 4),
		Size = UDim2.fromOffset(44, 44),
		TextSize = 18,
	})
	Paper.frame(content, {
		Position = UDim2.fromOffset(PAD, 53),
		Size = UDim2.fromOffset(CONTENT_WIDTH - PAD * 2, 1),
		BackgroundColor3 = Paper.Colors.Ink,
	})

	-- Weapon column: one button per style that can be chosen now, and a note listing the ones to come.
	Paper.tab(content, "Weapon style", {
		Position = UDim2.fromOffset(WEAPON_X, TOP),
		Size = UDim2.fromOffset(WEAPON_WIDTH, 22),
	})
	local weaponButtons: { [string]: TextButton } = {}
	local comingSoon: { string } = {}
	local weaponRow = 0
	for _, weaponId in Weapons.Order do
		local def = Weapons.get(weaponId)
		if def and def.Available then
			weaponButtons[weaponId] = Paper.button(content, def.Name, {
				Name = "Weapon" .. weaponId,
				Position = UDim2.fromOffset(WEAPON_X, TOP + 30 + weaponRow * 50),
				Size = UDim2.fromOffset(WEAPON_WIDTH, 44),
				TextSize = 16,
			})
			weaponRow += 1
		elseif def then
			table.insert(comingSoon, def.Name)
		end
	end
	if #comingSoon > 0 then
		Paper.label(content, "Still to come: " .. table.concat(comingSoon, ", ") .. ".", 15, {
			Position = UDim2.fromOffset(WEAPON_X, TOP + 30 + weaponRow * 50 + 4),
			Size = UDim2.fromOffset(WEAPON_WIDTH, 96),
			Font = Paper.Fonts.Hand,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
		})
	end

	-- Role column: a two-wide grid of roles, then "No role".
	Paper.tab(content, "Crew role", {
		Position = UDim2.fromOffset(ROLE_X, TOP),
		Size = UDim2.fromOffset(ROLE_WIDTH, 22),
	})
	local roleButtons: { [string]: TextButton } = {}
	local roleCount = 0
	for _, roleId in Roles.Order do
		local def = Roles.get(roleId)
		if def then
			local column = roleCount % 2
			local row = math.floor(roleCount / 2)
			roleButtons[roleId] = Paper.button(content, def.Name, {
				Name = "Role" .. roleId,
				Position = UDim2.fromOffset(ROLE_X + column * 128, TOP + 30 + row * 50),
				Size = UDim2.fromOffset(122, 44),
				TextSize = 14,
			})
			roleCount += 1
		end
	end
	local roleRows = math.ceil(roleCount / 2)
	roleButtons[NO_ROLE] = Paper.button(content, "No role", {
		Name = "RoleNone",
		Position = UDim2.fromOffset(ROLE_X, TOP + 30 + roleRows * 50),
		Size = UDim2.fromOffset(ROLE_WIDTH, 44),
		TextSize = 14,
	})
	Paper.label(content, "One of each role per crew. Whoever signs first gets it.", 15, {
		Position = UDim2.fromOffset(ROLE_X, TOP + 30 + (roleRows + 1) * 50 + 2),
		Size = UDim2.fromOffset(ROLE_WIDTH, 40),
		Font = Paper.Fonts.Hand,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
	})

	-- Details column: what the highlighted weapon and role do.
	Paper.tab(content, "What they do", {
		Position = UDim2.fromOffset(DETAIL_X, TOP),
		Size = UDim2.fromOffset(DETAIL_WIDTH, 22),
	})
	local details: ScrollingFrame = Paper.make("ScrollingFrame", {
		Name = "Details",
		Position = UDim2.fromOffset(DETAIL_X, TOP + 28),
		Size = UDim2.fromOffset(DETAIL_WIDTH, FOOTER - 8 - (TOP + 28)),
		BackgroundColor3 = Paper.Colors.PaperDark,
		BackgroundTransparency = 0.4,
		BorderSizePixel = 0,
		CanvasSize = UDim2.fromOffset(0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = Paper.Colors.Ink,
		Selectable = false,
	}, content)
	Paper.make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 5) }, details)
	Paper.make("UIPadding", {
		PaddingLeft = UDim.new(0, 8),
		PaddingRight = UDim.new(0, 10),
		PaddingTop = UDim.new(0, 6),
		PaddingBottom = UDim.new(0, 6),
	}, details)

	local detailOrder = 0
	local function detailLine(size: number, font: Enum.Font, rich: boolean): TextLabel
		detailOrder += 1
		return Paper.label(details, "", size, {
			LayoutOrder = detailOrder,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Font = font,
			RichText = rich,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
		})
	end
	local weaponTitle = detailLine(17, Paper.Fonts.Serif, false)
	local weaponRank = detailLine(13, Paper.Fonts.Serif, true)
	local weaponMinigame = detailLine(13, Paper.Fonts.Serif, true)
	local weaponIdentity = detailLine(13, Paper.Fonts.Serif, true)
	detailOrder += 1
	Paper.frame(details, {
		LayoutOrder = detailOrder,
		Size = UDim2.new(1, 0, 0, 1),
		BackgroundColor3 = Paper.Colors.Pale,
	})
	local roleTitle = detailLine(17, Paper.Fonts.Serif, false)
	local roleAction = detailLine(13, Paper.Fonts.Serif, true)
	local roleHelp = detailLine(13, Paper.Fonts.Serif, true)
	local rolePerk = detailLine(13, Paper.Fonts.Serif, true)
	local roleNote = detailLine(15, Paper.Fonts.Hand, false)

	-- Footer: the ship and the two action buttons.
	Paper.frame(content, {
		Position = UDim2.fromOffset(PAD, FOOTER),
		Size = UDim2.fromOffset(CONTENT_WIDTH - PAD * 2, 1),
		BackgroundColor3 = Paper.Colors.Ink,
	})
	local shipTitle = Paper.label(content, "", 14, {
		Name = "ShipTitle",
		Position = UDim2.fromOffset(PAD, FOOTER + 6),
		Size = UDim2.fromOffset(340, 20),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = false,
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
	local shipNote = Paper.label(content, "", 15, {
		Name = "ShipNote",
		Position = UDim2.fromOffset(PAD, FOOTER + 28),
		Size = UDim2.fromOffset(340, 54),
		Font = Paper.Fonts.Hand,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
	})
	local buyButton = Paper.button(content, "", {
		Name = "BuyShipButton",
		Position = UDim2.fromOffset(362, FOOTER + 16),
		Size = UDim2.fromOffset(190, 54),
		TextSize = 14,
		TextWrapped = true,
	})
	local signButton = Paper.button(content, "Sign the papers", {
		Name = "SignButton",
		Position = UDim2.fromOffset(562, FOOTER + 16),
		Size = UDim2.fromOffset(CONTENT_WIDTH - PAD - 562, 54),
		TextSize = 16,
	})

	-- State -----------------------------------------------------------------------------------------------------------
	local open = false
	local pendingWeapon = currentWeapon()
	local pendingRole = currentRole()
	local confirmingBuy = false
	local confirmToken = 0
	local lastSend = 0

	local function setStatus(text: string, good: boolean?)
		status.Text = text
		status.TextColor3 = if good == nil then Paper.Colors.Ink elseif good then Paper.Colors.Teal else Paper.Colors.Red
	end

	local function styleChoice(button: TextButton, selected: boolean, dimmed: boolean)
		button.BackgroundColor3 = if selected then Paper.Colors.Ink else Paper.Colors.Paper
		button.TextColor3 = if selected then Paper.Colors.Paper elseif dimmed then DIM else Paper.Colors.Ink
	end

	local function refreshChoices()
		for weaponId, button in weaponButtons do
			styleChoice(button, weaponId == pendingWeapon, false)
		end
		for roleId, button in roleButtons do
			styleChoice(button, roleId == pendingRole, roleHolder(roleId) ~= nil)
		end
	end

	local function refreshDetails()
		local weapon = Weapons.get(pendingWeapon)
		if weapon then
			weaponTitle.Text = weapon.Name
			weaponRank.Text = "<b>Stands:</b> " .. weapon.Rank
			weaponMinigame.Text = "<b>Attack:</b> " .. weapon.Minigame
			weaponIdentity.Text = "<b>Style:</b> " .. weapon.Identity
		end

		local role = if pendingRole ~= NO_ROLE then Roles.get(pendingRole) else nil
		roleAction.Visible = role ~= nil
		roleHelp.Visible = role ~= nil
		rolePerk.Visible = role ~= nil
		if role then
			roleTitle.Text = role.Name
			roleAction.Text = "<b>Your turn:</b> " .. role.Action
			roleHelp.Text = "<b>A crewmate's dodge:</b> " .. role.DodgeHelp
			rolePerk.Text = "<b>Voyage:</b> " .. role.VoyagePerk
			local holder = roleHolder(pendingRole)
			roleNote.Visible = holder ~= nil
			roleNote.Text = if holder then ("Held by %s."):format(holder.DisplayName) else ""
		else
			roleTitle.Text = "No role"
			roleNote.Visible = true
			roleNote.Text = "Sail without a role for now. None is required: a crew can win without any one of them."
		end
	end

	local function shipState(): (number, number)
		local tier = math.clamp(math.floor(numberAttribute("ShipTier") or 1), 1, Ships.MaxTier)
		local renown = math.floor(numberAttribute("Renown") or 0)
		return tier, renown
	end

	local function refreshShip()
		local tier, renown = shipState()
		local ship = Ships.Tiers[tier]
		if ship then
			shipTitle.Text = ("Your ship: %s (tier %d) · %d Renown"):format(ship.Name, tier, renown)
		end
		local nextShip = Ships.Tiers[tier + 1]
		if nextShip then
			local affordable = renown >= nextShip.Cost
			shipNote.Text = ("Next: the %s. %s"):format(nextShip.Name, nextShip.Adds)
			if confirmingBuy and affordable then
				buyButton.Text = ("Confirm: spend\n%d Renown?"):format(nextShip.Cost)
				buyButton.BackgroundColor3 = Paper.Colors.Gold
			else
				buyButton.Text = ("Buy the %s\n%d Renown"):format(nextShip.Name, nextShip.Cost)
				buyButton.BackgroundColor3 = Paper.Colors.Paper
			end
			buyButton.TextColor3 = if confirmingBuy and affordable then Paper.Colors.Paper
				elseif affordable then Paper.Colors.Ink
				else DIM
		else
			shipNote.Text = "The largest ship afloat. There is nothing more to buy."
			buyButton.Text = "Fully fitted"
			buyButton.BackgroundColor3 = Paper.Colors.Paper
			buyButton.TextColor3 = DIM
		end
	end

	local function refreshSign()
		local unsigned = pendingWeapon ~= currentWeapon() or pendingRole ~= currentRole()
		signButton.Text = if unsigned then "Sign the papers" else "Papers in order"
		signButton.BackgroundColor3 = if unsigned then Paper.Colors.Red else Paper.Colors.Paper
		signButton.TextColor3 = if unsigned then Paper.Colors.Paper else DIM
	end

	local function refreshAll()
		refreshChoices()
		refreshDetails()
		refreshShip()
		refreshSign()
	end

	local function send(...: any): boolean
		local now = os.clock()
		if now - lastSend < SEND_COOLDOWN then
			return false
		end
		lastSend = now
		remote:FireServer(...)
		return true
	end

	local function setOpen(value: boolean)
		if value and not isAboard() then
			return
		end
		if open == value then
			return
		end
		open = value
		panel.Visible = value
		if value then
			pendingWeapon = currentWeapon()
			pendingRole = currentRole()
			confirmingBuy = false
			setStatus(DEFAULT_STATUS)
			refreshAll()
			if usingGamepad() then
				GuiService.SelectedObject = weaponButtons[pendingWeapon] or closeButton
			end
		else
			local selected = GuiService.SelectedObject
			if selected and selected:IsDescendantOf(panel) then
				GuiService.SelectedObject = nil
			end
		end
	end

	local function refreshLocation()
		local aboard = isAboard()
		toggle.Visible = aboard
		if not aboard and open then
			setOpen(false)
		end
	end

	-- Buttons ---------------------------------------------------------------------------------------------------------
	toggle.Activated:Connect(function()
		setOpen(not open)
	end)
	closeButton.Activated:Connect(function()
		setOpen(false)
	end)

	for weaponId, button in weaponButtons do
		button.Activated:Connect(function()
			pendingWeapon = weaponId
			setStatus(DEFAULT_STATUS)
			refreshAll()
		end)
	end

	for roleId, button in roleButtons do
		button.Activated:Connect(function()
			pendingRole = roleId
			local holder = roleHolder(roleId)
			if holder then
				setStatus(("%s already holds that role."):format(holder.DisplayName), false)
			else
				setStatus(DEFAULT_STATUS)
			end
			refreshAll()
		end)
	end

	signButton.Activated:Connect(function()
		if pendingWeapon == currentWeapon() and pendingRole == currentRole() then
			setStatus("Your papers are already in order.", true)
			return
		end
		if send("SetBuild", pendingWeapon, pendingRole) then
			setStatus("Signing...")
		end
	end)

	buyButton.Activated:Connect(function()
		local tier, renown = shipState()
		local nextShip = Ships.Tiers[tier + 1]
		if not nextShip then
			setStatus("Your ship is already the largest there is.", false)
			return
		end
		if renown < nextShip.Cost then
			setStatus(("The %s costs %d Renown; you have %d."):format(nextShip.Name, nextShip.Cost, renown), false)
			return
		end
		if not confirmingBuy then
			-- First press arms the button; a second press within a few seconds spends the Renown.
			confirmingBuy = true
			confirmToken += 1
			local token = confirmToken
			refreshShip()
			task.delay(CONFIRM_SECONDS, function()
				if confirmingBuy and confirmToken == token then
					confirmingBuy = false
					refreshShip()
				end
			end)
			return
		end
		confirmingBuy = false
		refreshShip()
		if send("BuyShipTier") then
			setStatus("Buying...")
		end
	end)

	-- Server answers and live attribute changes -----------------------------------------------------------------------
	remote.OnClientEvent:Connect(function(_action: any, ok: any, message: any)
		if type(message) == "string" then
			setStatus(message, ok == true)
		end
		if open then
			refreshAll()
		end
	end)

	for _, name in { "Weapon", "CrewRole", "Renown", "ShipTier" } do
		player:GetAttributeChangedSignal(name):Connect(function()
			if open then
				refreshAll()
			end
		end)
	end
	player:GetAttributeChangedSignal("Location"):Connect(refreshLocation)

	-- Other players' roles decide which roles are taken.
	local function watchCrewmate(other: Player)
		if other == player then
			return
		end
		other:GetAttributeChangedSignal("CrewRole"):Connect(function()
			if open then
				refreshAll()
			end
		end)
	end
	for _, other in Players:GetPlayers() do
		watchCrewmate(other)
	end
	Players.PlayerAdded:Connect(watchCrewmate)
	Players.PlayerRemoving:Connect(function()
		task.delay(0.2, function()
			if open then
				refreshAll()
			end
		end)
	end)

	-- Keyboard and gamepad --------------------------------------------------------------------------------------------
	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if input.KeyCode == Enum.KeyCode.B then
			if not processed then -- not while typing in chat
				setOpen(not open)
			end
		elseif input.KeyCode == Enum.KeyCode.DPadUp then
			if not open then
				if not processed then
					setOpen(true)
				end
			elseif GuiService.SelectedObject == nil then
				GuiService.SelectedObject = weaponButtons[pendingWeapon] or closeButton
			end
		elseif input.KeyCode == Enum.KeyCode.ButtonB then
			if open then
				setOpen(false)
			end
		end
	end)

	refreshLocation()
	refreshAll()
end

return BuildController
