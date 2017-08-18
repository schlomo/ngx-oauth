---------
-- Module for configuration loading.

local util = require 'ngx-oauth.util'

local contains        = util.contains
local is_absolute_url = util.is_absolute_url
local is_empty        = util.is_empty
local map             = util.map
local par             = util.partial
local starts_with     = util.starts_with

local DEFAULTS = {
  client_id         = os.getenv('NGX_OAUTH_CLIENT_ID') or '',
  client_secret     = os.getenv('NGX_OAUTH_CLIENT_SECRET') or '',
  scope             = os.getenv('NGX_OAUTH_SCOPE') or '',
  redirect_uri      = os.getenv('NGX_OAUTH_REDIRECT_URI') or '/_oauth/callback',
  oaas_uri          = os.getenv('NGX_OAUTH_OAAS_URI') or '',  -- used only as a shorthand for setting these 3 below
  authorization_url = os.getenv('NGX_OAUTH_AUTHORIZATION_URL') or '${oaas_uri}/authorize',
  token_url         = os.getenv('NGX_OAUTH_TOKEN_URL') or '${oaas_uri}/token',
  userinfo_url      = os.getenv('NGX_OAUTH_USERINFO_URL') or "${oaas_uri}/userinfo",
  userinfo_field    = os.getenv('NGX_OAUTH_USERINFO_FIELD') or 'username',
  success_uri       = os.getenv('NGX_OAUTH_SUCCESS_URI') or '/',
  cookie_path       = os.getenv('NGX_OAUTH_COOKIE_PATH') or '/',
  cookie_prefix     = os.getenv('NGX_OAUTH_COOKIE_PREFIX') or 'oauth_',
  max_age           = os.getenv('NGX_OAUTH_MAX_AGE') or 2592000, -- 30 days
  aes_bits          = os.getenv('NGX_OAUTH_AES_BITS') or 128
}

local OAAS_ENDPOINT_VARS = {'authorization_url', 'token_url', 'userinfo_url'}


local load_from_ngx = par(map, function(default_value, key)
    return util.default(ngx.var['oauth_'..key], default_value)
  end, DEFAULTS)

local function validate (conf)
  local errors = {}

  if is_empty(conf.client_id) then
    table.insert(errors, '$oauth_client_id is not set')
  end

  if is_empty(conf.client_secret) then
    table.insert(errors, '$oauth_client_secret is not set')
  end

  if not contains(conf.aes_bits, {128, 192, 256}) then
    table.insert(errors, '$oauth_aes_bits must be 128, 192, or 256')
  end

  if conf.client_secret:len() < conf.aes_bits / 8 then
    table.insert(errors, ('$oauth_client_secret is too short, it must be at least %.0f'..
      ' characters long for $oauth_aes_bits = %.0f'):format(conf.aes_bits / 8, conf.aes_bits))
  end

  for _, key in ipairs(OAAS_ENDPOINT_VARS) do
    if starts_with('${oaas_uri}', conf[key]) then
      table.insert(errors, 'neither $oauth_'..key..' nor $oauth_oaas_uri is set')
    end
  end

  return errors
end

local M = {}

--- Loads settings from nginx variables and ensure that all required
-- variables are set.
--
-- @treturn {[string]=any,...} Settings
-- @treturn nil|string Validation error, or `false` if no validation
--   error was found.
function M.load ()
  local conf = load_from_ngx()

  if not is_absolute_url(conf.redirect_uri) then
    conf.redirect_uri = ngx.var.scheme..'://'..ngx.var.server_name..conf.redirect_uri
  end

  if not is_empty(conf.oaas_uri) then
    for _, key in ipairs(OAAS_ENDPOINT_VARS) do
      conf[key] = conf[key]:gsub('${oaas_uri}', conf.oaas_uri)
    end
  end

  local errors = validate(conf)
  return conf, #errors ~= 0 and table.concat(errors, '; ')
end

return M
