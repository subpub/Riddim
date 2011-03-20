
-- bugzilla plugin - Queries a bugzilla instance, via the !bug command, and responds
--                   with the data found.
--                   Requires Bugzilla 3.6 or later, and XMLRPC enabled.
--                   Also requires lua-xmlrpc - see
--                     http://keplerproject.github.com/lua-xmlrpc/

-- Configuration:
--  Define a 'bugzilla' entry pointing to the root of the bugzilla installation,
-- 			e.g. "http://my.bugzilla.example.com"
--  Optionally, if the buzgilla requires authentication, define buigzilla_user and
--  bugzilla_password as well. If they're not defined, it is assumed that authentication
--  is not required.

-- Written by Ciaran Gultnieks <ciaran@ciarang.com> - feel free to contact if it
-- doesn't work!

function riddim.plugins.bugzilla(bot)

	local bugzilla = bot.config.bugzilla
	if not bugzilla then return end

	local bugzilla_x = bugzilla .. "/xmlrpc.cgi"

   require("lxp.lom")
	xh = require("xmlrpc.http")

	bot:hook("commands/bug", function(command)
		if not command.param then return end
		local bug_id = string.match(command.param, "%w+")
		if not bug_id then return end

		local params = {}
		if bot.config.bugzilla_user then
			params.Bugzilla_login = bot.config.bugzilla_user
			params.Bugzilla_password = bot.config.bugzilla_password
		end
		params.permissive = false
		string_array_type = xmlrpc.newArray ("string")
		params.ids = xmlrpc.newTypedValue ( { bug_id }, string_array_type)

		local ok,res = xh.call(bugzilla_x, "Bug.get", params)
		if not ok then
			command:reply("Failed to get bug details - " .. res)
			return
		end

		local bug = res['bugs'][1]
		local desc = bug.summary

		command:reply(
			"Bug " .. bug_id .. " (" .. bug.status .. "/" .. bug.resolution
				.. "): " .. bug.summary .. "  "
				.. bugzilla .. "/show_bug.cgi?id=" .. bug_id
			)
	end)
end

