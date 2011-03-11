function riddim.plugins.pubsub(bot)
	bot.stream:add_plugin("pubsub");
	bot.pubsub = bot.stream.pubsub;

	-- Maybe pubsub/event/ns/element or something?
	bot.stream:hook("pubsub/event", function(event)
		return bot:event("pubsub/event", event);
	end);
end
