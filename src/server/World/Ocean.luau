--!strict
-- Fills the world with terrain water and a sand seabed. The waterline is y = 0 (ships and islands are built for it).
-- The server calls build() at startup; it does nothing if the ocean is already there.
-- To bake the ocean into the place so it also shows while editing, run this once in the Studio command bar and save:
--   require(game.ServerScriptService.Server.World.Ocean).build(true)

local RunService = game:GetService("RunService")

local Ocean = {}
Ocean.VERSION = 1
Ocean.SIZE = 3072 -- studs across, a square centred on the origin
Ocean.DEPTH = 48 -- water fills y = -DEPTH .. 0

local CHUNK = 512

function Ocean.isBuilt(): boolean
	return workspace.Terrain:GetAttribute("OceanVersion") == Ocean.VERSION
end

function Ocean.build(force: boolean?): boolean
	if not force and Ocean.isBuilt() then
		return false
	end
	local terrain = workspace.Terrain
	local half = Ocean.SIZE / 2
	local running = RunService:IsRunning()
	for x = -half, half - CHUNK, CHUNK do
		for z = -half, half - CHUNK, CHUNK do
			local cx, cz = x + CHUNK / 2, z + CHUNK / 2
			terrain:FillBlock(
				CFrame.new(cx, -Ocean.DEPTH / 2, cz),
				Vector3.new(CHUNK, Ocean.DEPTH, CHUNK),
				Enum.Material.Water
			)
			terrain:FillBlock(CFrame.new(cx, -Ocean.DEPTH - 2, cz), Vector3.new(CHUNK, 4, CHUNK), Enum.Material.Sand)
			if running then
				task.wait()
			end
		end
	end
	terrain:SetAttribute("OceanVersion", Ocean.VERSION)
	return true
end

return Ocean
