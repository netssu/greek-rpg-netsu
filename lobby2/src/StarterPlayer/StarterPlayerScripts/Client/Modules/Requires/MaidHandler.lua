local Maid = {}

function Maid.CleanConnections(tbl)
	for _, conn in ipairs(tbl) do
		if conn and conn.Disconnect then
			conn:Disconnect()
		end
	end
	table.clear(tbl)
end

return Maid