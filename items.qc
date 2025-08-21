/*
==============================================================================

ITEMS

items now set a lot of their own values directly rather than expect touch 
functions to check classnames

==============================================================================
*/

float	ITEM_SUSPENDED = 4;
/*FGD
@baseclass base(Appearflags, Target, Targetname) = Item
[
	message(string) : "Override Pickup Message"
	wait(string) : "Respawn interval. Default 0 is never respawn." : "0"
	count(integer) : "Respawn count. Default 0 is respawn forever (if 'wait' is set). -4 will auto-scale the count to the number of clients in coop." : 0
	spawnflags(flags) = 
	[
		4 : "Suspended" : 0
	]
]
*/

/*
================================
ItemFall
================================
*/
void() ItemFall =
{
	if (!(self.flags & FL_ITEM)) return;
	self.flags &~= FL_ONGROUND;
	self.solid = SOLID_TRIGGER;
	self.movetype = MOVETYPE_TOSS;	
	self.velocity = '0 0 1';
	
	self.spawnflags &~= ITEM_SUSPENDED;
}

/*
================================
ItemUse

triggering an item
 - if it regenerates, stop regenerating
 - if it doesn't, force it to respawn
items which have yet to be spawned have a different .use
================================
*/
void() ItemUse =
{
	if (self.wait > 0)
	{
		self.wait = 0;
		self.think = SUB_Remove;	// if nextthink is in the future, don't respawn again
		return;
	}
	
	self.alpha = 1;
	ItemSpawn();
}

/*
================================
ItemPiff
throw some light teledust off an item when it respawns
================================
*/
void() ItemPiff =
{
	vector org;
	org = BoundsCenter(self);
	org_z = self.absmin_z + 12;
	if (self.items & (IT_POWERUPS | IT_WEAPONS | IT_KEY1 | IT_KEY2))
		org_z += 20;
	particle(org, '8 8 0', 8, 16);
	particle(org, '8 -8 0', 8, 16);
	particle(org, '-8 8 0', 8, 16);
	particle(org, '-8 -8 0', 8, 16);
	
	sound (self, CHAN_VOICE, "items/itembk2.wav", 1, ATTN_NORM);	// play respawn sound
}

/*
================================
ItemSpawn
================================
*/
void() ItemSpawn =
{
	if (self.solid == SOLID_TRIGGER)
		return;	// already spawned
	
	// optimized away .mdl, recycled .wad as only the world uses it
	self.model = self.wad;		// restore original model
	self.solid = SOLID_TRIGGER;	// allow it to be touched again
	setorigin (self, self.origin);

	ItemPiff();
	
	if (self.wait)
		self.use = ItemUse;
}

/*
================================
SUB_regen
================================
*/
void() SUB_regen = {ItemSpawn();}

/*
================================
ItemDespawnBlink
================================
*/
void() ItemDespawnBlink =
{
	self.cnt += 1;
	if (self.cnt == 10)
	{
		SUB_Remove();
		return;
	}
	if (self.alpha == 1)
		self.alpha = 0.25;
	else
		self.alpha = 1;
	self.nextthink = time + 0.25;
}

/*
================================
ItemPrespawnFlicker
================================
*/
void() ItemPrespawnFlicker =
{
	if (time >= self.attack_finished)
	{
		self.alpha = 1;
		ItemSpawn();
		return;
	}

	// flicker back into place
	//self.alpha = (3.5 - (self.attack_finished - time)) / 8 + (1 - mod(self.attack_finished - time, 0.5)) * 0.2;
	self.alpha = (0.5 - mod(self.attack_finished - time, 0.5));
	self.nextthink = time + 0.05;
}

/*
================================
ItemPrespawn
get ready to respawn by setting up a throbby fadein
================================
*/
void() ItemPrespawn =
{
	self.model = self.wad;		// restore original model
	setorigin(self, self.origin);
	
	self.think = ItemPrespawnFlicker;
	ItemPrespawnFlicker();
}

/*
================================
ItemTouched
================================
*/
void() ItemTouched =
{
	// wait > 0 == item respawns, either from deathmatch rules or entity keyvalue
	if (self.wait > 0)
	{
		//self.model = string_null;
		self.alpha = 0.2;
		self.solid = SOLID_NOT;
		
		self.think = ItemPrespawn;
		self.attack_finished = time + self.wait;
		self.nextthink = self.attack_finished - 2.45;
	}
	// wait -1 == respawn every time the item is triggered
	else if (self.wait < 0 || self.use == ItemSpawn || self.use == SUB_regen)	// maintain old respawn hacks
	{
		self.model = string_null;
		self.solid = SOLID_NOT;
		if (self.use != SUB_regen)
			self.use = ItemUse;
	}
	else
	{
		SUB_RemoveSoon();
	}
	
	playercount_convert(count);
	if (self.count > 0)		// only respawn 'count' more times
	{
		self.count = self.count - 1;
		if (self.count == 0)
			SUB_RemoveSoon();	// can't remove during c touch/movement code
	}
	
	activator = other;
	SUB_UseTargets();
}



/*
================================
ItemRotateAndSize
jigger the origin and bounds of items with off-center origins so their models
appear in the center of their bboxes using MATHS
================================
*/
void() ItemRotateAndSize =
{
	if (self.mins != '0 0 0')
		return;	// not a silly corner-bbox item

	if (self.ideal_yaw)
		self.angles_y = crandom() * 90;
	
	vector offset, expand;	
	offset = '16 16 0';
	
	// still caused items to sometimes shrink to points, this is a no go
	/*
	float qang;
	// angled items feel smaller when their corners stick out and you can get
	// closer without touching them than it looks like you should
	qang = fabs(mod(self.angles_y, 90));
	if (qang >= 30 && qang <= 60)
		expand = '4 4 0';
	else if (qang >= 15 && qang <= 75)
		expand = '2 2 0';
	*/
	
	setorigin(self, self.origin + offset);
	setsize(self, self.mins - offset - expand, self.maxs - offset + expand);
}

/*
// old way, for items with corner origins
void() ItemRotateAndSize2 =
{
	if (self.angles_y == 0)
		return;
	if (self.mins != '0 0 0')
		return;	// not a silly corner-bbox item

	float qang;
	vector rot, orgofs, expand;
	vector max = self.maxs;
	
	rot = SinCos(self.angles_y - 135);
	rot *= 22.6274;	// length of diagonal radius of 32u box
	orgofs_x = rot_y + 16;
	orgofs_y = rot_x + 16;
	orgofs_z = 0;
	
	// angled items feel smaller when their corners stick out and you can get
	// closer without touching them than it looks like you should
	qang = fabs(mod(self.angles_y, 90));
	if (qang >= 30 && qang <= 60)
		expand = '4 4 0';
	else if (qang >= 15 && qang <= 75)
		expand = '2 2 0';
	
	setorigin(self, self.origin + orgofs);
	setsize(self, orgofs * -1 - expand, max - orgofs + expand);
}
*/

/*
================================
ItemDrop
plants the object on the floor or sometimes just destroys it completely
================================
*/
void() ItemDrop =
{
	float	oldz;
	self.movetype = MOVETYPE_TOSS;	
	self.velocity = '0 0 0';
	self.origin_z = self.origin_z + 6;
	oldz = self.origin_z;
	if (!droptofloor())
	{
		dprint4(self.classname," fell out of level at ",vtos(self.origin),"\n");
		// progression-critical items shouldn't just vanish
		if (self.classname == "item_sigil" || self.classname == "item_key1" || self.classname == "item_key2")
		{
			self.origin_z = oldz;
			setorigin(self, self.origin);	// relink
		}
		else
		{
			remove(self);
		}
	}
}

/*
================================
ItemPlace
work out initial placement based on states
================================
*/
void() ItemPlace =
{
	self.flags |= FL_ITEM;		// make extra wide
	
	if (SUB_VerifyTriggerable())
	{	// hide them until triggered if triggerable
		self.solid = SOLID_NOT;
		self.model = string_null;
		self.use = ItemSpawn;
	}
	else
	{
		self.solid = SOLID_TRIGGER;
		SUB_ChangeModel(self,self.wad);
		if (self.use != SUB_regen)	// map hack back compat
			self.use = ItemUse;
	}
	
	if (self.spawnflags & ITEM_SUSPENDED)
	{
		//dprint("item is suspended\n");
		self.movetype = MOVETYPE_NONE;
	}	
	else
	{
		ItemDrop();
	}
	
	ItemRotateAndSize();	// must do this after item_drop, droptofloor is picky about the weird things we do
}

void() PlaceItem = {ItemPlace();}


/*
================================
StartItem
Sets the clipping size and drops to floor
================================
*/
void() StartItem =
{
	// putting this here means items that never appear in the level will precache
	// anyway, but this isn't a big deal and I'm lazy
	if (!SUB_ShouldSpawn()) return;
	
	if (!self.type)
		self.type = "item";
		
	self.wad = self.model;		// so it can be restored on respawn
	self.model = string_null;
	
	// items start after other solids
	//self.nextthink = time + 0.2;
	self.nextthink = time + 0.2 + random() * 0.1;	// spread thinks to not ram quake to death with sub_verifytriggerable checks
	self.think = ItemPlace;
	
	ammo_total +=	self.ammo_shells * DEBUG_DMG_PER_SHELL +
					self.ammo_cells * DEBUG_DMG_PER_CELL +
					self.ammo_nails * DEBUG_DMG_PER_NAIL;
	num_rockets += self.ammo_rockets;
}


/*
===============================================================================

DROPPING

===============================================================================
*/

void(string tname) target_drop_do =
{
	if (tname == string_null)
		return;
		
	entity t;
	t = world;
	
	do	{
		t = find (t, targetname, tname);
		if (!t) break;
		if (!(t.flags & FL_ITEM)) continue;
		
		SUB_CallAsSelf(ItemFall, t);
	} while (t);
}

void() target_drop_use =
{
	target_drop_do(self.target);
	target_drop_do(self.target2);
	target_drop_do(self.target3);
	target_drop_do(self.target4);
}

/*QUAKED target_drop (0.75 0.25 0) (-16 -16 -16) (16 16 16) ?
Causes all targeted items which are SUSPENDED to drop when triggered.
*/
/*FGD
@PointClass base(Appearflags, Targetname) size(32 32 32) color(192 64 0) = target_drop : 
"Target Drop. Causes all targeted items which are suspended to drop when triggered."
[
	target(target_destination) : "Target: acts on all items with a matching targetname" 
	target2(target_destination) : "Target 2: acts on all items with a matching targetname" 
	target3(target_destination) : "Target 3: acts on all items with a matching targetname" 
	target4(target_destination) : "Target 4: acts on all items with a matching targetname" 
]
*/
void() target_drop =
{
	if (!SUB_ShouldSpawn()) return;
	self.use = target_drop_use;
}



/*
===============================================================================

GIVING/TAKING/CHECKING

===============================================================================
*/

float SPAWN_TGTITEMS_TAKE = 1;
float SPAWN_TGTITEMS_OVERRIDE = 2;
float SPAWN_TGTITEMS_FLASH = 4;
float SPAWN_TGTITEMS_TEST = 8;
float SPAWN_TGTITEMS_MIN = 16;

/*FGD
@baseclass = TrigItems [
	svflags(flags) =
	[
		1 : "E1 complete" : 0
		2 : "E2 complete" : 0
		4 : "E3 complete" : 0
		8 : "E4 complete" : 0
		16 : "Unused" : 0
		32 : "Unused" : 0
		64 : "Unused" : 0
		128 : "Unused" : 0
	]
	items(flags) =
	[
		1 : "Shotgun" : 0
		2 : "Super Shotgun" : 0
		4 : "Nailgun" : 0
		8 : "Perforator" : 0
		16 : "Grenade Laucher" : 0
		32 : "Rocket Launcher" : 0
		64 : "Lightning Gun" : 0
		4096 : "Axe" : 0
		131072 : "Silver Key" : 0
		262144 : "Gold Key" : 0
		524288 : "Ring" : 0
		1048576 : "Pent" : 0
		2097152 : "Biosuit" : 0
		4194304 : "Quad" : 0
	]
	ammo_shells(integer) : "Shells" : 0
	ammo_nails(integer) : "Nails" : 0
	ammo_rockets(integer) : "Rockets" : 0
	ammo_cells(integer) : "Cells" : 0
	health(integer) : "Health" : 0
	armorvalue(integer) : "Armor" : 0
	armortype(choices) : "Armor Strength" = [
		0.0 : "Ignore"
		0.3 : "Green (30%)"
		0.5 : "Yellow (50%)"
		0.7 : "Red (70%)"
	]
]
*/
void(entity e) target_items_setweapon =
{
	entity tgi = self;
	self = e;
	if (tgi.weapon)
		W_Select(tgi.weapon);

	if (!(self.weapon & self.items))
		W_SelectBestWeapon();
	
	self = tgi;
}

void(entity e) target_items_giveinv_min =
{
	if (self.health && self.health > e.health)
		T_Heal(e, (self.health - e.health), TRUE);
	
	float arm = zeroconvert(self.armorvalue);
	if (arm > e.armorvalue)
		armor_give(e, arm, self.armortype, TRUE);

	if (self.ammo_shells) e.ammo_shells =	max(e.ammo_shells,	zeroconvert(self.ammo_shells));
	if (self.ammo_nails) e.ammo_nails =		max(e.ammo_nails,	zeroconvert(self.ammo_nails));
	if (self.ammo_rockets) e.ammo_rockets =	max(e.ammo_rockets,	zeroconvert(self.ammo_rockets));
	if (self.ammo_cells) e.ammo_cells =		max(e.ammo_cells,	zeroconvert(self.ammo_cells));
}

void(entity e) target_items_giveinv =
{
	if (self.spawnflags & SPAWN_TGTITEMS_MIN)
	{
		target_items_giveinv_min(e);
	}
	else
	{
		if (self.health)
			T_Heal(e, self.health, TRUE);
			
		if (self.armorvalue)
			armor_give(e, zeroconvert(self.armorvalue), self.armortype, FALSE);

		if (self.ammo_shells) e.ammo_shells += zeroconvert(self.ammo_shells);
		if (self.ammo_nails) e.ammo_nails += zeroconvert(self.ammo_nails);
		if (self.ammo_rockets) e.ammo_rockets += zeroconvert(self.ammo_rockets);
		if (self.ammo_cells) e.ammo_cells += zeroconvert(self.ammo_cells);
	}
	bound_ammo(e);
	
	if (self.svflags)
		serverflags |= zeroconvert(self.svflags);

	if (self.items)
	{
		float it = zeroconvert(self.items);

		if (it & IT_WEAPONS)
			e.items |= it & IT_WEAPONS;
		
		// set artifact timers properly
		if (it & IT_INVISIBILITY)
			powerup_invisibility(e, self.length);
		if (it & IT_INVULNERABILITY)
			powerup_invulnerability(e, self.length);
		if (it & IT_SUIT)
			powerup_envirosuit(e, self.length);
		if (it & IT_QUAD)
			powerup_super_damage(e, self.length);
		
		if (it & IT_KEY1)
			key_give_silver(e);
		if (it & IT_KEY2)
			key_give_gold(e);
			
		target_items_setweapon(e);
	}
	SUB_CallAsSelf(W_ResetWeaponState, e);
}

float(entity e) target_items_testinv =
{
	if (self.health > 0 && self.health > e.health) return FALSE;
	if (self.armorvalue && self.armorvalue > e.armorvalue) return FALSE;
	if (self.armortype && self.armortype > e.armortype) return FALSE;

	if (self.svflags)
	{
		float sf = zeroconvert(self.svflags);
		if (sf & serverflags != sf) return FALSE;
	}	


	if (self.ammo_shells && self.ammo_shells > e.ammo_shells) return FALSE;
	if (self.ammo_nails && self.ammo_nails > e.ammo_nails) return FALSE;
	if (self.ammo_rockets && self.ammo_rockets > e.ammo_rockets) return FALSE;
	if (self.ammo_cells && self.ammo_cells > e.ammo_cells) return FALSE;

	if (self.items)
	{
		float it = zeroconvert(self.items);
		if (it & e.items != it) return FALSE;
	}
	
	return TRUE;
}

float(entity e) target_items_takeinv =
{
	if (!(self.spawnflags & SPAWN_TGTITEMS_MIN))
	{
		if (!target_items_testinv(e)) return FALSE;
	}
	
	if (self.armorvalue)
	{
		e.armorvalue = max(0, e.armorvalue - self.armorvalue);
		armor_set_type(e);
	}

	if (self.health > 0)
	{
		T_Damage(e, self, activator, min(e.health, self.health), DMGTYPE_SCRIPT | DMGTYPE_NOARMOR);
		if (e.health <= 0)
			return FALSE;
	}
		
	if (self.svflags)
	{
		float sf = zeroconvert(self.svflags);
		serverflags = not(serverflags, sf);
	}
	

	if (self.ammo_shells)
	{
		e.ammo_shells = max(0, e.ammo_shells - zeroconvert(self.ammo_shells));
	}
	if (self.ammo_nails)
	{
		e.ammo_nails = max(0, e.ammo_nails - zeroconvert(self.ammo_nails));
	}
	if (self.ammo_rockets)
	{
		e.ammo_rockets = max(0, e.ammo_rockets - zeroconvert(self.ammo_rockets));
	}
	if (self.ammo_cells)
	{
		e.ammo_cells = max(0, e.ammo_cells - zeroconvert(self.ammo_cells));
	}

	if (self.items)
	{
		float it = zeroconvert(self.items);

		if (it & IT_WEAPONS)
			e.items = not(e.items, it & IT_WEAPONS);
		
		// set artifact timers properly
		if (it & IT_INVISIBILITY)
		{
			e.items = not(e.items, it & IT_INVISIBILITY);
			e.invisible_finished = 0;
			e.invisible_time = 0;
		}

		if (it & IT_INVULNERABILITY)
		{
			e.items = not(e.items, it & IT_INVULNERABILITY);
			e.invincible_finished = 0;
			e.invincible_time = 0;
		}

		if (it & IT_SUIT)
		{
			e.items = not(e.items, it & IT_SUIT);
			e.radsuit_finished = 0;
			e.rad_time = 0;
		}

		if (it & IT_QUAD)
		{
			e.items = not(e.items, it & IT_QUAD);
			e.super_damage_finished = 0;
			e.super_time = 0;
		}
		
		if (!(e.items & (IT_INVISIBILITY | IT_INVULNERABILITY | IT_QUAD)))
			e.effects = not(e.effects, EF_DIMLIGHT);
			
		if (it & IT_KEY1)
			key_take_silver(e);
		if (it & IT_KEY2)
			key_take_gold(e);
			
	}
	
	target_items_setweapon(e);
	
	return TRUE;
}


void(entity e) target_items_setinv =
{
	if (self.health > 0)
		e.health = self.health;
		
	if (self.armorvalue)
	{
		e.armorvalue = zeroconvert(self.armorvalue);
		if (self.armortype)
		{
			e.armortype = self.armortype;
		}
		else	// value but no type: assume a color from amount given
		{
			if (self.armorvalue > 150)
				e.armortype = ARMORTYPE_RED;
			else if (self.armorvalue > 100)
				e.armortype = ARMORTYPE_YELLOW;
			else
				e.armortype = ARMORTYPE_GREEN;
		}
		armor_set_type(e);
	}
	else if (self.armortype && e.armorvalue)	// type but not value: override color on player
	{
		e.armortype = self.armortype;
		armor_set_type(e);
	}

	if (self.svflags)
	{
		serverflags = zeroconvert(self.svflags);		
	}

	if (self.ammo_shells) e.ammo_shells = zeroconvert(self.ammo_shells);
	if (self.ammo_nails) e.ammo_nails = zeroconvert(self.ammo_nails);
	if (self.ammo_rockets) e.ammo_rockets = zeroconvert(self.ammo_rockets);
	if (self.ammo_cells) e.ammo_cells = zeroconvert(self.ammo_cells);
	bound_ammo(e);
	
	if (self.items)
	{
		float it = zeroconvert(self.items);

		if (it & IT_WEAPONS || self.items == -1)
			e.items = not(e.items, IT_WEAPONS) + (it & IT_WEAPONS);
			
		// set artifact timers properly
		if (it & IT_INVISIBILITY)
			powerup_invisibility(e, self.length);
		else
		{
			e.items = not(e.items, IT_INVISIBILITY);
			e.invisible_finished = 0;
			e.invisible_time = 0;
		}

		if (it & IT_INVULNERABILITY)
			powerup_invulnerability(e, self.length);
		else
		{
			e.items = not(e.items, IT_INVULNERABILITY);
			e.invincible_finished = 0;
			e.invincible_time = 0;
		}

		if (it & IT_SUIT)
			powerup_envirosuit(e, self.length);
		else
		{
			e.items = not(e.items, IT_SUIT);
			e.radsuit_finished = 0;
			e.rad_time = 0;
		}

		if (it & IT_QUAD)
			powerup_super_damage(e, self.length);
		else
		{
			e.items = not(e.items, IT_QUAD);
			e.super_damage_finished = 0;
			e.super_time = 0;
		}
		
		if (!(e.items & (IT_INVISIBILITY | IT_INVULNERABILITY | IT_QUAD)))
			e.effects = not(e.effects, EF_DIMLIGHT);
		
		e.items = not(e.items, IT_KEY1 | IT_KEY2);
		e.worldtype = 0;
		if (it & IT_KEY1)
			key_give_silver(e);
		if (it & IT_KEY2)
			key_give_gold(e);

		target_items_setweapon(e);
	}
	SUB_CallAsSelf(W_ResetWeaponState, e);
	
	// after resetweaponstate or else deadthink will be overwritten
	if (self.health < 0)
		T_Damage(e, self, activator, e.health, DMGTYPE_SCRIPT | DMGTYPE_NOARMOR);
}


void() target_items_use =
{
	entity act = SUB_PlayerizeActivator();
	if (act.classname != "player") return;
	if (act.health <= 0) return;
	
	if (self.spawnflags & SPAWN_TGTITEMS_OVERRIDE)
	{
		target_items_setinv(act);
	}
	else if (self.spawnflags & SPAWN_TGTITEMS_TEST)
	{
		// TAKE reverses the polarity of TEST, so that it only tests if you don't
		// have all the specified inventory
		if (target_items_testinv(act) != !!(self.spawnflags & SPAWN_TGTITEMS_TAKE))
		{
			activator = act;
			SUB_UseTargetsSilent();
		}
		else
		{
			SUB_PrintMessage();
			return;
		}
	}
	else if (self.spawnflags & SPAWN_TGTITEMS_TAKE)
	{
		if (target_items_takeinv(act))
		{
			activator = act;
			SUB_UseTargetsSilent();
		}
		else
		{
			SUB_PrintMessage();
			return;
		}
	}
	else
	{
		target_items_giveinv(act);
	}
	if (self.spawnflags & SPAWN_TGTITEMS_FLASH)
		stuffcmd(act, "bf\n");
	if (self.noise != string_null)
		sound (act, CHAN_VOICE, self.noise, 1, ATTN_NORM);
		
	activator = act;
}

/*QUAKED target_items (0.75 0.25 0) (-8 -8 -8) (8 8 8) TAKE OVERRIDE FLASH TEST MINIMUM
Gives weapons, ammo, items, health, armor, and/or runes to the activating player when triggered. 

Keyvalues:
"ammo_shells" number of shells player should receive - same for _cells, _rockets, and _nails
"health" health (will overheal beyond 100)
"armorvalue" armor (protection color scales automatically)
"armortype" armor strength (0.3+ green, 0.5+ yellow, 0.7+ red)
"weapon" item bitflag (not impulse number!) of the weapon the player should swap to (if he has it)
"items" bitmask of what items the player should get (see below for reference)
"svflags" bitmask of serverflags to alter (1/2/4/8 are the episode runes, 16+ are invisible)
"length" length of powerup time in seconds if any are given (default 30)
"noise" wav file to play on activator

Spawnflags:
FLASH: flash the recipient's screen when triggered, defaults to being stealthy
MINIMUM: for numeric amounts, give the player enough to have a minimum of the amount specified
TAKE: subtract specified inventory amounts instead of adding
  - subtracting enough health WILL kill the player
  - will fire its targets if all items can be successfully taken
  - will print "message" and take nothing instead
  - TAKE with MINIMUM will skip the test and take whatever it can, firing no targets either way
OVERRIDE: force the player's inventory to all specified amounts (mainly useful triggered from spawnpoints), specify -1 for any keyvalue to force a 0 (-1 does not work for health)
TEST: behaves like TAKE, but doesn't take anything 
  - fires targets if activator has the matching inventory
  - prints "message" if not
  - TEST with TAKE will reverse the test (fire if player doesn't have)
  - beware of how this interacts with triggers: it will only test the first client to touch a trigger in coop unless it has ALL_CLIENTS set

Item Bitmask Reference:
	SG	= 1		SSG	= 2
	NG	= 4		SNG	= 8
	GL	= 16	RL	= 32
	LG	= 64	Axe	= 4096
	
	Silver	= 131072
	Gold	= 262144
	Ring	= 524288
	Pent	= 1048576
	Biosuit	= 2097152
	Quad	= 4194304
*/
/*FGD
@PointClass base(Appearflags, Target, Targetname, TrigItems, Deathtype) size(32 32 32) color(192 64 0) = target_items : 
"Target: Give. Adds weapons, ammo, items, health, armor, and/or runes to the activating player when triggered.

Spawnflag Usage:
'Take': subtract specified inventory amounts instead of adding
  - subtracting enough health WILL kill the player
  - will fire its targets if all items are successfully taken
  - will print 'message' if fewer than all items are successfully taken
'Override': force the player's inventory to all specified amounts (mainly useful triggered from spawnpoints), specify -1 for any keyvalue to force a 0 (-1 does not work for items or health)
'Test Only': behaves like TAKE, but without taking anything 
  - fires targets if activator has the matching inventory
  - prints 'message' if not
  - TEST with TAKE will reverse the test (fire if player doesn't have)
  - beware of how this interacts with triggers: it will only test the first client to touch a trigger in coop!
'Minimum': for numeric amounts, give the player enough to have a minimum of the amount specified
'Flash screen': flash the recipient's screen when triggered, defaults to being stealthy"
[
	length(integer) : "Override powerup duration" : 0
	message(string) : "Message to print if Take was unsuccessful"
	spawnflags(flags) =
	[
		1 : "Take instead" : 0
		2 : "Override instead" : 0
		4 : "Flash screen" : 0
		8 : "Test only" : 0
		16 : "Minimum" : 0
	]
	weapon(choices) : "Force Select Weapon" = 
	[
		0 : "Don't"
		1 : "Shotgun"
		2 : "Super Shotgun"
		4 : "Nailgun"
		8 : "Perforator"
		16 : "Grenade Laucher"
		32 : "Rocket Launcher"
		64 : "Lightning Gun"
		4096 : "Axe"
	]
	noise(string) : "wav file to play on activator"
]
*/
void() target_items =
{
	if (!SUB_ShouldSpawn()) return;
	self.use = target_items_use;
	
	if (self.length <= 0)
		self.length = 30;
	if (self.deathtype == string_null)
		self.deathtype = "had their life removed";
	
	if (self.items > 0)
	{
		// clear the item flags that are only for HUD switches so we can be sloppy with .items later
		self.items = not(self.items, IT_SHELLS | IT_NAILS | IT_ROCKETS | IT_CELLS | 
									 IT_ARMOR1 | IT_ARMOR2 | IT_ARMOR3 );
		/*
		// not necessary; we're already precaching them universally in world
		if (self.items & IT_INVISIBILITY)
			precache_invisibility();
		if (self.items & IT_INVULNERABILITY)
			precache_invulnerability();
		if (self.items & IT_SUIT)
			precache_envirosuit();
		if (self.items & IT_QUAD)
			precache_super_damage();
		*/
	}
	
	// snap armor color to only allowed values
	if (self.armortype >= ARMORTYPE_RED)
		self.armortype = ARMORTYPE_RED;
	else if (self.armortype >= ARMORTYPE_YELLOW)
		self.armortype = ARMORTYPE_YELLOW;
	else if (self.armortype >= ARMORTYPE_GREEN)
		self.armortype = ARMORTYPE_GREEN;
	else
		self.armortype = 0;
	
	if (self.noise != string_null)
		precache_sound_safe(self.noise);
}
void() target_give = {target_items();}


// ==========================================================

void() trigger_inventory =
{
	dprint("trigger_inventory is deprecated; use an ALL_CLIENTS trigger with a target_items\n");
	if(!SUB_ShouldSpawn()) return;
	
	// dumb rearguard action to support this entity I shouldn't have made: copy ourself
	// to an ALL_CLIENTS trigger, then turn ourself into a target_items that it triggers
	entity trig = spawn();
	trig.model = self.model;
	trig.wait = self.wait;
	trig.delay = self.delay;
	trig.spawnflags = (self.spawnflags & SPAWNFLAG_TRIGGER_FIRST) | SPAWNFLAG_ALL_CLIENTS;
	SUB_CallAsSelf(trigger_multiple,trig);
	trig.targetname = self.targetname;
	
	vector bb = BoundsCenter(trig);
	trig.target = ftos(fabs(bb_x+bb_y+bb_z));	// we need a unique-ish targetname ...
	self.targetname = trig.target;
	setorigin(self,bb);
	float inv = !(self.spawnflags & 1);
	self.spawnflags = not(self.spawnflags, SPAWN_NOTEASY - 1);
	self.spawnflags |= SPAWN_TGTITEMS_TEST + (SPAWN_TGTITEMS_TAKE * inv);
	target_items();
}
