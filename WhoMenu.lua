-- Who Menu: a "Who" entry on the right-click menu of a player's portrait or
-- name, in chat and in the roster lists. It runs the same exact-name /who the
-- game sends when you shift-click a name.
--
-- Entries are added with Blizzard's Menu.ModifyMenu, so no menu is replaced.
-- The search is only ever sent from the click on the entry: the game drops a
-- SendWho that an addon starts on its own.
--
-- /whomenu check shows the search it would send, /whomenu debug logs each step
-- of a search to chat.

local issecretvalue = issecretvalue or function() return false end

local function Chat(msg)
    print("|cff0cd29fWho Menu:|r " .. msg)
end

-------------------------------------------------------------------------------
--  The search
-------------------------------------------------------------------------------

-- The exact-name filter, "x-First-Surname". Menus give a name in two parts (a
-- portrait), or whole ("First Surname", sometimes with "-Realm" in the guild
-- list). Forever names are unique across the region, so a realm is dropped.
-- nil for a name the game hides from addons (a secret value): it can't be read,
-- and passing it to SendWho from here would be an error.
local function ExactFilter(name, surname)
    if issecretvalue(name) or issecretvalue(surname) then return end
    if type(name) ~= "string" then return end
    if type(surname) == "string" then name = name .. " " .. surname end
    name = name:gsub("%-[^%s%-]*%d[^%s%-]*$", "")   -- "-CamWoWUS1Realm2PvP": only realms have digits
    local first, last = name:match("^([^%s%-]+)[%s%-]*([^%s%-]*)")
    if not first then return end
    return WHO_TAG_EXACT .. C_NameUtil.ReplaceSurnameSeparatorWithLinkSeparator(
        NameUtil.GetFullNameWithoutRealm(first, last))
end

-- Looked up on every click, so another addon's wrapper (OlympusMute) still runs.
local function Search(filter)
    C_FriendList.SendWho(filter, Enum.SocialWhoOrigin.Chat)
end

-------------------------------------------------------------------------------
--  The menus
-------------------------------------------------------------------------------
local MENUS = {
    "PLAYER", "PARTY", "RAID_PLAYER", "RAID", "FOCUS",      -- portraits and group frames
    "FRIEND",                                               -- chat names, friends list, Who list
    "COMMUNITIES_GUILD_MEMBER", "COMMUNITIES_WOW_MEMBER",   -- guild and community rosters
    "CHAT_ROSTER", "RECENT_ALLY",
}

local function AddWho(_, root, data)
    if type(data) ~= "table" then return end
    local unit = data.unit
    if issecretvalue(unit) or (unit and not UnitIsPlayer(unit)) then return end
    local filter = ExactFilter(data.name, data.surname)
    if not filter then return end
    root:CreateDivider()
    root:CreateButton(WHO or "Who", Search, filter)
end

for _, which in ipairs(MENUS) do
    Menu.ModifyMenu("MENU_UNIT_" .. which, AddWho)
end

-------------------------------------------------------------------------------
--  /whomenu debug: log each step of a search, ours or the game's shift-click.
--  Nothing is hooked until it's first turned on.
-------------------------------------------------------------------------------
local RESULT_WINDOW = 5   -- seconds after a search that system lines are logged

local debugOn, debugFrame, sentAt = false, nil, nil

local function Show(v)
    if issecretvalue(v) then return "(hidden by the game)" end
    return (tostring(v):gsub("|", "||"))   -- as text, so links and colors stay readable
end

local function YesNo(v) return v and "yes" or "no" end

local function OnLinkClick(link, _, button)
    if not debugOn then return end
    if not issecretvalue(link) and not (type(link) == "string" and link:find("^player")) then return end
    Chat(("clicked %s with %s: link modifier %s, shift %s, chat box active %s"):format(
        Show(link), Show(button), YesNo(IsModifiedClick("CHATLINK")), YesNo(IsShiftKeyDown()),
        YesNo(ChatFrameUtil.GetActiveWindow())))
end

local function OnSendWho(filter, origin)
    if not debugOn then return end
    sentAt = GetTime()
    Chat(("search sent: %s (origin %s)"):format(Show(filter), Show(origin)))
end

local function OnMenuTag(_, tag)
    if debugOn then Chat("menu opened: " .. Show(tag)) end
end

local function OnDebugEvent(_, event, arg1, arg2)
    if event == "WHO_LIST_UPDATE" then
        local shown, total = C_FriendList.GetNumWhoResults()
        Chat(("WHO_LIST_UPDATE: %s shown, %s total"):format(Show(shown), Show(total)))
    elseif event == "ADDON_ACTION_BLOCKED" or event == "ADDON_ACTION_FORBIDDEN" then
        if type(arg2) == "string" and not issecretvalue(arg2) and arg2:find("SendWho", 1, true) then
            Chat(("%s: %s called %s"):format(event, Show(arg1), arg2))
        end
    elseif sentAt and GetTime() - sentAt <= RESULT_WINDOW then
        Chat(("%s: %s"):format(event, Show(event == "UI_ERROR_MESSAGE" and arg2 or arg1)))
    end
end

local function SetDebug(on)
    debugOn = on
    if on and not debugFrame then
        debugFrame = CreateFrame("Frame")
        debugFrame:SetScript("OnEvent", OnDebugEvent)
        hooksecurefunc("SetItemRef", OnLinkClick)
        hooksecurefunc(C_FriendList, "SendWho", OnSendWho)
        EventRegistry:RegisterCallback("Menu.OpenMenuTag", OnMenuTag, debugFrame)
    end
    if on then
        for _, event in ipairs({ "WHO_LIST_UPDATE", "CHAT_MSG_SYSTEM", "UI_ERROR_MESSAGE",
                "ADDON_ACTION_BLOCKED", "ADDON_ACTION_FORBIDDEN" }) do
            debugFrame:RegisterEvent(event)
        end
    elseif debugFrame then
        debugFrame:UnregisterAllEvents()
    end
    Chat("debug " .. (on and "on. Shift-click a name in chat, then use the Who entry on one." or "off."))
end

-------------------------------------------------------------------------------
--  Slash command
-------------------------------------------------------------------------------
local function Check()
    local unit = UnitIsPlayer("target") and "target" or "player"
    local filter = ExactFilter(UnitNameUnmodified(unit))
    Chat(("%s would search for %s"):format(unit == "target" and "your target" or "your own name",
        filter and Show(filter) or "nothing (name hidden by the game)"))
end

SLASH_WHOMENU1 = "/whomenu"
SlashCmdList.WHOMENU = function(msg)
    msg = (msg or ""):lower():match("^%s*(.-)%s*$")
    if msg == "check" then
        Check()
    elseif msg == "debug" then
        SetDebug(not debugOn)
    else
        Chat("right-click a player's portrait or name and choose Who.")
        Chat("/whomenu check: show the search for your target. /whomenu debug: log each step to chat.")
    end
end
