local cjson = require("cjson")
local class = require("middleclass")
local http = require("resty.http")
local plugin = require("bunkerweb.plugin")
local utils = require("bunkerweb.utils")

local slack = class("slack", plugin)

function slack:initialize()
	-- Call parent initialize
	plugin.initialize(self, "slack")
end

function slack:log(bypass_use_slack)
	-- Check if slack is enabled
	if not bypass_use_slack then
		if self.variables["USE_SLACK"] ~= "yes" then
			return self:ret(true, "slack plugin not enabled")
		end
	end
	-- Check if request is denied
	local reason = utils.get_reason(self.ctx)
	if reason == nil then
		return self:ret(true, "request not denied")
	end
	-- Compute data
	local data = {}
	data.content = "```Denied request for IP "
		.. self.ctx.bw.remote_addr
		.. " (reason = "
		.. reason
		.. ").\n\nRequest data :\n\n"
		.. ngx.var.request
		.. "\n"
	local headers, err = ngx.req.get_headers()
	if not headers then
		data.content = data.content .. "error while getting headers : " .. err
	else
		for header, value in pairs(headers) do
			data.content = data.content .. header .. ": " .. value .. "\n"
		end
	end
	data.content = data.content .. "```"
	-- Send request
	local hdr
	hdr, err = ngx.timer.at(0, self.send, self, data)
	if not hdr then
		return self:ret(true, "can't create report timer : " .. err)
	end
end

-- luacheck: ignore 212
function slack.send(premature, self, data)
	local httpc, err = http.new()
	if not httpc then
		self.logger:log(ngx.ERR, "can't instantiate http object : " .. err)
	end
	local res, err_http = httpc:request_uri(self.variables["SLACK_WEBHOOK_URL"], {
		method = "POST",
		headers = {
			["Content-Type"] = "application/json",
		},
		body = cjson.encode(data),
	})
	httpc:close()
	if not res then
		self.logger:log(ngx.ERR, "error while sending request : " .. err_http)
	end
	if self.variables["SLACK_RETRY_IF_LIMITED"] == "yes" and res.status == 429 and res.headers["Retry-After"] then
		self.logger:log(ngx.WARN, "slack API is rate-limiting us, retrying in " .. res.headers["Retry-After"] .. "s")
		local hdr
		hdr, err = ngx.timer.at(res.headers["Retry-After"], self.send, self, data)
		if not hdr then
			self.logger:log(ngx.ERR, "can't create report timer : " .. err)
			return
		end
		return
	end
	if res.status < 200 or res.status > 299 then
		self.logger:log(ngx.ERR, "request returned status " .. tostring(res.status))
		return
	end
	self.logger:log(ngx.INFO, "request sent to webhook")
end

function slack:log_default()
	-- Check if slack is activated
	local check, err = utils.has_variable("USE_SLACK", "yes")
	if check == nil then
		return self:ret(false, "error while checking variable USE_slack (" .. err .. ")")
	end
	if not check then
		return self:ret(true, "slack plugin not enabled")
	end
	-- Check if default server is disabled
	check, err = utils.get_variable("DISABLE_DEFAULT_SERVER", false)
	if check == nil then
		return self:ret(false, "error while getting variable DISABLE_DEFAULT_SERVER (" .. err .. ")")
	end
	if check ~= "yes" then
		return self:ret(true, "default server not disabled")
	end
	-- Call log method
	return self:log(true)
end

return slack
