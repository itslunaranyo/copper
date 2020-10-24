/*
=========================================================================

HEALTH BOXES

=========================================================================
*/

float	ITEM_HEALTH_ROTTEN = 1;
float	ITEM_HEALTH_MEGA = 2;


void() health_touch =
{
	if (!CheckValidTouch()) return;
	
	if (!T_Heal(other, self.healamount, (self.spawnflags & ITEM_HEALTH_MEGA)))
		return;

	// coop 1 megahealth brings all other clients up to 100
	entity pl;
	if (coop == 1 && self.spawnflags & ITEM_HEALTH_MEGA)
	{
		pl = get_next_client(other);
		while (pl != other)
		{
			if (T_Heal(pl, 100, FALSE))
			{
				sprint(pl, "You were restored by ");
				sprint(pl, other.netname);
				sprint(pl, "'s Megahealth\n");
				sound(pl, CHAN_ITEM, self.noise, 1, ATTN_NORM);
			}
			pl = get_next_client(pl);
		}
	}

	sound(other, CHAN_ITEM2, self.noise, 1, ATTN_NORM);

	ItemTouched();
}	


/*
================================
item_health & item_health_go
split up precaches and business code for late game health spawns
================================
*/
void() item_health_go
{
	self.touch = health_touch;
	self.type = "health";

	if (self.spawnflags & ITEM_HEALTH_ROTTEN)
	{
		setmodel(self, "progs/m_h15.mdl");
		self.noise = "items/r_item1.wav";
		self.healamount = 15;
	}
	else if (self.spawnflags & ITEM_HEALTH_MEGA)
	{
		setmodel(self, "progs/m_h100.mdl");
		self.noise = "items/r_item2.wav";
		self.healamount = 100;
	}
	else
	{
		setmodel(self, "progs/m_h25.mdl");
		self.noise = "items/health1.wav";
		self.healamount = 25;
	}
	setsize (self, '0 0 0', '32 32 56');
	
	if (deathmatch == 1)
		self.wait = 20;
		
	StartItem ();
}

// ===============================================================================

/*QUAKED item_health (0 .5 .5) (0 0 0) (32 32 32) SMALL MEGA SUSPENDED 
Health box. Normally gives 25 points.

Flags:
"mega" will add 100 health, then rot you down to your maximum health limit, one point per second
"small" gives 15 points

Keys:
"target/2/3/4/k" - entity to trigger when picked up
"targetname" - will not spawn until triggered
"wait" - will respawn after 'wait' seconds. fires targets every time.
"count" - limit number of times to respawn
*/
/*FGD
@PointClass size(0 0 0, 32 32 56) base(Item) 
	model(
        {{
            spawnflags & 2 ->   ":maps/b_bh100.bsp",
            spawnflags & 1 ->   ":maps/b_bh10.bsp",
                                ":maps/b_bh25.bsp"
        }}
    ) =
    item_health : "Health pack" 
[
	spawnflags(flags) = 
	[
		1 : "Rotten" : 0
		2 : "Megahealth" : 0
	]
]
*/
void() item_health =
{	
	if (!SUB_ShouldSpawn()) return;
	if (self.spawnflags & ITEM_HEALTH_MEGA)
	{
		precache_model_safe("progs/m_h100.mdl");
		precache_sound_safe("items/r_item2.wav");
	}
	else if (self.spawnflags & ITEM_HEALTH_ROTTEN)
	{
		precache_model_safe("progs/m_h15.mdl");
		precache_sound_safe("items/r_item1.wav");
	}
	else
	{
		precache_model_safe("progs/m_h25.mdl");
		precache_sound_safe("items/health1.wav");
	}

	item_health_go();
}





/*
===============================================================================

ARMOR

armorvalue = hit point quantity
armortype = 0-1 protection rate

===============================================================================
*/

float ARMORTYPE_GREEN = 0.3;
float ARMORTYPE_YELLOW = 0.5;
float ARMORTYPE_RED = 0.7;

/*
============
armor_set_type

coverage derived from last armor grabbed, but drops off to a lower tier below 100 * type
============
*/
void(entity e) armor_set_type =
{
	if (e.classname != "player")
		return;
	
	e.items = not(e.items, (IT_ARMOR1 | IT_ARMOR2 | IT_ARMOR3));
	if (!e.armorvalue)
	{
		e.armortype = 0.0;
		return;
	}
	
	if (e.armortype == ARMORTYPE_GREEN)
		e.items |= IT_ARMOR1;
	else if (e.armortype == ARMORTYPE_YELLOW)
		e.items |= IT_ARMOR2;
	else if (e.armortype == ARMORTYPE_RED)
		e.items |= IT_ARMOR3;
	
	e.armorvalue = min(e.armorvalue, 500);
}


/*
============
armor_give
============
*/
float(entity e, float amt, float absorb, float replace) armor_give =
{
	if (!amt)
		return FALSE;
	if (replace)
	{
		if (absorb < e.armortype)
		{
			// quake's original armor comparison test weighted both amounts by their protection
			// strength with a straight multiply (a.type * a.amt > e.type * e.amt) to determine 
			// which was "worth" more. with the current values, those breakeven points fall on
			// 42, 60, and 107, so we round those off to make it easier for players to notice
			// and learn the pickup cutoffs
			if (absorb == ARMORTYPE_GREEN && e.armortype == ARMORTYPE_RED && e.armorvalue > 40)
				return FALSE;
			if (absorb == ARMORTYPE_GREEN && e.armortype == ARMORTYPE_YELLOW && e.armorvalue > 60)
				return FALSE;
			if (absorb == ARMORTYPE_YELLOW && e.armortype == ARMORTYPE_RED && e.armorvalue > 100)
				return FALSE;
		}
		else
		{
			if (amt <= e.armorvalue)
				return FALSE;
		}
		e.armorvalue = amt;
		e.armortype = absorb;
	}
	else
	{
		if (e.armortype == 0)
			e.armortype = ARMORTYPE_GREEN;
		e.armorvalue += amt;
	}
	
	armor_set_type(e);
	return TRUE;
}


/*
============
armor_touch
============
*/
void() armor_touch =
{
	if (!CheckValidTouch()) return;
	
	if (!armor_give(other, self.armorvalue, self.armortype, TRUE))
		return;

	sound(other, CHAN_ITEM, "items/armor1.wav", 1, ATTN_NORM);
	sprint(other, "You got armor\n");

	stuffcmd (other, "bf\n");
	ItemTouched();
}

// ===============================================================================

/*
============
StartArmor
============
*/
void(float skn, float amt) StartArmor =
{
	if (!SUB_ShouldSpawn()) return;

	self.skin = skn;
	self.armorvalue = amt;
	if (skn == 2)
		self.armortype = ARMORTYPE_RED;
	else if (skn == 1)
		self.armortype = ARMORTYPE_YELLOW;
	else
		self.armortype = ARMORTYPE_GREEN;

	self.touch = armor_touch;
	self.type = "armor";
	precache_model ("progs/armor.mdl");
	setmodel (self, "progs/armor.mdl");
	
	if (deathmatch == 1)
		self.wait = 20;

	setsize (self, '-16 -16 0', '16 16 56');
	StartItem ();
}


/*QUAKED item_armor1 (0 .5 .5) (-16 -16 0) (16 16 32) ? ? SUSPENDED
Green armor, gives 100 points.

Keys:
"target/2/3/4/k" - entity to trigger when picked up
"targetname" - will not spawn until triggered
"wait" - will respawn after 'wait' seconds. fires targets every time.
"count" - limit number of times to respawn
*/
/*FGD
@PointClass size(-16 -16 0, 16 16 56) base(Item) model({ "path": ":progs/armor.mdl" }) =
	item_armor1 : "Green armor (100%)" []
*/
void() item_armor1 = { StartArmor(0,100); }

/*QUAKED item_armor2 (0 .5 .5) (-16 -16 0) (16 16 32) ? ? SUSPENDED
Yellow armor, gives 150 points.

Keys:
"target/2/3/4/k" - entity to trigger when picked up
"targetname" - will not spawn until triggered
"wait" - will respawn after 'wait' seconds. fires targets every time.
"count" - limit number of times to respawn
*/
/*FGD
@PointClass size(-16 -16 0, 16 16 56) base(Item) model({ "path": ":progs/armor.mdl", "skin": 1 }) =
	item_armor2 : "Yellow armor (150%)" []
*/
void() item_armor2 = { StartArmor(1,150); }

/*QUAKED item_armorInv (0 .5 .5) (-16 -16 0) (16 16 32) ? ? SUSPENDED
Red armor, gives 200 armor points.

Keys:
"target/2/3/4/k" - entity to trigger when picked up
"targetname" - will not spawn until triggered
"wait" - will respawn after 'wait' seconds. fires targets every time.
"count" - limit number of times to respawn
*/
/*FGD
@PointClass size(-16 -16 0, 16 16 56) base(Item) model({ "path": ":progs/armor.mdl", "skin": 2 }) =
	item_armorInv : "Red armor (200%)" []
*/
void() item_armorInv = { StartArmor(2,200); }


