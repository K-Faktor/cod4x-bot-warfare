|\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/|
///////////CoD4x Bot Warfare//////////////
Feel free to use code, however give credit where credit is due!
	-INeedGames/INeedBot(s) @ ineedbots@outlook.com
|________________________________________|

Contents:
1: Features
2: Installation/Requirements
3: FAQs/Usage
4: Changelog
5: Credits

|\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/|
///////////////1: Features////////////////
This is a beta. Not all features are yet available.
Expect bomb type gamemodes, bots camping, following and nade shotting in the final release.
And a more detailed readme and tutorial...


Bots will play all objectives except for the bomb gametypes, that will be in the final release.


Still need botLookAtPlayer (https://github.com/callofduty4x/CoD4x_Server/issues/261) and SwitchToWeapon (https://github.com/callofduty4x/CoD4x_Server/issues/243) GSC functions to work for the bots.
And fixing the 'bot movement done' spam when 'developer' is disabled.


---

Whats different?

Well this makes use of CoD4x's custom GSC bot functions, these functions allows bots to be controlled in a more natural way.
Bots can ADS, jump, knife, mount, move, sprint etc.

Not only that, but the scripts are MUCH more efficient then any bot mod previously for the cod games. Every script has been remade from scratch with optimization in mind the whole time.
For example, I can have a 20v20 game of bots with only 7% CPU utilization on my 6700k.

The mod is stable and rid of any script errors.
But having too many bots in the game (over 32) may cause the exceeded script variables error. This is just a hard limit of the engine.

The AStar search has been completely remade, it makes use of heaps, sets and KDTrees for much better performance.
It also has been modified to make paths that bots are taking more expensive, so that the bots may split up instead of all of them taking the same 'best path'.
|________________________________________|

|\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/|
///////2: Installation/Requirements///////
This mod requires CoD4x client + server. You can find everything you need at https://cod4x.me/

Once you got a working CoD4x server, simply add the 'main_shared' folder found in 'Add to root of CoD4x server' folder to the root of your CoD4x server installation.

Start the server and you can use the new DVARs (or add them to your server.cfg) provided below to customize your game with bots.

You can now connect to your server with the CoD4x client and play with the bots.
|________________________________________|

|\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/|
///////////////3: FAQs/Usage//////////////
Server DVARs:
bots_manage_add - an integer amount of bots to add to the game, resets to 0 once the bots have been added.
	for example: 'bots_manage_add 10' will add 10 bots to the game.

bots_manage_fill - an integer amount of players/bots (depends on bots_manage_fill_mode) to retain on the server, it will automatically add bots to fill player space.
	for example: 'bots_manage_fill 10' will have the server retain 10 players in the server, if there are less than 10, it will add bots until that value is reached.

bots_manage_fill_mode - a value to indicate if the server should consider only bots or players and bots when filling player space.
	0 will consider both players and bots.
	1 will only consider bots.

bots_manage_fill_kick - a boolean value (0 or 1), whether or not if the server should kick bots if the amount of players/bots (depends on bots_manage_fill_mode) exceeds the value of bots_manage_fill.

bots_manage_fill_spec - a boolean value (0 or 1), whether or not if the server should consider players who are on the spectator team when filling player space.


bots_team - a string, the value indicates what team the bots should join:
	'autoassign' will have bots balance the teams
	'allies' will have the bots join the allies team
	'axis' will have the bots join the axis team
	'custom' will have bots_team_amount bots on the axis team, the rest will be on the allies team
	
bots_team_amount - an integer amount of bots to have on the axis team if bots_team is set to 'custom', the rest of the bots will be placed on the allies team.
	for example: there are 5 bots on the server and 'bots_team_amount 3', then 3 bots will be placed on the axis team, the other 2 will be placed on the allies team.

bots_team_force - a boolean value (0 or 1), whether or not if the server should enforce periodically the bot's team instead of just a single team when the bot is added to the game.
	for example: 'bots_team_force 1' and 'bots_team autoassign' and the teams become to far unbalanced, then the server will change a bot's team to make it balanced again.

bots_team_mode - a value to indicate if the server should consider only bots or players and bots when counting players on the teams.
	0 will consider both players and bots.
	1 will only consider bots.


bots_skill - value to indicate how difficult the bots should be.
	0 will be mixed difficultly
	1 will be the most easy
	2-6 will be in between most easy and most hard
	7 will be the most hard.
	8 will be custom.

bots_skill_axis_hard - an integer amount of hard bots on the axis team.
bots_skill_axis_med - an integer amount of medium bots on the axis team.
bots_skill_allies_hard - an integer amount of hard bots on the allies team.
bots_skill_allies_med - an integer amount of medium bots on the allies team, if bots_skill is 8 (custom). The remaining bots on the team will become easy bots.
	for example: having 5 bots on the allies team, 'bots_skill_allies_hard 2' and 'bots_skill_allies_med 2' will have 2 hard bots, 2 medium bots, and 1 easy bot on the allies team.


bots_loadout_reasonable - a boolean value (0 or 1), whether or not if the bots should filter out bad create a class selections (like no silenced miniuzi with overkill perk, etc)

bots_loadout_allow_op - a boolean value (0 or 1), whether or not if the bots are allowed to use jug, marty and laststand.
|________________________________________|

|\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/|
///////////////4: Changelog///////////////
Prerelease (1/2/2019):
	Initial release.
|________________________________________|

|\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/|
////////////////5: Credits////////////////
INeedGames(me) - creator: http://www.moddb.com/mods/bot-warfare
PeZBOT team - snippets and inspiration: https://www.moddb.com/mods/pezbot
CoD4x team - for the CoD4x server and client: https://cod4x.me/
|________________________________________|


Feel free to use code, host on other sites, host on servers, mod it and merge mods with it, just give credit where credit is due!
	-INeedGames/INeedBot(s) @ ineedbots@outlook.com
