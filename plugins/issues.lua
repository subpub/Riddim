-- Plugin for querying issue-tracker
--
-- Example config:
-- issues = {
--   ["project@conference.example.org"] = "http://example.org/issues/";
-- }

local url = require"socket.url";
local json = require"util.json";
local http = require"net.http";

function riddim.plugins.issues(bot)
	local conf = bot.config.issues;

	local ex = {
		headers = {
			Accept = "application/json";
		};
	};

	local function get_issue_url(base, id)
		local base_url = url.parse(base or "http://localhost:8006/");
		local base_path = url.parse_path(base_url.path);
		base_path[#base_path+1] = "issue";
		base_path[#base_path+1] = id;
		base_path.is_directory = nil;
		base_url.path = url.build_path(base_path);
		return url.build(base_url);
	end

	bot:hook("commands/issue", function (command)
		local issue_id = tonumber(command.param);
		if not issue_id then return; end
		local current_conf = conf[command.room and command.room.jid or "default"];
		if not current_conf then return end
		local issue_url = get_issue_url(current_conf, issue_id);
		http.request(issue_url, ex, function (data, code)
			if code > 400 then
				return command:reply("HTTP Error "..code.." :(");
			end
			data = data and json.decode(data);
			if not data then
				return command:reply("Got invalid JSON back :(");
			end
			local issue = data.issue;
			local tags = {};
			for tag in pairs(issue.tags) do
				table.insert(tags, tag);
			end
			command:reply(("Issue #%d %q {%s}\n%s"):format(issue.id, issue.title, table.concat(tags, ", "), issue_url));
		end);
		return true;
	end);

	local function check_for_issue_id(message)
		local issue_id = message.body and message.body:match"#(%d+)";
		if issue_id then
			return bot:event("commands/issue", { param = issue_id, reply = message.reply, room = message.room });
		end
	end

	bot:hook("groupchat/joining", function (room)
		room:hook("message", check_for_issue_id);
	end);
end
