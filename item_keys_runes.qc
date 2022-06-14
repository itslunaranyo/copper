/*
===============================================================================

KEYS

we use .worldtype on the player to store number of keys: first 4 bits are silver keys, 
next higher 4 bits are golds

15 of each key is well above the number of keys a mapper should expect a player to collect

===============================================================================
*/

float(entity cl) key_count_silver =
{
	if (!(cl.items & IT_KEY1))
		return 0;
	return (cl.worldtype & 15);
}

float(entity cl) key_count_gold =
{
	if (!(cl.items & IT_KEY2))
		return 0;
	return (cl.worldtype & 240)/16;
}

float(entity cl) key_give_silver =
{
	if (!(cl.items & IT_KEY1))
	{
		sprint (cl, "You got the Silver Key\n");

		cl.items |= IT_KEY1;
		cl.worldtype += 1;
		return TRUE;
	}
		
	if (cl.worldtype & 15 == 15)
		return FALSE;	// we're full
		
	cl.worldtype += 1;
	sprint (cl, "You have ");
	sprint (cl, ftos(cl.worldtype & 15));
	sprint (cl, " Silver Keys\n");
	
	return TRUE;
}

float(entity cl) key_take_silver =
{
	if (!(cl.items & IT_KEY1))
	{
		return FALSE;	// we're dry
	}
	
	cl.worldtype -= 1;
	if (cl.worldtype & 15 == 0)
	{
		cl.items = not(cl.items, IT_KEY1);
		return TRUE;
	}
	
	float keys = (cl.worldtype & 15);
	sprint (cl, "You have ");
	sprint (cl, ftos(keys));
	if (keys > 1)
		sprint (cl, " Silver Keys left\n");
	else
		sprint (cl, " Silver Key left\n");
	
	return TRUE;
}


float(entity cl, float num) key_take_silvers =
{
	if (key_count_silver(cl) < num)
	{
		return FALSE;	// we're dry
	}
	
	cl.worldtype -= num;
	if (cl.worldtype & 15 == 0)
	{
		cl.items = not(cl.items, IT_KEY1);
		return TRUE;
	}
	
	float keys = (cl.worldtype & 15);
	sprint (cl, "You have ");
	sprint (cl, ftos(keys));
	if (keys > 1)
		sprint (cl, " Silver Keys left\n");
	else
		sprint (cl, " Silver Key left\n");
	
	return TRUE;
}

float(entity cl) key_give_gold =
{
	if (!(cl.items & IT_KEY2))
	{
		sprint (cl, "You got the Gold Key\n");

		cl.items |= IT_KEY2;
		cl.worldtype += 16;
		return TRUE;
	}
		
	if (cl.worldtype & 240 == 240)
		return FALSE;	// we're full
	
	cl.worldtype += 16;
	sprint (cl, "You have ");
	sprint (cl, ftos((cl.worldtype & 240)/16));
	sprint (cl, " Gold Keys\n");
	
	return TRUE;
}

float(entity cl) key_take_gold =
{
	if (!(cl.items & IT_KEY2))
	{
		return FALSE;	// we're dry
	}
	
	cl.worldtype -= 16;
	if (cl.worldtype & 240 == 0)
	{
		cl.items = not(cl.items, IT_KEY2);
		return TRUE;
	}
	
	float keys = (cl.worldtype & 240)/16;
	sprint (cl, "You have ");
	sprint (cl, ftos(keys));
	if (keys > 1)
		sprint (cl, " Gold Keys left\n");
	else
		sprint (cl, " Gold Key left\n");
	
	return TRUE;
}

float(entity cl, float num) key_take_golds =
{
	if (key_count_gold(cl) < num)
	{
		return FALSE;	// we're dry
	}
	
	cl.worldtype -= 16 * num;
	if (cl.worldtype & 240 == 0)
	{
		cl.items = not(cl.items, IT_KEY2);
		return TRUE;
	}
	
	float keys = (cl.worldtype & 240)/16;
	sprint (cl, "You have ");
	sprint (cl, ftos(keys));
	if (keys > 1)
		sprint (cl, " Gold Keys left\n");
	else
		sprint (cl, " Gold Key left\n");
	
	return TRUE;
}

void() key_touch =
{
	if (!CheckValidTouch()) return;

	float gave = FALSE;
	
	if (self.items == IT_KEY1)
	{
		gave = key_give_silver(other);
	}
	else if (self.items == IT_KEY2)
	{
		gave = key_give_gold(other);
	}
	
	if (!gave) return;
	//if (other.items & self.items) return;
	
	sound (other, CHAN_ITEM, self.noise, 1, ATTN_NORM);
	stuffcmd (other, "bf\n");
	//other.items = other.items | self.items;

//	if (!coop)
//	{	
		self.solid = SOLID_NOT;
		self.model = string_null;
//	}

	activator = other;
	SUB_UseTargets();				// fire all targets / killtargets
}

string() key_sound =
{
	if (world.worldtype == 1)
		return "misc/runekey.wav";
	if (world.worldtype == 2)
		return "misc/basekey.wav";

	return "misc/medkey.wav";
}

void() key_setsounds =
{
	string key = key_sound();
	precache_sound_safe (key);
	self.noise = key;
}

/*QUAKED item_key1 (0 .5 .5) (-16 -16 -24) (16 16 32) ? ? SUSPENDED
Silver key. In order for keys to work you MUST set your maps worldtype (see worldspawn).

Keys:
"target"		fired when picked up
*//*
"skin"			flavor
0 = Silver
2 = Iron
4 = Pewter
6 = Lead
*/
/*FGD
@PointClass size(-16 -16 -24, 16 16 32) base(Item) model({ "path": ":progs/w_s_key.mdl" }) = 
	item_key1 : "Silver Key" []
*/
void() item_key1 =
{
	if (!SUB_ShouldSpawn()) return;
	if (world.worldtype == 0)
	{
		precache_model_safe ("progs/m_key.mdl");
		setmodel (self, "progs/m_key.mdl");
		self.netname = "silver key";
		self.skin = 0;
	}
	else if (world.worldtype == 1)
	{
		precache_model_safe ("progs/r_key.mdl");
		setmodel (self, "progs/r_key.mdl");
		self.netname = "silver runekey";
		self.skin = 0;
	}
	else if (world.worldtype == 2)
	{
		precache_model2_safe ("progs/b_s_key.mdl");
		setmodel (self, "progs/b_s_key.mdl");
		self.netname = "silver keycard";
	}
	key_setsounds();
	self.touch = key_touch;
	self.items = IT_KEY1;
	setsize (self, '-16 -16 -24', '16 16 32');
	StartItem ();
}

/*QUAKED item_key2 (.5 .5 0) (-16 -16 -24) (16 16 32) ? ? SUSPENDED
Gold key. In order for keys to work you MUST set your maps worldtype (see worldspawn).

Keys:
"target"		fired when picked up
*//*
"skin"			flavor
1 = Gold
3 - Copper
5 = Bronze
7 = Brass
*/
/*FGD
@PointClass size(-16 -16 -24, 16 16 32) base(Item) model({ "path": ":progs/w_g_key.mdl" }) = 
	item_key2 : "Gold Key" []
*/
void() item_key2 =
{
	if (!SUB_ShouldSpawn()) return;
	if (world.worldtype == 0)
	{
		precache_model_safe ("progs/m_key.mdl");
		setmodel (self, "progs/m_key.mdl");
		self.netname = "gold key";
		self.skin = 1;
	}
	else if (world.worldtype == 1)
	{
		precache_model_safe ("progs/r_key.mdl");
		setmodel (self, "progs/r_key.mdl");
		self.netname = "gold runekey";
		self.skin = 1;
	}
	if (world.worldtype == 2)
	{
		precache_model2_safe ("progs/b_g_key.mdl");
		setmodel (self, "progs/b_g_key.mdl");
		self.netname = "gold keycard";
	}
	key_setsounds();
	self.touch = key_touch;
	self.items = IT_KEY2;
	setsize (self, '-16 -16 -24', '16 16 32');
	StartItem ();
}


/*
===============================================================================

RUNES

===============================================================================
*/

void() sigil_touch =
{
	if (!CheckValidTouch()) return;

	self.solid = SOLID_NOT;
	self.model = string_null;
	serverflags |= self.svflags;
	self.classname = string_null;		// so rune doors won't find it
	
	
	activator = other;
	SUB_UseTargets();				// fire all targets / killtargets
	
	centerprint (other, self.message);
	sound (other, CHAN_ITEM, self.noise, 1, ATTN_NORM);
	stuffcmd (other, "bf\n");
}


/*QUAKED item_sigil (0 .5 .5) (-16 -16 -24) (16 16 32) E1 E2 E3 E4 SUSPENDED
End of episode sigil. Can be customized through keyvalue manipulation to serve as any generic cross-map inventory item.

Flags:
"E1 -E4" sets episode
"SUSPENDED" do not drop to floor on spawn

Keys:
"noise" override pickup noise
"svflags" set a serverflag other than the episode 1-4 flags on pickup
"model" specify any model
"message" override pickup message
"target" entity to trigger when picked up
"targetname" entity name
*/
/*FGD
@PointClass size(-16 -16 -24, 16 16 32) base(Item) model({ "path": ":progs/end1.mdl" }) = 
	item_sigil : "End of episode rune"
[
	spawnflags(Flags) =
	[
		1 : "Episode 1" : 1
		2 : "Episode 2" : 0
		4 : "Episode 3" : 0
		8 : "Episode 4" : 0
		16 : "Suspended" : 0
	]
]
*/
void() item_sigil =
{
	if (!SUB_ShouldSpawn()) return;
	if (!self.spawnflags)
		objerror("no spawnflags");

	if (!self.noise)
		self.noise = "misc/runekey.wav";
	precache_sound_safe (self.noise);

	string msg;
	msg = "You got the rune!";
	
	if (self.spawnflags & 8)
	{
		precache_model2_safe ("progs/end4.mdl");
		setmodel (self, "progs/end4.mdl");
		msg = "You got the rune\n of Elder Magic!";
		self.svflags = 8;
	}
	else if (self.spawnflags & 4)
	{
		precache_model2_safe ("progs/end3.mdl");
		setmodel (self, "progs/end3.mdl");
		msg = "You got the rune\n of Hell Magic!";
		self.svflags = 4;
	}
	else if (self.spawnflags & 2)
	{
		precache_model2_safe ("progs/end2.mdl");
		setmodel (self, "progs/end2.mdl");
		msg = "You got the rune\n of Black Magic!";
		self.svflags = 2;
	}
	else if (self.spawnflags & 1)
	{
		precache_model_safe ("progs/end1.mdl");
		setmodel (self, "progs/end1.mdl");
		msg = "You got the rune\n of Earth Magic!";
		self.svflags = 1;
	}
	else
	{
		if (!self.model)
			self.model = "progs/end1.mdl";
		precache_model2_safe(self.model);
		setmodel(self, self.model);
		if (!self.svflags)
			self.svflags = 16;
	}
	
	if (self.message == string_null)
		self.message = msg;
	
	// rearrange extra spawnflags so they align with other items
	self.spawnflags = not(self.spawnflags, SVFL_ALLEPISODES);
	if (self.spawnflags & 16)
		self.spawnflags = self.spawnflags - 16 + ITEM_SUSPENDED;
	self.touch = sigil_touch;
	setsize (self, '-16 -16 -24', '16 16 32');
	StartItem ();
}
