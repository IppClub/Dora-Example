-- Copyright (c) 2026 Li Jin. SPDX-License-Identifier: MIT
local function encode(value)
 local kind=type(value)
 if kind=='nil' then return 'null'
 elseif kind=='boolean' or kind=='number' then return tostring(value)
 elseif kind=='string' then
  return '"'..value:gsub('\\','\\\\'):gsub('"','\\"'):gsub('\n','\\n'):gsub('\r','\\r'):gsub('\t','\\t')..'"'
 elseif kind=='table' then
  local fields={}
  for key,item in pairs(value) do fields[#fields+1]=encode(tostring(key))..':'..encode(item) end
  return '{'..table.concat(fields,',')..'}'
 end
 error('unsupported JSON value: '..kind)
end
return encode
