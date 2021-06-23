/*
==============================================================================

TELEPORT TRIGGERS

all teleport functionality handled by one function, to allow me to invoke
teleports with a couple different entities that don't replicate each other's
code

==============================================================================
*/

float	TELEPORT_PLAYER_ONLY	= 1;
float	TELEPORT_SILENT			= 2;
float	TELEPORT_PUSH			= 2;
float	TELEPORT_TRIGGER_FIRST	= 4;
float	TELEPORT_NOTRIGGER		= 8;
float	TELEPORT_NOFLASH		= 16;
float	TELEPORT_MONSTER_ONLY	= 32;

// --------------------------------

void() teleport_flash = 
{
	local	float v;
	local	string snd;
	v = random() * 5;
	if (v < 1)
		snd = "misc/r_tele1.wav";
	else if (v < 2)
		snd = "misc/r_tele2.wav";
	else if (v < 3)
		snd = "misc/r_tele3.wav";
	else if (v < 4)
		snd = "misc/r_tele4.wav";
	else
		snd = "misc/r_tele5.wav";

	sound (self, CHAN_VOICE, snd, 1, ATTN_NORM);

	WriteByte (MSG_BROADCAST, SVC_TEMPENTITY);
	WriteByte (MSG_BROADCAST, TE_TELEPORT);
	WriteCoord (MSG_BROADCAST, self.origin_x);
	WriteCoord (MSG_BROADCAST, self.origin_y);
	WriteCoord (MSG_BROADCAST, self.origin_z);
}

// player teleports are the only case we don't want to play the tflash right on
// an entity, so teleport_flash still accepts an entity argument and we just make
// a temp entity for it in this single case
// arguably not at all better than changing teleport_flash to accept a vector arg
// but we need an ent to play the sound on anyway
void() teleport_flasher =
{
	teleport_flash();
	remove(self);
}

void(float d) teleport_flash_delay = 
{
	entity flash;
	if (d)
	{
		flash = spawn();
		setorigin(flash, self.origin);
		flash.think = teleport_flasher;
		flash.nextthink = time + d;
		return;
	}
	teleport_flash();
}



/*
================================
TELEPORT LIMBO

not telefragging teammates in coop sometimes cannot be avoided (spawning in
the wrong place, or falling into a func_void two at a time)

instead clients will disappear into 'teleport limbo' if they would telefrag 
a teammate upon arrival, seeing a black screen until the destination is clear

a trigger_push is spawned at the destination to nudge players, but if this 
doesn't work after 1 second of waiting, the teleporting player can press jump
or fire to force a telefrag. after 5 seconds it happens automatically.
================================
*/
void(entity client, entity dst, float tfog, float nofwd) teleport_enter_limbo =
{
	ClearItemEffects(client);	// remove powerups to clear glows/tints
	TintScreen(client, 255);
	
	client.flags |= FL_NOTARGET;
	client.customflags |= CFL_LIMBO;
	client.takedamage = DAMAGE_NO;
	client.solid = SOLID_NOT;
	client.movetype = MOVETYPE_NONE;
	client.goalentity = dst;
	client.dest = Vector(tfog, nofwd, 0);	// z is for the 'force' flag
	client.velocity = VEC_ORIGIN;

	client.model = string_null;
	
	client.attack_finished = time + 1;	// allow forcing a telefrag after 1000ms
	client.search_time = time + 0.1;
	
	spawn_tpush(dst, client);	// gust of wind at the spot to hasten the process
}

void(entity client) teleport_exit_limbo =
{
	TintScreen(client, 0);
	RestoreItemEffects(client);
	
	client.flags = not(client.flags, FL_NOTARGET);
	client.customflags = not(client.customflags, CFL_LIMBO);
	client.takedamage = DAMAGE_AIM;
	client.solid = SOLID_SLIDEBOX;
	client.movetype = MOVETYPE_WALK;
	
	self.attack_finished = time + 0.1;	// don't shoot on the first frame
	client.dest = VEC_ORIGIN;

	if (has_invis(client))
	{
		client.modelindex = modelindex_eyes;
		client.model = "progs/eyes.mdl";
	}
	else
	{
		client.modelindex = modelindex_player;
		client.model = "progs/player.mdl";
	}
}

void() teleport_limbo_think =
{
	// self is the player in limbo
	
	// if it's been a second, check for jump/fire and set force flag
	if (time >= self.attack_finished)
	{
		if (self.button1 || self.button2 || self.button0 ||
			time >= self.attack_finished + 4)	// autoforce after 5 seconds
		{
			self.dest_z = TRUE;
		}		
	}
	
	// keep trying to teleport
	if (time >= self.search_time)
	{
		self.search_time = time + 0.1;
		teleport(self, self.goalentity, self.dest_x, self.dest_y);
	}
}

float(entity spot) teleport_check_for_client =
{
	float cl = 0;
	entity pl = world;
	while (cl < clients)
	{
		pl = find(pl, classname, "player");
		if (!pl) break;
		if (pl.health <= 0 || pl.type == "head") continue;
		if (pl != self)	// players can't block themselves
			if (BoundsTouching(spot.absmin, spot.absmax, pl.absmin, pl.absmax, 2))
				return TRUE;
		
		cl++;
	}
	
	// also check for client owned teledeath here
	pl = world;
	do {
		pl = find(pl, classname, "teledeath");
		if (pl)
			if (pl.owner.classname == "player")
				if (BoundsTouching(spot.absmin, spot.absmax, pl.absmin, pl.absmax, 2))
					return TRUE;				
	} while (pl);
	
	return FALSE;
}




/*
================================
TELEPORT

just call this to teleport something somewhere
================================
*/
void(entity traveler, entity dst, float tfog, float nofwd) teleport =
{
	vector vdir;
	float flash = 3;	// 1 = @org, 2 = @dest, 3 = both

	// telefrag protection in /*no-friendly-fire*/ coop
	if (coop)// && teamplay)
	{
		if (teleport_check_for_client(dst))
		{
			if (!(traveler.customflags & CFL_LIMBO))
			{
				teleport_enter_limbo(traveler, dst, tfog, nofwd);
				flash = 1;
			}
			else if (traveler.dest_z != 0)
			{
				teleport_exit_limbo(traveler);
				flash = 2;
			}
			else return;	// stay in limbo
		}
		else if (traveler.customflags & CFL_LIMBO)
		{
			teleport_exit_limbo(traveler);
			flash = 2;
		}
	}
	
	if (dst.classname == "misc_teleporttrain")
	{
		if (dst.think1 == fly_idle)
		{
			vdir = vectoangles(dst.origin - traveler.origin);
			nofwd = TRUE;
		}
		else
		{
			vdir = vectoangles(dst.velocity);
		}
		vdir_x = 0;	// null pitch
	}
	else
		vdir = dst.mangle;

	if (tfog)
	{
		entity tport;
		
		if (flash & 1)
			SUB_CallAsSelf(teleport_flash, traveler);	// flash at departure point
		
		if (flash & 2)
		{
			tport = spawn();
			
			// teleport controller's origin is desired teleport flash location on arrival
			if (traveler.classname == "player")
			{
				makevectors (vdir);
				setorigin(tport, dst.origin + v_forward * 16);
			}	
			else
			{
				setorigin(tport, dst.origin);
			}
		
			tport.think = teleport_flasher;
			tport.nextthink = time + 0.05;
		}
	}

	if (traveler.customflags & CFL_LIMBO)
		return;
	
	spawn_tdeath(dst.origin, traveler);

	setorigin(traveler, dst.origin);
	traveler.angles = vdir;
	if (traveler.flags & FL_MONSTER)
	{
		traveler.ideal_yaw = traveler.angles_y;
	}

	if (traveler.classname == "player")
	{
		fog_setFromEnt(traveler, dst);
		traveler.fixangle = 1;		// turn this way immediately
		makevectors (vdir);
		SUB_UseEntTargets(dst);
		
		if (nofwd)
		{
			traveler.velocity = VEC_ORIGIN;
		}
		else
		{
			traveler.teleport_time = time + 0.7;
			traveler.velocity = v_forward * 300;
		}
	}
	else
	{
		traveler.velocity = VEC_ORIGIN;
	}
		
	traveler.flags = not(traveler.flags, FL_ONGROUND);
}

// --------------------------------
// tpush
//
// shove coop players off a teledest as a more neighborly alternative to telefragging them
// --------------------------------
void() tpush_touch =
{
	if (!CheckValidTouch()) return; // don't telepush monsters
	
	if (other == self.owner)
	{
		// our owner has arrived by teleport, tpush no longer needed
		SUB_RemoveSoon();
		return;
	}
	
	// push all clients in coop
	if (time != self.dmgtime)
		if (time < self.attack_finished)
			return;

	other.velocity = self.mangle;
	
	self.dmgtime = time;
	self.attack_finished = time + 0.1;
}

void(entity spot, entity pusher) spawn_tpush =
{
	entity p;
	vector dir;

	p = spawn();
	p.classname = "telepush";
	p.movetype = MOVETYPE_NONE;
	p.solid = SOLID_TRIGGER;
	setsize (p, pusher.mins - '1 1 1', pusher.maxs + '1 1 1');
	setorigin (p, spot.origin);
	if (spot.mangle != VEC_ORIGIN)
		dir = spot.mangle;
	else
		dir = spot.angles;
	makevectors(dir);
	p.mangle = v_forward * 300 + '0 0 50';
	p.touch = tpush_touch;
	p.nextthink = time + 1;
	p.think = SUB_Remove;
	p.owner = pusher;
	
	force_retouch = 2;		// make sure even still objects get hit
}

// --------------------------------
// tdeath
// --------------------------------
void() tdeath_touch =
{
	if (other == self.owner)
		return;

	// original owner of this teledeath has cleared its bounds, and there's 
	// no more danger of overlapping bboxes, so remove it
	if (!BoundsTouching(self.absmin, self.absmax, self.owner.absmin, self.owner.absmax, 2))
	{
		SUB_RemoveSoon();
		return;
	}
	
// frag anyone who teleports in on top of an invincible player
	if (other.classname == "player")
	{
		if (has_invuln(other))
			self.classname = "teledeath2";
		if (self.owner.classname != "player")
		{	// other monsters explode themselves
			T_Damage (self.owner, self, self, 50000);
			return;
		}
	}

	if (other.health)
		T_Damage (other, self, self, 50000);
}

void(vector org, entity death_owner) spawn_tdeath =
{
	local entity	death;

	// dumb hack so the world isn't flooded with a tdeath for every monster at map start
	if (time < 2) return;	
	
	death = spawn();
	death.classname = "teledeath";
	death.movetype = MOVETYPE_NONE;
	death.solid = SOLID_TRIGGER;
	setsize (death, death_owner.mins - '1 1 1', death_owner.maxs + '1 1 1');
	setorigin (death, org);
	death.angles = '0 0 0';
	death.touch = tdeath_touch;
	death.nextthink = time + 0.2;
	death.think = SUB_Remove;
	death.owner = death_owner;
	
	force_retouch = 2;		// make sure even still objects get hit
}

// --------------------------------

void() teleport_touch =
{
	local entity	t;
	if (self.customflags & CFL_LOCKED) return;
	if (other.health <= 0 || other.solid != SOLID_SLIDEBOX) return;	// only teleport living creatures
	if (other.movetype == MOVETYPE_NOCLIP) return;
	if ((self.spawnflags & TELEPORT_PLAYER_ONLY) && (other.classname != "player")) return;
	if ((self.spawnflags & TELEPORT_MONSTER_ONLY) && !(other.flags & FL_MONSTER)) return;

	if ((self.spawnflags & TELEPORT_NOTRIGGER) == 0)
		if (self.targetname != string_null)
			if ((self.spawnflags & TELEPORT_TRIGGER_FIRST) == 0) // not trigger first
				if (self.nextthink < time)
	{
		//dprint3("  teleport with targetname ", self.targetname, " not activated yet, not teleporting\n");
		return;
	}

	t = find (world, targetname, self.target);
	if (!t)
		objerror ("teleporter couldn't find target");

	playercount_convert(count);
	if (!self.count) 
	{
		SUB_RemoveSoon();
		return;
	}
	else if (self.count > 0)
		self.count -= 1;
	
	teleport( other, t, ((self.spawnflags & TELEPORT_NOFLASH) == 0), 0 );
	
	if (t.classname == "misc_teleporttrain")
		return;
	activator = other;
	SUB_UseTargets();
}

// ================================================================


/*QUAKED info_teleport_destination (.75 .25 .85) (-16 -16 0) (16 16 48)
This is the destination marker for a teleporter.

Keys:
"angle" new view angle after teleporting
"targetname" value used by teleporter
"fog_color"/"fog_density" set the fog for anyone teleporting here
*/
/*FGD
@PointClass size(-32 -32 0, 32 32 64) base(Appearflags, Angle, Targetname, Fog) model({ "path": ":progs/player.mdl" }) = info_teleport_destination : "Teleporter destination" []
*/
void() info_teleport_destination =
{
	if (!SUB_ShouldSpawn()) return;

	self.mangle = self.angles;
	self.angles = '0 0 0';
	self.model = string_null;
	self.origin = self.origin + '0 0 27';
	setsize(self,VEC_HULL_MIN,VEC_HULL_MAX);
	if (!self.targetname)
		objerror ("no targetname");
}

// --------------------------------
// info_teleport_target
//
// this entity is handy when activating a big trigger_teleport volume
// to try and teleport something is inconvenient
// --------------------------------

// teleports the activator to this spot
void() teleport_target_use =
{
	if (self.customflags & CFL_LOCKED)
	{
		dprint("  teleport_target is locked: not teleporting\n");
		return;
	}
	
	if (self.spawnflags & TELEPORT_PLAYER_ONLY)
		if (activator.classname != "player")
			return;
	if (self.spawnflags & TELEPORT_MONSTER_ONLY)
		if (!(activator.flags & FL_MONSTER))
			return;
	if (activator.movetype == MOVETYPE_NOCLIP)
		return;
	// only teleport living creatures
	if (activator.health <= 0 || activator.solid != SOLID_SLIDEBOX)
		return;

	playercount_convert(count);
	if (!self.count) 
	{
		SUB_RemoveSoon();
		return;
	}
	else if (self.count > 0)
		self.count -= 1;

	teleport( activator, self, !(self.spawnflags & TELEPORT_NOFLASH), !(self.spawnflags & TELEPORT_PUSH) );
	activator.jump_flag = 0;
}


/*QUAKED info_teleport_target (.5 .75 .25) (-8 -8 -8) (8 8 32) PLAYER_ONLY PUSH TRIGGER_FIRST ? NOFLASH MONSTER_ONLY
This is a usable destination marker that acts as its own teleporter.  When triggered, the activator is teleported to this spot.

Flags:
PLAYER_ONLY		only players will teleport
PUSH			chuck the player forward like a trigger_teleport does
TRIGGER_FIRST	first use turns it on, and every subsequent use teleports
NOFLASH			don't spawn telefog or make noise
MONSTER_ONLY	only monsters will teleport

Keys:
"fog_color"/"fog_density" set the fog for anyone teleporting here
"count"		remove after this many uses
*/
/*FGD
@PointClass size(-32 -32 0, 32 32 64) base(Appearflags, Angle, Fog, Trigger) = info_teleport_target : "Triggerable Teleporter destination" [
	spawnflags(flags) = [
		1 : "Player only" : 0
		2 : "Push forward" : 0
		16 : "No tflash" : 0
	]
]
*/
void() info_teleport_target =
{
	if (!SUB_ShouldSpawn()) return;
	self.mangle = self.angles;
	self.angles = '0 0 0';
	setorigin(self, self.origin + '0 0 16'); // 
	setsize(self,VEC_HULL_MIN,VEC_HULL_MAX);
	if (self.targetname == string_null)
		objerror ("no targetname");
	self.count = zeroconvertdefault(self.count, -1);
	self.use = teleport_target_use;
}


// --------------------------------

void() teleport_hum =
{
	local vector o;
	if (self.origin != '0 0 0')
		o = self.origin;
	else
		o = (self.absmin + self.absmax)*0.5;
	ambientsound (o, "ambience/hum1.wav",0.5 , ATTN_STATIC);
}

void() teleport_use =
{
	self.nextthink = time + 0.2;
	force_retouch = 2;		// make sure even still objects get hit
	self.think = SUB_Null;
}

void() teleport_reactivate =
{
	trigger_reactivate();
	// triggerfirst + nonsilent = delayed ambientsound, so shortcut teleporters don't sound like secrets
	if ( self.spawnflags & TELEPORT_TRIGGER_FIRST && !(self.spawnflags & TELEPORT_SILENT) )
		teleport_hum();
	
	self.use = teleport_use;
}

void() trigger_teleport_setup =
{
	self.touch = teleport_touch;
	// find the destination 
	if (!self.target)
		objerror ("no target");
	self.use = teleport_use;
	self.count = zeroconvertdefault(self.count, -1);
	if (!(self.spawnflags & TELEPORT_SILENT))
	{
		precache_sound_safe ("ambience/hum1.wav");
		if (!(self.spawnflags & TELEPORT_TRIGGER_FIRST))
			teleport_hum();
	}
}

/*FGD
@baseclass base(Appearflags, Target, Targetname) = Teleport [
	spawnflags(Flags) =
	[
		1 : "Player only" : 0
		2 : "Silent" : 0
		8 : "Not triggerable (ignore targetname)" : 0
		16 : "No tflash" : 0
		32 : "Monsters only" : 0
	]
	count(integer) : "Limited uses" : -1
]

*/

/*QUAKED trigger_teleport (.5 .0 .5) ? PLAYER_ONLY SILENT TRIGGER_FIRST NOTRIGGER NOFLASH MONSTER_ONLY
Any object touching this will be transported to the corresponding info_teleport_destination entity.
You must set the "target" field, and create an object with a "targetname" field that matches.

Flags:
"player_only" only players will teleport
"silent" no whispering from the slipgate
"trigger_first" won't be touchable until triggered once by something else
"notrigger" default behavior for a teleporter with a targetname is to only teleport what's touching it
	when triggered.  this will preserve ordinary no-targetname behavior (if you're using the teleporter's
	targetname for a killtarget for example)
"noflash" don't spawn tfog or make noise
"monster_only" only monsters will teleport

Keys:
"target" targetname of info_teleport_destination (required)
"targetname" entity name (required)
"count" remove after this many uses
*/
/*FGD
@SolidClass base(Teleport) = trigger_teleport : "Trigger: Teleporter" []
*/
void() trigger_teleport =
{
	if (!SUB_ShouldSpawn()) return;
	InitTrigger ();
	trigger_teleport_setup();	// after inittrigger, so that size/model is set, so the telehum hums in the right place
	if (self.spawnflags & TELEPORT_TRIGGER_FIRST)
		self.use = teleport_reactivate;
}

/*QUAKED trigger_teleport_box (.5 .0 .5) (-8 -8 -8) (8 8 8) PLAYER_ONLY SILENT TRIGGER_FIRST NOTRIGGER
Any object touching this will be transported to the corresponding info_teleport_destination entity.
You must set the "target" field, and create an object with a "targetname" field that matches.
Quoth2-style edict-saving bounding box trigger: define bounds size with "mangle" - trigger volume will be centered on the trigger_teleport_box's origin.

Flags:
"player_only" only players will teleport
"silent" no whispering from the slipgate
"trigger_first" won't be touchable until triggered once by something else
"notrigger" default behavior for a teleporter with a targetname is to only teleport what's touching it
	when triggered.  this will preserve ordinary no-targetname behavior (if you're using the teleporter's
	targetname for a killtarget for example)
"noflash" don't spawn tfog or make noise

Keys:
"target" targetname of info_teleport_destination (required)
"targetname" entity name (required)
*/
/*FGD
@PointClass base(Teleport, Bounds) = trigger_teleport_box : "Trigger: Teleporter bounds" []
*/
void() trigger_teleport_box =
{
	if (!SUB_ShouldSpawn()) return;
	InitTriggerBounds();
	trigger_teleport_setup();
	if (self.spawnflags & TELEPORT_TRIGGER_FIRST)
		self.use = teleport_reactivate;
}


