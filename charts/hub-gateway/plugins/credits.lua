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
    },
    required = {"host"}
}

local _M = {
    version = 0.1,
    priority = 3,
    name = "credits",
    schema = schema
}

function _M.check_schema(conf)
    return core.schema.check(schema, conf)
end

function _M.access(conf, ctx)

    -- return early if operation is query
    local operation = ctx.var.graphql_operation
    if not operation or operation == "query" then
        return
    end

    local input = json.decode(core.request.get_body())
    local graphql_query = input['query']

    -- Check if query is createOrganization
    if graphql_query:match("createOrganization") then
        core.log.error("Creating Organization. Unable to continue.")
        return
    end

    local org_id = core.request.header(ctx, "X-Organization-Id")

    local params = {
        method = "GET",
        keepalive = conf.keepalive,
        ssl_verify = conf.ssl_verify
    }

    if conf.keepalive then
        params.keepalive_timeout = conf.keepalive_timeout
        params.keepalive_pool = conf.keepalive_pool
    end

    local endpoint = conf.host .. "/internal/organizations/" .. org_id

    local httpc = http.new()
    httpc:set_timeout(conf.timeout)
    local res, err = httpc:request_uri(endpoint, params)

    -- return internal server error if unable to contact credits service
    if err then
        return 500, json.encode({ message = err })
    end

    local data, err_json = json.decode(res.body)

    if err_json then
      return 500, json.encode({ message = err })
    end

    if not data.balance then
        return 500, json.encode({ message = err })
    end

    -- respond the credit balance to the user too
    if conf.expose_credit_balance then
        core.request.set_header(ctx, "X-Credit-Balance", data.balance)
        core.response.set_header(ctx, "X-Credit-Balance", data.balance)
    end
end

return _M
