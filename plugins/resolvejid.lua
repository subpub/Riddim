function riddim.plugins.resolvejid(bot)
	function bot:resolvejid(jid, room)
		local nows = jid:match"%S+"
		local trimd = jid:match"^%s*(.-)%s*$"
		if room then
			local occupant = room.occupants[jid]
			or room.occupants[trimd]
			or room.occupants[nows]
			if occupant then return occupant.jid end
		end
		return nows
	end
end
