local http = require "net.http";
local t_insert, t_remove = table.insert, table.remove;
local now = os.time;

local debug = function() end;

local ttl = 3600;
local data = {
	rfc = {
		source = "http://www.ietf.org/download/rfc-index.txt",
		links = "http://tools.ietf.org/html/rfc%s",
	},
	draft = {
		source = "http://www.ietf.org/download/id-index.txt",
		links = "http://tools.ietf.org/html/%s",
	},
}


function data.rfc:update(cb)
	debug("fetch %s", self.source);
	http.request(self.source, {
		headers = {
			["If-Modified-Since"] = self.updated_at
				and os.date("!%a, %d %b %Y %H:%M:%S %Z", self.updated_at) or nil;
		}
	}, function (data, code)
		debug("got status %d", code);
		if code == 200 then
			debug("got %d bytes of data", #data);
			self.data = data
					:gsub("\n\n[^\n]+%b()\n%-+\n\n", "\n\n")
					:gsub("\n     ", " ")
					:gsub("\n\n  ", "\n")
					:gsub("\n  ", " ");
					-- TODO Can this be made better?
			self.updated_at = now();
		end
		self.expires = now() + ttl;
		cb();
	end);
end

data.draft.update = data.rfc.update;

function data.rfc:_search(string, cb)
	debug("really search for %s", string);
	local number = tonumber(string);
	local link, match, matches;
	if number then
		number = ("%04d"):format(number);
		debug("search for RFC%s", number);
		link, match = self.data:match("\n(" .. number .. ")%s*([^\n]*)");
	else
		local pat = string:gsub("[()]", function(s) return "%" .. s end)
			:gsub("[%[]",function(s) return "%" .. s end)
			:gsub("%%(%b[])",function(s) return (#s > 2 and "" or "%") .. s end)
			:gsub("\n+", " "):gsub("\\n", "");
		debug("fulltext search for \"%s\"", pat);
		--link, match = self.data:match("\n(%d%d%d%d) ([^\n]-"..pat.."[^\n]*)");
		for l,m in self.data:gmatch("\n(%d%d%d%d) ([^\n]-"..pat.."[^\n]*)") do
			link, match = l, m
			-- Note: This allways returns the last result.
			-- FIXME Decide on what to do if >1 results.
		end
		--[[
		matches = {};
		for link, match in g do
			t_insert(matches, {link=link, match=match});
		end
		matches = t_remove(matches);
		matches.link, matches.match;
		--]]
	end

	if match then
		debug("matched %d bytes, number is %s", #match, link);
		if #match > 300 then
			cb("Match was too big");
			return
		end
		local remove = {
			Also = true,
			Format = true,
			--Obsoleted = true,
			Obsoletes = true,
			--Updated = true,
			Updates = true,
			--Status = true,
		};
		match = match:gsub("%s*\n%s+", " ")
		match = match:gsub("%s*%b()", function(s)
			local first = s:match("%(([^: ]*)"); return first and remove[first] and "" or s
		end);
		link = self.links:format(link);
		match = match:gsub("%. ", ".\n", 1); -- Add a newline between title and authors
		cb(match .. "\n" .. link);
	else
		cb("Sorry, no match");
	end
end

function data.draft:_search(string, cb)
	debug("really search for %s", string);
	local pat = string:gsub("[()]", function(s) return "%" .. s end)
		:gsub("[%[]",function(s) return "%" .. s end)
		:gsub("%%(%b[])",function(s) return (#s > 2 and "" or "%") .. s end)
		:gsub("\n+", " "):gsub("\\n", "");
	debug("fulltext search for \"%s\"", pat);
	local match = self.data:match("\n([^\n]-"..pat.."[^\n]*)")

	if match then
		debug("match: %s", match);
		local match, link = match:match("(.-)%s(%b<>)")
		link = link and self.links:format(link:sub(2,-2)) or "no link";
		cb(match .. "\n" .. link);
	else
		cb("Sorry, no match");
	end
end

function data.rfc:search(string, cb)
	debug("search for %s", string);
	if not self.data then --or self.expires < now() then
		self:update(function() self:_search(string,cb) end);
		return
	else
		self:_search(string,cb)
	end
end

data.draft.search = data.rfc.search;


function riddim.plugins.ietf(bot)
	if bot.stream.debug then
		function debug(...)
			return bot.stream:debug(...)
		end
	end

	bot:hook("commands/rfc", function(command)
		local rfc = data.rfc;
		debug("search for %s", command.param);
		return rfc:search(command.param, function(match)
			command:reply(match)
		end)
	end)

	bot:hook("commands/draft", function(command)
		local draft = data.draft;
		debug("search for %s", command.param);
		return draft:search(command.param, function(match)
			command:reply(match)
		end)
	end)
end
