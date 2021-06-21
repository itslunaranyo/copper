/*
==============================================================================

EXPLOBOXES

==============================================================================
*/

void() explobox_respawn =
{
	entity who = find_touching(FALSE);
	if (who)	// solid, can't respawn if blocked
	{
		self.think = explobox_respawn;
		self.nextthink = self.ltime + 0.2;
		return;
	}

	self.solid = SOLID_BSP;
	self.movetype = MOVETYPE_PUSH;
	self.use = explobox_explode_go;
	self.health = self.max_health;
	if (self.health != -1)
		self.takedamage = DAMAGE_AIM;

	self.alpha = 1;
	setorigin(self, self.origin);
	bmodel_lightstyle(self, "a");
	ItemPiff();
}

void() explobox_flicker =
{
	if (self.ltime >= self.attack_finished)
	{
		explobox_respawn();
		return;
	}

	// flicker back into place
	self.alpha = (3.5 - (self.attack_finished - self.ltime)) / 8 + (1 - mod(self.attack_finished - self.ltime, 0.5)) * 0.2;
	self.nextthink = self.ltime + 0.1;
}

void() explobox_prespawn =
{
	self.model = self.wad;		// restore original model
	setorigin(self, self.origin);
	self.enemy = world;
	
	self.think = explobox_flicker;
	explobox_flicker();
}

void() explobox_explode_go =
{
	self.takedamage = DAMAGE_NO;
	self.classname = "explo_box";
	//sound (self, CHAN_VOICE, "weapons/r_exp3.wav", 1, ATTN_NORM);
	
	self.use = SUB_Null;
	self.health = 0;	// ensure triggered exploboxes don't hurt themselves and loop again
	kaboom(BoundsCenter(self), self.dmg, self, 0);
	bmodel_lightstyle(self, "m");
	
	if (!self.wait)
	{
		if (self.enemy)
			activator = self.enemy;
		SUB_UseTargets();
		SUB_Remove();
	}
	
	self.wad = self.model;
	self.model = string_null;
	self.solid = SOLID_NOT;
	//self.takedamage = DAMAGE_NO;
	
	self.think = explobox_prespawn;
	self.attack_finished = self.ltime + self.wait;
	self.nextthink = max(self.ltime + 0.05, self.attack_finished - 3.5);
	
	playercount_convert(count);
	if (self.count > 0)		// only respawn 'count' more times
	{
		self.count = self.count - 1;
		if (self.count <= 0)
		{
			if (self.enemy)
				activator = self.enemy;
			SUB_UseTargets();
			SUB_Remove();
		}
	}
}

void() explobox_explode =
{
	if (self.think == explobox_explode_go)
		return;	// already exploding
	self.enemy = activator;
	self.think = explobox_explode_go;
	self.nextthink = self.ltime + 0.05;	// infini-barrel crash fixed
}

// ye olde barrel explode function preserved for maphacks
void() barrel_explode =
{
	kaboom(self.origin + '0 0 32', 160, world, TRUE);
}

//============================================================================


void() explobox_setup =
{
	precache_sound_safe ("weapons/r_exp3.wav");
	self.th_die = explobox_explode;
	self.use = explobox_explode_go;
	if (!self.health)
		self.health = 18;
	if (self.health != -1)
		self.takedamage = DAMAGE_AIM;
	self.type = "explobox";
	self.max_health = self.health;
	
	// no droptofloor for mapper-built func
	if (self.classname=="func_explobox")
		return;
		
	/*
	vector oldorg;
	
	oldorg = self.origin;
	self.origin_z = self.origin_z + 2;
	droptofloor(0,0);
	if (oldorg_z - self.origin_z > 250)
	{
		dprint3("explobox fell out of level at ",vtos(oldorg),"\n");
		remove(self);
	}
	*/
	
	vector bottom = self.origin + (self.mins + self.maxs) / 2;
	//bprint(vtos(bottom));bprint("\n");
	bottom_z = self.origin_z;
	traceline(bottom, bottom + '0 0 -512', TRUE, self);
	if (trace_allsolid || trace_fraction == 1.0 || trace_fraction == 0.0)
		return;
	bottom = self.origin;
	bottom_z = trace_endpos_z;
	setorigin(self, bottom);
}

/*QUAKED misc_explobox (0 .5 .8) (0 0 0) (32 32 64)
Large exploding box. 150 damage. 
will do enough damage to set off other barrels at up to ~172u distance (center to center)

"target"	fires targets when it explodes
"targetname"	will explode when triggered
"wait"		will respawn after 'wait' seconds
"count"		will only respawn 'count' times
*/
/*FGD
@PointClass base(Appearflags, Target, Targetname) size(0 0 0, 32 32 64) model({ "path": ":maps/b_explob.bsp" }) = misc_explobox : 
"Large exploding container, 150 damage. 
Explodes when triggered or shot. Fires targets when it explodes.
will do enough damage to set off other barrels at up to ~172u distance (center to center)." 
[
	wait(string) : "Respawn delay"
	count(integer) : "Respawn limit"
]
*/
void() misc_explobox =
{
	if (!SUB_ShouldSpawn()) return;
	self.solid = SOLID_BSP;
	self.movetype = MOVETYPE_PUSH;
	precache_model ("maps/b_explob.bsp");
	setmodel (self, "maps/b_explob.bsp");
	
	self.dmg = zeroconvertdefault(self.dmg,150);
		
	explobox_setup();
}


/*QUAKED misc_explobox2 (0 .5 .8) (0 0 0) (32 32 32)
Smaller exploding box. 100 damage. REGISTERED ONLY
will do enough damage to set off other barrels at up to ~128u distance (center to center)

"target"	fires targets when it explodes
"targetname"	will explode when triggered
"wait"		will respawn after 'wait' seconds
"count"		will only respawn 'count' times
*/
/*FGD
@PointClass base(Appearflags, Target, Targetname) size(0 0 0, 32 32 32) model({ "path": ":maps/b_exbox2.bsp" }) = misc_explobox2 : "Small exploding container, 100 damage. 
Explodes when triggered or shot. Fires targets when it explodes.
will do enough damage to set off other barrels at up to ~128u distance (center to center)." 
[
	wait(string) : "Respawn delay"
	count(integer) : "Respawn limit"
]
*/
void() misc_explobox2 =
{
	if (!SUB_ShouldSpawn()) return;
	self.solid = SOLID_BSP;
	self.movetype = MOVETYPE_PUSH;
	precache_model2 ("maps/b_exbox2.bsp");
	setmodel (self, "maps/b_exbox2.bsp");
	self.dmg = zeroconvertdefault(self.dmg,100);
		
	explobox_setup();
}

/*QUAKED func_explobox (0 .5 .8) ?
Build your own exploding box!

Keyvalues:
"health"	defaults to 18
"dmg"		damage to explode with, defaults to 150 if unset. -1 will force 0.
"target"	fires targets when it explodes
"targetname"	will explode when triggered
"wait"		will respawn after 'wait' seconds
"count"		will only respawn 'count' times
*/
/*FGD
@SolidClass base(Appearflags, Target, Targetname) = func_explobox : "Customizable exploding container. 
Explodes when triggered or shot. Fires targets when it explodes." 
[
	health(integer) : "Hit points" : 18
	dmg(integer) : "Explosion damage" : 150
	wait(string) : "Respawn delay"
	count(integer) : "Respawn limit"
]
*/
void() func_explobox =
{
	if (!SUB_ShouldSpawn()) return;
	self.solid = SOLID_BSP;
	self.movetype = MOVETYPE_PUSH;
	setmodel(self,self.model);
	self.dmg = zeroconvertdefault(self.dmg,150);
	bmodel_lightstyle(self, "a");
	explobox_setup();
}