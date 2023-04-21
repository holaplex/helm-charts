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
        login_uri = {
          type = "string"
        },
        redirect_to = {
          type = "boolean",
          default = false
        }
    },
    require = {"login_uri"}
}

local _M = {
    version = 0.1,
    priority = 1,
    name = "session-redirect",
    schema = schema
}

function _M.check_schema(conf)
    return core.schema.check(schema, conf)
end

function _M.access(conf, ctx)
    local redirect_to = conf.redirect_to
    local user_id = core.request.header(ctx, "X-USER-ID")
    local uri = ctx.var.uri
    local redirect_uri = conf.login_uri

    if redirect_to then
      redirect_uri = redirect_uri .. "?return_to=" .. uri
    end

    if not user_id then
        core.response.set_header("Location", redirect_uri)

        return 302, "Unauthorized please login"
    end
end

return _M
