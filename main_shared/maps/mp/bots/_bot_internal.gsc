#include common_scripts\utility;
#include maps\mp\_utility;
#include maps\mp\gametypes\_hud_util;
#include maps\mp\bots\_bot_utility;

/*
	When a bot is added (once ever) to the game (before connected).
	We init all the persistent variables here.
*/
added()
{
	self endon("disconnect");
	
	self.pers["bots"] = [];
	
	self.pers["bots"]["skill"] = [];
	self.pers["bots"]["skill"]["base"] = 7;
	self.pers["bots"]["skill"]["aim_time"] = 0.05;
	self.pers["bots"]["skill"]["init_react_time"] = 0;
	self.pers["bots"]["skill"]["reaction_time"] = 0;
	self.pers["bots"]["skill"]["remember_time"] = 10000;
	self.pers["bots"]["skill"]["fov"] = -1;
	self.pers["bots"]["skill"]["dist"] = 100000;
	self.pers["bots"]["skill"]["spawn_time"] = 0;
	self.pers["bots"]["skill"]["help_dist"] = 10000;
	self.pers["bots"]["skill"]["semi_time"] = 0.05;
	
	self.pers["bots"]["behavior"] = [];
	self.pers["bots"]["behavior"]["strafe"] = 50;
	self.pers["bots"]["behavior"]["nade"] = 50;
	self.pers["bots"]["behavior"]["sprint"] = 50;
	self.pers["bots"]["behavior"]["camp"] = 50;
	self.pers["bots"]["behavior"]["follow"] = 50;
	self.pers["bots"]["behavior"]["crouch"] = 10;
	self.pers["bots"]["behavior"]["switch"] = 1;
	self.pers["bots"]["behavior"]["class"] = 1;
	self.pers["bots"]["behavior"]["jump"] = 100;
}

/*
	When a bot connects to the game.
	This is called when a bot is added and when multiround gamemode starts.
*/
connected()
{
	self endon("disconnect");
	
	self.bot = spawnStruct();
	self.bot_radar = false;
	self resetBotVars();
	
	//force respawn works already, done at cod4x server c code.
	self thread onPlayerSpawned();
	self thread bot_skip_killcam();
	self thread onUAVUpdate();
}

/*
	The thread for when the UAV gets updated.
*/
onUAVUpdate()
{
	self endon("disconnect");
	
	for(;;)
	{
		self waittill("radar_timer_kill");
		self thread doUAVUpdate();
	}
}

/*
	We tell that bot has a UAV.
*/
doUAVUpdate()
{
	self endon("disconnect");
	self endon("radar_timer_kill");
	
	self.bot_radar = true;//wtf happened to hasRadar? its bugging out, something other than script is touching it
	
	wait level.radarViewTime;
	
	self.bot_radar = false;
}

/*
	The callback hook for when the bot gets killed.
*/
onKilled(eInflictor, eAttacker, iDamage, sMeansOfDeath, sWeapon, vDir, sHitLoc, timeOffset, deathAnimDuration)
{
}

/*
	The callback hook when the bot gets damaged.
*/
onDamage(eInflictor, eAttacker, iDamage, iDFlags, sMeansOfDeath, sWeapon, vPoint, vDir, sHitLoc, timeOffset)
{
}

/*
	We clear all of the script variables and other stuff for the bots.
*/
resetBotVars()
{
	self.bot.script_target = undefined;
	self.bot.targets = [];
	self.bot.target = undefined;
	self.bot.target_this_frame = undefined;
	
	self.bot.script_aimpos = undefined;
	
	self.bot.script_goal = undefined;
	self.bot.script_goal_dist = 0.0;
	
	self.bot.next_wp = -1;
	self.bot.second_next_wp = -1;
	self.bot.towards_goal = undefined;
	self.bot.astar = [];
	
	self.bot.isfrozen = false;
	self.bot.sprintendtime = -1;
	self.bot.isreloading = false;
	self.bot.issprinting = false;
	self.bot.isfragging = false;
	self.bot.issmoking = false;
	self.bot.isfraggingafter = false;
	self.bot.issmokingafter = false;
	
	self.bot.semi_time = false;
	self.bot.jump_time = undefined;
	self.bot.greedy_path = false;
	self.bot.is_cur_full_auto = false;
	
	self.bot.rand = randomInt(100);
	
	self botStop();
}

/*
	Bots will skip killcams here.
*/
bot_skip_killcam()
{
	level endon("game_ended");
	self endon("disconnect");
	
	for(;;)
	{
		wait 1;
		
		if(isDefined(self.killcam))
		{
			self notify("end_killcam");
		}
	}
}

/*
	When the bot spawns.
*/
onPlayerSpawned()
{
	self endon("disconnect");
	
	for(;;)
	{
		self waittill("spawned_player");
		
		self resetBotVars();
		self thread onWeaponChange();
		
		self thread reload_watch();
		self thread sprint_watch();
		
		self thread spawned();
	}
}

/*
	We wait for a time defined by the bot's difficulty and start all threads that control the bot.
*/
spawned()
{
	self endon("disconnect");
	self endon("death");

	wait self.pers["bots"]["skill"]["spawn_time"];
	
	self thread grenade_danger();
	self thread check_reload();
	self thread stance();
	self thread walk();
	self thread target();
	self thread aim();
	self thread watchHoldBreath();
	self thread onNewEnemy();
	
	self notify("bot_spawned");
}

/*
	The hold breath thread.
*/
watchHoldBreath()
{
	self endon("disconnect");
	self endon("death");
	
	for(;;)
	{
		wait 1;
		
		if(self.bot.isfrozen)
			continue;
		
		self holdbreath((self playerADS() && weaponClass(self getCurrentWEapon()) == "rifle"));
	}
}

/*
	When the bot changes weapon.
*/
onWeaponChange()
{
	self endon("disconnect");
	self endon("death");
	
	for(;;)
	{
		self waittill( "weapon_change", newWeapon );
		
		self.bot.is_cur_full_auto = WeaponIsFullAuto(newWeapon);
		
		if(level.gameEnded || self.bot.isfrozen)
			continue;
		
		// A cod4x fix because bots don't switchtoweapon properally. When a bot goes on a ladder or mount, they will by stuck with a none weapon. Also fixes the bot's weapon while going into laststand.
		//fix for when switchtoweapon doesnt work and weapons get disabled from climbing or somethings
		if(newWeapon == "none")
		{
			if(!isDefined(self.lastStand) || !self.lastStand)
			{
				if(isDefined(self.lastDroppableWeapon) && self.lastDroppableWeapon != "none")
					self setSpawnWeapon(self.lastDroppableWeapon);
			}
			else
			{
				weaponslist = self getweaponslist();
				for( i = 0; i < weaponslist.size; i++ )
				{
					weapon = weaponslist[i];
					
					if ( maps\mp\gametypes\_weapons::isPistol( weapon ) )
					{
						self setSpawnWeapon(weapon);
						break;
					}
				}
			}
		}
	}
}

/*
	Updates the bot if it is sprinting.
*/
sprint_watch()
{
	self endon("disconnect");
	self endon("death");
	
	for(;;)
	{
		self waittill("sprint_begin");
		self.bot.issprinting = true;
		self waittill("sprint_end");
		self.bot.issprinting = false;
		self.bot.sprintendtime = getTime();
	}
}

/*
	Update's the bot if it is reloading.
*/
reload_watch()
{
	self endon("disconnect");
	self endon("death");
	
	for(;;)
	{
		self waittill("reload_start");
		self.bot.isreloading = true;
		self waittill_notify_or_timeout("reload", 7.5);
		self.bot.isreloading = false;
	}
}

/*
	Bots will update its needed stance according to the nodes on the level. Will also allow the bot to sprint when it can.
*/
stance()
{
	self endon("disconnect");
	self endon("death");
	
	for(;;)
	{
		self waittill_either("finished_static_waypoints", "new_static_waypoint");
		
		if(self.bot.isfrozen)
			continue;
	
		toStance = "stand";
		if(self.bot.next_wp != -1)
			toStance = level.waypoints[self.bot.next_wp].type;
		if(toStance != "stand" && toStance != "crouch" && toStance != "prone")
			toStance = "crouch";
			
		if(toStance == "stand" && randomInt(100) <= self.pers["bots"]["behavior"]["crouch"])
			toStance = "crouch";
			
		if(toStance == "stand")
			self stand();
		else if(toStance == "crouch")
			self crouch();
		else
			self prone();
			
		curweap = self getCurrentWeapon();
			
		if(toStance != "stand" || self.bot.isreloading || self.bot.issprinting || self.bot.isfraggingafter || self.bot.issmokingafter)
			continue;
			
		if(randomInt(100) > self.pers["bots"]["behavior"]["sprint"])
			continue;
			
		if(isDefined(self.bot.target) && self canFire(curweap) && self isInRange(self.bot.target.dist, curweap))
			continue;
			
		if(self.bot.sprintendtime != -1 && getTime() - self.bot.sprintendtime < 2000)
			continue;
			
		if(!isDefined(self.bot.towards_goal) || DistanceSquared(self.origin, self.bot.towards_goal) < level.bots_minSprintDistance || getConeDot(self.bot.towards_goal, self.origin, self GetPlayerAngles()) < 0.75)
			continue;
			
		self thread sprint();
	}
}

/*
	Bot will wait until there is a grenade nearby and possibly throw it back.
*/
grenade_danger()
{
	self endon("disconnect");
	self endon("death");
	
	for(;;)
	{
		self waittill("grenade danger", grenade, attacker, weapname);
		
		if(!isDefined(grenade))
			continue;
		
		if(weapname != "frag_grenade_mp")
			continue;
			
		if(isDefined(attacker) && level.teamBased && attacker.team == self.team)
			continue;
			
		self thread watch_grenade(grenade);
	}
}

/*
	Bot will throw back the given grenade if it is close, will watch until it is deleted or close.
*/
watch_grenade(grenade)
{
	self endon("disconnect");
	self endon("death");
	grenade endon("death");
	
	while(1)
	{
		wait 1;
		
		if(!isDefined(grenade))
		{
			return;
		}
		
		if(self.bot.isfrozen)
			continue;
	
		if(!bulletTracePassed(self getEyePos(), grenade.origin, false, grenade))
			continue;
			
		if(DistanceSquared(self.origin, grenade.origin) > 20000)
			continue;
		
		if(self.bot.isfraggingafter || self.bot.issmokingafter)
			continue;
		
		self thread frag();
	}
}

/*
	Bot will wait until firing.
*/
check_reload()
{
	self endon("disconnect");
	self endon("death");
	
	for(;;)
	{
		self waittill( "weapon_fired" );
		self thread reload_thread();
	}
}

/*
	Bot will reload after firing if needed.
*/
reload_thread()
{
	self endon("disconnect");
	self endon("death");
	self endon("weapon_fired");
	
	wait 2.5;
	
	if(isDefined(self.bot.target) || self.bot.isreloading || self.bot.isfraggingafter || self.bot.issmokingafter || self.bot.isfrozen)
		return;
		
	cur = self getCurrentWEapon();
	
	if(IsWeaponClipOnly(cur) || !self GetWeaponAmmoStock(cur))
		return;
	
	maxsize = WeaponClipSize(cur);
	cursize = self GetWeaponammoclip(cur);
	
	if(cursize/maxsize < 0.5)
		self thread reload();
}

/*
	The main target thread, will update the bot's main target. Will auto target enemy players and handle script targets.
*/
target()
{
	self endon("disconnect");
	self endon("death");
	
	for(;;)
	{
		wait 0.05;
		
		if(self maps\mp\_flashgrenades::isFlashbanged())
			continue;
	
		myEye = self GetEyePos();
		theTime = getTime();
		myAngles = self GetPlayerAngles();
		distsq = self.pers["bots"]["skill"]["dist"];
		distsq *= distsq;
		myFov = self.pers["bots"]["skill"]["fov"];
		bestTargets = [];
		bestTime = 9999999999;
		rememberTime = self.pers["bots"]["skill"]["remember_time"];
		initReactTime = self.pers["bots"]["skill"]["init_react_time"];
		hasTarget = isDefined(self.bot.target);
		
		if(hasTarget && !isDefined(self.bot.target.entity))
		{
			self.bot.target = undefined;
			hasTarget = false;
		}
		
		if(isDefined(self.bot.script_target))
		{
			ent = self.bot.script_target;
			key = ent getEntityNumber()+"";
			daDist = distanceSquared(self.origin, ent.origin);
			obj = self.bot.targets[key];
			isObjDef = isDefined(obj);
			entOrigin = ent.origin + (0, 0, 5);
			
			for(;;)
			{
				if(daDist > distsq)
				{
					if(isObjDef)
						self.bot.targets[key] = undefined;
				
					break;
				}
				
				if(SmokeTrace(myEye, entOrigin, level.smokeRadius) && bulletTracePassed(myEye, entOrigin, false, ent))
				{
					if(!isObjDef)
					{
						obj = spawnStruct();
						obj.entity = ent;
						obj.last_seen_pos = (0, 0, 0);
						obj.dist = 0;
						obj.time = theTime;
						obj.trace_time = 0;
						obj.no_trace_time = 0;
						obj.trace_time_time = 0;
						obj.rand = randomInt(100);
						obj.didlook = false;
						
						self.bot.targets[key] = obj;
					}
					
					obj.no_trace_time = 0;
					obj.trace_time += 50;
					obj.dist = daDist;
					obj.last_seen_pos = ent.origin;
					obj.trace_time_time = theTime;
				}
				else
				{
					if(!isObjDef)
						break;
					
					obj.no_trace_time += 50;
					obj.trace_time = 0;
					obj.didlook = false;
					
					if(obj.no_trace_time > rememberTime)
					{
						self.bot.targets[key] = undefined;
						break;
					}
				}
				
				if(theTime - obj.time < initReactTime)
					break;
				
				timeDiff = theTime - obj.trace_time_time;
				if(timeDiff < bestTime)
				{
					bestTargets = [];
					bestTime = timeDiff;
				}
				
				if(timeDiff == bestTime)
					bestTargets[key] = obj;
				break;
			}
		}
		
		if(isDefined(self.bot.target_this_frame))
		{
			player = self.bot.target_this_frame;
		
			key = player getEntityNumber()+"";
			obj = self.bot.targets[key];
			daDist = distanceSquared(self.origin, player.origin);
			
			if(!isDefined(obj))
			{
				obj = spawnStruct();
				obj.entity = player;
				obj.last_seen_pos = (0, 0, 0);
				obj.dist = 0;
				obj.time = theTime;
				obj.trace_time = 0;
				obj.no_trace_time = 0;
				obj.trace_time_time = 0;
				obj.rand = randomInt(100);
				obj.didlook = false;
				
				self.bot.targets[key] = obj;
			}
			
			obj.no_trace_time = 0;
			obj.trace_time += 50;
			obj.dist = daDist;
			obj.last_seen_pos = player.origin;
			obj.trace_time_time = theTime;
			
			self.bot.target_this_frame = undefined;
		}
		
		playercount = level.players.size;
		for(i = 0; i < playercount; i++)
		{
			player = level.players[i];
			
			if(!isDefined(player.bot_model_fix))
				continue;
			if(player == self)
				continue;
			
			key = player getEntityNumber()+"";
			obj = self.bot.targets[key];
			daDist = distanceSquared(self.origin, player.origin);
			isObjDef = isDefined(obj);
			if((level.teamBased && self.team == player.team) || player.sessionstate != "playing" || !isAlive(player) || daDist > distsq)
			{
				if(isObjDef)
					self.bot.targets[key] = undefined;
			
				continue;
			}
			
			if((bulletTracePassed(myEye, player getTagOrigin( "j_head" ), false, player) || bulletTracePassed(myEye, player getTagOrigin( "j_ankle_le" ), false, player) || bulletTracePassed(myEye, player getTagOrigin( "j_ankle_ri" ), false, player)) && (SmokeTrace(myEye, player.origin, level.smokeRadius) || daDist < level.bots_maxKnifeDistance*4) && (getConeDot(player.origin, self.origin, myAngles) >= myFov || (isObjDef && obj.trace_time)))
			{
				if(!isObjDef)
				{
					obj = spawnStruct();
					obj.entity = player;
					obj.last_seen_pos = (0, 0, 0);
					obj.dist = 0;
					obj.time = theTime;
					obj.trace_time = 0;
					obj.no_trace_time = 0;
					obj.trace_time_time = 0;
					obj.rand = randomInt(100);
					obj.didlook = false;
					
					self.bot.targets[key] = obj;
				}
				
				obj.no_trace_time = 0;
				obj.trace_time += 50;
				obj.dist = daDist;
				obj.last_seen_pos = player.origin;
				obj.trace_time_time = theTime;
			}
			else
			{
				if(!isObjDef)
					continue;
				
				obj.no_trace_time += 50;
				obj.trace_time = 0;
				obj.didlook = false;
				
				if(obj.no_trace_time > rememberTime)
				{
					self.bot.targets[key] = undefined;
					continue;
				}
			}
			
			if(theTime - obj.time < initReactTime)
				continue;
			
			timeDiff = theTime - obj.trace_time_time;
			if(timeDiff < bestTime)
			{
				bestTargets = [];
				bestTime = timeDiff;
			}
			
			if(timeDiff == bestTime)
				bestTargets[key] = obj;
		}
		
		if(hasTarget && isDefined(bestTargets[self.bot.target.entity getEntityNumber()+""]))
			continue;
		
		closest = 9999999999;
		toBeTarget = undefined;
		
		bestKeys = getArrayKeys(bestTargets);
		for(i = bestKeys.size - 1; i >= 0; i--)
		{
			theDist = bestTargets[bestKeys[i]].dist;
			if(theDist > closest)
				continue;
				
			closest = theDist;
			toBeTarget = bestTargets[bestKeys[i]];
		}
		
		beforeTargetID = -1;
		newTargetID = -1;
		if(hasTarget)
			beforeTargetID = self.bot.target.entity getEntityNumber();
		if(isDefined(toBeTarget))
			newTargetID = toBeTarget.entity getEntityNumber();
		
		if(beforeTargetID != newTargetID)
		{
			self.bot.target = toBeTarget;
			self notify("new_enemy");
		}
	}
}

/*
	When the bot gets a new enemy.
*/
onNewEnemy()
{
	self endon("disconnect");
	self endon("death");
	
	for(;;)
	{
		self waittill("new_enemy");
		
		if(!isDefined(self.bot.target))
			continue;
			
		if(!isDefined(self.bot.target.entity) || !isPlayer(self.bot.target.entity))
			continue;
			
		if(self.bot.target.didlook)
			continue;
			
		self thread watchToLook();
	}
}

/*
	Bots will jump or dropshot their enemy player.
*/
watchToLook()
{
	self endon("disconnect");
	self endon("death");
	self endon("new_enemy");
	
	for(;;)
	{
		while(self.bot.target.didlook)
			wait 0.05;
	
		while(self.bot.target.dist)
			wait 0.05;
		
		self.bot.target.didlook = true;
		
		if(self.bot.isfrozen)
			continue;
		
		if(self.bot.target.dist > level.bots_maxShotgunDistance*2)
			continue;
			
		if(self.bot.target.dist <= level.bots_maxKnifeDistance)
			continue;
		
		curweap = self getCurrentWEapon();
		if(!self canFire(curweap))
			continue;
			
		if(!self isInRange(self.bot.target.dist, curweap))
			continue;
			
		if(randomInt(100) > self.pers["bots"]["behavior"]["jump"])
			continue;
		
		thetime = getTime();
		if(isDefined(self.bot.jump_time) && thetime - self.bot.jump_time <= 5000)
			continue;
			
		if(self.bot.target.rand <= self.pers["bots"]["behavior"]["strafe"])
		{
			if(self getStance() != "stand")
				continue;
			
			self.bot.jump_time = thetime;
			self jump();
		}
		else
		{
			if(getConeDot(self.bot.target.last_seen_pos, self.origin, self getPlayerAngles()) < 0.8 || self.bot.target.dist <= level.bots_noADSDistance)
				continue;
		
			self.bot.jump_time = thetime;
			self prone();
			wait 2.5;
			self crouch();
		}
	}
}

/*
	This is the bot's main aimming thread. The bot will aim at its targets or a node its going towards. Bots will aim, fire, ads, grenade.
*/
aim()
{
	self endon("disconnect");
	self endon("death");
	
	for(;;)
	{
		wait 0.05;
		
		if(level.inPrematchPeriod || level.gameEnded || self.bot.isfrozen || self maps\mp\_flashgrenades::isFlashbanged())//because cod4x aim is hacky setPlayerAngles, we gotta check if inPrematchPeriod etc
			continue;
			
		aimspeed = self.pers["bots"]["skill"]["aim_time"];
		if(self IsStunned() || self isArtShocked())
			aimspeed = 1;
		
		if(isDefined(self.bot.target) && isDefined(self.bot.target.entity))
		{
			trace_time = self.bot.target.trace_time;
			no_trace_time = self.bot.target.no_trace_time;
			last_pos = self.bot.target.last_seen_pos;
			target = self.bot.target.entity;
			conedot = 0;
			isplay = isPlayer(target);
			dist = self.bot.target.dist;
			curweap = self getCurrentWeapon();
			eyePos = self getEyePos();
			angles = self GetPlayerAngles();
			rand = self.bot.target.rand;
			remember_time = self.pers["bots"]["skill"]["remember_time"];
			reaction_time = self.pers["bots"]["skill"]["reaction_time"];
			nadeAimOffset = 0;
			myeye = self getEyePos();
			
			if(self.bot.isfraggingafter || self.bot.issmokingafter)
				nadeAimOffset = dist/3000;
			else if(weaponClass(curweap) == "grenade")
				nadeAimOffset = dist/16000;
			
			if(no_trace_time)
			{
				if(no_trace_time > remember_time/2)
				{
					self ads(false);
					
					if(isplay)
					{
						//better room to nade? cook time function with dist?
						if(!self.bot.isfraggingafter && !self.bot.issmokingafter)
						{
							nade = self getValidGrenade();
							if(isDefined(nade) && rand <= self.pers["bots"]["behavior"]["nade"] && bulletTracePassed(myEye, myEye + (0, 0, 75), false, self) && bulletTracePassed(last_pos, last_pos + (0, 0, 100), false, target))
							{
								if(nade == "frag_grenade_mp")
									self thread frag(2.5);
								else
									self thread smoke(0.5);
									
								self notify("kill_goal");
							}
						}
					}
					else
					{
						self stopNading();
					}
				}
				
				self botLookAt(last_pos + (0, 0, self getEyeHeight() + nadeAimOffset), aimspeed);
				continue;
			}
			
			self stopNading();
			
			if(isplay)
			{
				aimpos = target getTagOrigin( "j_spineupper" ) + (0, 0, nadeAimOffset);
				conedot = getConeDot(aimpos, eyePos, angles);
				
				if(!nadeAimOffset && conedot > 0.999)
				{
					//self botLookAtPlayer(target, "j_spineupper");//cod4x is crashing when this is called
					self botLookAt(aimpos, aimspeed);
				}
				else
				{
					self botLookAt(aimpos, aimspeed);
				}
			}
			else
			{
				aimpos = target.origin + (0, 0, 5 + nadeAimOffset);
				conedot = getConeDot(aimpos, eyePos, angles);
				self botLookAt(aimpos, aimspeed);
			}
			
			if(isplay && conedot > 0.9 && dist < level.bots_maxKnifeDistance && trace_time > reaction_time)
			{
				self ads(false);
				self knife();
				continue;
			}
			
			if(!self canFire(curweap) || !self isInRange(dist, curweap))
			{
				self ads(false);
				continue;
			}
			
			//c4 logic here, but doesnt work anyway
			
			canADS = self canAds(dist, curweap);
			self ads(canADS);
			if((!canADS || self playerads() == 1.0) && conedot > 0.999 && trace_time > reaction_time)
			{
				self botFire();
			}
			
			continue;
		}
		
		self ads(false);
		self stopNading();
		
		lookat = self.bot.script_aimpos;
		if(self.bot.second_next_wp != -1 && !self.bot.issprinting)
			lookat = level.waypoints[self.bot.second_next_wp].origin;
		else if(isDefined(self.bot.towards_goal))
			lookat = self.bot.towards_goal;
		
		if(isDefined(lookat))
			self botLookAt(lookat + (0, 0, self getEyeHeight()), aimspeed);
	}
}

/*
	Bots will fire their gun.
*/
botFire()
{
	if(self.bot.is_cur_full_auto)
	{
		self thread pressFire();
		return;
	}

	if(self.bot.semi_time)
		return;
		
	self thread pressFire();
	self thread doSemiTime();
}

/*
	Waits a time defined by their difficulty for semi auto guns (no rapid fire)
*/
doSemiTime()
{
	self endon("death");
	self endon("disconnect");
	self notify("bot_semi_time");
	self endon("bot_semi_time");
	
	self.bot.semi_time = true;
	wait self.pers["bots"]["skill"]["semi_time"];
	self.bot.semi_time = false;
}

/*
	Stop the bot from nading.
*/
stopNading()
{
	if(self.bot.isfragging)
		self thread frag(0);
	if(self.bot.issmoking)
		self thread smoke(0);
}

/*
	Returns a random grenade in the bot's inventory.
*/
getValidGrenade()
{
	grenadeTypes = [];
	grenadeTypes[grenadeTypes.size] = "frag_grenade_mp";
	grenadeTypes[grenadeTypes.size] = "smoke_grenade_mp";
	grenadeTypes[grenadeTypes.size] = "flash_grenade_mp";
	grenadeTypes[grenadeTypes.size] = "concussion_grenade_mp";
	
	possibles = [];
	
	for(i = 0; i < grenadeTypes.size; i++)
	{
		if ( !self hasWeapon( grenadeTypes[i] ) )
			continue;
			
		if ( !self getAmmoCount( grenadeTypes[i] ) )
			continue;
			
		possibles[possibles.size] = grenadeTypes[i];
	}
	
	return random(possibles);
}

/*
	Returns true if the bot can fire their current weapon.
*/
canFire(curweap)
{
	if(curweap == "none")
		return false;
		
	return self GetWeaponammoclip(curweap);
}

/*
	Returns true if the bot can ads their current gun.
*/
canAds(dist, curweap)
{
	far = level.bots_noADSDistance;
	if(self hasPerk("specialty_bulletaccuracy"))
		far *= 1.4;

	if(dist < far)
		return false;
	
	weapclass = (weaponClass(curweap));
	if(weapclass == "spread" || weapclass == "grenade")
		return false;
	
	return true;
}

/*
	Returns true if the bot is in range of their target.
*/
isInRange(dist, curweap)
{
	weapclass = weaponClass(curweap);
	
	if(weapclass == "spread" && dist > level.bots_maxShotgunDistance)
		return false;
		
	return true;
}

/*
	This is the main walking logic for the bot.
*/
walk()
{
	self endon("disconnect");
	self endon("death");
	
	for(;;)
	{
		wait 0.05;
		
		self botMoveTo(self.origin);
		
		if(self.bot.isfrozen)
			continue;
			
		if(self maps\mp\_flashgrenades::isFlashbanged())
		{
			self botMoveTo(self.origin + self GetVelocity()*500);
			continue;
		}
		
		hasTarget = isDefined(self.bot.target) && isDefined(self.bot.target.entity);
		if(hasTarget)
		{
			curweap = self getCurrentWeapon();
			
			if(self.bot.target.entity.classname == "script_vehicle" || self.bot.isfraggingafter || self.bot.issmokingafter)
			{
				continue;
			}
			
			if(isPlayer(self.bot.target.entity) && self.bot.target.trace_time && self canFire(curweap) && self isInRange(self.bot.target.dist, curweap))
			{
				if(self.bot.target.rand <= self.pers["bots"]["behavior"]["strafe"])
					self strafe(self.bot.target.entity);
				continue;
			}
		}
		
		dist = 16;
		if(level.waypointCount)
			goal = level.waypoints[randomInt(level.waypointCount)].origin;
		else
			goal = (0, 0, 0);
		
		if(isDefined(self.bot.script_goal) && !hasTarget)
		{
			goal = self.bot.script_goal;
			dist = self.bot.script_goal_dist;
		}
		else
		{
			if(hasTarget)
				goal = self.bot.target.last_seen_pos;
				
			self notify("new_goal");
		}
		
		self doWalk(goal, dist);
		self.bot.towards_goal = undefined;
		self.bot.next_wp = -1;
		self.bot.second_next_wp = -1;
	}
}

/*
	The bot will strafe left or right from their enemy.
*/
strafe(target)
{
	self endon("new_enemy");
	self endon("flash_rumble_loop");
	self endon("kill_goal");
	
	angles = VectorToAngles(vectorNormalize(target.origin - self.origin));
	anglesLeft = (0, angles[1]+90, 0);
	anglesRight = (0, angles[1]-90, 0);
	
	myOrg = self.origin + (0, 0, 16);
	left = myOrg + anglestoforward(anglesLeft)*500;
	right = myOrg + anglestoforward(anglesRight)*500;
	
	traceLeft = BulletTrace(myOrg, left, false, self);
	traceRight = BulletTrace(myOrg, right, false, self);
	
	strafe = traceLeft["position"];
	if(traceRight["fraction"] > traceLeft["fraction"])
		strafe = traceRight["position"];
	
	self botMoveTo(strafe);
	wait 2;
}

/*
	Will kill the goal when the bot made it to its goal.
*/
watchOnGoal(goal, dis)
{
	self endon("disconnect");
	self endon("death");
	self endon("kill_goal");
	
	while(DistanceSquared(self.origin, goal) > dis)
		wait 0.05;
		
	self notify("goal");
}

/*
	Cleans up the astar nodes when the goal is killed.
*/
cleanUpAStar(team)
{
	self waittill_any("death", "disconnect", "kill_goal");
	
	for(i = self.bot.astar.size - 1; i >= 0; i--)
		level.waypoints[self.bot.astar[i]].bots[team]--;
}

/*
	Calls the astar search algorithm for the path to the goal.
*/
initAStar(goal)
{
	team = undefined;
	if(level.teamBased)
		team = self.team;
		
	self.bot.astar = AStarSearch(self.origin, goal, team);
	
	if(isDefined(team))
		self thread cleanUpAStar(team);
	
	return self.bot.astar.size - 1;
}

/*
	Cleans up the astar nodes for one node.
*/
removeAStar()
{
	remove = self.bot.astar.size-1;
	
	if(level.teamBased)
		level.waypoints[self.bot.astar[remove]].bots[self.team]--;
	
	self.bot.astar[remove] = undefined;
	
	return self.bot.astar.size - 1;
}

/*
	Will stop the goal walk when an enemy is found or flashed or a new goal appeared for the bot.
*/
killWalkOnEvents()
{
	self endon("kill_goal");
	self endon("disconnect");
	self endon("death");
	
	self waittill_any("flash_rumble_loop", "new_enemy", "new_goal", "goal", "bad_path");
	
	self notify("kill_goal");
}

/*
	Will walk to the given goal when dist near. Uses AStar path finding with the level's nodes.
*/
doWalk(goal, dist)
{
	self endon("kill_goal");
	self endon("goal");//so that the watchOnGoal notify can happen same frame, not a frame later
	
	distsq = dist*dist;
	self thread killWalkOnEvents();
	self thread watchOnGoal(goal, distsq);
	
	current = self initAStar(goal);
	while(current >= 0)
	{
		self.bot.next_wp = self.bot.astar[current];
		self.bot.second_next_wp = -1;
		if(current != 0)
			self.bot.second_next_wp = self.bot.astar[current-1];
		
		self notify("new_static_waypoint");
		
		self movetowards(level.waypoints[self.bot.next_wp].origin);
	
		current = self removeAStar();
	}
	
	self.bot.next_wp = -1;
	self.bot.second_next_wp = -1;
	self notify("finished_static_waypoints");
	
	if(DistanceSquared(self.origin, goal) > distsq)
	{
		self movetowards(goal);
	}
	
	self notify("finished_goal");
	
	wait 1;
	if(DistanceSquared(self.origin, goal) > distsq)
		self notify("bad_path");
}

/*
	Will move towards the given goal. Will try to not get stuck by crouching, then jumping and then strafing around objects.
*/
movetowards(goal)
{
	if(isDefined(goal))
		self.bot.towards_goal = goal;

	lastOri = self.origin;
	stucks = 0;
	timeslow = 0;
	time = 0;
	while(distanceSquared(self.origin, self.bot.towards_goal) > level.bots_goalDistance)
	{
		self botMoveTo(self.bot.towards_goal);
		
		if(time > 2.5)
		{
			time = 0;
			if(distanceSquared(self.origin, lastOri) < 128)
			{
				stucks++;
				
				randomDir = self getRandomLargestStafe(stucks);
			
				self botMoveTo(randomDir);
				wait stucks;
			}
			
			lastOri = self.origin;
		}
		else if(timeslow > 1.5)
		{
			self thread jump();
		}
		else if(timeslow > 0.75)
		{
			self crouch();
		}
		
		wait 0.05;
		time += 0.05;
		if(lengthsquared(self getVelocity()) < 1000)
			timeslow += 0.05;
		else
			timeslow = 0;
		
		if(stucks == 3)
			self notify("bad_path");
	}
	
	self.bot.towards_goal = undefined;
	self notify("completed_move_to");
}

/*
	Will return the pos of the largest trace from the bot.
*/
getRandomLargestStafe(dist)
{
	//find a better algo?
	traces = NewHeap(::HeapTraceFraction);
	myOrg = self.origin + (0, 0, 16);
	
	traces HeapInsert(bulletTrace(myOrg, myOrg + (-100*dist, 0, 0), false, self));
	traces HeapInsert(bulletTrace(myOrg, myOrg + (100*dist, 0, 0), false, self));
	traces HeapInsert(bulletTrace(myOrg, myOrg + (0, 100*dist, 0), false, self));
	traces HeapInsert(bulletTrace(myOrg, myOrg + (0, -100*dist, 0), false, self));
	traces HeapInsert(bulletTrace(myOrg, myOrg + (-100*dist, -100*dist, 0), false, self));
	traces HeapInsert(bulletTrace(myOrg, myOrg + (-100*dist, 100*dist, 0), false, self));
	traces HeapInsert(bulletTrace(myOrg, myOrg + (100*dist, -100*dist, 0), false, self));
	traces HeapInsert(bulletTrace(myOrg, myOrg + (100*dist, 100*dist, 0), false, self));
	
	toptraces = [];
	
	top = traces.data[0];
	toptraces[toptraces.size] = top;
	traces HeapRemove();
	
	while(traces.data.size && top["fraction"] - traces.data[0]["fraction"] < 0.1)
	{
		toptraces[toptraces.size] = traces.data[0];
		traces HeapRemove();
	}
	
	return toptraces[randomInt(toptraces.size)]["position"];
}

/*
	Bot will hold breath if true or not
*/
holdbreath(what)
{
	if(what)
		self botAction("+holdbreath");
	else
		self botAction("-holdbreath");
}

/*
	Bot will sprint.
*/
sprint()
{
	self endon("death");
	self endon("disconnect");
	self notify("bot_sprint");
	self endon("bot_sprint");
	
	self botAction("+sprint");
	wait 0.05;
	self botAction("-sprint");
}

/*
	Bot will knife.
*/
knife()
{
	self endon("death");
	self endon("disconnect");
	self notify("bot_knife");
	self endon("bot_knife");
	
	self botAction("+melee");
	wait 0.05;
	self botAction("-melee");
}

/*
	Bot will reload.
*/
reload()
{
	self endon("death");
	self endon("disconnect");
	self notify("bot_reload");
	self endon("bot_reload");
	
	self botAction("+reload");
	wait 0.05;
	self botAction("-reload");
}

/*
	Bot will hold the frag button for a time
*/
frag(time)
{
	self endon("death");
	self endon("disconnect");
	self notify("bot_frag");
	self endon("bot_frag");

	if(!isDefined(time))
		time = 0.05;
	
	self botAction("+frag");
	self.bot.isfragging = true;
	self.bot.isfraggingafter = true;
	
	if(time)
		wait time;
		
	self botAction("-frag");
	self.bot.isfragging = false;
	
	wait 1.25;
	self.bot.isfraggingafter = false;
}

/*
	Bot will hold the 'smoke' button for a time.
*/
smoke(time)
{
	self endon("death");
	self endon("disconnect");
	self notify("bot_smoke");
	self endon("bot_smoke");

	if(!isDefined(time))
		time = 0.05;
	
	self botAction("+smoke");
	self.bot.issmoking = true;
	self.bot.issmokingafter = true;
	
	if(time)
		wait time;
		
	self botAction("-smoke");
	self.bot.issmoking = false;
	
	wait 1.25;
	self.bot.issmokingafter = false;
}

/*
	Bot will fire if true or not.
*/
fire(what)
{
	self notify("bot_fire");
	if(what)
		self botAction("+fire");
	else
		self botAction("-fire");
}

/*
	Bot will fire for a time.
*/
pressFire(time)
{
	self endon("death");
	self endon("disconnect");
	self notify("bot_fire");
	self endon("bot_fire");

	if(!isDefined(time))
		time = 0.05;
	
	self botAction("+fire");
	
	if(time)
		wait time;
		
	self botAction("-fire");
}

/*
	Bot will ads if true or not.
*/
ads(what)
{
	self notify("bot_ads");
	if(what)
		self botAction("+ads");
	else
		self botAction("-ads");
}

/*
	Bot will press ADS for a time.
*/
pressADS(time)
{
	self endon("death");
	self endon("disconnect");
	self notify("bot_ads");
	self endon("bot_ads");

	if(!isDefined(time))
		time = 0.05;
	
	self botAction("+ads");
	
	if(time)
		wait time;
	
	self botAction("-ads");
}

/*
	Bot will jump.
*/
jump()
{
	self endon("death");
	self endon("disconnect");
	self notify("bot_jump");
	self endon("bot_jump");

	if(self getStance() != "stand")
	{
		self stand();
		wait 1;
	}

	self botAction("+gostand");
	wait 0.05;
	self botAction("-gostand");
}

/*
	Bot will stand.
*/
stand()
{
	self botAction("-gocrouch");
	self botAction("-goprone");
}

/*
	Bot will crouch.
*/
crouch()
{
	self botAction("+gocrouch");
	self botAction("-goprone");
}

/*
	Bot will prone.
*/
prone()
{
	self botAction("-gocrouch");
	self botAction("+goprone");
}
