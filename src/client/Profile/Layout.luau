--!strict
-- Screen placement shared by HudController and BuildController, so the "Crew papers" button sits next to the HUD
-- strip at every screen size. Sizes are in design pixels; both are shrunk by hudScale() on small screens.

local GuiService = game:GetService("GuiService")
local Workspace = game:GetService("Workspace")

local Layout = {}

Layout.Margin = 10
Layout.HudWidth = 250
Layout.HudHeight = 138
Layout.ButtonWidth = 150
Layout.ButtonHeight = 44

local function viewport(): Vector2
	local camera = Workspace.CurrentCamera
	if camera then
		local size = camera.ViewportSize
		if size.X > 0 and size.Y > 0 then
			return size
		end
	end
	return Vector2.new(1280, 720)
end

-- Height of Roblox's top bar, which our ScreenGuis ignore (Paper.screen sets IgnoreGuiInset).
function Layout.topInset(): number
	local ok, topLeft = pcall(function()
		local inset = GuiService:GetGuiInset()
		return inset
	end)
	if ok and typeof(topLeft) == "Vector2" then
		return math.max(topLeft.Y, 36)
	end
	return 58
end

-- Top edge of the HUD strip and the button beside it.
function Layout.hudTop(): number
	return Layout.topInset() + 6
end

-- Scale for the HUD strip and its button: full size on a desktop, smaller on phones.
function Layout.hudScale(): number
	local size = viewport()
	return math.clamp(math.min(size.X / 1000, size.Y / 600), 0.75, 1)
end

-- Scale that fits a centred panel of the given design size on the screen.
function Layout.panelScale(width: number, height: number): number
	local size = viewport()
	return math.clamp(math.min((size.X - 16) / width, (size.Y - 16) / height), 0.4, 1)
end

-- Runs `callback` now and again whenever the screen size changes.
function Layout.onViewport(callback: () -> ())
	local sizeConnection: RBXScriptConnection? = nil
	local function hook()
		if sizeConnection then
			sizeConnection:Disconnect()
			sizeConnection = nil
		end
		local camera = Workspace.CurrentCamera
		if camera then
			sizeConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(callback)
		end
		callback()
	end
	Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(hook)
	hook()
end

return Layout
