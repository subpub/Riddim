local url = require"socket.url";
local json = require"util.json";
local http = require"net.http";

function riddim.plugins.github(bot)
	local conf = bot.config.github;
	local base_url = url.parse("https://api.github.com/repos/x/y/issues/123");
	local base_path = url.parse_path(base_url.path);
	base_path[2], base_path[3] = conf.user, conf.project;

	local ex = {
		headers = {
			Accept = "application/vnd.github.v3+json";
		};
	};

	local function issue_url(number)
		base_path[5] = number;
		base_url.path = url.build_path(base_path);
		local url = url.build(base_url);
		return url;
	end

	bot:hook("commands/issue", function (command)
		local issue_id = tonumber(command.param);
		if not issue_id then return; end
		assert(http.request(issue_url(issue_id), ex, function (issue, code)
			if code > 400 then
				return command:reply("HTTP Error "..code.." :(");
			end
			issue = issue and json.decode(issue);
			if not issue then
				return command:reply("Got invalid JSON back :(");
			end
			command:reply(("%s #%d\n%s"):format(issue.title, issue.number issue.html_url));
		end));
		return true;
	end);

	local function check_for_issue_id(message)
		local issue_id = message.body and message.body:match"#(%d+)";
		if issue_id then
			return bot:event("commands/issue", { param = issue_id, reply = message.reply, });
		end
	end

	bot:hook("message", check_for_issue_id);

	bot:hook("groupchat/joining", function (room)
		room:hook("message", check_for_issue_id);
	end);
end
