/*
==============================================================================

IMPULSES

==============================================================================
*/

// --------------------------------
// Cheat_Keys
// --------------------------------
void() Cheat_Keys =
{
	if(deathmatch || coop)
		return;

	key_give_silver(self);
	key_give_gold(self);
	stuffcmd(self,"bf\n");
}


// --------------------------------
// Cheat_Items
// --------------------------------
void() Cheat_Items =
{
	if(deathmatch || coop)
		return;

	self.ammo_shells = MAX_AMMO_SHELLS;
	self.ammo_nails = MAX_AMMO_NAILS;
	self.ammo_rockets = MAX_AMMO_ROCKETS;
	self.ammo_cells = MAX_AMMO_CELLS;
	
	self.items = self.items |
	//	IT_KEY1 | IT_KEY2 | 
		IT_AXE |
		IT_SHOTGUN |
		IT_SUPER_SHOTGUN |
		IT_NAILGUN |
		IT_SUPER_NAILGUN |
		IT_GRENADE_LAUNCHER |
		IT_ROCKET_LAUNCHER;

	self.items = self.items | IT_LIGHTNING;

	W_SetCurrentAmmo();
	W_Select(IT_ROCKET_LAUNCHER);

	stuffcmd(self,"bf\n");
}

// --------------------------------
// Cheat_Genocide
// --------------------------------
void() Cheat_Genocide =
{
	entity t;
	
	t = nextent(world);	
	while(t != world)
	{
		// these monsters haven't spawned yet, turn them into relays so their 
		// deathtargets fire as soon as they're triggered and their absence doesn't
		// break the level
		if(t.customflags & CFL_SPAWNER || t.spawnflags & SPAWN_TRIGGERED)
		{
			t.classname = "trigger_relay";
			t.count = 0;
			t.use = trigger_relay_use;
			t.spawnflags = 0;
		}
		t = nextent(t);
	}
	// kill existing monsters second, so that any monsters triggered by other monsters
	// are already de-monsterized
	t = nextent(world);
	while(t != world)
	{
		if(t.flags & FL_MONSTER)
		{
			// don't forget monsters on the verge of spawning
			if (t.think == mon_spawner_tryspawn || t.modelindex == 0 || t.classname == string_null )
				remove(t);
			else
				T_Damage(t, self, self, t.health, DMGTYPE_SCRIPT);		// waurgh
		}
		t = nextent(t);
	}
}

// --------------------------------
// Cheat_Undying
// --------------------------------
void() Cheat_Undying =
{
	if(deathmatch || coop)
		return;
	if(self.customflags & CFL_UNDYING)
	{
		sprint(self, "Undying mode disabled\n");
		self.customflags = not(self.customflags, CFL_UNDYING);
		return;
	}
	sprint(self, "Undying mode enabled\n");
	self.customflags |= CFL_UNDYING;
}


// --------------------------------
// Cheat_Quad
// --------------------------------
void() Cheat_Quad =
{
	if(deathmatch || coop)
		return;
	stuffcmd(self, "bf\n");
	self.items = self.items | IT_QUAD;
	powerup_super_damage(self, 30);
}

// --------------------------------
// Cheat_Pent
// --------------------------------
void() Cheat_Pent =
{
	if(deathmatch || coop)
		return;
	stuffcmd(self, "bf\n");
	self.items = self.items | IT_INVULNERABILITY;
	powerup_invulnerability(self, 30);
}

// --------------------------------
// Cheat_Ring
// --------------------------------
void() Cheat_Ring =
{
	if(deathmatch || coop)
		return;
	stuffcmd(self, "bf\n");
	self.items = self.items | IT_INVISIBILITY;
	powerup_invisibility(self, 30);
}

// --------------------------------
// Cheat_Suit
// --------------------------------
void() Cheat_Suit =
{
	if(deathmatch || coop)
		return;
	stuffcmd(self, "bf\n");
	self.items = self.items | IT_SUIT;
	powerup_envirosuit(self, 30);
}

// --------------------------------
// ServerflagsCommand
// --------------------------------
void() ServerflagsCommand =
{
	serverflags = serverflags * 2 + 1;
	dev_serverflags();
};


// --------------------------------
// ImpulseCommands
// --------------------------------
void() ImpulseCommands =
{
	if (!self.impulse) return;
	
	if (self.impulse < 9)
	{
		W_ChangeWeapon();
	}
	else if (self.impulse >= 20 && self.impulse <= 39)
	{
		dev_impulse(self.impulse);
	}
	else switch(self.impulse)
	{
	case 10:
		CycleWeaponCommand();
		break;
	case 12:
		CycleWeaponReverseCommand();
		break;
	case 11:
		ServerflagsCommand();
		break;
	case 13:
		W_SelectBestShotgun();
		break;
	case 14:
		W_SelectBestNailgun();
		break;
	case 15:
		W_SelectBestWeapon();
		break;
	case 16:
		W_SelectLastWeapon();
		break;

	case 40:
		dev_impulse_list();
		break;
	case 64:
		dev_i_cant_see();
		break;
	case 72:
		dev_test();
		break;
	case 80:
		dev_add_meatball();
		break;
	case 81:
		dev_remove_meatball();
		break;
	case 100:
		dev_invoke();
		break;
	case 101:
		dev_reveal();
		break;
	case 102:
		dev_trigger();
		break;
	case 103:
		dev_hitpoints();
		break;
	case 104:
		dev_serverflags();
		break;
	case 105:
		dev_warp();
		break;
	case 106:
		dev_whatami();
		break;
	case 108:
		dev_tracetest();
		break;
	case 127:
	case 129:
		coredump();
		break;
	
	case 140:
		sound(self, CHAN_VOICE, "player/tornoff2.wav", 1, ATTN_STATIC);
		centerprint(self, version_s);
		break;
	
	case 9:
		Cheat_Items();
		break;
	case 99:
		Cheat_Keys();
		break;
	// how about, execute order six?
	// nah. makes it sound like there aren't that many orders
	case 66:
	case 205:
		if(!deathmatch && !coop)
			Cheat_Genocide();
		break;
	case 200:
		dev_remaining_monsters();
		break;
	case 210:
		toggle_autosave();
		break;
	case 215:
		Cheat_Undying();
		break;
	case 225: 
		Cheat_Suit();
		break;
	case 235:
		Cheat_Pent();	
		break;
	case 245:
		Cheat_Ring();	
		break;
	case 255:
		Cheat_Quad();	
		break;
		
	default:
		return;
	}
	
	self.impulse = 0;
}
