local xmlns_muc = "http://jabber.org/protocol/muc";
local xmlns_muc_user = xmlns_muc .. "#user";
local xmlns_jxc = "jabber:x:conference";

function riddim.plugins.invited(bot)
	bot:hook("message", function(event)
		local x = event.stanza:get_child("x", xmlns_muc_user);
		if x then -- XEP 45
			local invite = x:get_child("invite");
			if invite then
				bot:join_room(event.stanza.attr.from);
			end
		else -- try XEP 249
			x = event.stanza:get_child("x", xmlns_jxc);
			if x and x.attr.jid then
				bot:join_room(x.attr.jid);
			end
		end
	end);
end
--TODO
-- Passwords
