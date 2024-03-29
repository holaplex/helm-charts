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
        expose_client_id = {
            type = "boolean",
            default = false
        },
        expose_owner = {
            type = "boolean",
            default = false
        },
    },
    required = {"host"}
}

local _M = {
    version = 0.1,
    priority = 6,
    name = "oauth2",
    schema = schema
}

function _M.check_schema(conf)
    return core.schema.check(schema, conf)
end

function _M.access(conf, ctx)
    local api_token = core.request.header(ctx, "Authorization")

    if not api_token then
        return 401, json.encode({
          message = "Authorization header not found"
        })
    end

    local params = {
        method = "POST",
        body = "token=" .. api_token,
        headers = {
            ["Content-Type"] = "application/x-www-form-urlencoded"
        },
        keepalive = conf.keepalive,
        ssl_verify = conf.ssl_verify
    }

    if conf.keepalive then
        params.keepalive_timeout = conf.keepalive_timeout
        params.keepalive_pool = conf.keepalive_pool
    end

    local endpoint = conf.host .. "/admin/oauth2/introspect"

    local httpc = http.new()
    httpc:set_timeout(conf.timeout)
    local res, err = httpc:request_uri(endpoint, params)

    -- block by default when introspection failed
    if err then
        return 401, json.encode({
              message = err
            })
    end

    -- parse the introspection data
    local data, err_json = json.decode(res.body)

    if err_json then
        return 401, err
    end

    -- block if token is not active
    if not data.active then
        return 401, json.encode({
            message = "Authorization token is not valid anymore. Please get a new one from the Hub web UI"
        })
    end

    if conf.expose_client_id then
        core.request.set_header(ctx, "X-Client-Id", data.client_id)
        core.response.set_header("X-Client-Id", data.client_id)
    end

    -- Lookup full hydra client data
    local params = {
        method = "GET",
        headers = {
            ["Accept"] = "application/json"
        },
        keepalive = conf.keepalive,
        ssl_verify = conf.ssl_verify
    }

    if conf.keepalive then
        params.keepalive_timeout = conf.keepalive_timeout
        params.keepalive_pool = conf.keepalive_pool
    end

    local endpoint = conf.host .. "/admin/clients/" .. data.client_id

    local res, err = httpc:request_uri(endpoint, params)

    -- block by default when unable to get client data
    if err then
        return 401, json.encode({message = err})
    end

    local data, err = json.decode(res.body)
    if err then
        return 401, err
    end

    -- Expose hydra client owner id on request header
    if conf.expose_owner then
        if not data.owner then
          core.log.error("unable to get owner from response:", json.encode(data))
        end
        core.request.set_header(ctx, "X-Client-Owner-Id", data.owner)

        -- Get kratos user id from hydra client contacts and expose on x-user-id header
        core.request.set_header(ctx, "X-User-Id", data.contacts[1])
        core.response.set_header("X-User-Id", data.contacts[1])
    end
end

return _M
