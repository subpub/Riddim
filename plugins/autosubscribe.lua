
function riddim.plugins.autosubscribe(bot)
	bot:hook("presence", function (presence)
		if presence.stanza.attr.type ~= 'subscribe' then return nil; end
		bot:send_presence(presence.sender.jid, 'subscribed');
		return false;
	end);
end
