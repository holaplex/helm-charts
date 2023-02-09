local core   = require("apisix.core")
local http   = require("resty.http")
local json   = require("apisix.core.json")

local schema = {
    type = "object",
    properties = {
        host = {type = "string"},
        ssl_verify = {
            type = "boolean",
            default = true,
        },
        timeout = {
            type = "integer",
            minimum = 1,
            maximum = 60000,
            default = 3000,
            description = "timeout in milliseconds",
        },
        keepalive = {type = "boolean", default = true},
        keepalive_timeout = {type = "integer", minimum = 1000, default = 60000},
        keepalive_pool = {type = "integer", minimum = 1, default = 5},
        redirect_unauthorized = {type = "boolean", default = false},
        redirect_uri = {type = "string"},
    },
    required = {"host"}
}


local _M = {
    version = 0.1,
    priority = 1005,
    name = "hub-orgs",
    schema = schema,
}


function _M.check_schema(conf)
    return core.schema.check(schema, conf)
end

local function build_json_error(code, status, reason)

    core.response.set_header("content", "application/json")
    local res = {
        error = {
          code = code,
          status = status,
          reason = reason
        }
      }
    return json.encode(res)
end

function _M.access(conf, ctx)
    local headers = core.request.headers();
    local user_id = ctx.var.kratos_user_id

    if not user_id then
        local res = build_json_error(500, "Internal server error", "Unable to read user-id from kratos plugin")
        core.log.error("unable to read user-id from kratos plugin")
        return 500, res
    end
    -- Get Org data
    local params = {
        method = "GET",
        headers = {
            ["X-USER-ID"] = user_id,
            ["Content-Type"] = "application/json",
            ["Accept"] = "application/json",
        },
        keepalive = conf.keepalive,
        ssl_verify = conf.ssl_verify
    }
    local org_id = ngx.var['cookie__hub_org'] or headers['x-organization-id']
    if not org_id then
        local res = build_json_error(401, "Unauthorized", "X-Organization-Id header not found")
        core.log.error("Failed to get org id from header or cookie")
        return 401, res
    end

    -- make the call - get affiliations
    local endpoint = conf.host .. "/affiliations"
    local httpc = http.new()
    httpc:set_timeout(conf.timeout)
    local res, err = httpc:request_uri(endpoint, params)

    core.log.error("Getting affiliations from hub-orgs for user: ", user_id)
    -- return 503 if error on response or when parsing
    if not res then
        local res = build_json_error(500, "Internal server error", "Unable to get affiliations")
        core.log.error("Failed to get affiliations. invalid response body: ", res.body, " err: ", err)
        return 500, res
    end

    local affiliations, err = json.decode(res.body)
    if not affiliations then
        local res = build_json_error(404, "Not found", "No affiliations found for user id: " .. user_id)
        return res.status, res
    end

    -- Expose org_id and affiliations on variables: org_id, hub_affiliations
    core.ctx.register_var("org_id", function(ctx)
      return org_id
    end)

    local affiliations = ngx.encode_base64(res.body)
    core.ctx.register_var("hub_affiliations", function(ctx)
      return affiliations
    end)

    core.response.set_header("x-organization-id", org_id)
end

return _M
