/*
==============================================================================

AI

Moving, animating, and decision making

==============================================================================
*/




/*
=============
eyeline
=============
*/
vector(entity targ) eyeline =
{
	vector spot1, spot2;
	spot1 = self.origin + self.view_ofs;
	spot2 = targ.origin + targ.view_ofs;
	
	return (spot2 - spot1);
}

/*
=============
range

returns the range categorization of an entity relative to self
=============
*/
float(entity targ) range =
{
	vector d;
	float r;
	
	if (EntitiesTouching(self, targ))	// always melee someone standing on your head
		return RANGE_MELEE;
	
	d = eyeline(targ);
	//d_z *= 2;	// don't melee guys way above or below you
	r = vlen(d);
	if (r < 120)
		return RANGE_MELEE;
	if (r < 500)
		return RANGE_NEAR;
	if (r < 900)
		return RANGE_MID;
	if (r < 1250)
		return RANGE_FAR;
	return RANGE_TOOFAR;
}

/*
=============
visible

returns 1 if the entity is visible to self, even if not infront()

uses enemy's real position, NOT the potentially ring-of-shadows-offset BS position!
=============
*/
float (entity targ) visible =
{
	local vector	spot1, spot2;
	
	spot1 = self.origin + self.view_ofs;
	spot2 = targ.origin + targ.view_ofs;
	traceline2(spot1, spot2, self, TRACE_NOMONSTERS|TRACE_WATER);	// see through other monsters
	
	if (trace_inopen && trace_inwater)
		return FALSE;			// sight line crossed contents

	if (trace_fraction == 1)
		return TRUE;
	return FALSE;
}


/*
=============
infront

returns 1 if the entity is in front (in sight) of self
=============
*/
float(entity targ) infront =
{
	vector vec;
	float dot;
	
	// spawns gain all-around vision after they've been awakened the first time so they
	// don't go to sleep facing a wall or corner and become inert
	if (self.classname == "monster_tarbaby" && (self.customflags & CFL_OMNIVISION))
		return TRUE;
	
	makevectors (self.angles);
	vec = normalize (targ.origin - self.origin);
	dot = vec * v_forward;
	
	if ( dot > 0.3)
	{
		return TRUE;
	}
	return FALSE;
}

/*
=============
z_overlaps

returns 1 if the entity's bounds on z overlap those of self
for checking if melee attacks are worthwhile
=============
*/
float(entity targ) z_overlap =
{
	return (self.absmin_z < targ.absmax_z && targ.absmin_z < self.absmax_z);
}

/*
=============
enemy_vispos

Run every monster's aiming routine against this func instead of self.enemy.origin, so they
can be confused by a ring of shadows and fire in wrong directions
=============
*/
vector() enemy_vispos =
{
	// dogs can still smell the player
	if (!has_invis(self.enemy) || self.classname == "monster_dog" )
		return self.enemy.origin;
	if ( time < self.dmgtime + 1 )	// shooting right at a monster gives you away for a moment
		return self.enemy.origin;
	
	vector dir, visOrg;
	float hadjust;
	dir = self.enemy.origin - self.origin;
	
	// pick random offset based on time, salted with monster's position for variety
	visOrg = SinCos(time * 121 - self.origin_x - self.origin_y) * (vlen(dir) * 0.8 - 64);// * 0.4 + 64);
	hadjust = normalize(dir) * normalize(visOrg);
	visOrg_z = dir_z * hadjust * 0.5;
	
	visOrg += self.enemy.origin;
	
	return visOrg;
}

/*
===========
alive

Verify if entity can still be attacked
Returns FALSE if e should be permanently forgotten
============
*/
float(entity e) alive =
{
	if (e.health <= 0) return FALSE;
	// also consider a downed zombie to be dead, instead of waving a chainsaw over its body forever
	if (e.customflags & (CFL_KNOCKEDDOWN)) return FALSE;
	// coop spectating is a deadflag without being out of health
	if (e.deadflag) return FALSE;
	return TRUE;
}
float() enemy_alive = {return alive(self.enemy);}

/*
=============
enemy_yaw
=============
*/
float() enemy_yaw =
{
	if (!self.enemy)
		return self.ideal_yaw;
	
	return vectoyaw(enemy_vispos() - self.origin);
}

/*
============
FacingIdeal
============
*/
float() FacingIdeal =
{
	return (angledif(self.angles_y,self.ideal_yaw) < 45);
}

/*
============
enemy_aim_vertical

raise aim point a bit when target is up high to try and clear ledges
============
*/
vector() enemy_aim_vertical =
{
	float up = self.enemy.maxs_z * 1.6;
	vector dir = normalize(self.enemy.origin - self.origin);
	
	up *= max(0, dir_z);
	return Vector(0,0,up);
}

/*
============
LeadTarget

returns a relative position to aim at to lead a shot at a moving target
(not a normalized firing vector, so monsters can modify the result further first)

source: where the projectile will originate from
misvel: speed of projectile
degree: amount to lead target, < 1 will still lag behind target a bit
============
*/
vector(vector source, float misvel, float degree) LeadTarget =
{
	local vector vel, lead_offset, evel;
	
	vel = enemy_vispos() - source;
	// don't lead if you can't see the target
	if (has_invis(self.enemy))
		return vel;
	
	evel = self.enemy.velocity;
	if( !(self.enemy.flags & FL_ONGROUND) && fabs(evel_z) < 275 )
		evel_z = 0;	// ignore if the player is jumping around
	
	lead_offset = (vlen(vel) / misvel) * evel * degree;
	return vel + lead_offset;
}

vector(vector source, float misvel) LeadTargetBySkill =
{
	// in normal combat, leading above ~50% makes for worse accuracy, not better, because 
	// the player is always changing speed and direction
	return LeadTarget(source, misvel, min(0.5, skill * 0.25)); 
}



/*
==============================================================================

ATTACK CHECKS

==============================================================================
*/

/*
=============
enemy_priority

for switching targets with a semblance of intelligence in coop
a monster will switch to another player if that player is
	- closer to the monster than its enemy
	- more in front of it than its enemy
	- more visible than its enemy
	
higher return value = higher priority
=============
*/
float(entity targ) enemy_priority =
{
	vector vec;
	float r, d, p;
	r = RANGE_TOOFAR - range(targ); // melee = 4, near = 3 ...
	
	makevectors (self.angles);
	vec = targ.origin - self.origin;
	vec_z *= 2;
	vec = normalize(vec);
	d = (vec * v_forward + 2) / 2;	// 0.5=behind, 1.5=dead ahead

	p = r * d;
	if (!visible(targ))
		p *= 0.5;	// no LOS
	if (has_invis(targ))
		p *= 0.25;	// under the radar
	if (has_quad(targ))
		p *= 4;		// way over the radar
	/*	
	bprint(targ.netname);
	bprint2(": r ", ftos(r));
	bprint2(" d ", ftos(d));
	bprint3(" -> p ", ftos(p), "\n");
	*/
	
	return p;
}


/*
===========
ReprioritizeEnemy

in coop, monsters always immediately switched targets when harmed, so players 
could easily nullify threats by juggling aggro.

I've abandoned the infight-based aggro-pulling model, rather than overloading the 
definition of "when harmed" with more logic. now, if a monster is angry at any one
player, it treats all players in view as potential targets, attacking whichever
player is most convenient at the moment.

.search_time: a monster will not switch to another player in coop until after
	this time - set when angered by a player and after switching targets
============
*/
float() ReprioritizeEnemy =
{
	if (self.enemy.classname != "player") return FALSE;
	
	entity pl, best;
	float priority, bestp;
	bestp = -1;
	best = world;
	
	pl = nextent(world);
	while (pl.flags & FL_CLIENT)
	{
		if (FilterTarget(pl))
		{
			priority = enemy_priority(pl);
			if (priority > bestp)
			{
				bestp = priority;
				best = pl;
			}
		}
		pl = nextent(pl);
	}
	
	if (best && best != self.enemy)
	{
		self.oldenemy = self.enemy;
		self.enemy = best;
		self.goalentity = best;
		self.search_time = time + 1;
		
		sight_entity = self;
		sight_entity_time = time;
		self.show_hostile = time + 1;
		
		// don't switch targets the instant before firing or lightning comes out of your ass
		ai_attack_finished(1);
		
		return TRUE;
	}
	return FALSE;
}

/*
===========
CheckClearAttack

Ensure the line of fire to the enemy isn't blocked by another creature
============
*/
float() CheckClearAttack =
{
	vector spot1, spot2;
	
	if (self.enemy.customflags & (CFL_PLUNGE|CFL_LIMBO) || self.enemy.deadflag == DEAD_SPECTATING)
		return FALSE;
		
	if (has_invis(self.enemy))
		return TRUE;
	
	spot1 = self.origin + self.view_ofs;
	spot2 = enemy_vispos() + self.enemy.view_ofs;
	traceline2(spot1, spot2, self, TRACE_WATER);

	if (trace_inopen && trace_inwater)
		return FALSE;	// sight line crossed contents

	if (trace_ent != self.enemy)
	{
		if (trace_ent.classname == "player")
			return TRUE;	// go ahead and hit a player
		
		return FALSE;	// don't have a clear shot
	}
	
	return TRUE;
}

/*
===========
ai_attack_finished

lunaran: nightmare is no longer made harder by all monsters always firing. they looked 
really stupid when they'd automatically become turrets, and it made combat much less 
mobile and dynamic (shamblers were particularly 'cheesable')

monster attack frequency is no longer used as a means to artificially inflate or
scale difficulty. a theoretical player who begins learning Quake on Easy would gain
skills and reflexive instincts which can be guaranteed to carry over to higher skills
as that player improves to higher challenges.
============
*/
void(float t) ai_attack_finished =
{
	self.attack_finished = time + t;
}

/*
===========
ai_check_refire

these monsters DO fire more than once on nightmare, but not infinitely over and
over - making it random makes it uncertain and thus not cheesable
============
*/
void (void() th, float minf) ai_check_refire_min =
{
	if (!alive(self.enemy))
		return;
	if (!CheckClearAttack())
		return;
	
	if (self.cnt < minf)
	{
		self.cnt += 1;
		self.think = th;
		return;
	}
	
	// no further refire unless nightmare
	if (skill < 3)
	{
		self.cnt = 0;
		return;
	}
	
	// diminish chances of refire with each extra shot
	self.cnt = max(1, (self.cnt-minf) * 2);
	if ( random() * self.cnt > 0.5 )
	{
		self.cnt = 0;
		return;
	}
	self.cnt += minf;
	self.think = th;
}

void (void() th) ai_check_refire =
{
	ai_check_refire_min(th, 0);
}


/*
===========
CheckAttack

The player is in view, so decide to move or launch an attack
Returns FALSE if movement should continue
============
*/
float() CheckAttack =
{
	local float		chance;

	if (!CheckClearAttack()) return FALSE;

	// always melee immediately when close enough
	if ((enemy_range == RANGE_MELEE  && z_overlap(self.enemy)) || 
		(has_invis(self.enemy) && random() < 0.1) )	// wave arms randomly now and then if target is invisible
	{
		if (self.th_melee)
		{
			self.attack_state = AS_MELEE;
			return TRUE;
		}
	}
	
	if (!self.th_missile) return FALSE;
	if (enemy_range >= RANGE_FAR) return FALSE;
	
	if (enemy_range == RANGE_MELEE)
	{
		chance = 0.9;
		self.attack_finished = 0;
	}
	if (time < self.attack_finished) return FALSE;	// after melee check
	if (enemy_range == RANGE_NEAR)
	{
		if (self.th_melee)
			chance = 0.2;
		else
			chance = 0.4;
	}
	else if (enemy_range == RANGE_MID)
	{
		if (self.th_melee)
			chance = 0.05;
		else
			chance = 0.1;
	}
	else if (enemy_range >= RANGE_FAR)
		chance = 0;

	if (random() < chance)
	{
		self.attack_state = AS_MISSILE;
		ai_attack_finished (2*random());
		return TRUE;
	}

	return FALSE;
}


/*
==============================================================================

WAKING UP

==============================================================================
*/
void() HuntTarget =
{
	self.goalentity = self.enemy;
	self.ideal_yaw = enemy_yaw();
	self.think = self.th_run;
	self.nextthink = time + 0.1;
	ai_attack_finished (1);	// wait a while before first attack
}

void() SightSound =
{
	if (self.classname == "monster_ogre" )	
		sound (self, CHAN_VOICE, "ogre/ogwake.wav", 1, ATTN_NORM);
	else if (self.classname == "monster_knight" || self.classname == "monster_axegrunt")
		sound (self, CHAN_VOICE, "knight/ksight.wav", 1, ATTN_NORM);
	else if (self.classname == "monster_shambler")
		sound (self, CHAN_VOICE, "shambler/ssight.wav", 1, ATTN_NORM);
	else if (self.classname == "monster_demon1")
		sound (self, CHAN_VOICE, "demon/sight2.wav", 1, ATTN_NORM);
	else if (self.classname == "monster_wizard")
		sound (self, CHAN_VOICE, "wizard/wsight.wav", 1, ATTN_NORM);
	else if (self.classname == "monster_zombie")
		sound (self, CHAN_VOICE, "zombie/z_idle.wav", 1, ATTN_NORM);
	else if (self.classname == "monster_dog")
		sound (self, CHAN_VOICE, "dog/dsight.wav", 1, ATTN_NORM);
	else if (self.classname == "monster_hell_knight" )
		sound (self, CHAN_VOICE, "hknight/sight1.wav", 1, ATTN_NORM);
	else if (self.classname == "monster_tarbaby")
		sound (self, CHAN_VOICE, "blob/sight1.wav", 1, ATTN_NORM);
	else if (self.classname == "monster_enforcer")
	{
		local float	rsnd;
		rsnd = random();
		if (rsnd < 0.25)
			sound (self, CHAN_VOICE, "enforcer/sight1.wav", 1, ATTN_NORM);
		else if (rsnd < 0.5)
			sound (self, CHAN_VOICE, "enforcer/sight2.wav", 1, ATTN_NORM);
		else if (rsnd < 0.75)
			sound (self, CHAN_VOICE, "enforcer/sight3.wav", 1, ATTN_NORM);
		else
			sound (self, CHAN_VOICE, "enforcer/sight4.wav", 1, ATTN_NORM);
	}
	else if (self.classname == "monster_army")
		sound (self, CHAN_VOICE, "soldier/sight1.wav", 1, ATTN_NORM);
	else if (self.classname == "monster_shalrath")
		sound (self, CHAN_VOICE, "shalrath/sight.wav", 1, ATTN_NORM);
}

void() FoundTarget =
{
	while(!alive(self.enemy))
	{
		if (self.oldenemy)
		{
			self.enemy = self.oldenemy;
			self.oldenemy = world;
		}
		else
		{
			self.enemy = world;
			self.th_stand();
			return;
		}
	}
	
	if (self.enemy.classname == "player")
	{	// let other monsters see this monster for a while
		sight_entity = self;
		sight_entity_time = time;
	}
	
	self.show_hostile = time + 1;	// wake up other monsters
	self.dmgtime = time + 1;		// aggro timer
	self.search_time = time + 3;	// aggro timer
	
	SightSound ();
	
	// for awakening with velocity
	if (self.movetype == MOVETYPE_STEP && self.movedir != '0 0 0')
	{
		self.velocity = self.movedir;
		self.flags = not(self.flags, FL_ONGROUND);
		self.movedir = '0 0 0';	// don't leap again if an infight starts
	}
	
	HuntTarget ();
}

float(entity client) FilterTarget =
{
	if (client.flags & FL_NOTARGET || client.movetype == MOVETYPE_NOCLIP)
		return FALSE;
	if (client.health <= 0 || client.deadflag)
		return FALSE;
	if (client.customflags & (CFL_PLUNGE|CFL_LIMBO))
		return FALSE;
	if (range(client) == RANGE_TOOFAR)
		return FALSE;
		
	return TRUE;
}

/*
===========
FindTarget

Self is currently not attacking anything, so try to find a target

Returns TRUE if an enemy was sighted

When a player fires a missile, the point of impact becomes a fakeplayer so
that monsters that see the impact will respond as if they had seen the
player.
============
*/
float() FindTarget =
{
	local entity	client;
	local float		r;

	//dprint("in findtarget\n");
	// (spawnflags & 3) unhacked by lunaran since I actually want to use spawnflag 2 for something
	// apparently all the mega-enforcers in lunsp1 were ambush because of this ... oops
	if ( sight_entity_time >= time - 0.1 && ( !(self.spawnflags & SPAWN_AMBUSH ) ) )
	{
		client = sight_entity;
		if (client.enemy == self.enemy)
			return FALSE;
	}
	else
	{
		// to avoid spending too much time, only check a single client (or fakeclient)
		// this means multiplayer games have slightly slower noticing monsters
		client = checkclient();
		if (!client)
			return FALSE;	// no check entities in PVS
	}

	if (client == self.enemy)
		return FALSE;
		
	if (!FilterTarget(client))
		return FALSE;		
	if (client.classname != "player" && !FilterTarget(client.enemy))
		return FALSE;	// don't wake up other monsters in notarget mode
	
	if (!visible (client))
		return FALSE;

	r = range(client);
	
	if (r == RANGE_NEAR)
	{
		if (client.show_hostile < time && !infront(client))
			return FALSE;
	}
	else if (r == RANGE_MID || r == RANGE_FAR)
	{
		if ( !infront(client) )
			return FALSE;
	}
	
	// the only two things that alert monsters when invisible besides damage:
	// - firing a weapon
	// - bumping into a dog
	if (has_invis(client))
	{
		if (self.classname == "monster_dog" && client.classname == "player")
		{
			if (r != RANGE_MELEE)
				return FALSE;
		} 
		else if (client.show_hostile < time)
		{
			return FALSE;
		}
	}

	// got one
	self.enemy = client;
	if (self.enemy.classname != "player")
	{
		self.enemy = self.enemy.enemy;	// angered by a monster angering, use its enemy
		if (self.enemy.classname != "player")
		{
			self.enemy = world;
			return FALSE;
		}
	}
	
	FoundTarget();

	return TRUE;
}


void(entity m) ai_freeze_monster =
{
	if (m == world)
		error("tried to freeze the world");
	if (m.nextthink > time + 0.11 || m.nextthink < time)
		return;	// don't mess with what isn't active anyway
	
	m.nextthink = time + A_SHITLOAD;
	m.button0 = m.movetype;
	m.button1 = m.solid;
	m.button2 = m.takedamage;
	m.oldorigin = m.velocity;
	
	m.movetype = MOVETYPE_NONE;
	m.solid = SOLID_NOT;
	m.takedamage = DAMAGE_NO;
	m.velocity = VEC_ORIGIN;
}



void(entity m) ai_unfreeze_monster =
{
	if (m == world)
		error("tried to unfreeze the world");
	if (!m.button0 && !m.button1 && !m.button2)
		return;	// never frozen
	
	m.nextthink = time + random() * 0.1 + 0.01;
	m.movetype = m.button0;
	m.solid = m.button1;
	m.takedamage = m.button2;
	m.velocity = m.oldorigin;

	m.button0 = m.button1 = m.button2 = 0;
}


/*
==============================================================================
PATH PATROL CODE

The angle of the pathcorner effects standing and bowing direction, but has 
no effect on movement, which always heads to the next target.
==============================================================================
*/

void() path_corner_touch =
{
	if (other.goalentity != self) return;
	if (other.enemy) return;		// fighting, not following a path
	//bprint("valid pathcorner touch\n");
	
	if (self.target != string_null)
	{
		other.goalentity = findunlocked(world, targetname, self.target);
	}
	else
	{
		other.goalentity = world;
	}
	if (!other.goalentity)
	{
		//bprint("dude stopped without a goalentity\n");
		other.pausetime = time + A_SHITLOAD;
		other.think = other.th_stand;
	//	other.th_stand ();
		if (self.angles_y)
			other.ideal_yaw = self.angles_y;
		return;
	}

	if (other.classname == "monster_ogre")
		sound (other, CHAN_VOICE, "ogre/ogdrag.wav", 1, ATTN_IDLE);// play chainsaw drag sound

	if (self.wait)
	{
		other.pausetime = time + self.wait;
		other.think = other.th_stand;
	//	other.th_stand ();
		if (self.angles_y)
			other.ideal_yaw = self.angles_y;
		return;
	}
	other.ideal_yaw = vectoyaw(other.goalentity.origin - other.origin);
}

/*QUAKED path_corner (0.5 0.3 0) (-8 -8 -8) (8 8 8) - - - - BEZIER
Waypoint for platforms and monsters. Will stop here for good if no path_corner is targeted by this entity.
Monsters who wait here will turn to face 'angle'.

Keys:
"targetname" must be present.  The name of this pathcorner.
"target" the next spot to move to.  If not present, stop here for good.
"wait" The number of seconds to spend standing here
"angle" direction to face while standing here
"speed" tell a visiting func_train to change its speed. If a path_corner's speed is -1, the func_train's move when LEAVING that corner will be to snap instantly to the next corner.

Spawnflags:
BEZIER	Act as a bilinear control point between the previous and next pathcorner in the chain (train only, no monster patrols)
	"count"	change number of steps of interpolation along the curve the train will make (default 10)
*/
/*FGD
@PointClass base(Appearflags, Targetname, Target, Angle) size(16 16 16) color(128 80 0) = 
	path_corner : 
"Waypoint for platforms and monsters. Will stop here for good if no path_corner is targeted by this entity.
Monsters who wait here will turn to face 'angle'.
Checking the Bezier spawnflag will make this pathcorner act as a bilinear control point - meaning curved motion - between the previous and next pathcorner in the chain (train only, no monster patrols).
	"count"	change number of steps of interpolation along the curve the train will make (default 10)"
[
	spawnflags(Flags) = [
		16 : "Bezier point" : 0
	]
	wait(string) : "Wait time (seconds)" : "0"
	speed(string) : "A visiting func_train to change its speed to this. If 'speed' is -1, the func_train's move when LEAVING that corner will be to snap instantly to the next corner." : "0"
	count(integer) : "steps of interpolation along this bezier curve segment" : 10
]
*/
void() path_corner =
{
	if (!SUB_ShouldSpawn()) return;
	
	if (self.targetname == string_null)
	{
		dprint3("path_corner with no targetname at ", vtos(self.origin), "\n");
		remove(self);
		return;
	}
	
	if (!self.wait)
	{
		if (self.pausetime)
			self.wait = self.pausetime;
		//else if (!self.target)
		//	self.wait = -1;
	}
	
	if ((self.spawnflags & 16) && self.count <= 0)
		self.count = 10;
	
	self.solid = SOLID_TRIGGER;
	self.touch = path_corner_touch;
	setsize (self, '-8 -8 -8', '8 8 8');
}


/*
=============
victim_path_expand

keep expanding the victim-approach trigger so monsters don't keep 
trying to approach a dead victim if it's getting crowded
=============
*/
void() victim_path_expand =
{
	self.cnt += 1;
	if (self.cnt > 4) 
	{
		// try to catch anyone left and then stop being such a bigass trigger
		setsize(self, self.mins - '512 512 0', self.maxs + '512 512 0');
		self.think = SUB_Remove;
		self.nextthink = time + 0.2;
		force_retouch = 2;
		return;
	}
	setsize(self, self.mins - '64 64 0' * self.cnt, self.maxs + '64 64 0' * self.cnt);
	self.nextthink = time + 2 * (5-self.cnt);
}

/*
=============
ai_approach_victim

monsters walk towards a vanquished player and stop when close enough to admire their handiwork
=============
*/
void(entity vic) ai_approach_victim =
{
	entity targ;
	// bind the trigger to the dead player and reuse it so we don't make a 
	// bazillion of them when the player dies to a bazillion monsters
	if (vic.enemy && vic.enemy.classname == "victim_path")
	{
		targ = vic.enemy;
	}
	else
	{
		targ = spawn();
		targ.classname = "victim_path";
		targ.solid = SOLID_TRIGGER;
		setorigin(targ, self.goalentity.origin);
		setsize (targ, '-64 -64 -512', '64 64 1024');
		//targ.angles = self.angles;
		targ.touch = path_corner_touch;
		targ.think = victim_path_expand;
		targ.nextthink = time + 5;
		targ.lifetime_finished = time + 10;
		vic.enemy = targ;
	}
	self.goalentity = targ;
	self.th_walk ();
}

/*
=============
ai_check_liquid

take damage from slime and lava. returns FALSE if monster died from it.
=============
*/
float() ai_check_liquid =
{
	// there are hacked takedamage cthons out there, and they're all in the lava
	if (self.type == "boss" || self.classname == "monster_rotfish")
		return TRUE;
		
	vector wtt;
	wtt = WaterTest();
	float wl, wt;
	wl = wtt_x;
	wt = wtt_y;
	
	// never do liquid damage for some mild wading, since lots of ep3 has lava
	// the monsters can step into and out of
	if (wl < 3)
		return TRUE;
	
	// monsters that spawn in slime/lava were clearly intended to be there by the
	// mapper, so give them special dispensation to not quietly die before the 
	// player ever finds them. also, revoke their liquid rights once they leave, so 
	// they just die instead of staying lost if they fall back in
	if (!wl)
	{
		self.customflags = not(self.customflags, CFL_LIQUID_IMMUNE);
		return TRUE;
	}
	if (self.customflags & CFL_LIQUID_IMMUNE)
		return TRUE;
		
	if (self.type == "zombie")
	{
		// zombies immune to slime (or else they just keep falling and getting up)
		if (wt == CONTENT_LAVA)	// but always gib if touching lava
			T_Damage(self, world, world, self.health + 10);
	}
	else
	{
		if (wt == CONTENT_LAVA)
			T_Damage(self, world, world, wl * 10);
		if (wt == CONTENT_SLIME && self.classname != "monster_wizard")
			// scrags will happily fly down into slime, and they do spit green shit anyway
			T_Damage(self, world, world, wl * 5);
	}
	
	return self.health > 0;
}

/*
==============================================================================

ANIMATION

==============================================================================
*/


/*
=============
ai_face

Stay facing the enemy
=============
*/
void() ai_face =
{
	if (self.flags & (FL_FLY|FL_SWIM))
		self.velocity = '0 0 0';
	
	self.ideal_yaw = enemy_yaw();
	ChangeYaw ();
}


/*
=============
ai_floatmove

wrap movement code in this hot bullshit for making scrags do sick drifts
=============
*/
void() ai_floatmove_start =
{
	if (self.flags & (FL_FLY|FL_SWIM) == 0)
		return;
	
	self.velocity = '0 0 0';
	self.movetype = MOVETYPE_STEP;
	self.oldorigin = self.origin;
	self.flags = not(self.flags, FL_ONGROUND);
}

float(vector mask) ai_floatmove_ceiltrace =
{
	vector start, end;
	start = self.origin + vec_scale(self.maxs, mask);
	end = self.origin + vec_scale(VEC_HULL_MAX, mask);
	
	traceline(start, end, FALSE, self);
	if (trace_fraction < 1.0 || trace_startsolid || trace_allsolid)
		return FALSE;
	return TRUE;
}

float() ai_floatmove_ceilcheck =
{
	if (!ai_floatmove_ceiltrace('0 0 1')) return FALSE;
	if (!ai_floatmove_ceiltrace('1 1 1')) return FALSE;
	if (!ai_floatmove_ceiltrace('-1 1 1')) return FALSE;
	if (!ai_floatmove_ceiltrace('1 -1 1')) return FALSE;
	if (!ai_floatmove_ceiltrace('-1 -1 1')) return FALSE;
	return TRUE;
}

float() ai_fishmovecheck =
{
	float opc;
	opc = pointcontents(self.oldorigin);
	if ( pointcontents(self.origin) != opc || 
		pointcontents(self.origin + '0 0 16') != opc ||
		!ai_floatmove_ceilcheck())	// goddamn fish noclipping through ceilings
		return FALSE;
	return TRUE;
}

void(float dist) ai_floatmove_finish =
{
	vector move;
	float interv, spd, frac;
	
	if (self.flags & (FL_FLY|FL_SWIM) == 0)
		return;
		
	self.movetype = MOVETYPE_FLY;
	move = self.origin - self.oldorigin;
	
	// fish have short bounding boxes, which in quake physics land means they can noclip through ceilings
	if (pointcontents(self.origin) == CONTENT_SOLID)
	{
		setorigin(self, self.oldorigin);
		//dprint("detected move into solid\n");
		self.velocity = '0 0 0';
		return;
	}

	if (vlen(move) > dist + 16)
	{
		// probably touched a teleporter, so don't try to velocity interp
		self.velocity = '0 0 0';
		return;
	}
	
	interv = max(0.01, self.nextthink - time);
	
	// flying/swimming monsters don't raise/lower for regular path walking normally, so
	// fudge the z velocity manually
	if (self.goalentity.classname == "path_corner")
	{
		if (fabs(self.goalentity.origin_z - self.origin_z) > 16)
		{
			spd = vlen(move);
			frac = spd / vlen(self.goalentity.origin - self.origin);
			move_z = frac * (self.goalentity.origin_z - self.origin_z);
		}
	}
	// FL_SWIM just invalidates any movement out of water, so simulate velocity 
	// being clipped off at the surface instead
	// TODO: support water volumes that end in other directions than up
	if (self.flags & FL_SWIM)
	{
		if (!ai_fishmovecheck())
			move_z = -1;
	}
	setorigin(self, self.oldorigin);
	self.velocity = move / interv;
}

/*
=============
movetogoalplus/walkmoveplus
=============
*/
void(float dist) movetogoalplus =
{
	ai_floatmove_start();
	movetogoal(dist);
	ai_floatmove_finish(dist);
}

float(float yaw, float dist) walkmoveplus =
{
	float result;
	vector oldorg;
	ai_floatmove_start();
	oldorg = self.origin;
	result = walkmove(yaw, dist);
	if (oldorg == self.origin || !result)
	{
		ai_floatmove_finish(0);
		return FALSE;
	}
	ai_floatmove_finish(dist);
	return TRUE;
}

/*
=============
walkmove_jitter

try walkmoves on either side of ideal_yaw in case we're blocked by something glancing
=============
*/
float(float yaw, float dist) walkmove_jitter =
{
	float yd;
	if (walkmoveplus(yaw, dist)) return TRUE;
	
	if (random() < 0.5) yd = -15;
	else yd = 15;
	
	if (walkmoveplus(yaw + yd, dist)) return TRUE;
	if (walkmoveplus(yaw - yd, dist)) return TRUE;
	return FALSE;
}

/*
=============
ai_rush

The monster is in a charging melee attack, always turning to face the player
rather than navigating around obstacles. this sometimes leads to getting hung
up and stuck on anything in the way, so add a safety check for our origin not
changing. 

we don't do this in normal ai_charge or wonky things happen with the charges 
as part of normal melee-range attacks involving forward steps
=============
*/
void(float d) ai_rush =
{
	if (!ai_check_liquid()) return;
	ai_face();
	
	if ( !walkmove_jitter(self.ideal_yaw, d) )
	{
		if ( !walkmove_jitter(self.ideal_yaw, d * 0.5) )
		{
			if (!walkmove_jitter(self.ideal_yaw, 1))
			{
				if (self.oldorigin == self.origin && d > 0)
				{
					// haven't moved in 3 frames, verify charge
					if (range(self.enemy) != RANGE_MELEE || !visible(self.enemy))
					{
						// we aren't in the enemy's face, probably hung up on something
						//bprint("canceling charge\n");
						self.think = self.th_run;
						ai_attack_finished(0.4);	// take a half second to get around the obstacle
						return;
					}
					// it's important to use RANGE_MELEE as the test or else monsters will rapidly
					// oscillate in and out of melee when fights get crowded and they can't move
				}
			}
		}
	}
	
	self.oldorigin = self.origin;
}

/*
=============
ai_charge

The monster is in a melee attack, so get as close as possible to .enemy
=============
*/
float(float d) ai_charge =
{
	if (!ai_check_liquid()) return FALSE;
	
	ai_face();
	
	// try to get closer
	// don't movetogoal in ai_charge or the yaw will spaz as the monster tries to 'pathfind' in c
	if ( !walkmove_jitter(self.ideal_yaw, d) )
	{
		if ( !walkmove_jitter(self.ideal_yaw, d * 0.5) )
		{
			if (walkmove_jitter(self.ideal_yaw, 1))
			{
				return TRUE;
			}
		}
		else
		{
			return TRUE;
		}
	}
	else
	{
		return TRUE;
	}
	return FALSE;
}

void() ai_charge_side =
{
	local	vector	dtemp;
	local	float	heading;
	
	if (!ai_check_liquid()) return;
	
// aim to the left of the enemy for a flyby

	self.ideal_yaw = enemy_yaw();
	ChangeYaw ();
	

	makevectors (self.angles);
	dtemp = self.enemy.origin - 30*v_right;
	heading = vectoyaw(dtemp - self.origin);
	
	walkmove_jitter(heading, 20);
}


/*
=============
ai_melee
=============
*/
void() ai_melee =
{
	local vector	delta;
	local float 	ldmg;

	if (!self.enemy)
		return;		// removed before stroke
		
	delta = self.enemy.origin - self.origin;

	if (vlensqr(delta) > 60*60)
		return;
		
	if (self.enemy.type == "zombie")
		ldmg = 15;	// trigger zombie pain so ai_melee'ing monsters don't just slash away endlessly
	else
		ldmg = 3 + random() * 2; //(random() + random() + random()) * 3;
		
	T_DamageMelee (self.enemy, self, ldmg);
}


void() ai_melee_side =
{
	local vector	delta;
	local float 	ldmg;

	if (!self.enemy)
		return;		// removed before stroke
		
	ai_charge_side();
	
	delta = self.enemy.origin - self.origin;

	if (vlensqr(delta) > 60*60)
		return;
	if (!CanDamage (self.enemy, self.origin))
		return;
	ldmg = (random() + random() + random()) * 3;
	T_DamageMelee (self.enemy, self, ldmg);
}

//============================================================================

/*
=============
ai_forward/ai_back

move without invoking any decisionmaking
=============
*/
void(float dist) ai_forward =
{
	walkmove_jitter (self.angles_y, dist);
}

void(float dist) ai_back =
{
	walkmove_jitter ( (self.angles_y+180), dist);
}


/*
=============
ai_pain

stagger back a bit
=============
*/
void(float dist) ai_pain =
{
	ai_back (dist);
}

/*
=============
ai_painforward

stagger back a bit, but forward
=============
*/
void(float dist) ai_painforward =
{
	//walkmove (self.ideal_yaw, dist);
	ai_forward (dist);
}

/*
=============
ai_walk

The monster is walking its beat
=============
*/
void(float dist) ai_walk =
{
	//movedist = dist;
	if (!ai_check_liquid()) return;

	// check for noticing a player
	if (FindTarget ())
		return;
		
	movetogoalplus(dist);	// wraps movetogoal
}


/*
=============
ai_stand

The monster is staying in one place for a while
=============
*/
void() ai_stand =
{
	if (!ai_check_liquid()) return;
	
	if (self.flags & (FL_FLY|FL_SWIM))
		self.velocity = '0 0 0';
	
	if (FindTarget ())
		return;
	
	if (time > self.pausetime && self.goalentity)
	{
		self.th_walk ();
		return;
	}
	
	ChangeYaw();
}

/*
=============
ai_turn

don't move, but turn towards ideal_yaw
=============
*/
void() ai_turn =
{
	
	if (FindTarget ())
		return;
	
	ChangeYaw ();
}


//============================================================================

/*
=============
ai_run_melee

Turn and close until within an angle to launch a melee attack
=============
*/
void() ai_run_melee =
{
	self.ideal_yaw = enemy_yaw();
	ChangeYaw ();

	if (FacingIdeal())
	{
		self.th_melee ();
		self.attack_state = AS_STRAIGHT;
	}
}


/*
=============
ai_run_missile

Turn in place until within an angle to launch a missile attack
=============
*/
void() ai_run_missile =
{
	self.ideal_yaw = enemy_yaw();
	ChangeYaw ();
	if (FacingIdeal())
	{
		self.th_missile ();
		self.attack_state = AS_STRAIGHT;
	}
}


/*
=============
ai_run_slide

Strafe sideways, but stay at approximately the same range
FIXME: check CONTENT_SOLID and reverse movement if any corners go out of the map
to fix scrags strafing into walls
is it strafing only or does flying ai_forward do it too?
=============
*/
void(float dist) ai_run_slide =
{
	local float	ofs;
	
	self.ideal_yaw = enemy_yaw();
	ChangeYaw ();
	if (self.customflags & CFL_LEFTY)
		ofs = 90;
	else
		ofs = -90;
	
	if (walkmoveplus (self.ideal_yaw + ofs, dist))
		return;
	
	self.customflags = xor(self.customflags, CFL_LEFTY);
	//self.lefty = 1 - self.lefty;
	
	walkmoveplus (self.ideal_yaw - ofs, dist);
}


/*
=============
ai_run

The monster has an enemy it is trying to kill
=============
*/
void(float dist) ai_run =
{
	if (!ai_check_liquid()) return;	// died in slime/lava already
	
	entity e;
	
	// if infighting and we haven't damaged our enemy in a while, give up
	if (self.enemy.classname != "player" && self.oldenemy.classname == "player")
	{
		self.frags += 1;
		// 15 seconds for monsters with ranged attacks, 10 for melee monsters
		if (((self.customflags & CFL_MELEEONLY) && self.frags > 100) || self.frags > 150)
		{
			self.frags = 0;
			self.enemy = self.oldenemy;
			FoundTarget();
		}
	}
	
	// see if the enemy is dead
	if (!alive(self.enemy))
	{
		e = self.enemy;
		self.enemy = world;
		self.frags = 0;

		if (self.oldenemy.health > 0)
		{
			self.enemy = self.oldenemy;			
			HuntTarget();
		}
		else
		{
			if (e.classname == "player")
			{
				if (!coop || !(ReprioritizeEnemy()))
				// go mill around the dead enemy
				ai_approach_victim(e);
			}
			else
			{
				self.goalentity = world;
				self.th_stand ();
			}
			return;
		}
	}

	// this never did anything if not sight_entity
	//self.show_hostile = time + 1;		// wake up other monsters

	// check knowledge of enemy
	enemy_vis = visible(self.enemy);
	enemy_range = range(self.enemy);

	// look for other coop players
	if (coop && self.search_time < time)
	{
		ReprioritizeEnemy();
		//if (ReprioritizeEnemy ())
		//	return;
	}
	
	if (enemy_vis && !(self.enemy.customflags & (CFL_PLUNGE|CFL_LIMBO)))
	{
		if (enemy_range == RANGE_MELEE)
			self.attack_finished = 0;
	
		if (self.th_checkattack())
		{
			if (self.attack_state == AS_MISSILE)
				ai_run_missile ();	
			else if (self.attack_state == AS_MELEE)
				ai_run_melee ();
			else if (self.attack_state == AS_SLIDING)
				ai_run_slide (dist);
			return;
		}
	}
	
	if (self.attack_state == AS_SLIDING)
	{
		ai_run_slide (dist);
		return;
	}
	
	// head straight in
	movetogoalplus(dist);	// wraps movetogoal()
}

/*
=============
ai_nop
=============
*/
void() ai_nop =
{
	if (self.flags & (FL_FLY | FL_SWIM))
		self.velocity = '0 0 0';
}
