local BravLib = BravLib

-- ============================================================================
-- SERIALISATION (table Lua → string, string → table Lua)
-- Format maison, pas de dependance externe.
-- ============================================================================

local type, pairs, tostring, tonumber = type, pairs, tostring, tonumber
local format, gsub, sub, byte, char = string.format, string.gsub, string.sub, string.byte, string.char
local concat, sort = table.concat, table.sort

-- ============================================================================
-- SERIALIZE
-- ============================================================================

local function SerializeValue(val, buf)
    local t = type(val)

    if t == "string" then
        -- escape backslash, double-quotes, newlines
        local escaped = gsub(val, '[\\"\n\r]', function(c)
            if c == "\\" then return "\\\\"
            elseif c == '"' then return '\\"'
            elseif c == "\n" then return "\\n"
            elseif c == "\r" then return "\\r"
            end
        end)
        buf[#buf + 1] = '"' .. escaped .. '"'

    elseif t == "number" then
        buf[#buf + 1] = tostring(val)

    elseif t == "boolean" then
        buf[#buf + 1] = val and "true" or "false"

    elseif t == "nil" then
        buf[#buf + 1] = "nil"

    elseif t == "table" then
        buf[#buf + 1] = "{"

        -- trier les cles pour un output deterministe
        local keys = {}
        for k in pairs(val) do keys[#keys + 1] = k end
        sort(keys, function(a, b)
            local ta, tb = type(a), type(b)
            if ta == tb then
                if ta == "number" then return a < b end
                return tostring(a) < tostring(b)
            end
            return ta < tb
        end)

        local first = true
        for _, k in ipairs(keys) do
            local v = val[k]
            if v ~= nil then
                if not first then buf[#buf + 1] = "," end
                first = false

                -- key
                if type(k) == "number" then
                    buf[#buf + 1] = "[" .. tostring(k) .. "]="
                elseif type(k) == "string" then
                    -- cle simple sans caracteres speciaux
                    if k:match("^[%a_][%w_]*$") then
                        buf[#buf + 1] = k .. "="
                    else
                        buf[#buf + 1] = '["'
                        local escaped = gsub(k, '[\\"\n\r]', function(c)
                            if c == "\\" then return "\\\\"
                            elseif c == '"' then return '\\"'
                            elseif c == "\n" then return "\\n"
                            elseif c == "\r" then return "\\r"
                            end
                        end)
                        buf[#buf + 1] = escaped .. '"]='
                    end
                else
                    -- boolean key etc
                    buf[#buf + 1] = "[" .. tostring(k) .. "]="
                end

                SerializeValue(v, buf)
            end
        end

        buf[#buf + 1] = "}"
    end
end

function BravLib.Serialize(tbl)
    if type(tbl) ~= "table" then return nil end
    local buf = {}
    SerializeValue(tbl, buf)
    return concat(buf)
end

-- ============================================================================
-- DIFF TABLE (retourne uniquement les valeurs differentes des defaults)
-- ============================================================================

local function DiffTable(data, ref)
    if type(data) ~= "table" or type(ref) ~= "table" then return data end

    local diff = {}
    local hasKeys = false

    for k, v in pairs(data) do
        local refV = ref[k]
        if refV == nil then
            -- cle inconnue des defaults, on ignore
        elseif type(v) == "table" and type(refV) == "table" then
            local sub = DiffTable(v, refV)
            if sub then
                diff[k] = sub
                hasKeys = true
            end
        elseif v ~= refV then
            diff[k] = v
            hasKeys = true
        end
    end

    return hasKeys and diff or nil
end

BravLib.DiffTable = DiffTable

-- ============================================================================
-- DESERIALIZE (parser securise, pas de loadstring)
-- ============================================================================

local Parser = {}
Parser.__index = Parser

function Parser.new(str)
    return setmetatable({ s = str, pos = 1, len = #str }, Parser)
end

function Parser:peek()
    return sub(self.s, self.pos, self.pos)
end

function Parser:advance(n)
    self.pos = self.pos + (n or 1)
end

function Parser:skipWhitespace()
    while self.pos <= self.len do
        local c = sub(self.s, self.pos, self.pos)
        if c == " " or c == "\t" or c == "\n" or c == "\r" then
            self.pos = self.pos + 1
        else
            break
        end
    end
end

function Parser:readString()
    -- self:peek() == '"'
    self:advance() -- skip opening quote
    local buf = {}
    while self.pos <= self.len do
        local c = sub(self.s, self.pos, self.pos)
        if c == "\\" then
            self:advance()
            local next = sub(self.s, self.pos, self.pos)
            if next == "n" then buf[#buf + 1] = "\n"
            elseif next == "r" then buf[#buf + 1] = "\r"
            elseif next == "\\" then buf[#buf + 1] = "\\"
            elseif next == '"' then buf[#buf + 1] = '"'
            else buf[#buf + 1] = next
            end
            self:advance()
        elseif c == '"' then
            self:advance() -- skip closing quote
            return concat(buf)
        else
            buf[#buf + 1] = c
            self:advance()
        end
    end
    error("Unterminated string")
end

function Parser:readNumber()
    local start = self.pos
    -- handle negative
    if sub(self.s, self.pos, self.pos) == "-" then
        self.pos = self.pos + 1
    end
    while self.pos <= self.len do
        local c = sub(self.s, self.pos, self.pos)
        if (c >= "0" and c <= "9") or c == "." or c == "e" or c == "E" or c == "+" or c == "-" then
            self.pos = self.pos + 1
        else
            break
        end
    end
    local numStr = sub(self.s, start, self.pos - 1)
    local num = tonumber(numStr)
    if not num then error("Invalid number: " .. numStr) end
    return num
end

function Parser:readValue()
    self:skipWhitespace()
    if self.pos > self.len then error("Unexpected end of input") end

    local c = self:peek()

    if c == '"' then
        return self:readString()
    elseif c == "{" then
        return self:readTable()
    elseif c == "t" then
        -- true
        if sub(self.s, self.pos, self.pos + 3) == "true" then
            self.pos = self.pos + 4
            return true
        end
        error("Unexpected token at " .. self.pos)
    elseif c == "f" then
        -- false
        if sub(self.s, self.pos, self.pos + 4) == "false" then
            self.pos = self.pos + 5
            return false
        end
        error("Unexpected token at " .. self.pos)
    elseif c == "n" then
        -- nil
        if sub(self.s, self.pos, self.pos + 2) == "nil" then
            self.pos = self.pos + 3
            return nil
        end
        error("Unexpected token at " .. self.pos)
    elseif c == "-" or (c >= "0" and c <= "9") then
        return self:readNumber()
    else
        error("Unexpected character '" .. c .. "' at " .. self.pos)
    end
end

function Parser:readTable()
    -- self:peek() == '{'
    self:advance() -- skip '{'
    local tbl = {}

    self:skipWhitespace()
    if self:peek() == "}" then
        self:advance()
        return tbl
    end

    while self.pos <= self.len do
        self:skipWhitespace()
        if self:peek() == "}" then
            self:advance()
            return tbl
        end

        -- key = value ou [key] = value
        local key
        if self:peek() == "[" then
            self:advance() -- skip '['
            self:skipWhitespace()
            if self:peek() == '"' then
                key = self:readString()
            else
                key = self:readNumber()
            end
            self:skipWhitespace()
            if self:peek() ~= "]" then error("Expected ']'") end
            self:advance()
            self:skipWhitespace()
            if self:peek() ~= "=" then error("Expected '='") end
            self:advance()
        else
            -- identifier key
            local start = self.pos
            while self.pos <= self.len do
                local ch = sub(self.s, self.pos, self.pos)
                if ch:match("[%w_]") then
                    self.pos = self.pos + 1
                else
                    break
                end
            end
            key = sub(self.s, start, self.pos - 1)
            if key == "" then error("Empty key at " .. self.pos) end

            self:skipWhitespace()
            if self:peek() ~= "=" then error("Expected '='") end
            self:advance()
        end

        local value = self:readValue()
        tbl[key] = value

        self:skipWhitespace()
        if self:peek() == "," then
            self:advance()
        end
    end

    error("Unterminated table")
end

function BravLib.Deserialize(str)
    if type(str) ~= "string" or str == "" then return nil end
    local parser = Parser.new(str)
    local ok, result = pcall(function()
        return parser:readValue()
    end)
    if not ok then
        BravLib.Warn("Deserialize error: " .. tostring(result))
        return nil
    end
    return result
end

-- ============================================================================
-- BASE64
-- ============================================================================

local b64chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local b64lookup = {}
for i = 1, 64 do
    b64lookup[sub(b64chars, i, i)] = i - 1
end

function BravLib.Base64Encode(str)
    if type(str) ~= "string" then return nil end
    local buf = {}
    local len = #str

    for i = 1, len, 3 do
        local b1 = byte(str, i)
        local b2 = byte(str, i + 1) or 0
        local b3 = byte(str, i + 2) or 0

        local n = b1 * 65536 + b2 * 256 + b3

        buf[#buf + 1] = sub(b64chars, math.floor(n / 262144) + 1, math.floor(n / 262144) + 1)
        buf[#buf + 1] = sub(b64chars, math.floor(n / 4096) % 64 + 1, math.floor(n / 4096) % 64 + 1)

        if i + 1 <= len then
            buf[#buf + 1] = sub(b64chars, math.floor(n / 64) % 64 + 1, math.floor(n / 64) % 64 + 1)
        else
            buf[#buf + 1] = "="
        end

        if i + 2 <= len then
            buf[#buf + 1] = sub(b64chars, n % 64 + 1, n % 64 + 1)
        else
            buf[#buf + 1] = "="
        end
    end

    return concat(buf)
end

function BravLib.Base64Decode(str)
    if type(str) ~= "string" then return nil end

    -- supprimer whitespace
    str = gsub(str, "%s", "")

    local buf = {}
    local len = #str

    for i = 1, len, 4 do
        local c1 = b64lookup[sub(str, i, i)] or 0
        local c2 = b64lookup[sub(str, i + 1, i + 1)] or 0
        local c3 = b64lookup[sub(str, i + 2, i + 2)]
        local c4 = b64lookup[sub(str, i + 3, i + 3)]

        local n = c1 * 262144 + c2 * 4096

        if c3 then n = n + c3 * 64 end
        if c4 then n = n + c4 end

        buf[#buf + 1] = char(math.floor(n / 65536) % 256)

        if sub(str, i + 2, i + 2) ~= "=" then
            buf[#buf + 1] = char(math.floor(n / 256) % 256)
        end

        if sub(str, i + 3, i + 3) ~= "=" then
            buf[#buf + 1] = char(n % 256)
        end
    end

    return concat(buf)
end

-- ============================================================================
-- COMPRESSION (LZW)
-- Compresse les strings serialisees avant le base64.
-- Dictionnaire de 256 entrees initiales (bytes), puis construction dynamique.
-- ============================================================================

function BravLib.Compress(str)
    if type(str) ~= "string" or str == "" then return str end

    -- initialiser le dictionnaire avec les 256 bytes
    local dict = {}
    local dictSize = 256
    for i = 0, 255 do
        dict[char(i)] = i
    end

    local result = {}
    local w = ""

    for i = 1, #str do
        local c = sub(str, i, i)
        local wc = w .. c
        if dict[wc] then
            w = wc
        else
            local code = dict[w]
            result[#result + 1] = char(math.floor(code / 256))
            result[#result + 1] = char(code % 256)

            if dictSize < 65536 then
                dict[wc] = dictSize
                dictSize = dictSize + 1
            end
            w = c
        end
    end

    if w ~= "" then
        local code = dict[w]
        result[#result + 1] = char(math.floor(code / 256))
        result[#result + 1] = char(code % 256)
    end

    return concat(result)
end

function BravLib.Decompress(data)
    if type(data) ~= "string" or data == "" then return data end
    if #data % 2 ~= 0 then return nil end

    local codes = {}
    for i = 1, #data, 2 do
        local hi = byte(data, i)
        local lo = byte(data, i + 1)
        codes[#codes + 1] = hi * 256 + lo
    end

    if #codes == 0 then return "" end

    local dict = {}
    local dictSize = 256
    for i = 0, 255 do
        dict[i] = char(i)
    end

    local result = {}
    local w = dict[codes[1]]
    if not w then return nil end
    result[#result + 1] = w

    for i = 2, #codes do
        local code = codes[i]
        local entry

        if dict[code] then
            entry = dict[code]
        elseif code == dictSize then
            entry = w .. sub(w, 1, 1)
        else
            return nil
        end

        result[#result + 1] = entry

        if dictSize < 65536 then
            dict[dictSize] = w .. sub(entry, 1, 1)
            dictSize = dictSize + 1
        end

        w = entry
    end

    return concat(result)
end
