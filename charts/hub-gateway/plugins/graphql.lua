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

local core    = require("apisix.core")
local http    = require("resty.http")
local json    = require("apisix.core.json")

local schema  = {
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
        schema_url = {
            description = "url to fetch the schema from",
            type = "string"
        },
        schema = {
            description = "base64 encoded graphql schema for incoming queries",
            type = "string"
        },
        schema_query = {
            description = "base64 encoded graphql query to get the schema. could be an introspection or sdl query",
            type = "string"
        }
    },
    required = {"host"}
}


local _M = {
    version = 0.1,
    priority = 2001,
    name = "graphql",
    schema = schema,
}


function _M.check_schema(conf)
    return core.schema.check(schema, conf)
end



local function fetch_graphql_schema(conf, ctx)
    local query = ngx.decode_base64(conf.schema_query)

    local params = {
        method = "POST",
        headers = {
            ["Content-Type"] = 'application/json',
            ["Accept"] = "application/json"
        },

        body = '{"query": "'  .. string.gsub(query, '\n', '') .. '"}',
        keepalive = conf.keepalive,
        ssl_verify = conf.ssl_verify
    }

    if conf.keepalive then
        params.keepalive_timeout = conf.keepalive_timeout
        params.keepalive_pool = conf.keepalive_pool
    end

    local endpoint = conf.host
    local httpc = http.new()
    httpc:set_timeout(conf.timeout)

    local res, err = httpc:request_uri(endpoint, params)

    -- block by default when user is not found
    if not res then
        core.log.error("failed to get schema, err: ", err)
        return 403, err
    end

    -- parse the results of the decision
    local data, err = json.decode(res.body)

    if not data then
        core.log.error("invalid response body: ", res.body, " err: ", err)
        return 503, res.body
    end
    local schema = ngx.encode_base64(data.data['_service']['sdl'])
    if not schema then
     core.log.error("invalid response from GraphQL: ", res.body,
                    " err: `_service.sdl` field does not exist")
     return 503, res.body

    end

    return schema
end

function _M.access(conf, ctx)
    local input = core.json.decode(core.request.get_body())
    local data = {
        name = ctx.var.graphql_name,
        operation = ctx.var.graphql_operation,
        root_fields = ctx.var.graphql_root_fields,
        schema = fetch_graphql_schema(conf,ctx),
        query = ngx.encode_base64(core.json.encode(input['query'])),
        variables = input['variables'],
    }
    local input = json.decode(core.request.get_body())
    core.ctx.register_var("gql_data", function(ctx)
          return json.encode(data)
    end)

end

return _M
