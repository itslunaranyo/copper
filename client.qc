/*
==============================================================================

CLIENT

==============================================================================
*/


void() SetChangeParms =
{
	if(reset_flag)
	{
		setspawnparms(self);
		return;
	}
	
	if (self.health <= 0)
	{
		SetNewParms ();
		return;
	}

	// remove items
	self.items = self.items - (self.items & (
		IT_KEY1 | IT_KEY2 | 
		IT_INVISIBILITY | IT_INVULNERABILITY | IT_SUIT | IT_QUAD
		) );
	
	// gung-ho players can run forward and grab weapons before other clients have
	// finished connecting, causing them to miss out on the global distribution
	// of that weapon in coop 1. since players can't actually have differing
	// sets of weapons in coop 1 otherwise, we union existing players' weapon sets
	// on connect to make sure nothing is missed and no late joins wind up gimped
	// for the rest of the episode
	if (coop == 1)
	{
		entity pl;
		pl = nextent(world);
		while (pl.flags & FL_CLIENT)
		{
			self.items |= pl.items & IT_WEAPONS;
			pl = nextent(pl);
		}		
	}
	
	// cap super health
	self.health = min(self.health, self.max_health);		
	// bump the player up if he's below 50 <- pretty much the only 'autobalance' in quake
	if (skill < 3)	// nightmare players now get no help
		self.health = max(self.health, 50);
	
	parm1 = self.items;
	parm2 = self.health;
	parm3 = self.armorvalue;
	// provide an ammo floor similar to the health floor on easy/medium
	if (skill < 2 && self.ammo_shells < 25 && self.ammo_nails < 50)
		parm4 = max(self.ammo_shells, floor((50 - self.ammo_nails) / 2));
	else
		parm4 = self.ammo_shells;
	parm5 = self.ammo_nails;
	parm6 = self.ammo_rockets;
	parm7 = self.ammo_cells;
	parm8 = self.weapon;
	parm9 = self.armortype;

}

void() SetNewParms =
{
	if (skill == 3)
		parm2 = 50;
	else
		parm2 = 100;

	parm1 = IT_SHOTGUN | IT_AXE;
	parm4 = 25;
	parm8 = IT_SHOTGUN;
	parm3 = 0;
	parm5 = 0;
	parm6 = 0;
	parm7 = 0;
	parm9 = 0;
//	parm10 = 0;
}


// COOP 1 ONLY
// shells and nails are kept over on respawn
void() SetCoopParms =
{
	if (skill == 3)
		parm2 = 50;
	else
		parm2 = 100;

	parm1 = self.items & IT_WEAPONS;
	parm4 = max(25,self.ammo_shells);
	if (parm1 & IT_SUPER_SHOTGUN)
		parm8 = IT_SUPER_SHOTGUN;
	else
		parm8 = IT_SHOTGUN;

	parm3 = 0;
	parm5 = self.ammo_nails;
	parm6 = 0;
	parm7 = 0;
	parm9 = 0;
//	parm10 = 0;
}

void() DecodeLevelParms =
{
	
	if (world.model == "maps/start.bsp")
		SetNewParms ();		// take away all stuff on starting new episode
	
	self.items = parm1;
	self.health = parm2;
	self.armorvalue = parm3;
	self.ammo_shells = parm4;
	self.ammo_nails = parm5;
	self.ammo_rockets = parm6;
	self.ammo_cells = parm7;
	self.weapon = parm8;
	self.armortype = parm9;
	
	armor_set_type(self);
}

// should this use localcmd()?
void(entity client, string savename) autosave =
{
	// quake rerelease default behavior is to quicksave over s0,
	// so just go ahead and do that in that engine for consistency
	if (!isKex)
	{
		stuffcmd(client, "echo Autosaving...; wait; save ");
		stuffcmd(client, savename);
		stuffcmd(client, "\n");
	}
}

// this is no longer called
// too many ways to accidentally load into the wrong game or at the wrong time
// especially because stuffcmd evaluates during demo playback
/*
void(entity client) autoload =
{
	if (autosavename == string_null) {bprint("no autosave\n");return;}
	if (coop || deathmatch) {bprint("is mp\n");return;}
	stuffcmd(client, "echo Loading last autosave...; wait; load ");
	stuffcmd(client, autosavename);
	stuffcmd(client, "\n");
}
*/


/*
=============================================================================

PLAYER GAME EDGE FUNCTIONS

=============================================================================
*/

entity(entity start) get_next_client =
{
	entity next;
	/*
	next = find(start, classname, "player");
	if (next == world)
		next = find(world, classname, "player");
	*/
	// nice trick from necros: clients are always the first entities after world
	next = nextent(start);
	if (next.flags & FL_CLIENT == 0)
		next = nextent(world);
	return next;
}

/*
================================
transfer_keys
take a player's keys and give them to other clients

letting the player carry more than one of each key broke coop. keys don't vanish 
when touched so the game doesn't break if a key gets lost through death/lava/disconnect,
but a coop player could thus get a full load of keys within 15 frames by touching
one of these eternal keys. changing one requires fixing the other in a different way.
================================
*/
float() TransferKeys =
{
	if (!coop) return TRUE;
	
	float silver, gold, give;
	entity recipient;	
	
	if (self.items & IT_KEY1)
		silver = self.worldtype & 15;
	if (self.items & IT_KEY2)
		gold = (self.worldtype & 240) / 16;
	
	// no keys
	if (!silver && !gold)
		return TRUE;

	recipient = get_next_client(self);
	// if it's coop in name only and we're the only client, recipient will be self right away
	while (recipient != self)
	{
		if (silver > 0)
		{
			give = 15 - (recipient.worldtype & 15);
			give = min(give, silver);
			if (give)
			{
				recipient.worldtype += give;
				recipient.items |= IT_KEY1;
				sprint(recipient, "You got ");
				if (give > 1)
				{
					sprint(recipient, ftos(give));
					sprint(recipient, " Silver Keys from ");
				}
				else
					sprint(recipient, "the Silver Key from ");
				sprint(recipient, self.netname);
				sprint(recipient, "\n");
				silver -= give;
				self.worldtype -= give;
				stuffcmd(recipient, "bf\n");
				sound (recipient, CHAN_ITEM, key_sound(), 1, ATTN_NORM);
			}
		}
		if (gold > 0)
		{
			give = 15 - (recipient.worldtype & 240)/16;
			give = min(give, gold);
			if (give)
			{
				recipient.worldtype += give * 16;
				recipient.items |= IT_KEY2;
				sprint(recipient, "You got ");
				if (give > 1)
				{
					sprint(recipient, ftos(give));
					sprint(recipient, " Gold Keys from ");
				}
				else
					sprint(recipient, "the Gold Key from ");
				sprint(recipient, self.netname);
				sprint(recipient, "\n");
				gold -= give;
				self.worldtype -= 16 * give;
				stuffcmd(recipient, "bf\n");
				sound (recipient, CHAN_ITEM, key_sound(), 1, ATTN_NORM);
			}
		}
		// no keys left, all given away
		if (!silver && !gold)
		{
			self.worldtype = 0;
			self.items = not(self.items, IT_KEY1|IT_KEY2);
			return TRUE;
		}
		
		recipient = get_next_client(recipient);
	}
	// we didn't give all the keys away, either all other players are full or we're the
	// only dude left on the server
	self.worldtype = silver + gold * 16;
	return FALSE;
	// just leave the rest in our own inventory and we'll respawn with them ourselves
	
	// keys can still be 'lost' from the server in the following way:
	// if someone makes a map for copper (possible) with more than 15 of the same key in 
	// it (unlikely) and coop players (very unlikely) pick them all up and then
	// someone disconnects such that there isn't enough room in all other players' 
	// combined inventories for them (infinitesimal), the remainder have nowhere to go
	// and vanish with the disconnecting player
}

void() set_respawn_delay =
{
	self.lifetime_finished = time + 1;
	
	if (coop != 1 || gameover) return;
	
	if (clientsAlive)
	{
		bprint ("5 seconds added to respawn delay\n");
		coop_time = max(time + 6, coop_time + 5);
	}
	else
	{
		bprint ("All players have died\n");
		coop_time = time + 2;
	}

}

void() clear_respawning_flag_do =
{
	dprint("RESPAWNING flag cleared\n");
	serverflags = not(serverflags, SVFL_RESPAWNING);
	remove(self);
}

void() clear_respawning_flag =
{
	entity e = spawn();
	e.think = clear_respawning_flag_do;
	e.nextthink = 2;
}

// restart the level
void() restart =
{
	//localcmd ("restart\n");
	
	// preach's runefix:
	// put serverflags back to map's initial setting
	serverflags = startingserverflags | SVFL_RESPAWNING;	// notify starting autosaves not to autosave
	reset_flag = TRUE;			// request a reset to the parms
	localcmd("changelevel ");	// "change" to the same level
	localcmd(mapname);
	localcmd("\n");
}

// called by ClientKill and DeadThink
void() respawn =
{
	if (deathmatch)
	{
		// make a copy of the dead body for appearances sake
		CopyToBodyQueue (self);
		// set default spawn parms
		SetNewParms ();
		// respawn		
		PutClientInServer ();
		return;
	}
	if (coop)
	{
		if (coop == 1)
		{
			// no restarting if someone else has already exited
			if (gameover)
			{
				centerprint(self, "You didn't make it!");
				sound (self, CHAN_VOICE, "misc/talk.wav", 1, ATTN_STATIC);
				return;
			}
			
			// must restart if all players are dead
			if (!clientsAlive)
			{
				if (time < coop_time)	// timer was bumped by 5 more, wait 2
				{
					centerprint(self, "Everyone is dead!");
					sound (self, CHAN_VOICE, "misc/talk.wav", 1, ATTN_STATIC);
				}
				else
					restart();
					
				return;
			}
			
			if (time < coop_time)
			{
				if (self.nextmovesound < time)	// don't spam it
				{
					self.nextmovesound = time + 1;
			
					// fart if it's not respawning time yet
					switch(ceil(coop_time - time))
					{
					case 10:
						centerprint(self, "You can respawn in \b10\b seconds"); break;
					case 9:
						centerprint(self, "You can respawn in \b9\b seconds"); break;
					case 8:
						centerprint(self, "You can respawn in \b8\b seconds"); break;
					case 7:
						centerprint(self, "You can respawn in \b7\b seconds"); break;
					case 6:
						centerprint(self, "You can respawn in \b6\b seconds"); break;
					case 5:
						centerprint(self, "You can respawn in \b5\b seconds"); break;
					case 4:
						centerprint(self, "You can respawn in \b4\b seconds"); break;
					case 3:
						centerprint(self, "You can respawn in \b3\b seconds"); break;
					case 2:
						centerprint(self, "You can respawn in \b2\b seconds"); break;
					case 1:
						centerprint(self, "You can respawn in \b1\b second!"); break;
					default:
						centerprint(self, "You cannot respawn yet");
					}
					sound (self, CHAN_VOICE, "misc/talk.wav", 1, ATTN_STATIC);
				}
				return;
			}
		}

		// make a copy of the dead body for appearances sake
		CopyToBodyQueue (self);
		
		if (coop == 1)
		{
			bprint2(self.netname, " respawned\n");
			SetCoopParms();		// lose ammo, keep weapons
		}
		else
			setspawnparms (self); // old 'respawn however you started the level' rules
			
		PutClientInServer ();
		return;
	}
	
	restart();
}



entity(entity spot) NextCoopStart =
{
	entity next;
	next = find(spot, classname, "info_player_coop");
	if (next == world)
		next = find (world, classname, "info_player_coop");
	return next;
}

/*
============
SelectSpawnPoint

Returns the entity to spawn at
============
*/
entity() SelectSpawnPoint =
{
	entity spot;
	float  pcount;
	
	if (deathmatch)
	{
		spot = lastspawn;
		pcount = ceil(random() * 4);
		while (pcount)
		{
			pcount--;
			
			spot = find(spot, classname, "info_player_deathmatch");
			if (spot == world)
				spot = find(world, classname, "info_player_deathmatch");
			if (spot == world)
				error("This map does not support deathmatch! (no spawn points)\n");
		}
		lastspawn = spot;
		return spot;
	}

	// choose a start point
	if (coop)
	{
		// spawn at the next coop start in the cycle not blocked by a client
		// if all are blocked, enter limbo waiting for the least recently used spot
		// if no coop spots, use the player start, also entering limbo if blocked
		
		lastspawn = NextCoopStart(lastspawn);
		spot = lastspawn;
		do {
			if (!teleport_check_for_client(spot))
				break;
			spot = NextCoopStart(spot);
		} while (spot != lastspawn && spot != world);

		if (!spot)
			spot = find(world, classname, "info_player_start");
		if (!spot)
			error ("SelectSpawnPoint: no info_player_start or info_player_coop on level");
		
		lastspawn = spot;
		return lastspawn;
	}

	// testinfo_player_start is only found in regioned levels
	spot = find (world, classname, "info_player_start_test");
	if (spot)
	{
		return spot;
	}

	if (serverflags & (SVFL_ALLEPISODES))
	{	// return with a rune to start
		spot = find (world, classname, "info_player_start2");
		if (spot)
			return spot;
	}
	
	spot = find (world, classname, "info_player_start");
	if (!spot)
		error ("SelectSpawnPoint: no info_player_start on level");
	
	return spot;
}


/*
===========
PutClientInServer

called each time a player is spawned
============
*/
void() PutClientInServer =
{
	local	entity spot;
	
	spot = SelectSpawnPoint();
	self.classname = "player";
	
	// new for nightmare: reduced max health instead of the manky attack time scale
	if (skill == 3)
		self.max_health = 50;
	else
		self.max_health = 100;
	self.health = self.max_health;
	
	self.takedamage = DAMAGE_AIM;
	self.solid = SOLID_SLIDEBOX;
	self.movetype = MOVETYPE_WALK;
	self.show_hostile = 0;
	self.flags = FL_CLIENT;
	self.customflags = 0;
	self.air_finished = time + 12;
	self.dmg = 0;   		// initial water damage
	self.super_damage_finished = 0;
	self.radsuit_finished = 0;
	self.invisible_finished = 0;
	self.notrace = 0;	// fix for dying with the ring
	self.invincible_finished = 0;
	self.invincible_time = 0;
	self.effects = 0;
	self.enemy = world;

	DecodeLevelParms();
	SetChangeParms();
	W_ResetWeaponState();

	// we respawned with keys not taken away, make sure .items reflects this
	if (self.worldtype & 15) self.items |= IT_KEY1;
	if (self.worldtype & 240) self.items |= IT_KEY2;
	
	self.attack_finished = time;
	self.th_pain = player_pain;
	self.th_die = PlayerDie;
	
	self.deadflag = DEAD_NO;
	clientsAlive += 1;

// paustime is set by teleporters to keep the player from moving a while
	self.pausetime = 0;
	
	self.dmg_take = 0;
	self.dmg_save = 0;
	self.dmg_inflictor = world;
	self.velocity = VEC_ORIGIN;

	self.origin = spot.origin + '0 0 1';
	self.v_angle = self.angles = spot.angles;
	self.fixangle = TRUE;		// turn this way immediately
	self.attack_finished = time + 0.1;	// don't shoot on the first frame if we clicked to spawn
	
	// yet another thing that doesn't work on the first frame
	if (spot.fog_density)
		fog_save(self,spot.fog_density,spot.fog_color,spot.fog_sky);
	else if (world.fog_density)
		fog_save(self,world.fog_density,world.fog_color,spot.fog_sky);
	cleanUpClientShit = 2;

// oh, this is a hack!
	setmodel (self, "progs/eyes.mdl");
	modelindex_eyes = self.modelindex;

	setmodel (self, "progs/player.mdl");
	modelindex_player = self.modelindex;

	setsize (self, VEC_HULL_MIN, VEC_HULL_MAX);
	
	self.view_ofs = '0 0 22';

	player_stand1();
	
	// spawns fire targets when spawned at
	SUB_UseEntTargets(spot);
	if (serverflags & SVFL_RESPAWNING) clear_respawning_flag();
	
	// enter teleport limbo instead of telefragging teammates
	if (coop)
	{
		if (teleport_check_for_client(spot))
		{
			teleport_enter_limbo(self, spot, TRUE, TRUE);
			return;
		}
		teleport_flash();
	}
	else if (deathmatch)
	{
		teleport_flash();
	}
	spawn_tdeath (self.origin, self);
	
}

/*
===============================================================================

DEATHMATCH RULES

===============================================================================
*/

/*
go to the next level for deathmatch
only called if a time or frag limit has expired
*/
void() NextLevel =
{
	local entity o;

	if (mapname == "start")
	{
		if (!cvar("registered"))
		{
			mapname = "e1m1";
		}
		else if (!(serverflags & SVFL_EPISODE1))
		{
			mapname = "e1m1";
			serverflags = serverflags | SVFL_EPISODE1;
		}
		else if (!(serverflags & SVFL_EPISODE2))
		{
			mapname = "e2m1";
			serverflags = serverflags | SVFL_EPISODE2;
		}
		else if (!(serverflags & SVFL_EPISODE3))
		{
			mapname = "e3m1";
			serverflags = serverflags | SVFL_EPISODE3;
		}
		else if (!(serverflags & SVFL_EPISODE4))
		{
			mapname = "e4m1";
			serverflags = serverflags - 7;	// cycle back to 1
		}

		o = spawn();
		o.map = mapname;
	}
	else
	{
		// find a trigger changelevel
		o = find(world, classname, "trigger_changelevel");

		// go back to start if no trigger_changelevel
		if (!o)
		{
			mapname = "start";
			o = spawn();
			o.map = mapname;
		}
	}

	nextmap = o.map;
	gameover = TRUE;
	
	if (o.nextthink < time)
	{
		o.think = execute_changelevel;
		o.nextthink = time + 0.1;
	}
}

/*
============
CheckRules

Exit multiplayer games upon conditions
============
*/
void() CheckRules =
{
	float timelimit;
	float fraglimit;
	
	if (coop == 1 && gameover && time > coop_time)
	{
		execute_changelevel();
		return;
	}
	
	if (gameover || !deathmatch)
		return;
		
	timelimit = cvar("timelimit") * 60;
	fraglimit = cvar("fraglimit");
	
	if (timelimit && time >= timelimit)
	{
		NextLevel ();
		return;
	}
	
	if (fraglimit && self.frags >= fraglimit)
	{
		NextLevel ();
		return;
	}	
}



/*
//============================================================================

PLAYER THINKS AND MOVEMENT

//============================================================================
*/

// the player's health will always rot off to the soft max
// countdown is global now and not controlled by a touched megahealth thinking
void() PlayerHealthTick =
{
	if ( time < self.healthtime )
		return;
	if ( self.health <= 0 )
		return;
	
	float hmax = self.max_health;
	
	if (self.health > hmax)
	{
		if (self.waterlevel < WL_EYES)
			self.dmg = 0;	// clear drown damage when overhealed
		self.health -= 1;
		self.healthtime = time + 1;
	}
	else
	{
		if (self.dmg > 0 && (self.waterlevel < WL_EYES || has_biosuit(self) ) )
		{
			// recover damage taken from drowning
			//T_Heal(self, self.dmg, 0);
			if (skill > 2)
				self.health = min(hmax, self.health + ceil(self.dmg/4));
			else
				self.health = min(hmax, self.health + ceil(self.dmg/2));
			self.dmg = max(0, self.dmg - 1);
			self.healthtime = time + 0.5;
		}	
	}
	
	
}	


/*
============
IntermissionThink

When the player presses attack or jump, change to the next level
============
*/
void() IntermissionThink =
{
	// this was for coop pre-exit camera spectating, but it shudders really badly 
	// on non-server clients, so players just get to look around while waiting
//	self.angles = self.v_angle = self.goalentity.mangle;
//	self.fixangle = TRUE;
	self.flags = not(self.flags, FL_ONGROUND);

	if (self.impulse)
	{
		// cycle forward or back in the intermissions with weapnext/weapprev
		if (self.attack_finished < time)
		{
			// stay on cameras twice as long if player cycles to them manually
			if (self.impulse == 10)
			{
				move_player_to_next_intermission();
				self.attack_finished = time + 0.2;
				self.lifetime_finished = time + 12;
			}
			else if (self.impulse == 12)
			{
				move_player_to_previous_intermission();
				self.attack_finished = time + 0.2;
				self.lifetime_finished = time + 12;
			}
		}
		self.impulse = 0;
	}
	
	if (!intermission_running) return;
	
	// auto-cycle intermission camera after six seconds
	else if (time > self.lifetime_finished)
	{
		move_player_to_next_intermission();
		self.lifetime_finished = time + 6;
	}
	
	if (time < intermission_exittime)
		return;

	// start listening for input to leave
	if (!self.button0 && !self.button1 && !self.button2) {
		if (self.wait) ExitIntermission ();
		self.wait = 0;
		return;
	}
	
	self.wait = 1;
}

/*
============
PlayerDeathThink

When the player presses attack or jump, respawn or restart
============
*/
void() PlayerDeathThink =
{
	local float		forward;

	if ((self.flags & FL_ONGROUND))
	{
		forward = vlen (self.velocity);
		forward = forward - 20;
		if (forward <= 0)
			self.velocity = '0 0 0';
		else	
			self.velocity = forward * normalize(self.velocity);
	}

	if (self.flags & FL_GODMODE && self.deadflag)
	{
		CopyToBodyQueue (self);
		
		self.health = self.max_health;
		self.deadflag = DEAD_NO;
		clientsAlive += 1;
		self.takedamage = DAMAGE_AIM;
		self.air_finished = time + 12;
		self.dmg = 0;   		// initial water damage
		
		self.solid = SOLID_SLIDEBOX;
		self.movetype = MOVETYPE_WALK;
		setsize (self, VEC_HULL_MIN, VEC_HULL_MAX);
		self.flags = FL_CLIENT;
		self.customflags = 0;

		self.effects = 0;
		self.enemy = world;
		self.show_hostile = 0;
		self.attack_finished = time + 0.1;	// don't shoot on the first frame if we clicked to spawn
		
		teleport_flash();
		spawn_tdeath (self.origin, self);
		
		self.view_ofs = '0 0 22';
		self.modelindex = modelindex_player;
		player_stand1();
		W_ResetWeaponState();
		
		return;
	}
	
	if (time < self.lifetime_finished) return;
	
	// wait for all buttons released
	if (!self.button0 && !self.button1 && !self.button2) {
		if (self.wait)
			respawn();
		
		self.wait = 0;
		return;
	}
	
	self.wait = 1;
}


void() PlayerJump =
{

	float upspeed;

	if (self.flags & FL_WATERJUMP)
		return;
	
	if (self.waterlevel >= WL_WAIST)
	{
		// fix for +jump not swimming upward as fast as +moveup
		upspeed = cvar("cl_upspeed");
		if (self.waterlevel < WL_EYES)
			upspeed *= 0.5; // match vanilla swim values at the surface so 
							// we don't launch out of the water any higher
		else
			upspeed *= 0.7;	// match moveup from SV_WaterMove
		
		if (self.watertype == CONTENT_LAVA)
			upspeed *= 0.5;	// originally 50
		else if (self.watertype == CONTENT_SLIME)
			upspeed *= 0.8;	// originally 80
		
		// scale upspeed to match WaterMove since playerjump gets called after it
		self.velocity_z = upspeed - 0.8 * self.waterlevel * frametime * upspeed;

		
		
		// play swimming sound
		if (self.nextmovesound < time)
		{
			self.nextmovesound = time + 1;
			if (random() < 0.5)
				sound (self, CHAN_BODY, "misc/water1.wav", 1, ATTN_NORM);
			else
				sound (self, CHAN_BODY, "misc/water2.wav", 1, ATTN_NORM);
		}

		return;
	}

	if (self.movetype != MOVETYPE_NOCLIP)
	{
		if (!(self.flags & FL_ONGROUND)) return;
		if ( !(self.flags & FL_JUMPRELEASED) ) return;		// don't pogo stick
		sound (self, CHAN_BODY, "player/plyrjmp8.wav", 1, ATTN_NORM);	// h00rt
	}
	
//	self.flags = self.flags - (self.flags & FL_JUMPRELEASED);
//	self.flags = self.flags - FL_ONGROUND;	// don't stairwalk
	self.flags = not(self.flags, FL_JUMPRELEASED | FL_ONGROUND);	// don't stairwalk
	
	self.button2 = 0;
	self.velocity_z = self.velocity_z + 270;
}



/*
===========
WaterTest
test for liquids touching self from all directions

doesn't set self.waterlevel/self.watertype directly because it's also used by
monsters, and faffing with those values makes them spam constant splash noises
============
*/
vector() WaterTest =
{
	if (self.movetype == MOVETYPE_NOCLIP)
		return VEC_ORIGIN;
		
	float wl = 0;
	float wt = 0;
	float wp;
	
	// iw -- fix waterlevel detection
	vector waist;

	// this is how the engine calculates the player's waist height (see
	// the "SV_CheckWater" function in "sv_phys.c")
	waist = self.origin;
	waist_z += (self.mins_z + self.maxs_z) * 0.5;

	//wp = pointcontents(self.origin);
	wp = pointcontents(waist);
	// iw -- END
	if (wp < -2 && wp > -6)
	{
		wl += 1;
		wt = min(wt,wp);
	}
	wp = pointcontents(self.origin + self.mins);
	if (wp < -2 && wp > -6)
	{
		wl += 1;
		wt = min(wt,wp);
	}
	wp = pointcontents(self.origin + self.maxs);
	if (wp < -2 && wp > -6)
	{
		wl += 1;
		wt = min(wt,wp);
	}
	wp = pointcontents(self.origin + self.view_ofs);
	if (wp < -2 && wp > -6)
	{
		wl += 1;
		wt = min(wt,wp);
	}
	
	return Vector(min(3,wl),wt,0);
}

/*
===========
PlayerWaterTest
============
*/
void() PlayerWaterTest =
{
	vector wtt;
	wtt = WaterTest();
	float wl, wt;
	wl = wtt_x;
	wt = wtt_y;

	self.waterlevel = max(wl,self.waterlevel);
	self.watertype = min(wt,self.watertype);
}

/*
===========
WaterMove
============
*/
void() WaterMove =
{
	if (self.movetype == MOVETYPE_NOCLIP) {
		self.air_finished = time + 120;
		return;
	}
	if (self.health < 0)
		return;
	
	if (self.waterlevel < WL_EYES)	// view is above water
	{
		if (self.flags & FL_UNDERWATER)
		{
			self.flags -= FL_UNDERWATER;
			self.nextmovesound = time + 0.5;
			if (random() < 0.5)
				sound (self, CHAN_BODY, "misc/water1.wav", 1, ATTN_NORM);
			else
				sound (self, CHAN_BODY, "misc/water2.wav", 1, ATTN_NORM);
		}
		if (time > 1)	// QSS-only hack for gasping after every level transition
		{
			if (time > self.air_finished ||
				time > self.air_finished - 10 && self.dmg)
			{
				sound (self, CHAN_VOICE, "player/gasp2.wav", 1, ATTN_NORM);
				self.healthtime = time + 0.5;
			}
			else if (time > self.air_finished - 9)
			{
				sound (self, CHAN_VOICE, "player/gasp1.wav", 1, ATTN_NORM);
			}
		}		
		// pentagram protects you from drowning, but if you spend enough time underwater,
		// you're instantly out of air when it ends
		self.air_finished = max(self.invincible_finished, time + 12);
		//self.dmg = 0;	// remember damage taken to recover it slowly
	}
	else	// view is below the water
	{
		if (!(self.flags & FL_UNDERWATER))
		{
			self.flags |= FL_UNDERWATER;
			if (self.watertype != CONTENT_LAVA)
			{
				if (self.jump_flag < -300)
				{
					sound (self, CHAN_ITEM2, "misc/w_under2.wav", 1, ATTN_NORM);
					local float i = 0;
					local vector b;
					while(i > self.jump_flag)
					{
						i -= 75;
						b = self.absmin + vec_scale(self.size, Vector(random(),random(),random()));
						if (pointcontents(b) == CONTENT_WATER)
							bubble_spawn(b);
					}
				}
				else
				{
					sound (self, CHAN_ITEM2, "misc/w_under.wav", 1, ATTN_STATIC);
				}
			}
		}
		// if you don't catch your breath from the last drowning episode before diving 
		// again, you start to drown sooner the next time
		if (self.air_finished < time + self.dmg / 2)
		{	// drown!
			if (self.pain_finished < time)
			{
				self.deathtype = "drowning";
				if (skill > 2)
					T_Damage (self, world, world, ceil(max(self.dmg, 1)/2));
				else
					T_Damage (self, world, world, max(self.dmg, 1));
				self.deathtype = string_null;
				self.pain_finished = time + 1;
				
				if (!has_invuln(self))	// don't advance the drowning timer with pent, or we
					self.dmg = min(15, self.dmg + 1);	// could recover health we didn't lose
			}
		}
	}
	
	if (!self.waterlevel)
	{
		if (self.flags & FL_INWATER)
		{	
			// play leave water sound
			sound (self, CHAN_BODY, "misc/outwater.wav", 1, ATTN_NORM);
			self.flags = self.flags - FL_INWATER;
		}
		return;
	}

	if (self.watertype == CONTENT_LAVA)
	{	// do damage
		if (self.dmgtime < time)
		{
			if (has_biosuit(self))
				self.dmgtime = time + 1;
			else
				self.dmgtime = time + 0.2;

			if (self.waterlevel)
			{
				self.deathtype = "lava";
				// biosuit protects from lava if it's 16u deep or less
				if (!(has_biosuit(self) && pointcontents(self.origin - '0 0 7') != CONTENT_LAVA))
					T_Damage (self, world, world, 10 * self.waterlevel);
				self.deathtype = string_null;
			}
		}
	}
	else if (self.watertype == CONTENT_SLIME)
	{	// do damage
		if (self.dmgtime < time && self.radsuit_finished < time)
		{
			self.dmgtime = time + 1;
			self.deathtype = "slime";
			T_Damage (self, world, world, 4 * self.waterlevel);
			self.deathtype = string_null;
		}
	}
	
	if ( !(self.flags & FL_INWATER) )
	{	// player enter water sound
		if (self.watertype == CONTENT_LAVA)
			sound (self, CHAN_BODY, "player/inlava.wav", 1, ATTN_NORM);
		else if (self.watertype == CONTENT_WATER)
		{
			if (self.jump_flag < -300)
				sound (self, CHAN_BODY, "player/h2ojump.wav", 1, ATTN_NORM);
			else
				sound (self, CHAN_BODY, "player/inh2o.wav", 1, ATTN_NORM);
		}
		else if (self.watertype == CONTENT_SLIME)
			sound (self, CHAN_BODY, "player/slimbrn2.wav", 1, ATTN_NORM);

		self.flags = self.flags + FL_INWATER;
		self.dmgtime = 0;
	}
	
	if ( !(self.flags & FL_WATERJUMP) )
	{
		// this is for water friction
		self.velocity = self.velocity - 0.8 * self.waterlevel * frametime * self.velocity;
	}
}

void() CheckWaterJump =
{
	if (self.movetype == MOVETYPE_NOCLIP)
		return;
		
	local vector start, end;

	
	// check for a jump-out-of-water
	makevectors (self.angles);
	start = self.origin;
	start_z = start_z + 8; 
	
	if (v_forward_z < -0.25)
		return;		// don't waterjump if looking down into the water
		
	v_forward_z = 0;
	normalize(v_forward);
	end = start + v_forward*24;
	
	traceline (start, end, TRUE, self);
	
	if (trace_fraction < 1)
	{
		// solid at waist
		start_z = start_z + self.maxs_z - 8;
		end = start + v_forward*24;
		self.movedir = trace_plane_normal * -50;
		
		traceline (start, end, TRUE, self);
		
		if (trace_fraction == 1)
		{
			// open at eye level
			self.flags = self.flags | FL_WATERJUMP;
			self.velocity_z = 225;
			self.flags = self.flags - (self.flags & FL_JUMPRELEASED);
			self.teleport_time = time + 2;	// safety net
			
			return;
		}
	}
}


/*
================
CheckPowerups

Check for turning off powerups
================
*/
void() CheckPowerups =
{
	if (self.health <= 0)
		return;

// invisibility
	if (self.invisible_finished)
	{
// sound and screen flash when items starts to run out
		if (self.invisible_sound < time)
		{
			sound (self, CHAN_AUTO, "items/inv3.wav", 0.5, ATTN_IDLE);
			self.invisible_sound = time + ((random() * 3) + 1);
		}


		if (self.invisible_finished < time + 3)
		{
			if (self.invisible_time == 1)
			{
				sprint (self, "Ring of Shadows' magic is fading ...\n");
				stuffcmd (self, "bf\n");
				sound (self, CHAN_AUTO, "items/inv2.wav", 1, ATTN_NORM);
				self.invisible_time = time + 1;
			}
			
			if (self.invisible_time < time)
			{
				self.invisible_time = time + 1;
				stuffcmd (self, "bf\n");
			}
		}

		if (self.invisible_finished < time)
		{	// just stopped
			self.items = self.items - IT_INVISIBILITY;
			//self.notrace = 0;
			self.invisible_finished = 0;
			self.invisible_time = 0;
		}
		
	// use the eyes
		self.frame = 0;
		self.modelindex = modelindex_eyes;
	}
	else
		self.modelindex = modelindex_player;	// don't use eyes

// invincibility
	if (self.invincible_finished)
	{
// sound and screen flash when items starts to run out
		if (self.invincible_finished < time + 3)
		{
			if (self.invincible_time == 1)
			{
				sprint (self, "Protection is almost burned out ...\n");
				stuffcmd (self, "bf\n");
				sound (self, CHAN_AUTO, "items/protect2.wav", 1, ATTN_NORM);
				self.invincible_time = time + 1;
			}
			
			if (self.invincible_time < time)
			{
				self.invincible_time = time + 1;
				stuffcmd (self, "bf\n");
			}
		}
		
		if (self.invincible_finished < time)
		{	// just stopped
			self.items = self.items - IT_INVULNERABILITY;
			self.invincible_time = 0;
			self.invincible_finished = 0;
		}
		if (self.invincible_finished > time)
			self.effects = self.effects | EF_DIMLIGHT;
		else
			self.effects = self.effects - (self.effects & EF_DIMLIGHT);
	}

// super damage
	if (self.super_damage_finished)
	{

// sound and screen flash when items starts to run out

		if (self.super_damage_finished < time + 3)
		{
			if (self.super_time == 1)
			{
				sprint (self, "Quad damage's power weakens ...\n");
				stuffcmd (self, "bf\n");
				sound (self, CHAN_AUTO, "items/damage2.wav", 1, ATTN_NORM);
				self.super_time = time + 1;
			}	  
			
			if (self.super_time < time)
			{
				self.super_time = time + 1;
				stuffcmd (self, "bf\n");
			}
		}

		if (self.super_damage_finished < time)
		{	// just stopped
			self.items = self.items - IT_QUAD;
			self.super_damage_finished = 0;
			self.super_time = 0;
		}
		if (self.super_damage_finished > time)
			self.effects = self.effects | EF_DIMLIGHT;
		else
			self.effects = self.effects - (self.effects & EF_DIMLIGHT);
	}	

// suit	
	if (self.radsuit_finished)
	{
		self.air_finished = time + 12;		// don't drown

// sound and screen flash when items starts to run out
		if (self.radsuit_finished < time + 3)
		{
			if (self.rad_time == 1)
			{
				sprint (self, "Air supply in Biosuit expiring ...\n");
				stuffcmd (self, "bf\n");
				sound (self, CHAN_AUTO, "items/suit2.wav", 1, ATTN_NORM);
				self.rad_time = time + 1;
			}
			
			if (self.rad_time < time)
			{
				self.rad_time = time + 1;
				stuffcmd (self, "bf\n");
			}
		}

		if (self.radsuit_finished < time)
		{	// just stopped
			self.items = self.items - IT_SUIT;
			self.rad_time = 0;
			self.radsuit_finished = 0;
		}
	}	

}

// a failed experiment to fix DOOF-DOOF-DOOFing down stairs
/*
void() CheckStairDescend =
{
	local vector drop;
	if (!(self.customflags & CFL_WASONGROUND))
		return;
	if (self.velocity_z > 0)
		return;
		
	drop = self.origin;
	
	if (droptofloor(0,16))
	{
		drop = drop - self.origin;
		bprint("dropped ");
		bprint(ftos(drop_z));
		bprint(" units\n");
		self.view_ofs_z += drop_z;
	}
}
*/


/*
================
PlayerPreThink

Called every frame before physics are run
================
*/
void() PlayerPreThink =
{
	if (cleanUpClientShit)
	{
		fog_setFromEnt( self, self );
		if ( !( self.customflags & (CFL_PLUNGE|CFL_LIMBO) ) )
		{
			stuffcmd(self,"\nv_cshift\n");
		}
		else if ( self.customflags & CFL_LIMBO )
		{
			TintScreen(self, 255);
		}
	}

	if (intermission_running || self.deadflag == DEAD_SPECTATING )
	{
		IntermissionThink ();	// otherwise a button could be missed between
		return;					// the think tics
	}
	makevectors (self.v_angle);		// is this still used
									// lunaran: "yes"

	CheckRules();

	if (self.deadflag >= DEAD_DEAD)
	{
		PlayerDeathThink ();
		return;
	}
	
	if (self.deadflag == DEAD_DYING)
		return;	// dying, so do nothing

	self.wait = 0;
	
	PlayerWaterTest();
	WaterMove();
	if (self.waterlevel == WL_WAIST)
		CheckWaterJump ();

	if (self.button2)
	{
		PlayerJump ();
	}
	else
	{
		self.flags = self.flags | FL_JUMPRELEASED;
	}
	
// teleporters can force a non-moving pause time	
	if (time < self.pausetime)
		self.velocity = '0 0 0';

	if(time > self.attack_finished && 
		self.currentammo == 0 && 
		self.weapon != IT_AXE
		)
	{
		W_SelectBestWeapon();
	}

	if (self.movetype == MOVETYPE_NOCLIP)
	{
		self.flags = self.flags | FL_FLY;
	}
	
	// ai_nav
	//nav_editorThink();
}
	

/*
================
PlayerPostThink

Called every frame after physics are run
================
*/
void() PlayerPostThink =
{
	if ( intermission_running ) return;
	
	if (self.view_ofs == '0 0 0')
		return;		// intermission or finale
	if (self.deadflag)
		return;
	
	if (self.customflags & CFL_LIMBO)
	{
		teleport_limbo_think();
		return;
	}
	
	// do weapon stuff
	W_WeaponFrame ();
	// do health stuff
	PlayerHealthTick();

	// check to see if player landed and play landing sound	
	if ((self.jump_flag < -300) && (self.flags & FL_ONGROUND) && (self.health > 0))
	{
		if (self.jump_flag < -650 && !(self.customflags & CFL_PLUNGE) && !self.waterlevel)
		{
			self.deathtype = "falling";
			T_Damage (self, world, world, 5); 
			self.deathtype = string_null;
			sound (self, CHAN_VOICE, "player/land2.wav", 1, ATTN_NORM);
		}
		else if (self.waterlevel < WL_EYES)
			sound (self, CHAN_VOICE, "player/land.wav", 1, ATTN_NORM);

		self.jump_flag = 0;
	}

	CheckPowerups ();
	
	if (self.movetype != MOVETYPE_NOCLIP) 
	{
		self.flags = not(self.flags, FL_FLY);
	}
	
	if (!(self.flags & FL_ONGROUND))
		self.jump_flag = self.velocity_z;
		
	// vaulting off the top of stairs sucks, but the right place to fix this is the .exe
	/*
	if (self.flags & FL_ONGROUND)
	{
		self.customflags = self.customflags | CFL_WASONGROUND;
	}
	else
	{
		self.jump_flag = self.velocity_z;
		CheckStairDescend();
		
		self.customflags = not(self.customflags, CFL_WASONGROUND);
	}
	*/
}

/*
============
ClientKill

Player entered the suicide command
============
*/
void() ClientKill =
{
	// don't kill the player through a special mechanism or too much stuff gets skipped
	self.invincible_finished = 0;
	T_Damage(self,self,self,ArmorSave(self, A_SHITLOAD) + self.health);
	
	/*
	bprint (self.netname);
	bprint (" suicides\n");
	TransferKeys();
	DropBackpack();
	set_suicide_frame ();
	self.modelindex = modelindex_player;
	self.frags = self.frags - 2;	// extra penalty
	respawn();
	*/
}

/*
===========
ClientConnect

called when a player connects to a server
============
*/
void() ClientConnect =
{
	bprint (self.netname);
	bprint (" entered the game\n");
	
	clients += 1;
//	clientsAlive += 1;	// happens on putclientinserver
	
// a client connecting during an intermission can cause problems
	if (intermission_running)
		ExitIntermission ();
}


/*
===========
ClientDisconnect

called when a player disconnects from a server
============
*/
void() ClientDisconnect =
{
	if (gameover)
		return;
	// if the level end trigger has been activated, just return
	// since they aren't *really* leaving

	clients -= 1;
	if (self.health > 0)
		clientsAlive -= 1;
	
	// don't leave with keys
	TransferKeys();
	
	// let everyone else know
	bprint (self.netname);
	if (deathmatch)
	{
		bprint(" left the game with ");
		bprint(ftos(self.frags));
		bprint(" frags\n");
	}
	else if (coop)
	{
		bprint(" left the game\n");
		self.flags = 0;	// let others grab the bag
		DropBackpack();
	}
	sound (self, CHAN_BODY, "player/tornoff2.wav", 1, ATTN_NONE);
	set_suicide_frame ();
}

/*
===========
ClientObituary

called when a player dies
============
*/
void() ClientObituary =
{
	local	float rnum;
	local	string deathstring, deathstring2;
	rnum = random();
	
	entity attacker = self.enemy;

	if (coop == 1)
	{
		// centerprint before bprint if you want players to see both
		entity e;
		e = nextent(world);
			
		while (e.flags & FL_CLIENT)
		{
			if (e != self)
			{
				if (clientsAlive == 1)
					centerprint2(e, self.netname, " is down -\nthere's no one left but you!");
				else
					centerprint2(e, self.netname, " is down!");
			}
			e = nextent(e);
		}
		/*
		*/
	}
	
	if (attacker.deathtype != string_null && attacker.classname != "player" )
	{
		bprint(self.netname);
		bprint(" ");
		bprint(attacker.deathtype);
		bprint("\n");
		
		if (deathmatch && (attacker.classname == "trigger_void" || attacker.classname == "func_void"))
			self.frags = self.frags - 1;
		return;
	}
	if (attacker.classname == "teledeath")
	{
		bprint (self.netname);
		bprint (" was telefragged by ");
		bprint (attacker.owner.netname);
		bprint ("\n");

		if (deathmatch)
			attacker.owner.frags = attacker.owner.frags + 1;
		return;
	}
	if (attacker.classname == "trigger_void" || attacker.classname == "func_void")
	{
		bprint (self.netname);
		bprint (" was lost to the void\n");
		if (deathmatch)
			self.frags = self.frags - 1;
		return;
	}
	if (attacker.classname == "teledeath2")
	{
		bprint ("Satan's power deflects ");
		bprint (self.netname);
		bprint ("'s telefrag\n");

		if (deathmatch)
			self.frags = self.frags - 1;
		return;
	}

	if (attacker.classname == "player")
	{
		if (self == attacker)
		{
			// killed self
			attacker.frags = attacker.frags - 1;
			bprint (self.netname);
			
			if (self.weapon == IT_LIGHTNING && self.waterlevel >= WL_WAIST)
			{
				bprint (" discharges into the water\n");
				return;
			}
			if (self.weapon == IT_GRENADE_LAUNCHER)
				bprint (" tries to put the pin back in\n");
			else if (self.weapon == IT_ROCKET_LAUNCHER)
			{
				if (random() < 0.5)
					bprint (" rocket-jumps into the next world\n");
				else
					bprint (" is no rocket surgeon\n");
			}
			else
				bprint (" becomes bored with life\n");
			return;
		}
		
		if ( (teamplay == 2) && (self.team > 0) && (self.team == attacker.team) )
		{
			if (rnum < 0.25)
				deathstring = " mows down a teammate\n";
			else if (rnum < 0.50)
				deathstring = " checks their glasses\n";
			else if (rnum < 0.75)
				deathstring = " gets a frag for the other team\n";
			else
				deathstring = " loses another friend\n";
			bprint (attacker.netname);
			bprint (deathstring);
			if (deathmatch)
				attacker.frags = attacker.frags - 1;
			return;
		}
		else
		{
			if (deathmatch)
				attacker.frags = attacker.frags + 1;

			rnum = attacker.weapon;
			if (rnum == IT_AXE)
			{
				if (random() < 0.5)
					deathstring = " was axe-murdered by ";
				else
					deathstring = " got the chop from ";
				deathstring2 = "\n";
			}
			if (rnum == IT_SHOTGUN)
			{
				deathstring = " chewed on ";
				deathstring2 = "'s boomstick\n";
			}
			if (rnum == IT_SUPER_SHOTGUN)
			{
				deathstring = " ate 2 loads of ";
				deathstring2 = "'s buckshot\n";
			}
			if (rnum == IT_NAILGUN)
			{
				deathstring = " was nailed by ";
				deathstring2 = "\n";
			}
			if (rnum == IT_SUPER_NAILGUN)
			{
				deathstring = " was punctured by ";
				deathstring2 = "\n";
			}
			if (rnum == IT_GRENADE_LAUNCHER)
			{
				deathstring = " eats ";
				deathstring2 = "'s pineapple\n";
				if (self.health < -40)
				{
					deathstring = " was gibbed by ";
					deathstring2 = "'s grenade\n";
				}
			}
			if (rnum == IT_ROCKET_LAUNCHER)
			{
				deathstring = " rides ";
				deathstring2 = "'s rocket\n";
				if (self.health < -40)
				{
					deathstring = " was gibbed by ";
					deathstring2 = "'s rocket\n" ;
				}
			}
			if (rnum == IT_LIGHTNING)
			{
				deathstring = " accepts ";
				if (attacker.waterlevel >= WL_WAIST)
					deathstring2 = "'s discharge\n";
				else
					deathstring2 = "'s shaft\n";
			}
			bprint (self.netname);
			bprint (deathstring);
			bprint (attacker.netname);
			bprint (deathstring2);
		}
		return;
	}
	else
	{
		//self.frags = self.frags - 1;
		bprint (self.netname);

		// killed by a monster?
		if (attacker.flags & FL_MONSTER)
		{
			// moved monster obits to their individual *.qc files
			bprint (" was uninsured\n");
			return;
		}

		// tricks and traps
		if (attacker.classname == "explo_box")
		{
			bprint (" blew up\n");
			return;
		}
		if (attacker.solid == SOLID_BSP && attacker != world)
		{	
			bprint (" was squished\n");
			return;
		}
		if (attacker.classname == "trap_shooter" || attacker.classname == "trap_spikeshooter")
		{
			bprint (" was spiked\n");
			return;
		}
		if (attacker.classname == "fireball")
		{
			bprint (" ate a lavaball\n");
			return;
		}
		if (attacker.classname == "trigger_changelevel")
		{
			bprint (" tried to leave\n");
			return;
		}

		// liquid deaths
		if (self.deathtype == "drowning")
		{
			if (random() < 0.5)
				bprint (" sleeps with the fishes\n");
			else
				bprint (" sucks it down\n");
			return;
		}
		else if (self.deathtype == "slime")
		{
			if (random() < 0.5)
				bprint (" gulped a load of slime\n");
			else
				bprint (" can't exist on slime alone\n");
			return;
		}
		else if (self.deathtype == "lava")
		{
			if (self.waterlevel < WL_EYES)
			{
				bprint (" burst into flames\n");
				return;
			}
			if (random() < 0.5)
				bprint (" turned into hot slag\n");
			else
				bprint (" visits the Volcano God\n");
			return;
		}

		// fell to their death?
		if (self.deathtype == "falling")
		{
			self.deathtype = string_null;
			if (random() < 0.5)
				bprint (" cratered\n");
			else
				bprint (" fell to their death\n");
			return;
		}

		// ELEPHINO
		bprint (" died\n");
	}
}



/*
=============================================================================

	SPAWNPOINTS

=============================================================================
*/

/*FGD
@baseclass base(Appearflags, Angle, Fog, Target) size(-16 -16 -24, 16 16 32) 
	color(0 255 0) model({ "path": ":progs/player.mdl" }) = PlayerClass []
*/

/*QUAKED info_player_start (1 0 0) (-16 -16 -24) (16 16 24) 
The normal starting point for a level. Only one is allowed. Will fire its targets when a player is spawned here, with player as activator.

"angle" viewing angle when spawning
"fog_color"/"fog_density"/"fog_sky" set the fog when spawning at this spot (fog_sky 0 = no change, -1 = clear to 0)
*/
/*FGD
@PointClass base(PlayerClass) = info_player_start : "Player 1 start" []
*/
void() info_player_start =
{
	setsize(self,VEC_HULL_MIN,VEC_HULL_MAX);	// for telefrag testing
	self.mangle = self.angles;
	fog_fixKeys();
}


/*QUAKED info_player_start2 (1 0 0) (-16 -16 -24) (16 16 24) 
Only used on start map for the return point from an episode. Will fire its targets when a player is spawned here, with player as activator.

"angle" viewing angle when spawning
"fog_color"/"fog_density"/"fog_sky" set the fog when spawning at this spot (fog_sky 0 = no change, -1 = clear to 0)
*/
/*FGD
@PointClass base(PlayerClass) = info_player_start2 : "Player episode return point" []
*/
void() info_player_start2 =
{
	setsize(self,VEC_HULL_MIN,VEC_HULL_MAX);	// for telefrag testing
	self.mangle = self.angles;
	fog_fixKeys();
}


/*QUAKED info_player_start_test (1 0 0) (-16 -16 -24) (16 16 24) USE
Debug starting point for a level.  Overrides info_player_start if present and 'USE' is checked, does nothing if 'USE' is not checked. Will fire its targets when a player is spawned, here with player as activator.

"angle" viewing angle when spawning
"fog_color"/"fog_density"/"fog_sky" set the fog when spawning at this spot (fog_sky 0 = no change, -1 = clear to 0)
*/
/*FGD
@PointClass base(PlayerClass) = info_player_start_test : "Developer-only spawn point" [
	spawnflags(flags) = [
		1 : "Spawn at this one plz" : 0
	]
]
*/
void() info_player_start_test =
{
	if (!(self.spawnflags & 1))
	{
		remove(self);
		return;
	}
	self.mangle = self.angles;
	fog_fixKeys();
}
void() testplayerstart = {info_player_start_test();}	// back compat with old editors that use regioned compiles

/*QUAKED info_player_deathmatch (1 0 1) (-16 -16 -24) (16 16 24)
potential spawning position for deathmatch games

"angle" viewing angle when spawning
"fog_color"/"fog_density"/"fog_sky" set the fog when spawning at this spot (fog_sky 0 = no change, -1 = clear to 0)
*/
/*FGD
@PointClass base(PlayerClass) = info_player_deathmatch : "Deathmatch start" []
*/
void() info_player_deathmatch =
{
	fog_fixKeys();
}

void() coop_enable =
{
	self.classname = "info_player_coop";
	self.use = SUB_Null;
}

/*QUAKED info_player_coop (1 0 1) (-16 -16 -24) (16 16 24) TRIGGER_FIRST
Potential spawning position(s) for coop games. Will fire its targets when a player is spawned here, with player as activator.

"angle" viewing angle when spawning
"fog_color"/"fog_density"/"fog_sky" set the fog when spawning at this spot (fog_sky 0 = no change, -1 = clear to 0)

TRIGGER_FIRST - this start won't be used to spawn coop players until triggered, so respawning players don't have to walk all the way back to the action
*/
/*FGD
@PointClass base(PlayerClass, Targetname) = info_player_coop : "Player cooperative start" [
	spawnflags(flags) = [
		1 : "Trigger first" : 0
	]
]
*/
void() info_player_coop =
{
	self.mangle = self.angles;
	if (self.spawnflags & 1)
	{
		self.classname = "info_player_coop_notyet";
		self.use = coop_enable;
	}
	fog_fixKeys();
	setsize(self,VEC_HULL_MIN,VEC_HULL_MAX);	// for telefrag testing
}