# Who Menu

A World of Warcraft Forever addon that adds **Who** to the right-click menu of a player's portrait or name. It runs the same exact-name `/who` the game sends when you shift-click a name in chat.

## Requirements

- The WoW Forever client (Interface 16001). No other addons are needed.

## Install

Put this folder in `World of Warcraft/_forever_/Interface/AddOns/` and name it exactly `WhoMenu`. GitHub's "Download ZIP" unpacks to `WhoMenu-main`; rename it, because WoW only loads a folder whose name matches the `.toc` file inside it.

## Use

Right-click one of these and choose **Who**:

- a player's portrait (target or focus), or a party or raid member
- a name in chat, the friends list, the Who list, recent allies or a channel roster
- a member in the guild or community list

Battle.net friends don't get the entry. Opposite-faction players do on EllesmereUI's unit frames, which open the friendly player menu for everyone, but not on Blizzard's target frame. The entry is left out when the game hides a player's name from addons, which it does in some fights and instances.

- `/whomenu check` shows the search it would send for your target, or for you with no player targeted.
- `/whomenu debug` logs each step of a search to chat: the click, the menu, the search and the answer. Run it again to turn it off.

## How it works

Blizzard's `Menu.ModifyMenu` adds the entry, so no menu is replaced. The search is `WHO_TAG_EXACT` plus the full name, with the surname separator swapped by `C_NameUtil.ReplaceSurnameSeparatorWithLinkSeparator`, the way Blizzard builds it. `C_FriendList.SendWho` is called straight from the click, because the game drops a search an addon starts on its own. The answer appears wherever a typed `/who` would put it.

## Tests

`lua5.1 tests/harness.lua WhoMenu.lua`, run from this folder, loads the addon against stubbed WoW API functions.
