/*
==============================================================================

MONSTERS

All things spawning and initializing

==============================================================================
*/

/*FGD
@baseclass base(Angle, Appearflags, Target, Targetname, Deathtype) color(220 0 0) = Monster 
[
	spawnflags(Flags) = 
	[
		1 : "Ambush" : 0
		16 : "Triggered Spawn" : 0
		32 : "No Teleflash on Spawn" : 0
		64 : "Don't Spawn If Would Telefrag" : 0
		128 : "Spawn Angry" : 0
	]
	movedir(string) : "Auto jump velocity on awaken"
	count(integer) : "Number of times to spawn if triggered (-1 for infinite)"
	wait(string) : "Pause before spawning if triggered" : "0"
	rand(string) : "Random extra before spawning if triggered" : "0"
]
*/

// at map start, anything that is a monster calls this and adds itself to various
// balance debugging totals, to take some of the guesswork out of ammo placement
void() TallyHitpoints =
{
	if (!cvar("developer")) return;
	
	//dprint5("tally hitpoints for ",self.classname," adding ",ftos(self.health),"\n");
	if (self.classname == "monster_boss" || self.classname == "monster_oldone")
		return;
	
	local float num;
	num = 1;
	if (self.spawnflags & SPAWN_TRIGGERED)
	{
		if (self.count > 1)
			num = self.count;
	}
	
	if (self.type == "zombie")
	{
		if ( !( self.spawnflags & SPAWN_CRUCIFIED ) )
			num_zombies += num;
	}
	else
		monster_health += self.health * num;
	
	if (self.classname == "monster_army")
		ammo_total += 5 * DEBUG_DMG_PER_SHELL;
	//if (self.classname == "monster_enforcer")
	//	ammo_total += 5 * DEBUG_DMG_PER_CELL;
	if (self.classname == "monster_ogre")
		num_rockets += 1;
}

/*
================================================================

SPAWNING

all monster_* entities can be used as triggerable monster teleport spawns,
which is way better than building a big teleport setup in a hidden room
for each one.

setting 'count' on any monster allows the same entity to be triggered more than 
once to spawn monsters repeatedly. 'count' monsters are added to the kill total 
when the map starts.
setting count to a negative number makes the spawner unlimited use, and monsters
are added to the kill total as they're spawned. 

FIXME: their bodies and head gibs WILL stick around forever

================================================================
*/



/*
================
monster_spawnsetup_go

sanity check for trigger-spawned monsters with no existing targeters
fix by iw
================
*/
void() monster_spawnsetup_go =
{
	self.think = SUB_Null;  // just to tidy up after ourselves

	if (self.targetname == string_null)
	{
		dprint5("WARNING: removed triggered-spawn ", self.classname,
			" with no targetname at ", vtos(self.origin), "\n");
		remove(self);
		return;
	}

	if (cvar("developer"))
	{
		if (!SUB_VerifyTriggerable())
		{
			bprint4("WARNING: removed triggered-spawn ", self.classname,
				" with unmatched targetname '", self.targetname);
			bprint3("' at ", vtos(self.origin), "\n");
			remove(self);
			return;
		}
	}

	self.customflags |= CFL_SPAWNER;
	self.use = self.think1;
	self.think1 = SUB_Null;  // just to tidy up after ourselves

	if (!self.count)
		self.count = 1;
	if (self.count == -1)
		self.count = 0;
	if (self.count != -4)
		addmonster(self.count);	// this count gets added late
};

/*
================
monster_spawnsetup

Checks if this monster is in some way a spawner of monsters, and returns
TRUE if so, after scheduling appropriate setup. A return of TRUE should
signal the calling spawnfunc that the monster shouldn't continue to be
spawned right now.

'spawnthink' is the function that should be used as the triggering action
if this monster is a spawner.
================
*/
float( void() spawnthink ) monster_spawnsetup =
{
	TallyHitpoints();
	
	if (!(self.spawnflags & SPAWN_TRIGGERED))
		return FALSE;
	
	// if we're not in coop mode, count -4 will always evaluate to 1, so go ahead and default 
	// this field back to 0 so the kill count doesn't change during play if it doesn't have to
	if (self.count == -4 && !cvar("coop"))
		self.count = 0;

	// wait for all potential targeters to finish spawning
	self.think1 = spawnthink;
	self.think = monster_spawnsetup_go;
	self.nextthink = time + 0.1 + random() * 0.05;	// spread thinks to not ram quake to death with sub_verifytriggerable checks
	
	return TRUE;
}

void(float num) addmonster =
{
	if (!self.th_checkattack)
		self.th_checkattack = CheckAttack;
	
	if (!num) return;
	
	total_monsters = total_monsters + num;
	WriteByte (MSG_ALL, SVC_UPDATESTAT);
	WriteByte (MSG_ALL, STAT_TOTALMONSTERS);
	WriteLong (MSG_ALL, total_monsters);
}

float(entity me) monster_check_enemy_activator =
{
	if ((activator.flags & (FL_CLIENT|FL_MONSTER)) && activator.health <= 0)
		return FALSE;
	return TRUE;
}

float(entity me) monster_check_enemy_inheritance =
{
	if (!(activator.flags & FL_MONSTER))
		return FALSE;
	if (!(activator.enemy.health > 0 || activator.oldenemy.health > 0))
		return FALSE;
	if (!(activator.enemy.classname == "player" || activator.oldenemy.classname == "player"))
		return FALSE;
	return TRUE;
}


entity(float onlymonsters) find_touching =
{
	entity head = findradius(BoundsCenter(self), self.size_z + 16);
	while (head != world)
	{
		if (head.health <= 0 ||
			(head.solid == SOLID_NOT || head.solid == SOLID_TRIGGER) ||
			!BoundsTouching(self.absmin, self.absmax, head.absmin, head.absmax, 4) ||
			(onlymonsters && (head.flags & FL_MONSTER == 0)) )
		{
			head = head.chain;
		}
		else return head;
	}
	return world;
}

void() mon_spawner_tryspawn
{
	if (find_touching(TRUE))
	{
		self.nextthink = time + 0.5;
		return;
	}
	
	if (!(self.spawnflags & SPAWN_NO_TFOG))
		teleport_flash();
	self.think1();
}

entity( void() spawnthink ) mon_spawner_use =
{
	//playercount_convert(count);
	if (self.count == -4)
	{
		self.count = clients;
		addmonster(clients);
	}
	
	entity mon;
	float pause;
	
	mon = spawn();
	
	// hack for QSS lerpmodels problems: force entity to move clientside for 
	//	at least one frame before spawning to flush old lerp position
	mon.movetype = MOVETYPE_TOSS;
	mon.oldorigin = self.origin;
	
	setorigin(mon, self.origin);
	mon.angles = self.angles;
	
	pause = max(0.01, self.wait) + random() * max(self.rand, 0.05);
	mon.nextthink = time + pause;
	mon.spawnflags = self.spawnflags;
	mon.movedir = self.movedir;
	mon.rmovedir = self.rmovedir;
	mon.lip = self.lip;
	mon.state = self.state;
	mon.alpha = self.alpha;
	mon.skin = self.skin;
	mon.effects = self.effects;
	mon.armortype = self.armortype;
	mon.armorvalue = self.armorvalue;
	mon.items = self.items;
	mon.gravity = self.gravity;
	mon.invincible_finished = self.invincible_finished;
	mon.invisible_finished = self.invisible_finished;
	mon.super_damage_finished = self.super_damage_finished;
	mon.radsuit_finished = self.radsuit_finished;
	mon.health = self.health;
	mon.delay = self.delay;
	mon.message = self.message;
	mon.deathtype = self.deathtype;
	SUB_CopyTargets(mon);
	
	// don't spawnfrag monsters if the mapper expects us to be spawning into chaos
	if ( (self.spawnflags & SPAWN_NO_TFRAG) )
	{
		// set monster's size now so we can check the landing zone for other monsters
		setsize(mon,self.mins,self.maxs);
		mon.think = mon_spawner_tryspawn;
		mon.think1 = spawnthink;
	}
	else
	{
		mon.think = spawnthink;
		if (!(self.spawnflags & SPAWN_NO_TFOG))
			teleport_flash_delay(pause);
	}

	// set .enemy before monster_start thinks, because 'activator' will be different by then
	if ( !self.enemy && (self.spawnflags & SPAWN_INSTAWAKE) && monster_check_enemy_activator(mon) )
	{
		// theSolipsist fix: monsters triggered or awakened by other monsters inherit their enemies
		if (monster_check_enemy_inheritance(mon))
		{
			mon.enemy = activator.enemy;
			mon.oldenemy = activator.oldenemy;
		}
		else
			mon.enemy = activator;
	}	

	if (self.count > 0)
	{
		self.count = self.count - 1;
		if (self.count == 0)
		{
			SUB_Remove();
		}
	}
	else 
	{
		addmonster(1); // add them one at a time if this is an unlimited spawner
	}
	
	return mon;
}

void(entity m) monster_kill =
{
	T_Damage(m, self, self, m.health + 100);
}

/*
================
monster_use

Using a monster makes it angry at the current activator, because
nobody likes to be used
================
*/
void() monster_use =
{
	if (self.health <= 0)
		return;
	if (self.enemy)
		return;
	if (has_invis(activator))
		return;
	if (activator.flags & FL_NOTARGET)
		return;

	if (!monster_check_enemy_activator(self)) return;	
	
	// theSolipsist fix: monsters triggered or awakened by other monsters inherit their enemies
	if (monster_check_enemy_inheritance(self))
	{
		self.enemy = activator.enemy;
		self.oldenemy = activator.oldenemy;
	}
	else 
		self.enemy = activator;

	// delay reaction so the monster is still heard if it's teleported
	self.nextthink = time + 0.1;
	self.think = FoundTarget;

}


/*
================
monster_death_use

When a monster dies, it fires all of its targets with the current
enemy as activator.
================
*/
void() monster_death_use =
{
	// fall to ground
	if (self.flags & FL_FLY)
		self.flags = self.flags - FL_FLY;
	if (self.flags & FL_SWIM)
		self.flags = self.flags - FL_SWIM;

	if (!self.target && !self.target2 && !self.target3 && !self.target4 && !self.killtarget)
		return;

	// try to make player activator even if the monster was killed while infighting
	if (self.enemy.classname != "player" && self.oldenemy.classname == "player")
		activator = self.oldenemy;
	else
		activator = self.enemy;
	
	SUB_UseTargets ();
}


//============================================================================

/*
================
Common monster starts
================
*/

void() monster_start =
{
	if (self.oldorigin == VEC_ORIGIN)
		self.oldorigin = self.origin;
	
	if (self.rmovedir != VEC_ORIGIN)
	{
		makevectors(self.angles);
		self.movedir = v_forward * self.rmovedir_x + v_right * self.rmovedir_y + v_up * self.rmovedir_z;
	}
		
	// moved from mon_spawner_use because it was too early to catch the monster's mins and maxs
	spawn_tdeath(self.origin, self);

	// wait a few frames to make sure doors have spawned before doing droptofloor
	self.nextthink = 1.15;
	// why 1.15 is a magic number:
	// - quake starts 'time' at 1.0 seconds.
	// - doors and movers and stuff reposition themselves at 1.1 seconds.
	// - items drop themselves into place at 1.2 seconds, after movers, so that they fall on them 
	//    in their final positions.
	// - we want monsters to do this too, but before items do, because they were always before
	//    items originally and altering the drop order too much could cause items that didn't
	//    fall out of the world before to do so erroneously in Copper.
	// - we don't use 'time + 0.15' because this could be running on a late spawn. a constant
	//    1.15 will always be when we want at map start but in the past upon late spawn.

	if (self.type == string_null)
		self.type = self.classname;
	
	// needed for monsters to be healed by a target_heal
	self.max_health = self.health;
}

void() monster_start_go =
{
	local entity pathgoal;
	self.takedamage = DAMAGE_AIM;
	
	self.ideal_yaw = self.angles * '0 1 0';
	self.use = monster_use;
	self.flags = self.flags | FL_MONSTER;
	
	// check if the mapper placed them touching a killer liquid and grant them immunity to it
	vector wtt;
	wtt = WaterTest();
	if (wtt_x)
	{
		if (wtt_y == CONTENT_LAVA || wtt_y == CONTENT_SLIME)
		{
			self.customflags |= CFL_LIQUID_IMMUNE;
		}
	}
	// ai_nav
	//self.radius = (self.maxs_x - self.mins_x) * 0.7;

	if (self.enemy.flags & FL_NOTARGET || self.enemy.movetype == MOVETYPE_NOCLIP)
		self.enemy = world;
	
	if (self.enemy)
	{
		self.th_stand();
		self.think = FoundTarget;
	}
	else if (self.target)
	{
		pathgoal = find(world, targetname, self.target);
		if (!pathgoal)
		{
			dprint (self.classname);
			dprint (" at ");
			dprint (vtos(self.origin));
			dprint (" can't find target\n");
		}
		
		if (pathgoal.classname == "path_corner")
		{
			self.goalentity = pathgoal;
			self.ideal_yaw = vectoyaw(self.goalentity.origin - self.origin);
			self.th_walk ();
		}
		else
		{
			self.pausetime = time + A_SHITLOAD;
			self.th_stand ();
		}
	}
	else
	{
		self.pausetime = time + A_SHITLOAD;
		self.th_stand ();
	}

	// spread think times so they don't all happen at same time
	// add tiny minimum in case random() ever returns exactly 0 (rare but possible)
	self.nextthink = time + random()*0.1 + 0.05;

}

/*
================
Walkmonster starts
================
*/

void() walkmonster_start_go =
{
	self.movetype = MOVETYPE_STEP;
	// fix monsters being stuck in floor because of QSS fix
	if (self.oldorigin != VEC_ORIGIN)
		setorigin(self,self.oldorigin);
	
	if (self.rmovedir != VEC_ORIGIN)
	{
		makevectors(self.angles);
		self.movedir = v_forward * self.rmovedir_x + v_right * self.rmovedir_y + v_up * self.rmovedir_z;
		self.rmovedir = VEC_ORIGIN;
	}
	
	if (self.movedir == VEC_ORIGIN && !(self.spawnflags & SPAWN_TRIGGERED) )	// always put telespawned monsters where the mapper wants
	{
		self.origin_z = self.origin_z + 1;	// raise off floor a bit
		droptofloor(0,0);
	}
	
	if (!walkmove(0,0))
	{
		dprint ("walkmonster in wall at: ");
		dprint (vtos(self.origin));
		dprint ("\n");
	}
	
	if (!self.yaw_speed)
		self.yaw_speed = 20;
	self.view_ofs = '0 0 25';
	
	if (self.spawnflags & SPAWN_TRIGGERED && self.movedir != VEC_ORIGIN)
	{
		self.velocity = self.movedir;
		self.movedir = VEC_ORIGIN;
	}
	
	monster_start_go();
}


void() walkmonster_start =
{
	monster_start();
	self.think = walkmonster_start_go;
}

/*
================
Flymonster starts
================
*/

void() flymonster_start_go =
{
	self.movetype = MOVETYPE_FLY;
	if (!self.yaw_speed)
		self.yaw_speed = 10;
	self.view_ofs = '0 0 25';

	if (!walkmove(0,0))
	{
		dprint ("flymonster in wall at: ");
		dprint (vtos(self.origin));
		dprint ("\n");
	}

	
	monster_start_go();
}

void() flymonster_start =
{
	monster_start();
	// iw -- move these here so fish don't fall for a frame and a half
	self.flags = self.flags | FL_FLY;

	self.think = flymonster_start_go;
}

/*
================
Swimmonster starts
================
*/

void() swimmonster_start_go =
{
	self.movetype = MOVETYPE_FLY;
	if (!self.yaw_speed)
		self.yaw_speed = 20;//10
	self.view_ofs = '0 0 10';
	
	// FIXME: why don't fish do a walkmove test?
	monster_start_go();
	// yes besides the fact that they don't have feet dickhead
}

void() swimmonster_start =
{
	monster_start();
	// iw -- move these here so fish don't fall for a frame and a half
	self.flags = self.flags | FL_SWIM;

	self.think = swimmonster_start_go;
}


/*
================
stuff for nomonsters 1
monsters which fire targets on death can't just not be spawned or the map
will break, so they become invisible eyes that fire their targets on sight
================
*/

float() nomonster_findtarget =
{
	local entity	client;
	local float		r;

	if ( sight_entity_time >= time - 0.1 && ( !(self.spawnflags & SPAWN_AMBUSH ) ) )
	{
		client = sight_entity;
		if (client.enemy == self.enemy)
			return FALSE;
	}
	else
	{
		client = checkclient();
		if (!client)
			return FALSE;	// no check entities in PVS
	}
		
	if (!FilterTarget(client))
		return FALSE;		
	
	if (!visible (client))
		return FALSE;

	r = range(client);	
	if (r == RANGE_TOOFAR)
	{
		return FALSE;
	}

	return TRUE;
}

void() nomonster_sleep =
{
	if (nomonster_findtarget())
	{
		sight_entity = self;
		sight_entity_time = time;
		self.show_hostile = time + 1;
		SUB_UseTargets();
		self.think = SUB_Remove;
		//self.think = BecomeExplosion;
	}
	self.nextthink = time + 0.2;
	//particle(self.origin, '0 0 0', 64, 16);
}

void() nomonster_find =
{
	self.think = nomonster_sleep;
	self.nextthink = time + 0.2;
	entity e;
	e = findalltargets(self);
	while (e)
	{
		if (e.classname != "path_corner")
			return;
		e = e.chain;
	}
	remove(self);
}

void() nomonster_go =
{
	// a nomonster still has to be a solid so that it can be teleported out of teleboxes
	self.solid = SOLID_SLIDEBOX;
	self.movetype = MOVETYPE_FLY;
	setsize(self, VEC_HULL_MIN, VEC_HULL_MAX);
	self.think = nomonster_find;
	self.view_ofs = '0 0 25';
	self.nextthink = time + 0.2 + random();
}

float() nomonster =
{
	if (cvar("nomonsters") == 0)
		return FALSE;
	
	if (self.target == string_null &&
		self.target2 == string_null &&
		self.target3 == string_null &&
		self.target4 == string_null &&
		self.killtarget == string_null)
	{
		remove(self);
		return TRUE;
	}
	
	self.classname = "nomonster";
	
	// make teleports work:
	self.health = 1;
	self.flags += FL_MONSTER;
	
	if (self.targetname != string_null && self.spawnflags & SPAWN_TRIGGERED)
		self.use = nomonster_go;
	else
		nomonster_go();
	
	return TRUE;
}
