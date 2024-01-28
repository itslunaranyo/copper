/*
==============================================================================

COMBAT

==============================================================================
*/

void() killed_monster =
{
	killed_monsters = killed_monsters + 1;
	WriteByte (MSG_ALL, SVC_KILLEDMONSTER);
}

/*
============
Killed
============
*/
void(entity targ, entity attacker, float dmgtype) Killed =
{
	local entity oself;

	activator = attacker;	// catches a lot of misc cases like a shootable door firing a trigger_secret
	
	oself = self;
	self = targ;
	
	if (self.health < -99)
		self.health = -99;		// don't let sbar look bad

	if (self.movetype == MOVETYPE_PUSH || // doors, triggers, etc
		(self.movetype == MOVETYPE_NONE && self.classname != "player" && !(self.flags & FL_MONSTER))) 
		// players are movetype none while hanging out in a void pit waiting to die
		// and monsters may be movetype_none (shootable chthons)
	{
		//self.enemy = attacker;	// why did you do this lunaran
		self.th_die ();
		self = oself;
		return;
	}

	// ai_nav
	// clear floaty bullshit on scrags and fish
	ai_floatmove_start();
	
	self.enemy = attacker;
	self.deadflag = DEAD_DYING;
	self.takedamage = DAMAGE_NO;
	self.touch = SUB_Null;

	if (coop && attacker.classname == "player")
	{
		if (self.classname == "player")
			attacker.frags -= 5;
		else
			attacker.frags += 1;
	}

	if (self.classname != "player" && self.customflags & CFL_PLUNGE)
	{
		setmodel(self, string_null);
		self.health = 0;
		self.think = SUB_Remove;
		self.nextthink = time + 1;
	}
	else
		self.th_die ();

	// call this after th_die in case the monster wants to do anything in die() first
	// nightmare zombies unflag themselves as MONSTER if they've been killed and res'd
	if (self.flags & FL_MONSTER)
	{
		// fall to ground
		if (self.flags & FL_FLY)
			self.flags = self.flags - FL_FLY;
		if (self.flags & FL_SWIM)
			self.flags = self.flags - FL_SWIM;

		killed_monster();	// bump the monster counter
		monster_death_use();
	}
	if (self.classname == "player")
		ClientObituary(dmgtype);
	
	self = oself;
}

void(float t) PainFinished =
{
	self.pain_finished = time + t;
}

/*
==============================================================================

MULTI-DAMAGE

Collects multiple small damages into a single damage. Creates a chain of 
entities and stores damage on each one, then applies it one by one and 
wipes the chain.

==============================================================================
*/

entity	multi_ent;

void() ClearMultiDamage =
{
	multi_ent = world;
}

void(float dmgtype = 0) ApplyMultiDamage =
{
	local entity head;
	if (!multi_ent)
		return;
	head = multi_ent;
	while (head) {
		//bprint(ftos(head.multi_dmg));
		//bprint("\n");
		T_Damage (head, self, self, head.multi_dmg, dmgtype);
		head.multi_dmg = 0;
		head = head.multidmg_chain;
	}
	multi_ent = world;
}

void(entity hit, float damage) AddMultiDamage =
{
	local entity head;
	
	if (!hit)
		return;

	if (!multi_ent)
	{
		// start the chain
		head = multi_ent = hit;
		head.multidmg_chain = world;
		head.multi_dmg = 0;	// in case of stale values
	}
	
	else if (hit != multi_ent)
	{
		// search the chain for the entity we hit
		head = multi_ent;
		while (head) {
			if (head == hit) break;
			head = head.multidmg_chain;
		}
		if (!head) {
			// put him at the beginning of the chain
			hit.multidmg_chain = multi_ent;
			multi_ent = hit;
			head = hit;
			head.multi_dmg = 0;	// in case of stale values
		}
	}
	else
		head = multi_ent;
	
	head.multi_dmg += damage;	
}


/*
============
CanDamage

Returns true if the inflictor can directly damage the target.  Used for
RadiusDamage and melee attacks.
============
*/
float(entity targ, vector srcorg) CanDamage =
{
	vector corner;
	float dist;
	
	// bmodels need special checking because their origin is 0,0,0
	if (targ.movetype == MOVETYPE_PUSH)
	{
		corner = BoundsCenter(targ);
		if (vlen(srcorg - corner) > 512)
			return FALSE;	// too far
		traceline2(srcorg, corner, self, TRACE_NOMONSTERS);
		if (trace_fraction == 1)
			return TRUE;
		if (trace_ent == targ)
			return TRUE;
		return FALSE;
	}
	
	dist = vlen(srcorg - targ.origin);
	if (dist > 512)
		return FALSE;	// too far
		
	// center
	traceline2(srcorg, targ.origin, self, TRACE_NOMONSTERS);
	if (trace_fraction == 1)
		return TRUE;
	
	if (dist > 256)
		return FALSE;	// skip extra traces beyond sensible explosion sizes 

	// lunaran: adapted from maddes fix
	
	// do top first, as it's most likely to return a positive
	corner = Vector(0,0,targ.maxs_z);
	traceline2(srcorg, targ.origin + corner, self, TRACE_NOMONSTERS);
	if (trace_fraction == 1)
		return TRUE;
	
	// bottom
	corner = Vector(0,0,targ.mins_z);
	traceline2(srcorg, targ.origin + corner, self, TRACE_NOMONSTERS);
	if (trace_fraction == 1)
		return TRUE;
	
	// check proper extents of wider monsters
	// skip the more expensive trace for these bc we don't really need to test
	// through notrace 7 times
	corner = targ.size * 0.5 - '1 1 0';
	corner_z = 0;
	traceline(srcorg, targ.origin + corner, TRUE, self);
	if (trace_fraction == 1)
		return TRUE;
		
	corner_x *= -1;
	traceline(srcorg, targ.origin + corner, TRUE, self);
	if (trace_fraction == 1)
		return TRUE;
		
	corner_y *= -1;
	traceline(srcorg, targ.origin + corner, TRUE, self);
	if (trace_fraction == 1)
		return TRUE;
		
	corner_x *= -1;
	traceline(srcorg, targ.origin + corner, TRUE, self);
	if (trace_fraction == 1)
		return TRUE;

	return FALSE;
}

/*
============
DamageCanKill

test for a would-kill condition while respecting armor and special flags
============
*/
float DamageCanKill(entity targ, float damage)
{
	if (damage <= 0) return FALSE;
	
	if (!targ.takedamage ||
		targ.customflags & CFL_UNDYING ||
		targ.flags & FL_GODMODE ||
		targ.items & IT_INVULNERABILITY )
		return FALSE;
	
	return (ArmorSave(targ, damage) + targ.health <= damage);
}

/*
============
ArmorSave

save damage based on the target's armor level.
is separate from T_Damage and duplicates a few checks so that func_voids can check
	if they would kill the player before they actually try
============
*/
float ArmorSave(entity targ, float damage, float dmgtype = 0)
{
	if (!damage) return 0;
	if (!targ.takedamage)
		return 0;
	// armor doesn't protect against things like drowning or target_items health adjustments
	if (dmgtype & DMGTYPE_NOARMOR || targ.armorvalue <= 0)
		return 0;
	if (targ.flags & FL_GODMODE || has_invuln(targ) )
		return 0;

	float save, savefrac;
	
	savefrac = targ.armortype * damage;

	if (targ.classname == "player")
	{
		/* ========		
		lots of tiny damages (like ai_melee or crushy movers) will always round to armor
		when yellow or red, stripping it away too fast, and always round to health when
		green, defeating the purpose of armor.
		
		instead we randomly apply the last fractional point to either armor or health so 
		that it's statistically balanced (... over geologic timescales)
		======== */
		save = floor(savefrac);
		savefrac -= save;
		if ( random() < savefrac ) save += 1;
	}
	else
	{
		// maintain old round-up behavior for everything else because mappers will use
		// QC hacks to do just about anything
		save = ceil(savefrac);
	}
	save = min(save, targ.armorvalue);
	
	return save;
}

/*
============
T_ReactToDamage
============
*/
void( entity attacker ) T_ReactToDamage =
{
	if (self.flags & FL_MONSTER)
	{
		monster_alt_use(
			(attacker.flags & (FL_MONSTER|FL_CLIENT)), // waketarget if attacker isn't world
			TRUE, 	// pain target obviously
			(self.health <= floor(self.max_health * 0.5)), // half health threshold
			FALSE);	// not dead yet
	}
	
	// ignore doors and nailshooters and so on
	if (!(attacker.flags & (FL_MONSTER|FL_CLIENT))) return;
	// ignore self dmg
	if ( attacker == self ) return;
	// ignore bosses because we can't kill them anyway
	if ( attacker.type == "boss" ) return;	
	// don't get distracted instantly after switching targets
	if (time < self.dmgtime) return;

	if (attacker == self.enemy && (attacker.flags & FL_MONSTER))
	{
		self.frags = 0;	// .frags used on monsters as a 'give up on infighting' timer
		return;
	}

	if (attacker.classname == "player")
	{
		if (self.enemy.classname != "player")
		{
			self.enemy = attacker;
			FoundTarget();
		}
		else
			self.enemy = attacker;

		if (coop)
			self.dmgtime = time + 2 + random();	// players pull guaranteed aggro for 2 seconds before infighting can distract
		else
			self.dmgtime = time + random();
		return;
	}

	// ========
	// all infighting cases follow:
	
	// fish should ignore monsters that aren't in the water with them
	if (self.flags & FL_SWIM && pointcontents(attacker.origin) > CONTENT_WATER) return;
	
	// get mad unless of the same class (except for soldiers)
	// classname check replaced with new "type" check
	// .type defaults to classname anyway, or can be overwritten so monsters can be grouped into mutually not-infighting groups
	if ( ( self.type != attacker.type ) || ( self.classname == "monster_army" ) )
	{
		if (self.enemy.classname == "player")
			self.oldenemy = self.enemy;
		self.enemy = attacker;
		self.dmgtime = time + 1 + random();	// focus on infight for a minumum of 1 second
		FoundTarget();
	}
}

/*
============
T_Damage

The damage is coming from inflictor, but get mad at attacker
This should be the only function that ever reduces health.

now wrapped around T_DamageApply so that zapped/axe flags always get cleared
even if the target resisted the damage
============
*/
void(entity targ, entity inflictor, entity attacker, float damage, float dmgtype = 0) T_Damage =
{
	T_DamageApply(targ, inflictor, attacker, damage, dmgtype);
	targ.customflags = not(targ.customflags, CFL_AXEHITME | CFL_ZAPPED);
}

void(entity targ, entity inflictor, entity attacker, float damage, float dmgtype = 0) T_DamageApply =
{
	vector	dir;
	entity	oldself;
	float	save, take;

	if (!damage || !targ.takedamage) return;
	
	if (targ == attacker)
	{
		// monsters which shouldn't be able to splash damage themselves to death:
		if (attacker.type == "boss") return;
		if (attacker.classname == "monster_ogre" || 
			attacker.classname == "monster_shalrath")
			return;
	}
	
	// used by buttons and triggers to set activator for target firing
	damage_attacker = attacker;

	if (has_quad(attacker) && !(dmgtype & DMGTYPE_SCRIPT))	// don't let target_items quad-damage you
	{
		damage = damage * 4;
		
		// silly hacky fix:
		// knight health was dropped 3hp (75 to 72) so that exactly three shells can kill a knight
		// the side effect of this was that one quad SNG shot (which does 72 dmg) would exactly kill a knight
		// when, in vanilla, one would drop the knight to 3hp and the next would gib him
		// the cleanest way to preserve the 'feel' of this is:
		if (targ.classname == "monster_knight" && attacker.classname == "player" && inflictor.classname == "spike")
			damage -= 3;
	}
	
	// variety is the spice of life:
	// scrags will happily fly down into slime, and they do spit green shit anyway
	if (targ.classname == "monster_wizard" && (dmgtype & DMGTYPE_SLIME))
		return;
	// shamblers take half damage from explosives
	else if (targ.classname == "monster_shambler" && (dmgtype & DMGTYPE_EXPLOSION))
		damage = damage * 0.5;
	// some attacks like vorepods and ogre grenades should explode zombies despite doing <60dmg
	else if (targ.type == "zombie")
	{
		if (dmgtype & DMGTYPE_MELEE)	// always knock a zombie down at least
			damage = max(damage, 20);
		else if (dmgtype & (DMGTYPE_ZKILL | DMGTYPE_LAVA))
			damage = max(damage, targ.health + 25);
		else if (dmgtype & DMGTYPE_SLIME)
			return;	// slime damage is not meaningful to zombies, they'll just pain over and over
	}		
	
	if (attacker.classname == targ.classname)
	{
		if (attacker.classname != "player" && attacker.classname != "monster_grunt")
			damage = damage * 0.5;
	}

	// .frags used on monsters to count time spent not damaging an enemy, so impossible infights time out
	if (attacker.flags & FL_MONSTER && attacker.enemy == targ)
	{
		attacker.frags = 0;
	}

	// figure momentum add
	if ( (inflictor != world) && (targ.movetype == MOVETYPE_WALK) )
	{
		dir = targ.origin - BoundsCenter(inflictor);
		dir = normalize(dir);
		targ.velocity = targ.velocity + dir*damage*8;
	}

	if (targ.flags & FL_GODMODE)
		return;
	
	// check for artifacts
	
	if (has_invuln(targ))
	{
		if (targ.invincible_sound < time)
		{
			sound (targ, CHAN_ITEM, "items/protect3.wav", 1, ATTN_NORM);
			targ.invincible_sound = time + 1;
		}
		return;
	}

	// team play damage avoidance
	if (teamplay && attacker.classname == "player")
	{
		if ((targ.team > 0) && 
			(targ.team == attacker.team) && 
			(targ != attacker) && 
			(inflictor.classname != "door") )	// because squishing a teammate is still possible
			return;

		// teamplay is automatically damage avoidance in coop because friends are always a team
		if (coop && 
			targ.classname == "player" &&
			attacker != targ)
			return;
	}

	// ready to do the damage
	damage = max(1, floor(damage));
	save = ArmorSave(targ, damage, dmgtype);
	targ.armorvalue = targ.armorvalue - save;
	if (targ.classname == "player")
		armor_set_type(targ);
	take = damage - save;

	if (targ.customflags & CFL_UNDYING)
		take = min(take, targ.health - 1);
		
	// add to the damage total for clients, which will be sent as a single
	// message at the end of the frame
	// FIXME: remove after combining shotgun blasts?
	if (targ.flags & FL_CLIENT)
	{
		targ.dmg_take = targ.dmg_take + take;
		targ.dmg_save = targ.dmg_save + save;
		targ.dmg_inflictor = inflictor;
	}

	// do the damage
	
	//bprint3("doing ", ftos(take), " damage\n");
	targ.health = ceil(targ.health - take);	// be an integer dammit
	
	if (targ.health <= 0)
	{
		Killed (targ, attacker, dmgtype);
		return;
	}

	// react to the damage
	oldself = self;
	self = targ;
	if ( (self.flags & FL_MONSTER) && attacker != world)
		T_ReactToDamage( attacker );
	
	// if (self.th_pain && time >= self.pain_finished)	// can't do this here, breaks zombie pain handling
	if (self.th_pain)
	{
		// nightmare scaling of .pain_finished moved to PainFinished(), called from .th_pain
		// on appropriate monsters only
		self.th_pain (attacker, take);

		// in coop, monsters will switch to the most convenient player to attack at will,
		// but triggering a pain animation will draw dedicated attention for a few seconds
		if (self.pain_finished > time && (attacker.flags & FL_CLIENT) && (self.enemy.flags & FL_CLIENT))
		{
			self.enemy = attacker;
			self.dmgtime = self.pain_finished + 3;
			self.search_time = self.pain_finished + 5;
		}
	}
	
	self = oldself;
}

/*
============
T_RadiusDamage
============
*/
void(entity inflictor, entity attacker, float damage, entity ignore, float dmgtype = DMGTYPE_EXPLOSION) T_RadiusDamage =
{
	// note: find downed zombies to gib first, then do radius damage, or else the radius 
	// damage will knock far away zombies down, then immediately gib them too
	if ((dmgtype & DMGTYPE_EXPLOSION) && damage > 48)
		T_GibDownedZombies(inflictor.origin, damage);
	
	float 	points, dist;
	entity	head;
	
	head = findradius(inflictor.origin, min(512, damage + 40));
	
	while (head)
	{
		if (head != ignore && head.takedamage)
		{
			// don't set off shootable doors/buttons with splash unless the player means it
			if ((head.movetype == MOVETYPE_PUSH || head.th_die == multi_killed) && head.type != "explobox")
			{
				dist = vlen (inflictor.origin - BoundsCenter(head));
				// a grenade at rest touching shootable should intuitively trigger it
				if ( !(inflictor.type == "grenade" && BoundsTouching(inflictor.origin, inflictor.origin, head.absmin, head.absmax, 2)) )
					if (dist > damage / 3)
						points = 0;
			}
			else
			{
				dist = vlen (inflictor.origin - head.origin);
				points = damage - (0.5 * dist);
				if (head == attacker && inflictor.type != "explobox")	// barrels never did half-self-splash in vanilla
					points *= 0.5;
			}
			// shambler takes half damage from all explosions
			//if (head.classname == "monster_shambler" && (dmgtype & DMGTYPE_EXPLOSION))
			//	points *= 0.5;
			// already halved by T_Damage
			

			if (points > 0 && CanDamage ( head, inflictor.origin ) )
				T_Damage (head, inflictor, attacker, points, dmgtype);
		}
		head = head.chain;
	}
}

/*
============
T_Heal: add health to an entity, limiting health to max_health if it's set
special rules if the player is being healed:
	"overheal" will limit health to the hard ceiling rather than medkit limit
returns TRUE if healing successfully took place
============
*/
float (entity e, float healamt, float overheal) T_Heal =
{
	float hmax, hceil;
	
	if (e.health <= 0)
		return FALSE;
	
	healamt = ceil(healamt);

	if (e.classname == "player")
	{
		hmax = e.max_health;
		hceil = 250;

		if (overheal)
			healamt = min(healamt, hceil - e.health);
		else
			healamt = min(healamt, hmax - e.health);

		healamt = floor(healamt);	// this should never come in as a float in the first place, buuut
		
		if (healamt <= 0)
			return FALSE;

		if (overheal)
			e.healthtime = time + 5;
		else
			e.healthtime = time + 1;
			
		e.health = e.health + healamt;

		// moved here from healthtouch so any source of healing prints messages
		sprint(e, "You are healed by ");
		sprint(e, ftos(healamt));
		sprint(e, "\n");
		stuffcmd (e, "bf\n");
		return TRUE;
	}

	if (e.max_health >= 0)
		healamt = min(healamt, e.max_health - e.health);	
	
	if (healamt <= 0)
		return FALSE;
	
	e.health = e.health + healamt;

	return TRUE;
}