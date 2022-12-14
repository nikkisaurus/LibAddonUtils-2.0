local lib = LibStub:NewLibrary("LibAddonUtils-2.0", 1)

if not lib then
    return
end

if not lib.frame then
    lib.frame = CreateFrame("Frame")
end

lib.frame:SetScript("OnEvent", function(self, event, ...)
    return self[event] and self[event](self, ...)
end)

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- Caching

local cache = {}
local invalid = {}
function lib:CacheItem(itemID, callback, args)
    args = type(args) == "table" and args or {}
    local itemName = GetItemInfo(itemID)
    if invalid[itemID] then
        cache[itemID] = nil
        invalid[itemID] = nil
        if callback and type(callback) == "function" then
            callback(false, itemID, unpack(args))
            return
        end
    elseif not itemName then
        local item
        if tonumber(itemID) then
            item = Item:CreateFromItemID(tonumber(itemID))
        else
            item = Item:CreateFromItemLink(itemID)
        end

        if not item:IsItemEmpty() then
            item:ContinueOnItemLoad(function()
                lib:CacheItem(itemID, callback, args)
            end)
        else
            cache[itemID] = nil
            if callback and type(callback) == "function" then
                callback(false, itemID, unpack(args))
                return
            end
        end
        return
    end

    cache[itemID] = nil

    if callback and type(callback) == "function" then
        return callback(true, itemID, unpack(args))
    end
end

lib.frame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
function lib.frame:GET_ITEM_INFO_RECEIVED(itemID, success)
    if not cache[itemID] then
        return
    elseif not success then
        invalid[itemID] = true
    end

    lib:CacheItem(unpack(cache[itemID]))
end

function lib:Cache(Type, id, callback, args)
    if Type == "item" then
        lib:CacheItem(id, callback, args)
    elseif Type == "currency" then
        callback(true, id, unpack(args))
    end
end

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- Miscellaneous

function lib:AddSpecialFrame(frame, frameName)
    _G[frameName] = frame
    tinsert(UISpecialFrames, frameName)
    self[frameName] = frame
end

function lib:GetModifierString()
    local modifier = ""
    if IsShiftKeyDown() then
        modifier = "shift"
    end
    if IsControlKeyDown() then
        modifier = "ctrl" .. (modifier ~= "" and "-" or "") .. modifier
    end
    if IsAltKeyDown() then
        modifier = "alt" .. (modifier ~= "" and "-" or "") .. modifier
    end
    return modifier
end

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- Numbers

local numSuffixes = {
    [3] = "K",
    [6] = "M",
    [9] = "B",
    [12] = "t",
    [15] = "q",
    [18] = "Q",
    [21] = "s",
    [24] = "S",
    [27] = "o",
    [30] = "n",
    [33] = "d",
    [36] = "U",
    [39] = "D",
    [42] = "T",
    [45] = "Qt",
    [48] = "Qd",
    [51] = "Sd",
    [54] = "St",
    [57] = "O",
    [60] = "N",
    [63] = "v",
    [66] = "c",
}

function lib:iformat(i, fType, roundDown)
    if not i then
        return
    end
    local orig = i

    if fType == 1 then
        local i, j, minus, integer, fraction = string.format("%f", i):find("([-]?)(%d+)([.]?%d*)")
        return string.format("%s%s%s", minus, integer:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", ""), (tonumber(fraction) > 0 and fraction or "")), orig
    elseif fType == 2 then
        i = string.format("%f", i)
        local mod = tonumber(strlen(strsplit(".", i)) - 1) - math.fmod(tonumber(strlen(strsplit(".", i)) - 1), 3)

        if mod == 0 then
            return tonumber(i), orig
        elseif mod > 66 then
            mod = 66
        end

        local int, dec = strsplit(".", tostring(i / 10 ^ mod))
        dec = dec and lib:round(dec / 10 ^ (strlen(dec) - 1), 0, roundDown) or 0

        if dec == 10 then
            return lib:iformat(tonumber((int + 1) * 10 ^ mod), 2), orig
        end

        local suffix = numSuffixes[mod]
        return string.format("%s%s", tonumber(int .. "." .. dec), suffix), orig
    end
end

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

function lib:round(num, decimals, roundDown)
    if roundDown then
        local power = 10 ^ decimals
        return math.floor(num * power) / power
    else
        return tonumber((("%%.%df"):format(decimals)):format(num))
    end
end

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- Tables

function lib:CloneTable(orig)
    -- https://forum.cockos.com/showthread.php?t=221712
    local copy
    if type(orig) == "table" then
        copy = {}
        for orig_key, orig_value in pairs(orig) do
            copy[lib:CloneTable(orig_key)] = lib:CloneTable(orig_value)
        end
        setmetatable(copy, lib:CloneTable(getmetatable(orig)))
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

local keys = {}
function lib:GetTableKey(tbl, value)
    wipe(keys)
    for k, v in pairs(tbl) do
        if v == value then
            tinsert(keys, k)
        end
    end
    return unpack(keys)
end

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

function lib:pairs(tbl, func)
    local a = {}

    for n in pairs(tbl) do
        tinsert(a, n)
    end

    sort(a, func)

    local i = 0
    local iter = function()
        i = i + 1
        if a[i] == nil then
            return nil
        else
            return a[i], tbl[a[i]]
        end
    end

    return iter
end

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

function lib:printt(tbl, cond)
    if type(tbl) == "table" then
        for k, v in lib:pairs(tbl) do
            if cond == 1 then
                print(k)
            elseif cond == 2 then
                print(v)
            else
                print(k, v)
            end
        end

        return true
    end
end

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

function lib:tcount(tbl, key, value)
    local counter = 0
    for k, v in pairs(tbl) do
        if (key and k == key) or (value and v[value]) or (not key and not value) then
            counter = counter + 1
        end
    end

    return counter
end

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

local keys = {}
function lib:tpairs(tbl, callback, duration, key, value, sorting)
    wipe(keys)
    for k, v in lib:pairs(tbl, sorting) do
        if (key and k == key) or (value and v[value]) or (not key and not value) then
            tinsert(keys, k)
        end
    end

    local index = 0
    local ticker = C_Timer.NewTicker(math.max(duration or 0.00001, 0.00001), function(self)
        index = index + 1
        if index > #keys then
            self:Cancel()
            return
        end
        callback(tbl, keys[index])
    end)
end

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

function lib:unpack(tbl, default)
    if type(tbl) == "table" then
        if not unpack(tbl) then
            local newTbl = {}
            for k, v in lib:pairs(tbl) do
                tinsert(newTbl, v)
            end
            return unpack(newTbl)
        else
            return unpack(tbl)
        end
    elseif default then
        return unpack(default)
    else
        return tbl
    end
end

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- Strings

-- Color codes courtesy of:
-- http://www.ac-web.org/forums/showthread.php?105949-Lua-Color-Codes
lib.ChatColors = {
    ["LIGHTRED"] = "|cffff6060",
    ["LIGHTBLUE"] = "|cff00ccff",
    ["TORQUISEBLUE"] = "|cff00C78C",
    ["SPRINGGREEN"] = "|cff00FF7F",
    ["GREENYELLOW"] = "|cffADFF2F",
    ["BLUE"] = "|cff0000ff",
    ["PURPLE"] = "|cffDA70D6",
    ["GREEN"] = "|cff00ff00",
    ["RED"] = "|cffff0000",
    ["GOLD"] = "|cffffcc00",
    ["GOLD2"] = "|cffFFC125",
    ["GREY"] = "|cff888888",
    ["WHITE"] = "|cffffffff",
    ["SUBWHITE"] = "|cffbbbbbb",
    ["MAGENTA"] = "|cffff00ff",
    ["YELLOW"] = "|cffffff00",
    ["ORANGEY"] = "|cffFF4500",
    ["CHOCOLATE"] = "|cffCD661D",
    ["CYAN"] = "|cff00ffff",
    ["IVORY"] = "|cff8B8B83",
    ["LIGHTYELLOW"] = "|cffFFFFE0",
    ["SEXGREEN"] = "|cff71C671",
    ["SEXTEAL"] = "|cff388E8E",
    ["SEXPINK"] = "|cffC67171",
    ["SEXBLUE"] = "|cff00E5EE",
    ["SEXHOTPINK"] = "|cffFF6EB4",
}

function lib:ColorFontString(str, color)
    return string.format("%s%s|r", lib.ChatColors[strupper(color)] or color, str)
end

function lib:ColorFormat(str, color)
    return str:gsub("$$!", lib.ChatColors[strupper(color)] or color)
end

function lib:GetSubstring(str, len)
    str = str or ""
    return strsub(str, 1, len) .. (strlen(str) > len and "..." or "")
end

function lib:IncrementString(str, callback, args)
    args = type(args) == "table" and args or {}

    if callback(str, unpack(args)) then
        local i = 2
        while true do
            local newStr = format("%s %d", str, i)

            if not callback(newStr, unpack(args)) then
                return newStr
            else
                i = i + 1
            end
        end
    else
        return str
    end
end

function lib:StringToTitle(str)
    local strs = { strsplit(" ", str) }

    for key, Str in pairs(strs) do
        strs[key] = strupper(strsub(Str, 1, 1)) .. strlower(strsub(Str, 2, strlen(Str)))
    end

    return table.concat(strs, " ")
end

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- Embeds

function lib:Embed(target)
    for name, _ in pairs(lib) do
        if name ~= "frame" then
            target[name] = lib[name]
        end
    end
end
