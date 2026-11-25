-- Stubbed WoW API tests for WhoMenu.lua under lua5.1:
--   lua5.1 tests/harness.lua WhoMenu.lua
-- The name helpers are copied from Blizzard's 1.60.1.71091 source
-- (Blizzard_FrameXMLUtil/Camelot/NameUtil.lua). The link separator is "-",
-- as other Forever addons report it.
local path = arg[1]

local SECRET = {}
function issecretvalue(v) return v == SECRET end
Constants = { CharacterNameSeparatorConsts = { CHARACTERNAME_SURNAME_SEPARATOR = " " } }
NameUtil = {}
function NameUtil.GetFullNameWithoutRealm(firstName, surname)
    if (firstName and firstName ~= "") and (surname and surname ~= "") then
        return firstName .. Constants.CharacterNameSeparatorConsts.CHARACTERNAME_SURNAME_SEPARATOR .. surname
    else
        return firstName
    end
end
C_NameUtil = {
    ReplaceSurnameSeparatorWithLinkSeparator = function(s)
        assert(type(s) == "string", "ReplaceSurnameSeparator got a " .. type(s))
        return (s:gsub(" ", "-"))
    end,
}
WHO_TAG_EXACT, WHO = "x-", "Who"
Enum = { SocialWhoOrigin = { Unknown = 0, Social = 1, Chat = 2, Item = 3 } }

local sent = {}
C_FriendList = {
    SendWho = function(filter, origin)
        assert(filter ~= SECRET, "a secret reached SendWho")
        sent[#sent + 1] = { filter, origin }
    end,
    GetNumWhoResults = function() return 1, 1 end,
}
local units = { target = { "Anna", "Vale" }, player = { "Dana", "Reed" } }
function UnitIsPlayer(u)
    assert(u ~= SECRET, "a secret reached UnitIsPlayer")
    return units[u] ~= nil
end
-- On Forever the second value is the surname, not the realm (Camelot/NameUtil.lua).
function UnitNameUnmodified(u) if units[u] then return units[u][1], units[u][2] end end
function IsModifiedClick() return true end
function IsShiftKeyDown() return true end
ChatFrameUtil = { GetActiveWindow = function() return nil end }
function GetTime() return 100 end
function SetItemRef() end
function hooksecurefunc(t, method, hook)
    if type(t) == "string" then t, method, hook = _G, t, method end
    local orig = t[method]
    t[method] = function(...) local r = { orig(...) }; hook(...); return unpack(r) end
end
local frames = {}
function CreateFrame()
    local f = { events = {} }
    function f:RegisterEvent(e) self.events[e] = true end
    function f:UnregisterAllEvents() self.events = {} end
    function f:SetScript(_, fn) self.onEvent = fn end
    frames[#frames + 1] = f
    return f
end
local tagCallback
EventRegistry = { RegisterCallback = function(_, _, fn) tagCallback = fn end }
SlashCmdList = {}
local printed = {}
function print(...) printed[#printed + 1] = table.concat({ ... }, " ") end

local menus = {}
Menu = { ModifyMenu = function(tag, fn) assert(not menus[tag], "registered twice: " .. tag); menus[tag] = fn end }

assert(loadfile(path))("WhoMenu")

-- Open a menu the way Blizzard does; returns the entry (or nil) and the divider count.
local function Open(which, data)
    local entry, dividers = nil, 0
    local root = {
        CreateDivider = function() dividers = dividers + 1 end,
        CreateButton = function(_, text, fn, d) entry = { text = text, click = function() return fn(d) end } end,
    }
    assert(menus["MENU_UNIT_" .. which], "no hook on " .. which)(nil, root, data)
    return entry, dividers
end

local n = 0
local function Eq(got, want, what)
    n = n + 1
    if got ~= want then error(("%s: got %s, want %s"):format(what, tostring(got), tostring(want)), 2) end
end
local function Sends(which, data, want, what)
    sent = {}
    local entry, dividers = Open(which, data)
    Eq(entry ~= nil, true, what .. " (entry)")
    Eq(dividers, 1, what .. " (divider)")
    Eq(#sent, 0, what .. " (nothing sent before the click)")
    entry.click()
    Eq(#sent, 1, what .. " (one search)")
    Eq(sent[1][1], want, what)
    Eq(sent[1][2], 2, what .. " (same origin as a typed /who)")
end
local function Hidden(which, data, what)
    local entry, dividers = Open(which, data)
    Eq(entry, nil, what)
    Eq(dividers, 0, what .. " (no stray divider)")
end

-- Portraits: OpenMenu fills name and surname from the unit.
Sends("PLAYER", { unit = "target", name = "Anna", surname = "Vale" }, "x-Anna-Vale", "portrait, name and surname")
Sends("PLAYER", { unit = "target", name = "Anna" }, "x-Anna", "portrait, no surname yet")
Sends("PLAYER", { unit = "target", name = "Anna", surname = "" }, "x-Anna", "portrait, empty surname")
-- Chat: the name arrives whole, with a space.
Sends("FRIEND", { name = "Anna Vale" }, "x-Anna-Vale", "chat name")
Sends("FRIEND", { name = "Anna-Vale" }, "x-Anna-Vale", "name already joined for a link")
Sends("COMMUNITIES_GUILD_MEMBER", { name = "Anna Vale-CamWoWUS1Realm2PvP" }, "x-Anna-Vale", "guild name with a realm")
Sends("PARTY", { unit = "target", name = "Anna", surname = "Vale-CamWoWUS1Realm2PvP" }, "x-Anna-Vale", "unit surname with a realm")
Sends("COMMUNITIES_GUILD_MEMBER", { name = "Anna-CamWoWUS1Realm2PvP" }, "x-Anna", "realm but no surname")
Sends("FRIEND", { name = "\195\137lise d'Or" }, "x-\195\137lise-d'Or", "accent and apostrophe")

Hidden("FOCUS", { unit = "npc", name = "Hogger" }, "an NPC in the focus frame")
Hidden("PARTY", { unit = "target", name = SECRET, surname = "Vale" }, "secret name")
Hidden("PARTY", { unit = "target", name = "Anna", surname = SECRET }, "secret surname")
Hidden("PARTY", { unit = SECRET, name = "Anna" }, "secret unit")
Hidden("FRIEND", { name = "" }, "empty name")
Hidden("FRIEND", {}, "no name")
Hidden("FRIEND", nil, "no context")

for _, which in ipairs({ "SELF", "PET", "TARGET", "ENEMY_PLAYER", "BN_FRIEND", "FRIEND_OFFLINE", "DISCORD_USER" }) do
    Eq(menus["MENU_UNIT_" .. which], nil, "not on " .. which)
end

-- SendWho is looked up at click time, so another addon's wrapper still runs.
local entry = Open("FRIEND", { name = "Anna Vale" })
local wrapped
local orig = C_FriendList.SendWho
C_FriendList.SendWho = function(f, ...) wrapped = f; return orig(f, ...) end
entry.click()
Eq(wrapped, "x-Anna-Vale", "goes through a later wrapper")
C_FriendList.SendWho = orig

-- Slash command
local slash = SlashCmdList.WHOMENU
local function Said(pattern)
    for _, line in ipairs(printed) do if line:find(pattern) then return true end end
    return false
end
printed = {}; slash("check"); Eq(Said("x%-Anna%-Vale"), true, "check shows the target's search")
Eq(#frames, 0, "no frame until debug is on")
units.target = nil
printed = {}; slash("check"); Eq(Said("x%-Dana%-Reed"), true, "check falls back to you")
printed = {}; slash(""); Eq(Said("/whomenu debug"), true, "help")

-- Debug: logs both paths, survives secrets, and turns off again.
SetItemRef("player:Anna Vale:1:GUILD", "", "LeftButton"); Eq(Said("clicked"), false, "silent while off")
slash("debug")
printed = {}; SetItemRef("player:Anna Vale:1:GUILD", "", "LeftButton"); Eq(Said("clicked.*LeftButton"), true, "logs a name click")
printed = {}; SetItemRef("item:19019", "", "LeftButton"); Eq(#printed, 0, "ignores other links")
printed = {}; SetItemRef(SECRET, "", "LeftButton"); Eq(Said("hidden"), true, "secret link")
printed = {}; C_FriendList.SendWho("x-Anna-Vale", 3); Eq(Said("x%-Anna%-Vale"), true, "logs a search from anywhere")
local f = frames[1]
printed = {}; f.onEvent(f, "WHO_LIST_UPDATE"); Eq(Said("WHO_LIST_UPDATE"), true, "logs the Who list")
printed = {}; f.onEvent(f, "CHAT_MSG_SYSTEM", "0 players total"); Eq(Said("0 players total"), true, "logs a system line after a search")
printed = {}; f.onEvent(f, "CHAT_MSG_SYSTEM", SECRET); Eq(Said("hidden"), true, "secret system line")
printed = {}; f.onEvent(f, "ADDON_ACTION_BLOCKED", "SomeAddon", "SendWho()"); Eq(Said("SendWho"), true, "logs a blocked search")
printed = {}; f.onEvent(f, "ADDON_ACTION_BLOCKED", "Plater", "Reload()"); Eq(#printed, 0, "ignores other blocked calls")
printed = {}; tagCallback(nil, "MENU_UNIT_FRIEND"); Eq(Said("MENU_UNIT_FRIEND"), true, "logs the menu tag")
GetTime = function() return 200 end
printed = {}; f.onEvent(f, "CHAT_MSG_SYSTEM", "You are now AFK"); Eq(#printed, 0, "ignores system lines long after a search")
slash("debug"); printed = {}
SetItemRef("player:Anna Vale:1:GUILD", "", "LeftButton"); C_FriendList.SendWho("x-A-B", 2); tagCallback(nil, "MENU_UNIT_FRIEND")
Eq(#printed, 0, "silent once off")
Eq(next(f.events), nil, "events released once off")
slash("debug"); Eq(#frames, 1, "turning it on twice hooks once")
printed = {}; C_FriendList.SendWho("x-A-B", 2); Eq(#printed, 1, "one line per search after toggling")

io.write(n, " checks passed\n")
