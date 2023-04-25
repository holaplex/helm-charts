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

local schema = {
    type = "object",
    properties = {
        query_cookie_name = {
            type = "string",
            default = "_hub_org"
        },
        query_header_name = {
            type = "string",
            default = "X-Client-Owner-Id"
        },
        output_header_name = {
            type = "string",
            default = "X-Organization-Id"
        },
    },
}

local _M = {
    version = 0.1,
    priority = 4,
    name = "org-lookup",
    schema = schema
}

function _M.check_schema(conf)
    return core.schema.check(schema, conf)
end

function _M.access(conf, ctx)
    local cookie_name = conf.query_cookie_name
    local cookie_header = "cookie_" .. cookie_name

    -- Get org id from cookie or header
    local cookie_value = ngx.var[cookie_header]
    local client_owner = core.request.header(ctx, conf.query_header_name)

    local org_id = cookie_value or client_owner

    -- Return if no org id is found
    if not org_id then
      return
    end

    -- Move value to header in conf.output_header_name
    core.request.set_header(ctx, conf.output_header_name, org_id)
end

return _M
