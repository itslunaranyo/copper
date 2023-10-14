/*
===============================================================================

PLAYER WEAPONS

individual weapons moved to their own files, as this one was getting long

===============================================================================
*/


// called by worldspawn
void() W_Precache =
{
	precache_sound ("weapons/r_exp3.wav");
	precache_sound ("weapons/rocket1i.wav");	// nailgun
	precache_sound ("weapons/sgun1.wav");
	precache_sound ("weapons/guncock.wav");		// sg
	precache_sound ("weapons/ric1.wav");		// ricochet (used in c code)
	precache_sound ("weapons/ric2.wav");		// ricochet (used in c code)
	precache_sound ("weapons/ric3.wav");		// ricochet (used in c code)
	precache_sound ("weapons/spike2.wav");		// super spikes
	precache_sound ("weapons/tink1.wav");		// spikes tink (used in c code)
	precache_sound ("weapons/grenade.wav");		// grenade launcher
	precache_sound ("weapons/bounce.wav");		// grenade bounce
	precache_sound ("weapons/shotgn2.wav");		// ssg
	precache_model2 ("progs/k_spike.mdl");
	precache_model ("progs/lavaball.mdl");	
	precache_sound ("weapons/lhit.wav");		//lightning
	precache_sound ("weapons/lstart.wav");		//lightning start
//	precache_sound ("items/damage3.wav");

// ax sounds	
	precache_sound ("weapons/ax1.wav");			// ax swoosh
	precache_sound2 ("weapons/axhit1.wav");		// ax hit meat
	precache_sound2 ("weapons/axhit2.wav");		// ax hit meat 2
	precache_sound ("player/axhit1.wav");		// ax hit me
	precache_sound ("player/axhit2.wav");		// ax hit world
	
	precache_sound ("zombie/z_hit.wav");
	
	

	precache_model ("progs/v_axe2.mdl");
	precache_model ("progs/v_shot.mdl");
	precache_model ("progs/v_nail.mdl");
	precache_model ("progs/v_rock.mdl");
	precache_model ("progs/v_shot2.mdl");
	precache_model ("progs/v_nail2.mdl");
	precache_model ("progs/v_rock2.mdl");
	precache_model ("progs/v_light.mdl");

}



/*
========
SuperDamageSound
========
*/
void() SuperDamageSound =
{
	if (!has_quad(self)) return;
	if (self.super_damage_finished < time + 3) return;
	if (self.super_sound < time)
	{
		self.super_sound = time + 0.9;
		sound (self, CHAN_POWERUP, "items/damage3.wav", 1, ATTN_NORM);
	}
}

void() W_SetIdleWeaponFrame =
{
	self.weaponframe = 0;
}

void() W_SetCurrentAmmo =
{
	self.items = self.items - ( self.items & (IT_SHELLS | IT_NAILS | IT_ROCKETS | IT_CELLS) );
	
	if (self.weapon == IT_SHOTGUN || self.weapon == IT_SUPER_SHOTGUN)
	{
		self.currentammo = self.ammo_shells;
		self.items = self.items | IT_SHELLS;
	}
	else if (self.weapon == IT_NAILGUN || self.weapon == IT_SUPER_NAILGUN)
	{
		self.currentammo = self.ammo_nails;
		self.items = self.items | IT_NAILS;
	}
	else if (self.weapon == IT_GRENADE_LAUNCHER || self.weapon == IT_ROCKET_LAUNCHER)
	{
		self.currentammo = self.ammo_rockets;
		self.items = self.items | IT_ROCKETS;
	}
	else if (self.weapon == IT_LIGHTNING)
	{
		self.currentammo = self.ammo_cells;
		self.items = self.items | IT_CELLS;
	}
	else	// axes, etc
	{
		self.currentammo = 0;
	}
}

void() W_ResetWeaponState =
{
	player_run ();		// get out of any weapon firing states

	self.weaponframe = 0;
	//self.attack_finished = 0;	// don't lose attack debounce time from last attack,
		// if any, or picking up/switching weapons can cause double attacks
	
	if (self.weapon == IT_AXE )
		self.weaponmodel = "progs/v_axe2.mdl";
	else if (self.weapon == IT_SHOTGUN)
		self.weaponmodel = "progs/v_shot.mdl";
	else if (self.weapon == IT_SUPER_SHOTGUN)
		self.weaponmodel = "progs/v_shot2.mdl";
	else if (self.weapon == IT_NAILGUN)
		self.weaponmodel = "progs/v_nail.mdl";
	else if (self.weapon == IT_SUPER_NAILGUN)
		self.weaponmodel = "progs/v_nail2.mdl";
	else if (self.weapon == IT_GRENADE_LAUNCHER)
		self.weaponmodel = "progs/v_rock.mdl";
	else if (self.weapon == IT_ROCKET_LAUNCHER)
		self.weaponmodel = "progs/v_rock2.mdl";
	else if (self.weapon == IT_LIGHTNING)
		self.weaponmodel = "progs/v_light.mdl";
	else
		self.weaponmodel = string_null;

	W_SetCurrentAmmo();
}

float(float w) W_RankForWeapon =
{
	if (!w)
		return 666;
	if (w == IT_LIGHTNING)
		return 1;
	if (w == IT_ROCKET_LAUNCHER)
		return 2;
	if (w == IT_SUPER_NAILGUN)
		return 3;
	if (w == IT_GRENADE_LAUNCHER)
		return 4;
	if (w == IT_SUPER_SHOTGUN)
		return 5;
	if (w == IT_NAILGUN)
		return 6;
	return 7;
}

/*
=============
W_BetterWeapon

Deathmatch weapon change rules for picking up a weapon
=============
*/
void(float new) W_BetterWeapon =
{
	if (!deathmatch)
	{
		// don't switch to explosive weapons with quad
		// 1.12: don't switch to explosives when invisible either, since you can't see the stupid viewmodel
		if ( (has_quad(self) || has_invis(self)) &&
			(new == IT_ROCKET_LAUNCHER || new == IT_GRENADE_LAUNCHER))
			return;
		// don't switch to a lightning gun when standing in water
		if (self.waterlevel >= 2 && new == IT_LIGHTNING)
			return;
	}	
	if (!deathmatch || W_RankForWeapon (new) < W_RankForWeapon (self.weapon) )
		self.weapon = new;
	W_ResetWeaponState();
}

float(float weap) W_HasAmmo =
{
	if (self.items & weap == 0) return FALSE;
	if (weap == IT_AXE) return TRUE;
	
	if (weap == IT_SUPER_SHOTGUN)	return (self.ammo_shells >= 2);
	if (weap == IT_SHOTGUN)			return (self.ammo_shells >= 1);
	if (weap == IT_NAILGUN)			return (self.ammo_nails >= 1);
	if (weap == IT_SUPER_NAILGUN)	return (self.ammo_nails >= 2);
	if (weap == IT_LIGHTNING)		return (self.ammo_cells >= 1);
	
	if (weap == IT_GRENADE_LAUNCHER || weap == IT_ROCKET_LAUNCHER)
		return (self.ammo_rockets >= 1);
		
	return FALSE;
}

float() W_BestWeapon =
{
	self.lip = 0;	// reset nailgun barrel cycle
	
	if(W_HasAmmo(IT_SUPER_NAILGUN))
		return IT_SUPER_NAILGUN;
	if(W_HasAmmo (IT_SUPER_SHOTGUN))
		return IT_SUPER_SHOTGUN;
	if (self.waterlevel <= 1 && W_HasAmmo(IT_LIGHTNING))
		return IT_LIGHTNING;
	if(W_HasAmmo(IT_NAILGUN))
		return IT_NAILGUN;
	if(W_HasAmmo(IT_SHOTGUN))
		return IT_SHOTGUN;
	if (self.items & IT_AXE)
		return IT_AXE;
	return 0;
}

void() W_SelectBestWeapon =
{
	self.weapon = W_BestWeapon();
	W_ResetWeaponState();
}

void() W_SelectBestShotgun =
{
	if (self.items & (IT_SHOTGUN|IT_SUPER_SHOTGUN))
	{
		if (W_HasAmmo(IT_SUPER_SHOTGUN))
		{
			self.weapon = IT_SUPER_SHOTGUN;
			W_ResetWeaponState();
		}
		else if (W_HasAmmo(IT_SHOTGUN))
		{
			self.weapon = IT_SHOTGUN;
			W_ResetWeaponState();
		}
		else sprint (self, "not enough ammo.\n");
	}
	else
	{
		sprint(self, "no weapon.\n");
	}
}

void() W_SelectBestNailgun =
{
	if (self.items & (IT_NAILGUN|IT_SUPER_NAILGUN))
	{
		if (W_HasAmmo(IT_SUPER_NAILGUN))
		{
			self.weapon = IT_SUPER_NAILGUN;
			W_ResetWeaponState();
		}
		else if (W_HasAmmo(IT_NAILGUN))
		{
			self.weapon = IT_NAILGUN;
			W_ResetWeaponState();
		}
		else sprint (self, "not enough ammo.\n");
	}
	else
	{
		sprint(self, "no weapon.\n");
	}
}

/*
============
W_Attack

An attack impulse can be triggered now
============
*/
void() W_Attack =
{
	if (!W_HasAmmo(self.weapon))
	{
		W_SelectBestWeapon();
		return;
	)
	if (self.customflags & (CFL_PLUNGE|CFL_LIMBO))
		return;
//	if (self.movetype == MOVETYPE_NOCLIP)
//		return;

	makevectors	(self.v_angle);			// calculate forward angle for velocity

	if (self.weapon == IT_AXE)
	{
		player_axe();
		W_AxeSwing();
		return;
	}
	
	// moved after axe so that silent swings don't wake monsters
	self.show_hostile = time + 1;
	
	if (self.weapon == IT_SHOTGUN)
	{
		player_shot1 ();
		W_FireShotgun ();
	}
	else if (self.weapon == IT_SUPER_SHOTGUN)
	{
		player_shot1 ();
		W_FireSuperShotgun ();
	}
	else if (self.weapon == IT_NAILGUN || self.weapon == IT_SUPER_NAILGUN)
	{
		player_nail();
		W_FireSpikes ();
	}
	else if (self.weapon == IT_GRENADE_LAUNCHER)
	{
		player_rocket1();
		W_FireGrenade();
	}
	else if (self.weapon == IT_ROCKET_LAUNCHER)
	{
		player_rocket1();
		W_FireRocket();
	}

	else if (self.weapon == IT_LIGHTNING)
	{
		player_light1();
		self.attack_finished = time + 0.1;
		sound (self, CHAN_AUTO, "weapons/lstart.wav", 1, ATTN_NORM);
	}
}

/*
============
W_ChangeWeapon
============
*/
void() W_ChangeWeapon =
{
	local	float	it, am, fl;
	
	if (self.customflags & CFL_PLUNGE)
		return;
		
	it = self.items;
	am = 0;
	
	if (self.impulse == 1)
	{
			fl = IT_AXE;
	}
	else if (self.impulse == 2)
	{
		fl = IT_SHOTGUN;
		if (self.ammo_shells < 1)
			am = 1;
	}
	else if (self.impulse == 3)
	{
		fl = IT_SUPER_SHOTGUN;
		if (self.ammo_shells < 2)
			am = 1;
	}		
	else if (self.impulse == 4)
	{
		fl = IT_NAILGUN;
		if (self.ammo_nails < 1)
			am = 1;
	}
	else if (self.impulse == 5)
	{
		fl = IT_SUPER_NAILGUN;
		if (self.ammo_nails < 2)
			am = 1;
	}
	else if (self.impulse == 6)
	{
		fl = IT_GRENADE_LAUNCHER;
		if (self.ammo_rockets < 1)
			am = 1;
	}
	else if (self.impulse == 7)
	{
		fl = IT_ROCKET_LAUNCHER;
		if (self.ammo_rockets < 1)
			am = 1;
	}
	else if (self.impulse == 8)
	{
		fl = IT_LIGHTNING;
		if (self.ammo_cells < 1)
			am = 1;
	}

	self.impulse = 0;
	
	if (!(self.items & fl))
	{	// don't have the weapon or the ammo
		sprint (self, "no weapon.\n");
		return;
	}
	
	if (am)
	{	// don't have the ammo
		sprint (self, "not enough ammo.\n");
		return;
	}

	self.weapon = fl;		
	W_ResetWeaponState();
}

/*
============
Weapon Cycling

for players who insist on shuffling through their inventory the slow way
============
*/
float W_Next(float w) =
{
	if (w == IT_AXE) return IT_SHOTGUN;
	else if (w == IT_LIGHTNING) return IT_AXE;
	else return w * 2;
}

float W_Prev(float w) =
{
	if (w == IT_SHOTGUN) return IT_AXE;
	else if (w == IT_AXE) return IT_LIGHTNING;
	else return w / 2;
}

// cycle weapon up
void() CycleWeaponCommand =
{
	float weap = self.weapon;
	self.impulse = 0;
	if (!weap)
		weap = W_BestWeapon();
	else do {
		weap = W_Next(weap);
		if (self.items & weap && W_HasAmmo(weap))
			break;
	} while (weap != self.weapon);
	self.weapon = weap;
	W_ResetWeaponState ();
}

// cycle weapon down
void() CycleWeaponReverseCommand =
{
	float weap = self.weapon;
	self.impulse = 0;
	if (!weap)
		weap = W_BestWeapon();
	else do {
		weap = W_Prev(weap);
		if (self.items & weap && W_HasAmmo(weap))
			break;
	} while (weap != self.weapon);
	self.weapon = weap;
	W_ResetWeaponState ();
}

/*
============
W_WeaponFrame

Called every frame so impulse events can be handled as well as possible
============
*/
void() W_WeaponFrame =
{
	if (self.impulse)
		ImpulseCommands();
	if (time < self.attack_finished)
		return;

	// check for attack
	if (self.button0)
	{
		SuperDamageSound ();
		W_Attack ();
	}
}

// impulses also moved to their own file
