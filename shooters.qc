

//============================================================================

float SF_SHOOT_SUPERSPIKE	= 1;
float SF_SHOOT_LASER		= 2;
float SF_SHOOT_OGRENADE		= 4;
float SF_SHOOT_ACTIVATOR	= 16;


/*FGD
@baseclass base(Appearflags, Target, Targetname, Angle) color(220 150 150) = Shooter
[
	spawnflags(Flags) = 
	[
		1 : "Spike" : 0
		2 : "Laser" : 0
		4 : "Ogre Grenade" : 0
		16 : "Fire At Activator" : 0
	]
	movedir(string) : "Override launch vector (x y z)"
	volume(string) : "Override sound volume"
	delay(string) : "Pause before firing" : "0"
	speed(integer) : "Launch velocity for grenades"
]
*/

void() spikeshooter_fire =
{
	if (self.state) return;
	
	vector dir;
	entity e;
	
	if (self.spawnflags & SF_SHOOT_ACTIVATOR)
	{
		if (!self.enemy)
			self.enemy = activator;
		dir = normalize(self.enemy.origin - self.origin);
	}
	else
	{
		if (self.target != string_null)
			e = find(world, targetname, self.target);
			
		if (e)
			dir = normalize(BoundsCenter(e) - self.origin);
		else
			dir = self.movedir;
	}
	
	if (self.spawnflags & SF_SHOOT_LASER)
	{
		sound (self, CHAN_VOICE, "enforcer/enfire.wav", self.volume, ATTN_NORM);
		dprint5("shot from ", vtos(self.origin), " at ",vtos(dir), "\n");
		launch_laser (self.origin, dir*600);
	}
	else if (self.spawnflags & SF_SHOOT_OGRENADE)
	{
		sound (self, CHAN_VOICE, "weapons/grenade.wav", self.volume, ATTN_NORM);
		e = launch_grenade(self.origin, dir * self.speed);
		e.touch = OgreGrenadeTouch;
		e.th_die = OgreGrenadeExplode;
	}
	else
	{
		sound (self, CHAN_VOICE, "weapons/spike2.wav", self.volume, ATTN_NORM);
		e = launch_nail (self.origin, dir * 500);
		if (self.spawnflags & SF_SHOOT_SUPERSPIKE)
		{
			e.classname = "superspike";
			e.skin = 1;
			e.dmg = 18;
		}
	}
}

void() shooter_proxy_think =
{
	self.buddy.enemy = self.enemy;
	SUB_CallAsSelf(spikeshooter_fire,self.buddy);
	remove(self);
}

void() shooter_once_think =
{
	// iw - if a shooter is triggered more often than its .delay, nextthink is
	// repeatedly overwritten and the shooter never fires (bbin1)
	// lunaran - spawn a proxy that'll fire at the right time to 'queue up'
	// shots, so that none are missed
	if (self.nextthink)
	{
		entity shooty = spawn();
		shooty.buddy = self;
		shooty.enemy = activator;
		shooty.think = shooter_proxy_think;
		shooty.nextthink = time + self.delay;
		return;
	}
	self.enemy = activator;
	self.think = spikeshooter_fire;
	self.nextthink = time + self.delay;
}

void() shooter_think =
{
	spikeshooter_fire ();
	self.nextthink = time + self.wait + self.rand * random();
}

void() spikeshooter_use = {spikeshooter_fire();}	// for id1 hacks
void() shooter_use =
{
	self.state = !(self.state);
	
	if (self.state) return;
	
	self.nextthink = time + self.delay;
	self.enemy = activator;
}

/*QUAKED trap_spikeshooter (0 .5 .8) (-8 -8 -8) (8 8 8) SUPERSPIKE LASER OGRENADE ? AT_ACTIVATOR
When triggered, fires a spike in the direction set by "angle".

"movedir" override angle with a launch vector of your choosing
"target" aim at an entity instead. can be moving (like a train.)
"delay" delay before firing (for staggering shooters)
"volume" override how loud these things are because damn
"speed" override launch velocity for grenades only (laser and nail speed is standardized for the player's sake)
*/
/*FGD
@PointClass base(Shooter) = trap_spikeshooter : "Triggered shooter" []
*/
void() trap_spikeshooter =
{
	if (!SUB_ShouldSpawn()) return;
	SetMovedir ();
	self.volume = zeroconvertdefault(self.volume, 1);
	self.use = shooter_once_think;
	if (self.spawnflags & SF_SHOOT_OGRENADE)
	{
		self.speed = zeroconvertdefault(self.speed, 400);
	}
	if (self.spawnflags & SF_SHOOT_LASER)
	{
		precache_model2 ("progs/laser.mdl");
		
		precache_sound2 ("enforcer/enfire.wav");
		precache_sound2 ("enforcer/enfstop.wav");
	}
	else
		precache_sound_safe ("weapons/spike2.wav");
}

/*QUAKED trap_shooter (0 .5 .8) (-8 -8 -8) (8 8 8) SUPERSPIKE LASER OGRENADE ? AT_ACTIVATOR
Continuously fires spikes in the direction set by "angle". Trigger to turn on, trigger again to turn off.
Laser is only for REGISTERED. YOU PAY FOR LASER
"wait" time between shots (1.0 default)
"delay" delay before firing first spike, so multiple shooters can be staggered
"movedir" override angle with a launch vector of your choosing
"speed" override launch velocity for grenades only (laser and nail speed is standardized for the player's sake)
*/
/*FGD
@PointClass base(Shooter) = trap_shooter : "Continuous shooter"
[
	nextthink(integer) : "Delay before first spike"
	wait(string) : "Wait between spikes"
	rand(string) : "Random extra delay between spikes"
]
*/
void() trap_shooter =
{
	if (!SUB_ShouldSpawn()) return;
	trap_spikeshooter ();
	
	if (self.targetname != string_null)	// start off if something targets us
		self.state = 1;
	self.use = shooter_use;
	if (self.wait == 0)
		self.wait = 1;
		
	// original id trap_shooter used nextthink as a mapper-editable delay, which is dumb
	// add it to nextthink here anyway for backwards compatibility
	self.nextthink = self.nextthink + self.delay + self.wait + self.ltime;
	self.think = shooter_think;
}

//============================================================================

float SF_LSHOOT_ONESHOT	= 1;
float SF_LSHOOT_TRACKME	= 2;

void(vector tgt) trap_lightning_effect =
{
	WriteByte (MSG_ALL, SVC_TEMPENTITY);
	
	if (self.strength == 3)
	{
		WriteByte (MSG_ALL, TE_LIGHTNING3);
	}
	else if (self.strength == 2)
	{
		WriteByte (MSG_ALL, TE_LIGHTNING1);
	}
	else
	{
		WriteByte (MSG_ALL, TE_LIGHTNING2);
	}
	
	WriteEntity (MSG_ALL, self);
	WriteCoord (MSG_ALL, self.origin_x);
	WriteCoord (MSG_ALL, self.origin_y);
	WriteCoord (MSG_ALL, self.origin_z);
	WriteCoord (MSG_ALL, tgt_x);
	WriteCoord (MSG_ALL, tgt_y);
	WriteCoord (MSG_ALL, tgt_z);
}

void() trap_lightning_fire =
{
	vector tgt, org, nudge;
	entity last, oself;
	float i = 0;
	
	if (!self.enemy)	// might already be activator
		self.enemy = findunlockedtarget(world);
	if (!self.enemy)
	{
		if (self.target != string_null || self.target2 != string_null || 
			self.target3 != string_null || self.target4 != string_null)
		{
			return;	// has targets, but none are unlocked
		}
		else
		{
			tgt = self.origin + self.movedir;	// has no targets
		}
	}
	else
	{
		tgt = BoundsCenter(self.enemy);	// for aiming at trains or bobboes
	}
		
	//self.enemy = world;	
	nudge = normalize(tgt - self.origin) * 8;
	
	if ( !(self.spawnflags & SF_LSHOOT_ONESHOT) || self.strength == 3)
	{
		if (time >= self.nextmovesound)
		{
			sound (self, CHAN_VOICE, "misc/power.wav", self.volume, ATTN_NORM);
			self.nextmovesound = time + 1.2;
		}
	}
	
	if (self.strength == 1)
	{
		// do 10 dmg every think
		traceline2(self.origin, tgt, self, 0);	// hit one target and stop
		tgt = trace_endpos;
		if (trace_ent.takedamage)
		{
			T_Damage(trace_ent, self, self, 10);
			particle (trace_endpos + nudge, nudge * -8, 225, 40);
			sound (trace_ent, CHAN_BODY, "weapons/lhit.wav", 1, ATTN_NORM);
		}
	}
	else
	{
		// str 2 and 3 lightnings pierce creatures to world
		traceline2(self.origin, tgt, self, TRACE_NOMONSTERS);
		tgt = trace_endpos;
		
		if (!(self.spawnflags & SF_LSHOOT_ONESHOT) || 	// always dmg on think in continuous mode
			(self.strength == 2 && self.count == 3) ||	// dmg on first think only in oneshot mode
			self.strength == 3 )	// fatbeam is instakill so do it either way
		{
			org = self.origin;
			last = self;
			do {
				i++;
				traceline2(org, tgt, last, 0);
				
				// end on buttons and shootable bmodels 
				if ( (trace_ent.solid != SOLID_BBOX && trace_ent.solid != SOLID_SLIDEBOX) && 
					(!trace_ent.movetype || trace_ent.movetype == MOVETYPE_PUSH) )
				{
					i = 8;
					tgt = trace_endpos;
				}
				org = trace_endpos + nudge;
			
				if (trace_ent.takedamage)
				{
					last = trace_ent;
					if (self.strength == 2)
					{
						T_Damage(trace_ent, self, self, 30);
						particle (org, nudge * -8, 225, 120);
					}
					else
					{
						// handle chthons and shubs intelligently
						if (trace_ent.classname == "monster_boss" || trace_ent.classname == "monster_oldone")
						{
							if (self.count == 10)	// first tic only so we don't melt the boss
							{
								if (trace_ent.classname == "monster_boss")
								{
									T_Damage (trace_ent, self, self, 1000);
								}
								else if (trace_ent.classname == "monster_oldone")
								{
									dprint4(ftos(self.count)," ", ftos(self.strength), " zapping shub with a thing\n");
									T_Damage (trace_ent, self, self, 10001);	// auto-trigger one pain warble
								}
							}
						}
						else
						{
							T_Damage (trace_ent, self, self, trace_ent.health + min(trace_ent.armorvalue, trace_ent.health / trace_ent.armortype) + 50);
						}
					}
					sound (trace_ent, CHAN_BODY, "weapons/lhit.wav", 1, ATTN_NORM);
				}
				else if (trace_ent.classname == "monster_boss" && self.strength == 3 && self.count == 10)
				{
					last = trace_ent;
					// get non-takedamage cthons too
					dprint4(ftos(self.count)," ", ftos(self.strength), " zapping cthon with a thing\n");
					oself = self;
					self = trace_ent;
					self.health = self.health - 1;
					boss_pain(activator, 1);
					self = oself;
				}
				
			} while (i < 8 && trace_ent != world);
		}
	}
	if (self.strength == 3)
		tgt -= nudge * 12;	// fatbeams are extra long
	trap_lightning_effect(tgt);
	
	if (self.spawnflags & SF_LSHOOT_ONESHOT)
	{
		self.count = self.count - 1;
		if (self.count <= 0)
			return;
	}
	self.think = trap_lightning_fire; 
	self.nextthink = time + 0.1;
}

void() trap_lightning_proxy =
{
	if (self.buddy.spawnflags & SF_LSHOOT_TRACKME)
		self.buddy.enemy = self.enemy;
	SUB_CallAsSelf(trap_lightning_fire, self.buddy);
	sound(self, CHAN_WEAPON, "weapons/lstart.wav", self.volume, ATTN_NORM);
	remove(self);
}

void() trap_lightning_use =
{
	entity proxy;
	
	if (self.spawnflags & SF_LSHOOT_TRACKME)
		self.enemy = activator;
	
	if (self.spawnflags & SF_LSHOOT_ONESHOT)
	{
		if (time < self.attack_finished) return;
		self.attack_finished = time + 0.1;
		
		if (self.strength == 3) self.count = 10;
		else if (self.strength == 2) self.count = 3;
		else self.count = 1;
		
		if (self.delay > 0)
		{
			proxy = spawn();
			proxy.think = trap_lightning_proxy;
			proxy.nextthink = time + self.delay;
			proxy.buddy = self;
			proxy.enemy = activator;
			return;
		}
			
		sound(self, CHAN_WEAPON, "weapons/lstart.wav", self.volume, ATTN_NORM);
		trap_lightning_fire();
		return;
	}

	// is a toggle zapper
	self.state = !self.state;
	self.nextmovesound = 0;
	if (self.state)
	{
		sound(self, CHAN_WEAPON, "weapons/lstart.wav", self.volume, ATTN_NORM);
		trap_lightning_fire();
	}
	else
	{
		sound (self, CHAN_VOICE, "misc/null.wav", 1, ATTN_NORM);	// stop zap noise
		self.nextthink = 0;
	}
}
	

/*QUAKED trap_lightning (0 .5 .8) (-8 -8 -8) (8 8 8) BURST AT_ACTIVATOR
Continuously fires lightning in the direction set by "angle". Trigger to turn on, trigger again to turn off.

Spawnflags
BURST		Fire once when triggered rather than toggling
AT_ACTIVATOR	Ignore target and fire at whatever activated it if LOS is not broken

"delay" delay before firing if BURST
"movedir" override angle with a launch vector of your choosing (length sets distance)
"target" override angle by aiming at an entity (will also search target2/3/4)
"strength" choose type of beam:
	1 - thin beam, 100dps (burst 10), stops at first target, default
	2 - thicker beam, 300dps, burst 30
	3 - fat anti-Chthon beam, death to touch, can hurt Chthons and Shubs
*/
/*FGD
@PointClass base(Appearflags, Target, Targetname, Angle) color(220 150 150) = trap_lightning : "Lightning shooter (Toggled)" [
	spawnflags(Flags) = 
	[
		1 : "One-shot" : 0
		2 : "Aim At Activator" : 0
	]
	movedir(string) : "Override aim vector (x y z)"
	delay(string) : "Pause before firing, if burst" : "0"
	strength(choices) : "Beam Size" = 
	[
		1 : "Small, 10dmg"
		2 : "Medium, 30dmg"
		3 : "Large, instagib"
	]

]
*/
void() trap_lightning =
{
	if (!SUB_ShouldSpawn()) return;

	SetMovedir();
	if (vlen(self.movedir) < 32)
	{
		self.movedir = normalize(self.movedir) * 768;
	}
	
	self.strength = min(3, max(1, self.strength));

	precache_sound ("weapons/lstart.wav");
	precache_sound ("misc/power.wav");
	precache_sound ("weapons/lhit.wav");
	
	self.volume = zeroconvertdefault(self.volume, 1);
	
	self.state = 0;
	self.count = 0;
	self.use = trap_lightning_use;
	
	if (self.deathtype == string_null)
		self.deathtype = "was fried by a bolt of lightning";
}
