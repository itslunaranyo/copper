/*
===============================================================================

WEAPONS

===============================================================================
*/

float	ITEM_AMMO_BIG = 1;


void(entity e) bound_ammo =
{
	e.ammo_shells = min(e.ammo_shells, MAX_AMMO_SHELLS);
	e.ammo_nails = min(e.ammo_nails, MAX_AMMO_NAILS);
	e.ammo_rockets = min(e.ammo_rockets, MAX_AMMO_ROCKETS);
	e.ammo_cells = min(e.ammo_cells, MAX_AMMO_CELLS);
}

/*
=============
weapon_touch_coop
=============
*/
void() weapon_touch_coop =
{
	if (!coop) return;
	activator = other;
	SUB_UseTargets();
	self.killtarget = string_null;
	self.target = string_null;
	self.target2 = string_null;
	self.target3 = string_null;
	self.target4 = string_null;
}

void(entity to) weapon_give =
{
	to.items |= self.items;
	to.ammo_shells += self.ammo_shells;
	to.ammo_nails += self.ammo_nails;
	to.ammo_rockets += self.ammo_rockets;
	to.ammo_cells += self.ammo_cells;
		
	bound_ammo(to);

	sprint (to, "You got the ");
	sprint (to, self.netname);
	sprint (to, "\n");

	sound (to, CHAN_ITEM, "weapons/pkup.wav", 1, ATTN_NORM);
	stuffcmd (to, "bf\n");
}

/*
=============
weapon_touch
=============
*/
void() weapon_touch =
{
	float	leave, nsw;

	if (!CheckValidTouch()) return;

	if (deathmatch == 2 || deathmatch == 3 || coop > 1)
		leave = 1;
	else
		leave = 0;
	
	if (leave)
	{
		if (other.items & self.items == self.items)	// already have it
		{
			weapon_touch_coop();
			return;
		}
	}
	
	if (self.items & other.items) nsw = TRUE;

	weapon_give(other);
	// change to the weapon
	entity	stemp;
	stemp = self;
	self = other;
	if (nsw)
		W_ResetWeaponState();
	else
		W_BetterWeapon(stemp.items);
	self = stemp;

	if (coop == 1)
	{
		entity pl = get_next_client(other);
		while (pl != other)
		{
			weapon_give(pl);
			pl = get_next_client(pl);
		}
	}
	
	if (leave)
	{
		weapon_touch_coop();
		return;
	}

	ItemTouched();
}


/*
============
StartWeapon
============
*/
void() StartWeapon =
{
	self.type = "weapon";
	self.touch = weapon_touch;
	setsize (self, '-16 -16 0', '16 16 56');
	if (deathmatch == 1)
		self.wait = 30;
	StartItem ();
}


// ===============================================================================

/*FGD
@baseclass size(-16 -16 0, 16 16 56) color(0 0 200) base(Item) = Weapon []
*/


/*QUAKED weapon_shotgun (0 0 1) (-16 -16 0) (16 16 56) ? ? SUSPENDED
Shotgun.

Keys:
"target/2/3/4/k" - entity to trigger when picked up
"targetname" - will not spawn until triggered
"wait" - will respawn after 'wait' seconds. fires targets every time.
"count" - limit number of times to respawn
*/
/*FGD
@PointClass base(Weapon) model({ "path": ":progs/g_shotgn.mdl" }) = weapon_shotgun : "Shotgun. 
5 Shells." []
*/
void() weapon_shotgun =
{
	if (!SUB_ShouldSpawn()) return;
	precache_model3 ("progs/g_shotgn.mdl");
	setmodel (self, "progs/g_shotgn.mdl");
	self.items = IT_SHOTGUN;
	self.ammo_shells = 5;
	self.netname = "Shotgun";
	StartWeapon();
}


/*QUAKED weapon_supershotgun (0 0 1) (-16 -16 0) (16 16 56) ? ? SUSPENDED
Double-barreled shotgun.

Keys:
"target/2/3/4/k" - entity to trigger when picked up
"targetname" - will not spawn until triggered
"wait" - will respawn after 'wait' seconds. fires targets every time.
"count" - limit number of times to respawn
*/
/*FGD
@PointClass base(Weapon) model({ "path": ":progs/g_shot.mdl" }) = weapon_supershotgun : "Double-barreled shotgun.
10 shells." []
*/
void() weapon_supershotgun =
{
	if (!SUB_ShouldSpawn()) return;
	precache_model_safe ("progs/g_shot.mdl");
	setmodel (self, "progs/g_shot.mdl");
	self.items = IT_SUPER_SHOTGUN;
	self.ammo_shells = 10;
	self.netname = "Double-barreled Shotgun";
	StartWeapon();
}

/*QUAKED weapon_nailgun (0 0 1) (-16 -16 0) (16 16 56) ? ? SUSPENDED
Nailgun.

Keys:
"target/2/3/4/k" - entity to trigger when picked up
"targetname" - will not spawn until triggered
"wait" - will respawn after 'wait' seconds. fires targets every time.
"count" - limit number of times to respawn
*/
/*FGD
@PointClass base(Weapon) model({ "path": ":progs/g_nail.mdl" }) = weapon_nailgun : "Nailgun.
30 nails." []
*/
void() weapon_nailgun =
{
	if (!SUB_ShouldSpawn()) return;
	precache_model_safe ("progs/g_nail.mdl");
	setmodel (self, "progs/g_nail.mdl");
	self.items = IT_NAILGUN;
	self.ammo_nails = 30;
	self.netname = "Nailgun";
	StartWeapon();
}

/*QUAKED weapon_supernailgun (0 0 1) (-16 -16 0) (16 16 56) ? ? SUSPENDED
Perforator (Super Nailgun).

Keys:
"target/2/3/4/k" - entity to trigger when picked up
"targetname" - will not spawn until triggered
"wait" - will respawn after 'wait' seconds. fires targets every time.
"count" - limit number of times to respawn
*/
/*FGD
@PointClass base(Weapon) model({ "path": ":progs/g_nail2.mdl" }) = weapon_supernailgun : "Perforator (Super Nailgun).
30 nails." []
*/
void() weapon_supernailgun =
{
	if (!SUB_ShouldSpawn()) return;
	precache_model_safe ("progs/g_nail2.mdl");
	setmodel (self, "progs/g_nail2.mdl");
	self.items = IT_SUPER_NAILGUN;
	self.ammo_nails = 30;
	self.netname = "Perforator";
	StartWeapon();
}

/*QUAKED weapon_grenadelauncher (0 0 1) (-16 -16 0) (16 16 56) ? ? SUSPENDED
Grenade Launcher.

Keys:
"target/2/3/4/k" - entity to trigger when picked up
"targetname" - will not spawn until triggered
"wait" - will respawn after 'wait' seconds. fires targets every time.
"count" - limit number of times to respawn
*/
/*FGD
@PointClass base(Weapon) model({ "path": ":progs/g_rock.mdl" }) = weapon_grenadelauncher : "Grenade launcher.
5 rockets." []
*/
void() weapon_grenadelauncher =
{
	if (!SUB_ShouldSpawn()) return;
	precache_model_safe ("progs/g_rock.mdl");
	setmodel (self, "progs/g_rock.mdl");
	self.items = IT_GRENADE_LAUNCHER;
	self.ammo_rockets = 5;
	self.netname = "Grenade Launcher";
	StartWeapon();
}

/*QUAKED weapon_rocketlauncher (0 0 1) (-16 -16 0) (16 16 56) ? ? SUSPENDED
Rocket Launcher.

Keys:
"target/2/3/4/k" - entity to trigger when picked up
"targetname" - will not spawn until triggered
"wait" - will respawn after 'wait' seconds. fires targets every time.
"count" - limit number of times to respawn
*/
/*FGD
@PointClass base(Weapon) model({ "path": ":progs/g_rock2.mdl" }) = weapon_rocketlauncher : "Rocket launcher.
5 rockets." []
*/
void() weapon_rocketlauncher =
{
	if (!SUB_ShouldSpawn()) return;
	precache_model_safe ("progs/g_rock2.mdl");
	setmodel (self, "progs/g_rock2.mdl");
	self.items = IT_ROCKET_LAUNCHER;
	self.ammo_rockets = 5;
	self.netname = "Rocket Launcher";
	StartWeapon();
}


/*QUAKED weapon_lightning (0 0 1) (-16 -16 0) (16 16 56) ? ? SUSPENDED
Thunderbolt Cannon.

Keys:
"target/2/3/4/k" - entity to trigger when picked up
"targetname" - will not spawn until triggered
"wait" - will respawn after 'wait' seconds. fires targets every time.
"count" - limit number of times to respawn
*/
/*FGD
@PointClass base(Weapon) model({ "path": ":progs/g_light.mdl" }) = weapon_lightning : "Thunderbolt.
12 cells." []
*/
void() weapon_lightning =
{
	if (!SUB_ShouldSpawn()) return;
	precache_model_safe ("progs/g_light.mdl");
	setmodel (self, "progs/g_light.mdl");
	self.items = IT_LIGHTNING;
	self.ammo_cells = 12;
	self.netname = "Thunderbolt";
	StartWeapon();
}

/*QUAKED weapon_axe (0 0 1) (-16 -16 0) (16 16 56) ? ? SUSPENDED
The axe, should you happen to make the player start without one.

Keys:
"target/2/3/4/k" - entity to trigger when picked up
"targetname" - will not spawn until triggered
"wait" - will respawn after 'wait' seconds. fires targets every time.
"count" - limit number of times to respawn
*/
/*FGD
@PointClass base(Weapon) model({ "path": ":progs/g_axe.mdl" }) = weapon_axe : "Axe." []
*/
void() weapon_axe =
{
	if (!SUB_ShouldSpawn()) return;
	precache_model_safe ("progs/g_axe.mdl");
	setmodel (self, "progs/g_axe.mdl");
	self.items = IT_AXE;
	self.netname = "Axe. Find some wood!";
	StartWeapon();
}


// ===============================================================================

/*
============
ammo_touch
============
*/
void() ammo_touch =
{
	if (!CheckValidTouch()) return;

	// structured in dual if's instead of using && to preserve ammo_touch maphacks
	if (self.ammo_shells)
	{
		if (other.ammo_shells < MAX_AMMO_SHELLS)
			other.ammo_shells += self.ammo_shells;
		else return;
	}
	else if (self.ammo_nails)
	{
		if (other.ammo_nails < MAX_AMMO_NAILS)
			other.ammo_nails += self.ammo_nails;
		else return;
	}
	else if (self.ammo_rockets)
	{
		if (other.ammo_rockets < MAX_AMMO_ROCKETS)
			other.ammo_rockets += self.ammo_rockets;
		else return;
	}
	else if (self.ammo_cells)
	{
		if (other.ammo_cells < MAX_AMMO_CELLS)
			other.ammo_cells += self.ammo_cells;
		else return;
	}
	//else return;	

	bound_ammo(other);
	
	sprint (other, "You got the ");
	sprint (other, self.netname);
	sprint (other, "\n");

	sound (other, CHAN_ITEM, "weapons/lock4.wav", 1, ATTN_NORM);
	stuffcmd (other, "bf\n");

	// if changed current ammo, update it
	SUB_CallAsSelf(W_SetCurrentAmmo, other);

	ItemTouched();
}

/*
============
StartAmmo
============
*/
void() StartAmmo =
{
	self.type = "ammo";
	setsize (self, '0 0 0', '32 32 56');
	self.touch = ammo_touch;
	if (deathmatch == 1)
		self.wait = 30;
	if (deathmatch == 3)
		self.wait = 15;
	StartItem ();
	//ItemRotateAndSize('32 32 56');
}

/*FGD
@baseclass size(0 0 0, 32 32 32) color(0 160 160) base(Item) = Ammo [ spawnflags(flags) =  [ 1 : "Large box (2x)" : 0 ] ]
*/

/*QUAKED item_shells (0 .5 .5) (0 0 0) (32 32 32) BIG ? SUSPENDED
20 shells for both Shotgun and SuperShotgun.

Flags:
"big" gives 40 instead of 20

Keys:
"target/2/3/4/k" - entity to trigger when picked up
"targetname" - will not spawn until triggered
"wait" - will respawn after 'wait' seconds. fires targets every time.
"count" - limit number of times to respawn
*/
/*FGD
@PointClass base(Ammo)
    model(
        {{
            spawnflags & 1 ->   ":maps/b_shell1.bsp",
                                ":maps/b_shell0.bsp"
        }}
    ) = item_shells : "Shells, 20/40" []
*/
void() item_shells =
{
	if (!SUB_ShouldSpawn()) return;
	if (self.spawnflags & ITEM_AMMO_BIG)
	{
		self.ammo_shells = 40;
		precache_model_safe ("progs/m_shell2.mdl");
		setmodel (self, "progs/m_shell2.mdl");
	}
	else
	{
		self.ammo_shells = 20;
		precache_model_safe ("progs/m_shell1.mdl");
		setmodel (self, "progs/m_shell1.mdl");
	}
	self.weapon = 1;
	self.netname = "shells";
	StartAmmo();
}

/*QUAKED item_spikes (0 .5 .5) (0 0 0) (32 32 32) BIG ? SUSPENDED
25 ammo points (spikes) for Perforator and Super Perforator.

Flags:
"big" gives 50 instead of 25

Keys:
"target/2/3/4/k" - entity to trigger when picked up
"targetname" - will not spawn until triggered
"wait" - will respawn after 'wait' seconds. fires targets every time.
"count" - limit number of times to respawn
*/
/*FGD
@PointClass base(Ammo) 
    model(
        {{
            spawnflags & 1 ->   ":maps/b_nail1.bsp",
                                ":maps/b_nail0.bsp"
        }}
    ) = item_spikes : "Nailgun/Perforator ammo, 25/50" []
*/
void() item_spikes =
{
	if (!SUB_ShouldSpawn()) return;
	if (self.spawnflags & ITEM_AMMO_BIG)
	{
		self.ammo_nails = 50;
		precache_model_safe ("progs/m_nails2.mdl");
		setmodel (self, "progs/m_nails2.mdl");
	}
	else
	{
		self.ammo_nails = 25;
		precache_model_safe ("progs/m_nails1.mdl");
		setmodel (self, "progs/m_nails1.mdl");
	}
	self.weapon = 2;
	self.netname = "nails";
	StartAmmo();
}

/*QUAKED item_rockets (0 .5 .5) (0 0 0) (32 32 32) BIG ? SUSPENDED
3 ammo points (rockets) for the Rocket/Grenade Launcher.

Flags:
"big" gives 6 instead of 3
    
Keys:
"target/2/3/4/k" - entity to trigger when picked up
"targetname" - will not spawn until triggered
"wait" - will respawn after 'wait' seconds. fires targets every time.
"count" - limit number of times to respawn
*/
/*FGD
@PointClass base(Ammo) 
    model(
        {{
            spawnflags & 1 ->   ":maps/b_rock1.bsp",
                                ":maps/b_rock0.bsp"
        }}
    ) =
    item_rockets : "Rockets, 4/8" []
*/
void() item_rockets =
{
	if (!SUB_ShouldSpawn()) return;
	if (self.spawnflags & ITEM_AMMO_BIG)
	{
		self.ammo_rockets = 8;
		precache_model_safe ("progs/m_rock2.mdl");
		setmodel (self, "progs/m_rock2.mdl");
	}
	else
	{
		self.ammo_rockets = 4;
		precache_model_safe ("progs/m_rock1.mdl");
		setmodel (self, "progs/m_rock1.mdl");
	}
	self.weapon = 3;
	self.netname = "rockets";
	StartAmmo();
}

/*QUAKED item_cells (0 .5 .5) (0 0 0) (32 32 32) BIG ? SUSPENDED
6 ammo points (cells) for the  Thunderbolt (Lightning).

Flags:
"big" gives 12 instead of 6
    
Keys:
"target/2/3/4/k" - entity to trigger when picked up
"targetname" - will not spawn until triggered
"wait" - will respawn after 'wait' seconds. fires targets every time.
"count" - limit number of times to respawn
*/
/*FGD
@PointClass base(Ammo) 
    model(
        {{
            spawnflags & 1 ->   ":maps/b_batt1.bsp",
                                ":maps/b_batt0.bsp"
        }}
    ) =
    item_cells : "Thunderbolt Ammo, 6/12 cells" []
*/
void() item_cells =
{
	if (!SUB_ShouldSpawn()) return;
	if (self.spawnflags & ITEM_AMMO_BIG)
	{
		self.ammo_cells = 12;
		precache_model_safe ("progs/m_cells2.mdl");
		setmodel (self, "progs/m_cells2.mdl");
	}
	else
	{
		self.ammo_cells = 6;
		precache_model_safe ("progs/m_cells1.mdl");
		setmodel (self, "progs/m_cells1.mdl");
	}
	self.weapon = 4;
	self.netname = "cells";
	StartAmmo();
}



// ================================


// still used in a few id maps, bleh
void() item_weapon =
{
	float WEAPON_SHOTGUN = 1;
	float WEAPON_ROCKET = 2;
	float WEAPON_SPIKES = 4;
	float WEAPON_BIG = 8;
	
	float oldflags;
	oldflags = self.spawnflags & 15;
	self.spawnflags = not(self.spawnflags, 15);
	
	if (oldflags & WEAPON_BIG)
		self.spawnflags = self.spawnflags | ITEM_AMMO_BIG;
	
	if (oldflags & WEAPON_SHOTGUN)
		item_shells();
	else if (oldflags & WEAPON_SPIKES)
		item_spikes();
	else if (oldflags & WEAPON_ROCKET)
		item_rockets();
};