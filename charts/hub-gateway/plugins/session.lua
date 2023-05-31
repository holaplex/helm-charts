--
-- Licensed to the Apache Software Foundation (ASF) under one or more
-- contributor license agreements.  See the NOTICE file distributed with
-- this work for additional information regarding copyright ownership.
-- The ASF licenses this file to You under the Apache License, Version 2.0
-- (the "License"); you may not use this file except in compliance with
-- the License.  You may obtain a copy of the License at
--
--     http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
--
local core = require("apisix.core")
local http = require("resty.http")
local json = require("apisix.core.json")

local schema = {
    type = "object",
    properties = {
        host = {
            type = "string"
        },
        ssl_verify = {
            type = "boolean",
            default = true
        },
        timeout = {
            type = "integer",
            minimum = 1,
            maximum = 60000,
            default = 3000,
            description = "timeout in milliseconds"
        },
        keepalive = {
            type = "boolean",
            default = true
        },
        keepalive_timeout = {
            type = "integer",
            minimum = 1000,
            default = 60000
        },
        keepalive_pool = {
            type = "integer",
            minimum = 1,
            default = 5
        },
        expose_user_id = {
            type = "boolean",
            default = false
        },
        session_cookie_name = {
            type = "string"
        },
        force_verification = {
            type = "boolean",
            default = false
        },
        verification_uri = {
            type = "string"
        },
    },
    required = {"host"}
}

local _M = {
    version = 0.1,
    priority = 5,
    name = "session",
    schema = schema
}

function _M.check_schema(conf)
    return core.schema.check(schema, conf)
end

function _M.access(conf, ctx)
    local session_cookie_name = string.lower(conf.session_cookie_name or "ory_kratos_session")

    local cookie_header = string.lower("cookie_" .. session_cookie_name)
    local cookie_value = ngx.var[cookie_header]

    -- Try to get session token from $session_cookie_name cookie
    local session_token = cookie_value

    if not session_token then
        return
    end

    local kratos_cookie = session_cookie_name .. "=" .. session_token

    local params = {
        method = "GET",
        headers = {
            ["Cookie"] = kratos_cookie
        },
        keepalive = conf.keepalive,
        ssl_verify = conf.ssl_verify
    }

    if conf.keepalive then
        params.keepalive_timeout = conf.keepalive_timeout
        params.keepalive_pool = conf.keepalive_pool
    end

    local endpoint = conf.host .. "/sessions/whoami"

    local httpc = http.new()
    httpc:set_timeout(conf.timeout)
    local res, err = httpc:request_uri(endpoint, params)

    -- block by default when user is not found
    if not res then
        return 401, json.encode({
              message = err
            })
    end

    -- parse the user data
    local data, err_json = json.decode(res.body)
    if err_json then
        return 401, json.encode({
              message = err
            })

    end

    -- block if user id is not found
    if not data.id then
        return 401, json.encode({
              message = err
            })
    end
    local user_email = data.identity.traits.email
    local user_id = data.identity.id

    if conf.force_verification then
      -- redirect if user address is not verified
      local verified = false
      for i=1, #data.identity.verifiable_addresses do
        if data.identity.verifiable_addresses[i].verified then
            verified = true
            break
        end
      end

      if not verified then
        local redirect_uri = conf.verification_uri .. "?email=" .. user_email .. "&return_to=" .. ctx.var.uri

        core.response.set_header("Location", redirect_uri)
        return 302, "Please verify your account address"
      end
    end

    -- Expose user email and id on headers
    if conf.expose_user_id then
        core.response.set_header("X-User-Id", user_id)
        core.request.set_header(ctx, "X-User-Id", user_id)
        core.request.set_header(ctx, "X-User-Email", user_email)
    end
end

return _M
