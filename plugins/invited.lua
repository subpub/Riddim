function riddim.plugins.invited(bot)
	bot:hook("message", function(event)
		local x = event.stanza:get_child("x", "http://jabber.org/protocol/muc#user");
		if x then -- XEP 45
			local invite = x:get_child("invite");
			if invite then
				bot:join_room(event.stanza.attr.from);
			end
		else -- try XEP 249
			x = event.stanza:get_child("x", "jabber:x:conference");
			if x and x.attr.jid then
				bot:join_room(x.attr.jid);
			end
		end
	end);
end
--TODO
-- Passwords
