/*
==============================================================================

EXPLOBOXES

==============================================================================
*/

/*FGD
@baseclass base(Appearflags, Target, Targetname) color(210 40 0) = Explobox [
	health(integer) : "Hit points (-1 to be immune and trigger-only)" : 18
	wait(string) : "Respawn interval. Default 0 is never respawn." : "0"
	count(integer) : "Respawn count. Default 0 is respawn forever (if 'wait' is set). -4 will auto-scale the count to the number of clients in coop." : 0
]
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
	self.use = explobox_use;
	self.health = self.max_health;
	if (self.health != -1)
		self.takedamage = DAMAGE_AIM;

	self.alpha = 1;
	setorigin(self, self.origin);
	bmodel_lightstyle(self, light_str(0,self));
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
	
	entity boom = spawn();
	setorigin(boom, BoundsCenter(self));
	boom.deathtype = self.deathtype;
	if (self.dmg > 0) T_RadiusDamage (boom, self.enemy, self.dmg, boom, DMGTYPE_EXPLOSION);
	boom.nextthink = time;
	if (self.spawnflags & 1)
	{
		sound (self, CHAN_VOICE, "blob/death1.wav", 1, ATTN_NORM);
		boom.think = BecomeTarExplosion;
	}
	else if (self.spawnflags & 2)	
		boom.think = BecomeWeakExplosion;
	else
		boom.think = BecomeExplosion;
	
	bmodel_lightstyle(self, light_str(1,self));
	
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
	self.enemy = damage_attacker;
	self.think = explobox_explode_go;
	self.nextthink = self.ltime + 0.05;	// infini-barrel crash fixed
}

void() explobox_use =
{
	self.enemy = activator;
	explobox_explode_go();
}

// ye olde barrel explode function preserved for maphacks
void() barrel_explode =
{
	kaboom(self.origin + '0 0 32', 160, world, TRUE);
}

//============================================================================

void() explobox_appear =
{
	if (self.solid != -1)
	{
		self.solid = SOLID_BSP;
		self.movetype = MOVETYPE_PUSH;
	}
	setorigin (self, self.origin);	
	setmodel (self, self.model);
	bmodel_lightstyle(self,light_str(0,self));
	
	self.use = explobox_use;
}

void() explobox_start_invis =
{
	self.use = explobox_appear;
	self.solid = SOLID_NOT;
	self.movetype = MOVETYPE_NONE;
	self.modelindex = 0;
	bmodel_lightstyle(self,light_str(1,self));
}


void() explobox_setup =
{
	precache_sound_safe ("weapons/r_exp3.wav");
	if (self.spawnflags & 1)
		precache_sound_safe("blob/death1.wav");
	self.th_die = explobox_explode;
	self.use = explobox_use;
	if (!self.health)
		self.health = 18;
	if (self.health != -1)
		self.takedamage = DAMAGE_AIM;
	self.type = "explobox";
	self.deathtype = "detonated";
	self.max_health = self.health;
	
	if (self.style < 0)
	{
		self.style *= -1;
		self.customflags |= CFL_INVLIGHT;
	}
	
	if (self.spawnflags & 128)
	{
		explobox_start_invis();
		return;
	}
	
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

/*QUAKED misc_explobox (.8 .2 0) (0 0 0) (32 32 64) - - - - - - - START_INVIS
Large exploding box. 150 damage. 
will do enough damage to set off other barrels at up to ~172u distance (center to center)

"health"	defaults to 18. -1 will make it immune to damage (trigger only)
"target"	fires targets when it explodes
"targetname"	will explode when triggered
"wait"		will respawn after 'wait' seconds
"count"		will only respawn 'count' times
*/
/*FGD
@PointClass base(Explobox, FuncInvis) size(0 0 0, 32 32 64) model({ "path": ":maps/b_explob.bsp" }) = misc_explobox : 
"Large exploding container, 150 damage. 
Explodes when triggered or shot. Fires targets when it explodes.
will do enough damage to set off other barrels at up to ~172u distance (center to center)." 
[]
*/
void() misc_explobox =
{
	if (!SUB_ShouldSpawn()) return;
	self.solid = SOLID_BSP;
	self.movetype = MOVETYPE_PUSH;
	precache_model_safe ("maps/b_explob.bsp");
	setmodel (self, "maps/b_explob.bsp");
	
	self.dmg = zeroconvertdefault(self.dmg,150);
		
	explobox_setup();
}

/*QUAKED misc_explobox2 (0 .5 .8) (0 0 0) (32 32 32) - - - - - - - START_INVIS
Smaller exploding box. 100 damage. REGISTERED ONLY
will do enough damage to set off other barrels at up to ~128u distance (center to center)

"health"	defaults to 18. -1 will make it immune to damage (trigger only)
"target"	fires targets when it explodes
"targetname"	will explode when triggered
"wait"		will respawn after 'wait' seconds
"count"		will only respawn 'count' times
*/
/*FGD
@PointClass base(Explobox, FuncInvis) size(0 0 0, 32 32 32) model({ "path": ":maps/b_exbox2.bsp" }) = misc_explobox2 : "Small exploding container, 100 damage. 
Explodes when triggered or shot. Fires targets when it explodes.
will do enough damage to set off other barrels at up to ~128u distance (center to center)." 
[]
*/
void() misc_explobox2 =
{
	if (!SUB_ShouldSpawn()) return;
	self.solid = SOLID_BSP;
	self.movetype = MOVETYPE_PUSH;
	precache_model2_safe ("maps/b_exbox2.bsp");
	setmodel (self, "maps/b_exbox2.bsp");
	self.dmg = zeroconvertdefault(self.dmg,100);
		
	explobox_setup();
}

/*QUAKED func_explobox (.8 .2 0) ? TARBABY PUFF - - - - - START_INVIS
Build your own exploding box!

Keyvalues:
"health"	defaults to 18. -1 will make it immune to damage (trigger only)
"dmg"		damage to explode with, defaults to 150 if unset. -1 will force 0.
"target"	fires targets when it explodes
"targetname"	will explode when triggered
"wait"		will respawn after 'wait' seconds
"count"		will only respawn 'count' times
*/
/*FGD
@SolidClass base(Explobox, FuncInvis) = func_explobox : "Customizable exploding container. 
Explodes when triggered or shot. Fires targets when it explodes." 
[
	dmg(integer) : "Explosion damage (-1 will force 0)" : 150
]
*/
void() func_explobox =
{
	if (!SUB_ShouldSpawn()) return;
	self.solid = SOLID_BSP;
	self.movetype = MOVETYPE_PUSH;
	setmodel(self,self.model);
	self.dmg = zeroconvertdefault(self.dmg,150);
	bmodel_lightstyle(self, light_str(0,self));
	explobox_setup();
}