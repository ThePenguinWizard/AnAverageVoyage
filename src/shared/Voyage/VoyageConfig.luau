--!strict
-- Numbers and names the voyage (sea chart and run loop) uses on both the server and the client.

local VoyageConfig = {}

-- Crew votes (chart picks and event choices): the timer starts with the first vote.
VoyageConfig.VoteSeconds = 12

-- Islands more than this many rows ahead of the ship are drawn as fog. The boss is always marked.
VoyageConfig.FogRows = 2

-- Node kinds in legend order. "Fog" is not a real kind: it is what the client is told about hidden islands.
VoyageConfig.KindOrder = { "Battle", "Elite", "Event", "Rest", "Treasure", "Port", "Boss" }

export type KindInfo = { Label: string, Note: string }

VoyageConfig.Kinds = {
	Battle = { Label = "Battle", Note = "A patrol or a pirate crew. A plain fight." },
	Elite = { Label = "Elite", Note = "A bounty target. Harder, and pays better." },
	Event = { Label = "Event", Note = "Something odd on the water. Your call." },
	Rest = { Label = "Rest", Note = "A quiet cove. Mends some wounds and nerves." },
	Treasure = { Label = "Treasure", Note = "Gold and something useful." },
	Port = { Label = "Port", Note = "A friendly harbour. Full rest before the boss." },
	Boss = { Label = "Boss", Note = "The one who rules this sea." },
	Fog = { Label = "Unknown", Note = "Too far ahead to make out." },
} :: { [string]: KindInfo }

-- Renown (the meta currency) is back-loaded: deeper seas pay far more. A full clear pays 70.
VoyageConfig.SeaRenown = { 5, 15, 30 }
VoyageConfig.BossBonus = { 4, 6, 10 }
-- A lost voyage still pays this share of the sea it ended in, scaled by how far through that sea the crew got.
VoyageConfig.PartialShare = 0.6

export type RenownLine = { Label: string, Amount: number }

-- Renown for a voyage that cleared `seasCleared` whole seas and then `islandsInSea` islands of the next one
-- (out of `rowsInSea`). Returns the total and the lines for the summary sheet.
function VoyageConfig.renown(seasCleared: number, islandsInSea: number, rowsInSea: number): (number, { RenownLine })
	local lines: { RenownLine } = {}
	local total = 0
	local seaCount = #VoyageConfig.SeaRenown
	for sea = 1, math.min(seasCleared, seaCount) do
		local pay = VoyageConfig.SeaRenown[sea]
		local bonus = VoyageConfig.BossBonus[sea] or 0
		table.insert(lines, { Label = ("Sea %d crossed"):format(sea), Amount = pay })
		table.insert(lines, { Label = ("Sea %d boss beaten"):format(sea), Amount = bonus })
		total += pay + bonus
	end
	local nextSea = seasCleared + 1
	if nextSea <= seaCount and islandsInSea > 0 and rowsInSea > 0 then
		local share = math.clamp(islandsInSea / rowsInSea, 0, 1) * VoyageConfig.PartialShare
		local partial = math.max(1, math.floor(VoyageConfig.SeaRenown[nextSea] * share))
		table.insert(lines, { Label = ("Sea %d, %d of %d islands"):format(nextSea, islandsInSea, rowsInSea), Amount = partial })
		total += partial
	end
	return total, lines
end

return VoyageConfig
