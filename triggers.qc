/*
================================================================

TRIGGERS

================================================================
*/


float	SPAWNFLAG_NOMESSAGE = 1;
float	SPAWNFLAG_NOTOUCH = 1;
float	SPAWNFLAG_SUPERSECRET = 2;
float	SPAWNFLAG_TRIGGER_FIRST = 4;
float	SPAWNFLAG_TRIGGER_TOGGLE = 4;
float	SPAWNFLAG_TRIGGER_MONSTERS = 8;
float	SPAWNFLAG_ALL_CLIENTS = 16;

/*FGD
@baseclass = TriggerSounds
[
	sounds(choices) : "Sounds" : 2 =
	[
		0 : "None"
		1 : "Secret"
		2 : "Doot doot"
		3 : "Large switch"
		-1 : "Force silent print"
	]
	noise(string) : "Choose wav to play"
]
@baseclass color(128 128 0) base(Appearflags, Targetname) = TriggerNoTargets
[
	spawnflags(Flags) = [
		4 : "trigger first"
	]
]
@baseclass base(TriggerNoTargets, Target) = Trigger 
[
	message(string) : "message to display when triggered"
]
@baseclass base(Trigger, TriggerSounds, Angle) = TriggerMulti
[
	health(integer) : "solid, must be killed to activate"
	count(integer) : "limit uses before self destructing" : 0
	angle(integer) : "Direction player must be facing to trigger (0-360 yaw, or -1 for up/-2 for down)"
	angles(string) : "Direction player must be facing to trigger, specifically (pitch yaw roll)"
	distance(integer) : "Width of facing cone (in degrees) if angle or angles is set" : 180
	spawnflags(Flags) = [
		1 : "No touch" : 0
		8 : "Monsters Will Fire" : 0
	]
]
*/

void() trigger_reactivate =
{
	// TheSolipsist fix: when the trigger has health, make it solid so it can be shot
	if (self.max_health)
		self.solid = SOLID_BBOX;
	else
		self.solid = SOLID_TRIGGER;
	self.use = self.think1;
	force_retouch = 2;		// make sure even still objects get hit
}

/*
================================
CheckValidTouch
health and playerhood checks were duplicated everywhere
added noclip check because Quake's default still-touch-everything noclip is awful
================================
*/
float() CheckValidTouch = 
{
	if (other.classname != "player")
		return FALSE;
	if (other.health <= 0)
		return FALSE;
	if (other.movetype == MOVETYPE_NOCLIP)
		return FALSE;
	// players in telelimbo aren't supposed to 'be' anywhere
	if (other.flags & CFL_LIMBO)
		return FALSE;
	return TRUE;
}


/*
================
InitTrigger
================
*/
void() InitTrigger =
{
// trigger angles are used for one-way touches.  An angle of 0 is assumed
// to mean no restrictions, so use a yaw of 360 instead.
	if (self.angles != '0 0 0')
		SetMovedir ();
	
	if (!self.health)
		self.solid = SOLID_TRIGGER;
	
	// do this first so setmodel links us correctly
	setmodel (self, self.model);	// set size and link into world
	self.movetype = MOVETYPE_NONE;
	
	if (self.spawnflags & SPAWNFLAG_TRIGGER_FIRST)
	{
		self.solid = SOLID_NOT;
		self.think1 = self.use;
		self.use = trigger_reactivate;
	}

	if (self.distance > 1)
		self.distance = cos(self.distance / 2);

	self.modelindex = 0;
	self.model = string_null;
}

/*
================
InitTriggerBounds
quoth2-style edict-saving bounding box triggers
================
*/
void() InitTriggerBounds =
{
// trigger angles are used for one-way touches.  An angle of 0 is assumed
// to mean no restrictions, so use a yaw of 360 instead.

	// do this first so setsize links us correctly
	if (!self.health)
		self.solid = SOLID_TRIGGER;
	setorigin (self, self.origin);
	
	if (self.size != '0 0 0')
		setsize (self, self.size * -0.5, self.size * 0.5);
	else if (self.mangle != '0 0 0')
	{
		setsize (self, self.mangle * -0.5, self.mangle * 0.5);
		self.mangle = '0 0 0';	// so setMoveDir doesn't think our mangle is our angle
	}
	
	if (self.angles != '0 0 0')
		SetMovedir ();
	
	if (self.distance > 1)
		self.distance = cos(self.distance / 2);

	if (self.spawnflags & SPAWNFLAG_TRIGGER_FIRST)
	{
		self.solid = SOLID_NOT;
		self.think1 = self.use;
		self.use = trigger_reactivate;
	}
		
	self.movetype = MOVETYPE_NONE;
//	particle(self.origin - self.mangle, '0 0 0', 232, 4);
//	particle(self.origin + self.mangle, '0 0 0', 232, 4);
//	self.modelindex = 0;
//	self.model = string_null;
}

/*
================
InitTriggerSounds
================
*/
void() InitTriggerSounds =
{
	if (!self.noise)
	{
		if (self.sounds == 1)
			self.noise = "misc/secret.wav";
		else if (self.sounds == 2)
			self.noise = "misc/talk.wav";
		else if (self.sounds == 3)
			self.noise = "misc/trigger1.wav";
	}
	
	if (self.noise)
		precache_sound_safe (self.noise);
}

//=============================================================================

// the wait time has passed, so set back up for another activation
void() multi_wait =
{
	if (self.max_health)
	{
		self.health = self.max_health;
		self.takedamage = DAMAGE_YES;
		self.solid = SOLID_BBOX;
	}
}

// the trigger was just touched/killed/used
// self.enemy should be set to the activator so it can be held through a delay
// so wait for the delay time before firing
float() multi_trigger =
{
	if (self.nextthink > time)
		return FALSE;		// already been triggered

	if (self.customflags & CFL_LOCKED)
	{
		//dprint("  trigger is locked: not firing\n");
		return FALSE;
	}
	
	activator = self.enemy;
	
	if (self.classname == "trigger_secret")
	{
		SUB_UseTargetsSilent();
		secret_use();
		return FALSE;
	}

	playercount_convert(count);
	if (self.count > 0)
	{
		self.count -= 1;
		if (self.count == 0)
			remove(self);
	}
	SUB_UseTargets();
	
	// sub_usetargets plays the sound if there's a message, doesn't if not
	if (self.noise != string_null)
		sound_delayed (self, CHAN_VOICE, self.noise, 1, ATTN_NORM, self.delay);

// don't trigger again until reset
	self.takedamage = DAMAGE_NO;
	
	if (self.wait > 0)	
	{
		self.think = multi_wait;
		self.nextthink = time + self.wait;
	}
	else
	{	// we can't just remove (self) here, because this is a touch function
		// called while C code is looping through area links...
		self.touch = SUB_Null;
		SUB_RemoveSoon();
	}
	
	return TRUE;
}

// simplified multi_trigger with repeat-per-client guard included
// and dumb shootable/secret overloads removed
float() multi_trigger_coop =
{
	if (self.customflags & CFL_LOCKED)
	{
		dprint("  trigger is locked: not firing\n");
		return FALSE;
	}
	
	// respond to multiple coop clients touching this at once before disabling
	if (time != self.dmgtime)
		if (time < self.attack_finished)
			return FALSE;
	
	playercount_convert(count);
	if (self.count > 0)
	{
		self.count -= 1;
		if (self.count == 0)
			remove(self);
	}
	activator = self.enemy;
	SUB_UseTargets();
	
	if (self.noise)
		sound (self, CHAN_VOICE, self.noise, 1, ATTN_NORM);
	
	if (self.spawnflags & SPAWNFLAG_ALL_CLIENTS)
		self.dmgtime = time;
	self.attack_finished = time + self.wait;

	return TRUE;
}


// trigger_multiples are sometimes used as shootable buttons :(
// most notably the 'well of wishes' secret message in start.bsp
void() multi_killed =
{
	self.enemy = damage_attacker;
	multi_trigger();
}

void() multi_use =
{
	self.enemy = activator;
	multi_trigger();
}

void() multi_touch =
{
	if (self.spawnflags & SPAWNFLAG_TRIGGER_MONSTERS)
	{
		if (!(other.flags & FL_MONSTER))
			return;
		if (!(other.enemy != world || other.goalentity != world))
			return;
	}
	else if (!CheckValidTouch())
	{
		return;
	}
	
	// if the trigger has an angles field, check player's facing direction
	if (self.movedir != '0 0 0')
	{
		makevectors (other.v_angle);
		if (v_forward * self.movedir < self.distance)
			return;		// not facing the right way
	}
	
	self.enemy = other;
	
	// would use think1 but the prototype has to be float(); hooray for saving an efield
	if (!self.th_checkattack)
		self.th_checkattack = multi_trigger;
	self.th_checkattack();
}


void() init_trigger_multiple =
{
	if (!self.wait)
		self.wait = 0.2;
	self.use = multi_use;

	if (self.health)
	{
		if (self.spawnflags & SPAWNFLAG_NOTOUCH)
			objerror ("init_trigger: health and notouch don't make sense together\n");
		if (self.spawnflags & SPAWNFLAG_ALL_CLIENTS)
			objerror ("init_trigger: allclients and health don't make sense together\n");
		self.max_health = self.health;
		self.th_die = multi_killed;
		self.takedamage = DAMAGE_YES;
		self.solid = SOLID_BBOX;
		setorigin (self, self.origin);	// make sure it links into the world
	}
	else
	{
		self.solid = SOLID_TRIGGER;
		if (self.spawnflags & SPAWNFLAG_ALL_CLIENTS)
		{
			if (self.spawnflags & SPAWNFLAG_NOTOUCH)
				objerror ("init_trigger: allclients and notouch don't make sense together\n");
			self.th_checkattack = multi_trigger_coop;
		}
		if ( !(self.spawnflags & SPAWNFLAG_NOTOUCH) )
		{
			self.touch = multi_touch;
		}
	}
}

/*QUAKED trigger_multiple (.5 .0 .5) ? NOTOUCH ? TRIGGER_FIRST MONSTERS ALL_CLIENTS
Variable sized repeatable trigger.
Must be targeted at one or more entities.

Flags:
"notouch" only triggered by other entities, not by touching
"all_clients" will trigger once per client touching it on the same frame before waiting (default behavior is to trigger only for the first touch event, ie the lowest-numbered client). use if you want to trigger a target_items or target_heal and have every client in the trigger affected by the result.
"trigger_first" won't be touchable until triggered once by something else
"monsters" monsters will fire this trigger (and count as activator, so be careful)

Keys:
"angle" the trigger will only fire when someone is facing the direction of the angle, use 360 for angle 0.
"distance" degrees of tolerance on facing angle if 'angle' is set
"delay" delay before firing (after trigger)
"health" solid, must be killed to activate
"message" message to display when triggered
"sounds"
    1 = secret
    2 = beep beep
	3 = large switch
	4 = it is a mysteryyy
	-1 = silent
"noise"	choose your own .wav
"target"  entity to trigger (required)
"targetname"  entity name
"wait" delay between triggerings (default: 0.2) (NOTE: wait -1 with all_clients will not work like you think.)
*/
/*FGD
@SolidClass base(TriggerMulti) = trigger_multiple : "Trigger multiple. Variable sized repeatable trigger.
Must be targeted at one or more entities.

Spawnflags:
'No Touch': only triggered by other entities, not by touching (legacy; just use a trigger relay)
'All Clients': will trigger once per client touching it on the same frame before waiting (default behavior is to trigger only for the first touch event, ie the lowest-numbered client). use if you want to trigger a target_items or target_heal and have every client in the trigger affected by the result.
'Trigger First': won't be touchable until triggered once by something else
'Monsters Will Activate': monsters will fire this trigger (and count as activator, so be careful)" 
[
	wait(string) : "Retriggering Interval" : "0.2"
]
*/
void() trigger_multiple =
{
	if (!SUB_ShouldSpawn()) return;
	InitTriggerSounds();
	
	init_trigger_multiple();
	InitTrigger ();

}


/*QUAKED trigger_multiple_box (.5 .5 0) (-8 -8 -8) (8 8 8) ? ? TRIGGER_FIRST MONSTERS ALL_CLIENTS
Trigger multiple. Variable sized repeatable trigger. Must be targeted at one or more entities.

Quoth2-style edict-saving bounding box trigger: define size with 'size', and the trigger volume will be that size centered on the trigger's origin.

Flags:
"all_clients" will trigger once per client touching it on the same frame before waiting (default behavior is to trigger only for the first touch event, ie the lowest-numbered client). use if you want to trigger a target_items or target_heal and have every client in the trigger affected by the result.
"trigger_first" won't be touchable until triggered once by something else
"monsters" monsters will fire this trigger (and count as activator, so be careful)

Keys:
"angle" the trigger will only fire when someone is facing the direction of the angle, use "360" for angle 0.
"distance" dot product result to compare "angle" against. 0 is 90 degrees off (default), 0.7 is 45 degrees.
"delay" delay before firing (after trigger)
"health" button must be killed to activate
"message" message to display when triggered
"sounds"
    1 = secret
    2 = beep beep
	3 = large switch
	4 = it is a mysteryyy
	-1 = silent
"noise"	choose your own .wav
"target"  entity to trigger (required)
"targetname"  entity name
"wait" delay between triggerings (default: 0.2) (NOTE: wait -1 with all_clients will not work like you think.)
*/
/*FGD
@PointClass base(TriggerMulti, Bounds) = trigger_multiple_box : "Trigger multiple. Variable sized repeatable trigger.
Must be targeted at one or more entities.

Quoth2-style edict-saving bounding box trigger: define size with 'size', and the trigger volume will be that size centered on the trigger's origin.

Spawnflags:
'No Touch': only triggered by other entities, not by touching (legacy; just use a trigger relay)
'All Clients': will trigger once per client touching it on the same frame before waiting (default behavior is to trigger only for the first touch event, ie the lowest-numbered client). use if you want to trigger a target_items or target_heal and have every client in the trigger affected by the result.
'Trigger First': won't be touchable until triggered once by something else
'Monsters Will Activate': monsters will fire this trigger (and count as activator, so be careful)"
[
	wait(string) : "Retriggering Interval" : "0.2"
]
*/
void() trigger_multiple_box =
{
	if (!SUB_ShouldSpawn()) return;
	InitTriggerSounds();
	
	init_trigger_multiple();
	setorigin (self, self.origin);	// make sure it links into the world
	InitTriggerBounds ();

}


/*QUAKED trigger_once (.5 .0 .5) ? NOTOUCH ? TRIGGER_FIRST MONSTERS
Variable sized trigger. Triggers once, then removes itself. You must set the key "target" to the name of another object in the level that has a matching "targetname". If notouch is set, the trigger is only fired by other entities, not by touching.

Wait is always -1.

Flags:
"notouch" only triggered by other entities, not by touching
"trigger_first" won't be touchable until triggered once by something else
"monsters" monsters will fire this trigger (and count as activator, so be careful)

Keys:
"angle" the trigger will only fire when someone is facing the direction of the angle, use "360" for angle 0.
"distance" dot product result to compare "angle" against. 0 is 90 degrees off (default), 0.7 is 45 degrees.
"delay" delay before firing (after trigger)
"health" button must be killed to activate
"message" message to display when triggered
"sounds"
    1 = secret
    2 = beep beep
	3 = large switch
	4 = it is a mysteryyy
	-1 = silent
"noise"	choose your own .wav
"target"  entity to trigger (required)
"targetname"  entity name
*/
/*FGD
@SolidClass base(TriggerMulti) = trigger_once : "Trigger multiple. Variable sized trigger.
Must be targeted at one or more entities. Wait is always -1: removes itself after one use.

Spawnflags:
'No Touch': only triggered by other entities, not by touching (legacy; just use a trigger relay)
'All Clients': will trigger once per client touching it on the same frame before waiting (default behavior is to trigger only for the first touch event, ie the lowest-numbered client). use if you want to trigger a target_items or target_heal and have every client in the trigger affected by the result.
'Trigger First': won't be touchable until triggered once by something else
'Monsters Will Activate': monsters will fire this trigger (and count as activator, so be careful)"
[]
*/
void() trigger_once =
{
	self.wait = -1;
	trigger_multiple();
}


/*QUAKED trigger_once_box (.5 .0 .5) ? ? ? TRIGGER_FIRST MONSTERS
Quoth2-style cache-saving bounding box triggers: define size with "mangle", as total dimensions in xyz - trigger volume will be that size centered on the trigger_multiple_box's origin.  otherwise acts like a normal trigger.

Wait is always -1.

Quoth2-style edict-saving bounding box trigger: define size with 'size', and the trigger volume will be that size centered on the trigger's origin.

Flags:
"trigger_first" won't be touchable until triggered once by something else
"monsters" monsters will fire this trigger (and count as activator, so be careful)

Keys:
"angle" the trigger will only fire when someone is facing the direction of the angle, use "360" for angle 0.
"distance" dot product result to compare "angle" against. 0 is 90 degrees off (default), 0.7 is 45 degrees.
"delay" delay before firing (after trigger)
"health" button must be killed to activate
"message" message to display when triggered
"sounds"
    1 = secret
    2 = beep beep
	3 = large switch
	4 = it is a mysteryyy
	-1 = silent
"noise"	choose your own .wav
"target"  entity to trigger (required)
"targetname"  entity name
*/
/*FGD
@PointClass base(TriggerMulti, Bounds) = trigger_once_box : "Trigger multiple. Variable sized trigger.
Must be targeted at one or more entities. Wait is always -1: removes itself after one use.

Quoth2-style edict-saving bounding box trigger: define size with 'size', and the trigger volume will be that size centered on the trigger's origin.

Spawnflags:
'No Touch': only triggered by other entities, not by touching (legacy; just use a trigger relay)
'All Clients': will trigger once per client touching it on the same frame before waiting (default behavior is to trigger only for the first touch event, ie the lowest-numbered client). use if you want to trigger a target_items or target_heal and have every client in the trigger affected by the result.
'Trigger First': won't be touchable until triggered once by something else
'Monsters Will Activate': monsters will fire this trigger (and count as activator, so be careful)"
[]
*/
void() trigger_once_box =
{
	self.wait = -1;
	trigger_multiple_box();
}
//=============================================================================



/*FGD
@baseclass = Secret
[
	spawnflags(flags) = [
		2 : "Supersecret" : 0
	]
	sounds(choices) : "Sounds" : 1 =
	[
		0 : "None"
		1 : "secret"
		2 : "beep beep"
		3 : "large switch"
	]
	message(string) : "Message"
]
*/

void() secret_use =
{
	if (activator.classname != "player")
		return;
	
	if (self.noise)
		sound (self, CHAN_VOICE, self.noise, 1, ATTN_NORM);
	
	if (self.spawnflags & SPAWNFLAG_SUPERSECRET)
	{
		// super secrets aren't counted toward the total until found
		total_secrets = total_secrets + 1;
		WriteByte (MSG_ALL, SVC_UPDATESTAT);
		WriteByte (MSG_ALL, STAT_TOTALSECRETS);
		WriteLong (MSG_ALL, total_secrets);
	}
	
	found_secrets = found_secrets + 1;
	WriteByte (MSG_ALL, SVC_FOUNDSECRET);
	
	SUB_PrintMessage();
//	sound (self, CHAN_VOICE, self.noise, 1, ATTN_NORM);
	sprint2_to_others(activator.netname, " found a secret area\n", activator);
	
	self.touch = SUB_Null;
	SUB_RemoveSoon();
}


void() trigger_secret_setup =
{
	if (!(self.spawnflags & SPAWNFLAG_SUPERSECRET))
	{
		// super secrets aren't counted toward the total until found
		total_secrets = total_secrets + 1;
	}
	self.spawnflags = not(self.spawnflags, SPAWNFLAG_TRIGGER_MONSTERS);	// jic of old stale spawnflags 8
	
	self.wait = -1;
	self.classname = "trigger_secret";
	if (self.message == string_null)
	{
		if (self.spawnflags & SPAWNFLAG_SUPERSECRET)
			self.message = "You found a \bvery\b secret area!";
		else
			self.message = "You found a secret area!";
	
	}
	if (!self.sounds)
		self.sounds = 1;
	
	InitTriggerSounds();
}

void() target_secret_check =
{
	// sanity check for dumb mappers like me
	entity w;
	w = find(world, target, self.targetname);
	if (w)
	{
		if (w.type == "ammo" || w.type == "armor" || ( w.type == "health" && !(w.spawnflags & 2)) )
			dprint("\bwarning:\b target_secret targeted by something the player might not be able to grab\n");
	}
}

/*QUAKED target_secret (.65 .0 .65) (-8 -8 -8) (8 8 8) ? SUPERSECRET
Secret counter trigger.  Player gets a secret credit when triggered.  Note when using a target_secret: if triggered by touching an item, and the item can't be picked up (because of health/armor/ammo limits already being met, etc), it won't fire its targets and thus the target_secret won't give credit. Use a trigger in that case.

Set "SUPERSECRET" to hide its existence in the total until it's found. Think very carefully if you actually want to use this.
Keys:
"message" message to display when triggered
"sounds"
    1 = secret
    2 = beep beep
	3 = large switch
	4 = it is a mysteryyy
	-1 = silent
"noise"	choose your own .wav
*/
/*FGD
@PointClass base(Secret, Targetname) color(160 0 160) = target_secret : "Secret counter trigger.  Player gets a secret credit when triggered.  Note when using a target_secret: if triggered by touching an item, and the item can't be picked up (because of health/armor/ammo limits already being met, etc), it won't fire its targets and thus the target_secret won't give credit. Use a trigger in that case.

Set the 'supersecret' spawnflag to hide its existence in the total until it's found. Think very carefully if you actually want to use this." []
*/
void() target_secret =
{
	if (!SUB_ShouldSpawn()) return;
	if (deathmatch) { remove(self); return; }
	trigger_secret_setup();
	self.use = secret_use;
	
	self.think = target_secret_check;
	self.nextthink = time + 0.2;
}

/*QUAKED trigger_secret (.5 .0 .5) ? NOTOUCH SUPERSECRET TRIGGER_FIRST
Secret counter trigger.  Player gets a secret credit when touched.  Set "SUPERSECRET" to hide its existence in the total until found.
Keys:
"message" message to display when triggered
"sounds"
    1 = secret
    2 = beep beep
	3 = large switch
	4 = it is a mysteryyy
	-1 = silent
"noise"	choose your own .wav

Flags:
"SUPERSECRET" hide its existence in the total until it's found
"trigger_first" won't be touchable until triggered once by something else
*/
/*FGD
@SolidClass base(Trigger, Secret) = trigger_secret : "Secret counter trigger. Player gets a secret credit when touched." 
[
	spawnflags(flags) = [
		1 : "Notouch (legacy)" : 0
	]
]
*/
void() trigger_secret =
{
	if (!SUB_ShouldSpawn()) return;
	if (deathmatch) { remove(self); return; }
	if (self.spawnflags & SPAWNFLAG_NOTOUCH)
	{
		target_secret();
		return;
	}
	init_trigger_multiple();
	InitTrigger();
	trigger_secret_setup();
}

/*QUAKED trigger_secret_box (.5 .0 .5) (-8 -8 -8) (8 8 8) ? SUPERSECRET TRIGGER_FIRST
Secret counter trigger.  Player gets a secret credit when touched.  Set "SUPERSECRET" to hide its existence in the total until found.

Quoth2-style edict-saving bounding box trigger: define size with 'size', and the trigger volume will be that size centered on the trigger's origin.

Keys:
"message" message to display when triggered
"sounds"
    1 = secret
    2 = beep beep
	3 = large switch
	4 = it is a mysteryyy
	-1 = silent
"noise"	choose your own .wav

Flags:
"SUPERSECRET" hide its existence in the total until it's found
"trigger_first" won't be touchable until triggered once by something else
*/
/*FGD
@PointClass base(Trigger, Secret, Bounds) = trigger_secret_box : "Trigger : Secret
Counts as a secret, trigger to give credit" []
*/
void() trigger_secret_box =
{
	if (!SUB_ShouldSpawn()) return;
	if (deathmatch) { remove(self); return; }
	init_trigger_multiple();
	InitTriggerBounds();
	trigger_secret_setup();
}


//=============================================================================



/*
==============================================================================
trigger_setskill & target_setskill
==============================================================================
*/

void(entity e, string sk) skill_set =
{
	cvar_set ("skill", sk);
	skill = cvar("skill");
}

void() target_setskill_use
{
	skill_set(activator, self.message);
}

/*FGD
@baseclass = Setskill [
	message(choices) : "Skill" : 0 = [
		0 : "Easy"
		1 : "Normal"
		2 : "Hard"
		3 : "NIGHTMAAARE"
	]
]
*/

/*QUAKED target_setskill (.65 .0 .65) (-8 -8 -8) (8 8 8)
Sets skill level to the value of "message". Only used on start map.

Keys:
"message"
    sets skill level
    0 = easy
    1 = normal
    2 = hard
    3 = nightmare
*/
/*FGD
@PointClass base(Setskill, Targetname) color(160 0 160) = target_setskill : "Target: Set Skill" []
*/
void() target_setskill =
{
	self.use = target_setskill_use;
}

void() trigger_skill_touch =
{
	if (!CheckValidTouch()) return;
	if (self.customflags & CFL_LOCKED) return;
	
	skill_set(other, self.message);
}

/*QUAKED trigger_setskill (.5 .0 .5) ? ? ? TRIGGER_FIRST
Sets skill level to the value of "message". Only used on start map.

Flags:
"trigger_first" won't be touchable until triggered once by something else

Keys:
"message"
    sets skill level
    0 = easy
    1 = normal
    2 = hard
    3 = nightmare
*/
/*FGD
@SolidClass base(Setskill, Trigger) = trigger_setskill : "Trigger: Set Skill" []
*/
void() trigger_setskill =
{
	if (!SUB_ShouldSpawn()) return;
	InitTrigger ();
	self.touch = trigger_skill_touch;
}


//============================================================================

void() trigger_onlyregistered_touch =
{
	if (!CheckValidTouch()) return;
	if (self.attack_finished > time)
		return;

	self.attack_finished = time + 2;
	if (cvar("registered"))
	{
		self.message = string_null;
		activator = other;
		SUB_UseTargets ();
		remove (self);
	}
	else
	{
		if (self.message != string_null)
		{
			centerprint (other, self.message);
			sound (other, CHAN_BODY, "misc/talk.wav", 1, ATTN_NORM);
		}
	}
}

/*QUAKED trigger_onlyregistered (.5 .0 .5) ?
Only fires if playing the registered version, otherwise prints the message
*/
/*FGD
@SolidClass base(Trigger) = trigger_onlyregistered : "Trigger: Registered only" []
*/
void() trigger_onlyregistered =
{
	precache_sound_safe ("misc/talk.wav");
	InitTrigger ();
	self.touch = trigger_onlyregistered_touch;
}




//============================================================================

void() hurt_on =
{
	self.solid = SOLID_TRIGGER;
	self.nextthink = -1;
}

void() hurt_retouch =
{
	force_retouch = 2;
}

void() hurt_touch =
{
	if (self.customflags & CFL_LOCKED)
		return;
	if (!other.takedamage)
		return;
		
	//if (!CheckValidTouch()) return;
	if (other.classname == "player")
	{
		if (other.movetype == MOVETYPE_NOCLIP)
			return FALSE;
	}
	if (other.health <= 0)
		return FALSE;
	
	if ((self.spawnflags & 8) && (other.flags & FL_MONSTER))
		return;
	if ((self.spawnflags & 2) && (other.radsuit_finished > time))
		return;
	
	// fix for multiple coop clients touching this at once only hurting the first one
	if (time != self.dmgtime)
		if (time < self.attack_finished)
			return;
	
	if (self.spawnflags & 1)
	{
		T_Damage (other, self, self, other.health + min(other.armorvalue, other.health / other.armortype) + 5);
	}
	else
		T_Damage (other, self, self, self.dmg);
	
	self.dmgtime = time;
	self.attack_finished = time + self.delay;
	
	// this is not ideal but all the other solutions are also not ideal: monsters
	// who stand still in a trigger hurt don't catch the trigger, so (for example)
	// enforcers who plant and open fire will be immune to the hurt as long as they
	// stay in one place
	if (other.flags & FL_MONSTER)
	{
		// so we have to ask the engine to spam a collision test of everything vs
		// everything else to catch them
		self.think = hurt_retouch;
		self.nextthink = time + self.delay;
	}
}

/*FGD
@baseclass base(TriggerNoTargets) = Hurt [
	spawnflags(flags) = [
		1 : "Just Kill Them" : 0
		2 : "Biosuits are Immune" : 0
		8 : "Don't Hurt Monsters" : 0
	]
	dmg(integer) : "Damage" : 5
	delay(string) : "Interval (seconds)" : "1"
]
*/

/*QUAKED trigger_hurt (.5 .0 .5) ? KILL BIOSUIT TRIGGER_FIRST NO_MONSTERS
any entity touching this will be hurt / to see if it still feels

Keys:
"dmg" sets damage, default is 5
"delay" frequency of damage in seconds, default 1

Flags:
"kill" always do enough damage to kill instantly
"biosuit" the biosuit protects against this trigger
"trigger_first" won't be touchable until triggered once by something else
"no_monsters" trigger will only hurt players
*/
/*FGD
@SolidClass base(Hurt) = trigger_hurt : "Trigger: Hurt. Any creature touching this will be damaged.
Resist the urge to put a tiny one of these on every light_flame." []
*/
void() trigger_hurt =
{
	if (!SUB_ShouldSpawn()) return;
	InitTrigger ();
	self.touch = hurt_touch;
	self.dmg = zeroconvertdefault(self.dmg,5);
	if (!self.delay)
		self.delay = 1;
}

/*QUAKED trigger_hurt_box (.5 .0 .5) (-8 -8 -8) (8 8 8) KILL BIOSUIT TRIGGER_FIRST NO_MONSTERS
Any creature touching this will be damaged.
Quoth2-style edict-saving bounding box trigger: define size with 'size', and the trigger volume will be that size centered on the trigger's origin.
Resist the urge to put a tiny one of these on every light_flame.

Keys:
"dmg" sets damage, default is 5
"delay" frequency of damage in seconds, default 1. use -1 for maximum host_framerate pain spam.

Flags:
"kill" always do enough damage to kill instantly
"biosuit" the biosuit protects against this trigger
"trigger_first" won't be touchable until triggered once by something else
"no_monsters" trigger will only hurt players
*/
/*FGD
@PointClass base(Hurt,Bounds) = trigger_hurt_box : "Trigger: Hurt. Any creature touching this will be damaged.
Quoth2-style edict-saving bounding box trigger: define size with 'size', and the trigger volume will be that size centered on the trigger's origin.
Resist the urge to put a tiny one of these on every light_flame." []
*/
void() trigger_hurt_box =
{
	if (!SUB_ShouldSpawn()) return;
	InitTriggerBounds ();
	self.touch = hurt_touch;
	self.dmg = zeroconvertdefault(self.dmg,5);
	self.delay = zeroconvertdefault(self.delay,1);
	self.classname = "trigger_hurt";
}



//============================================================================

float PUSH_ONCE = 1;
float PUSH_ADD_VEL = 2;
float PUSH_TUNNEL = 8;

void() trigger_push_touch =
{
	if (other.movetype == MOVETYPE_NOCLIP)
		return;
	if (self.customflags & CFL_LOCKED)
		return;
	
	if (!(other.health > 0 || other.type == "grenade" || 
		other.type == "gib" || other.type == "head"))	// suck up gibs too, why not
		return;

	if (self.spawnflags & PUSH_ADD_VEL)
	{
		if (time != self.dmgtime)
			if (time < self.attack_finished)
				return;

		if (self.speed2 > 0)
		{
			float overspeed;
			overspeed = (other.velocity * self.movedir) - self.speed2;
			if (overspeed < 0)
			{
				other.velocity += min(overspeed * -1, self.speed) * self.movedir;
			}
		}
		else
		{
			other.velocity += self.speed * self.movedir;
		}
		self.dmgtime = time;
		self.attack_finished = time + 0.05;
	}
	else
	{
		other.velocity = self.speed * self.movedir * 10;
	}
	
	if (other.classname == "player")
	{
		if (other.nextmovesound < time)
		{
			other.nextmovesound = time + 1.5;
			sound (other, CHAN_AUTO, self.noise, 1, ATTN_NORM);
		}
		if (self.spawnflags & PUSH_TUNNEL)
		{
			vector suck;
			suck = BoundsCenter(self) - other.origin;
			suck -= self.movedir * (suck * self.movedir);
			other.velocity += suck * self.speed * 0.1;
		}
	}

	if (self.spawnflags & PUSH_ONCE)
		SUB_Remove();
}

void() trigger_push_find =
{
	entity n;
	n = find(world, targetname, self.target);
	if (!n) return;
	
	self.movedir = normalize(n.origin - BoundsCenter(self));
}

/*QUAKED trigger_push (.5 .0 .5) ? PUSH_ONCE ADD_VEL TRIGGER_FIRST TUNNEL
Pushes the player, grenades, and gibs.

Flags:
"push_once" removes itself after firing
"trigger_first" won't be touchable until triggered once by something else
"add_vel" add to the player's velocity rather than overriding it (player can still move around and push against the current)
"tunnel" suck players towards the center of the brush in the direction of travel to avoid getting hung up on corners

Keys:
"angle" direction of push (-2 is down, -1 up)
"angles" specify a more exact direction (pitch yaw roll, positive pitch is down)
"speed" speed of push (default: 1000)
"speed2" in ADD_VEL
"noise" replace default wind blow sound
*/
/*FGD
@SolidClass base(Angle, TriggerNoTargets) = trigger_push : "Trigger: Push.
Entities that come in contact with this are pushed. 

The 'Add Velocity' spawnflag will add to the player's velocity rather than overriding it (like wind tunnels do), so the player can still move around and push against the current. Good for flowing water. Players will not be accelerated faster than 'speed2' if it is set.
The 'Tunnel Center' spawnflag will suck players towards the center of the brush in the direction of travel to avoid them getting hung up on corners."
[
	spawnflags(flags) = [
		1: "Push once" : 0
		2: "Add Velocity" : 0
		4: "Trigger First" : 0
		8: "Tunnel Center" : 0
	]
	speed(integer) : "Speed (will be divided by 10, sorry, blame id software)" : 1000
	speed2(integer) : "Speed Limit" : 0
	noise(string) : "Looping sound" : "ambience/windfly.wav"
	angles(string) : "Specific direction (pitch yaw roll)" : "0 0 0"
]
*/
void() trigger_push =
{
	if (!SUB_ShouldSpawn()) return;
	if (self.angles == '0 0 0')
		self.angles = '0 360 0';
	
	InitTrigger();
	if (self.noise == string_null)
		self.noise = "ambience/windfly.wav";
	precache_sound_safe (self.noise);
	self.touch = trigger_push_touch;
	if (!self.speed)
		self.speed = 1000;
	if (self.target != string_null)
	{
		self.think = trigger_push_find;
		self.nextthink = time + 0.1;
	}
}


//============================================================================

float SPAWN_MJUMP_NOLARGE = 1;
float SPAWN_MJUMP_NOSMALL = 2;
float SPAWN_MJUMP_MELEES = 8;
float SPAWN_MJUMP_ONLYFRONT = 16;
float SPAWN_MJUMP_ONLYBELOW = 32;
float SPAWN_MJUMP_ADDVEL = 64;

void() trigger_monsterjump_touch =
{
	vector dir;
	
	if (self.customflags & CFL_LOCKED) return;
	if (other.health <= 0) return;
	if ( other.flags & (FL_MONSTER | FL_FLY | FL_SWIM) != FL_MONSTER )
		return;
	// this might break a map that tosses monsters into view before they wake up
	//if (!other.enemy || other.enemy.deadflag || other.enemy.customflags & (CFL_PLUNGE|CFL_KNOCKEDDOWN))
	//	return;
	if (time != self.dmgtime)
		if (time < self.attack_finished)
			return;
	
	// filtration
	if (self.include == string_null || 
		(other.classname != self.include && other.targetname != self.include))	// always allow this class/tname
	{
		if (self.spawnflags & SPAWN_MJUMP_NOLARGE && other.maxs_x >= 24) return;
		if (self.spawnflags & SPAWN_MJUMP_NOSMALL && other.maxs_x < 24) return;
		if (self.spawnflags & SPAWN_MJUMP_MELEES && !(other.customflags & CFL_MELEEONLY)) return;
		
		if (self.exclude != string_null)
		{
			if (self.exclude == other.classname || self.exclude == other.targetname) return; // always exclude this class/tname
		}
	}
	if (self.spawnflags & SPAWN_MJUMP_ONLYBELOW)
	{
		if (!other.enemy) return;
		if (other.enemy.absmin_z > (other.absmin_z - 16)) return;
	}
	if (self.spawnflags & SPAWN_MJUMP_ONLYFRONT)
	{
		if (!other.enemy) return;
		dir = other.enemy.origin - other.origin;
		dir_z = 0;
		dir = normalize(dir);
		if (dir * self.movedir < self.distance)
			return;
	}
	
	if (self.wait == -1)
	{
		SUB_RemoveSoon();
	}
	else
	{
		self.dmgtime = time;
		self.attack_finished = time + self.wait;
	}
	// set XY even if not on ground, so the jump will clear lips
	if (self.spawnflags & SPAWN_MJUMP_ADDVEL)
	{
		other.velocity_x += self.movedir_x * self.speed;
		other.velocity_y += self.movedir_y * self.speed;
	}
	else
	{
		other.velocity_x = self.movedir_x * self.speed;
		other.velocity_y = self.movedir_y * self.speed;
	}
	
	if ( !(other.flags & FL_ONGROUND) )
	{
		if (self.spawnflags & SPAWN_MJUMP_ADDVEL)
			other.velocity_z += self.height;
		else
			return;
	}
	
	other.flags = not(other.flags, FL_ONGROUND);
	other.velocity_z = self.height;
}

void() trigger_monsterjump_init =
{
	self.speed = zeroconvertdefault(self.speed, 200);
	self.height = zeroconvertdefault(self.height, 200);
	if (!self.distance)
		self.distance = 0.5;
	if (self.angles == '0 0 0')
		self.angles = '0 360 0';
	self.touch = trigger_monsterjump_touch;
}

/*QUAKED trigger_monsterjump (.5 .0 .5) ? NO_LARGE NO_SMALL TRIGGER_FIRST ONLY_MELEES ONLY_FRONT ONLY_BELOW ADD_VEL
Monsters that touch this will 'jump' in the direction of the trigger's angle, if they meet its conditions.

Flags:
NO_LARGE only monsters with 32x32 bounds
NO_SMALL only monsters with 64x64 bounds
TRIGGER_FIRST won't be touchable until triggered once by something else
ONLY_MELEES only monsters with no ranged attack (dogs/fiends/spawns)
ONLY_FRONT will only trigger if monster's enemy is in front of the monster relative to jump angle
ONLY_BELOW will only trigger if monster's enemy is below the monster
ADD_VEL add velocity to monster rather than setting it

Keys:
"angle" angle towards the monster jumps
"height" the speed thrown upwards (default: 200)
"speed" the speed thrown forward (default: 200)
"target"  entity to trigger
"targetname"  entity name
"include" allow this classname of monster, or monsters with this targetname, no matter what
"exclude" exclude this classname of monster, or monsters with this targetname, no matter what
"wait" don't allow a jump touch more often than this many seconds (-1 for once only)
"distance" width of cone (in degrees) that counts as 'in front' if ONLY_FRONT checked
*/
/*FGD
@baseclass base(TriggerNoTargets, Angle) = Monsterjump [
	spawnflags(flags) = [
		1 : "No large monsters" : 0
		2 : "No small monsters" : 0
		8 : "Only melee monsters" : 0
		16 : "Only if target in front" : 0
		32 : "Only if target below" : 0
		64 : "Additive push" : 0
	]
	wait(string) : "Interval (-1 for once only)" : "0"
	speed(integer) : "Jump Speed" : 200
	height(integer) : "Jump Height" : 200
	include(string) : "Allow this classname of monster, or monsters with this targetname, no matter what"
	exclude(string) : "Ignore this classname of monster, or monsters with this targetname, no matter what"
	distance(integer) : "Width of facing cone (in degrees) if 'only in front' is set" : 120
]
@SolidClass base(Monsterjump) = trigger_monsterjump : "Trigger: Monster jump. Monsters that touch this will 'jump' in the direction of the trigger's angle, if they meet its conditions.

Use the 'Only if target in front'/'below' spawnflags to prevent monsters from being thrown off of ledges away from the player after the player has climbed up there.

Use the 'no large monsters', 'no small monsters', and 'only melee monsters' spawnflags to fine-tune which monsters jump and which don't if necessary. If this isn't fine-grained enough, the 'include' and 'exclude' keys can be set to specific monster classnames, or targetnames, to exempt matching monsters from those rules. If that isn't fine-grained enough, consider two overlapping monsterjumps with different, more specific rules." []
*/
void() trigger_monsterjump =
{
	if (!SUB_ShouldSpawn()) return;
	trigger_monsterjump_init();
	InitTrigger();
}


/*QUAKED trigger_monsterjump_box (.5 .0 .5) (-8 -8 -8) (8 8 8) NO_LARGE NO_SMALL TRIGGER_FIRST ONLY_MELEES ONLY_FRONT ONLY_BELOW ADD_VEL
Monsters that touch this will 'jump' in the direction of the trigger's angle, if they meet its conditions.

Quoth2-style edict-saving bounding box trigger: define bounds size with 'size' - trigger volume will be centered on the trigger's origin.

Flags:
NO_LARGE only monsters with 32x32 bounds
NO_SMALL only monsters with 64x64 bounds
TRIGGER_FIRST won't be touchable until triggered once by something else
ONLY_MELEES only monsters with no ranged attack (dogs/fiends/spawns)
ONLY_FRONT will only trigger if monster's enemy is in front of the monster relative to jump angle
ONLY_BELOW will only trigger if monster's enemy is below the monster
ADD_VEL add velocity to monster rather than setting it

Keys:
"angle" angle towards the monster jumps
"height" the speed thrown upwards (default: 200)
"speed" the speed thrown forward (default: 200)
"target"  entity to trigger
"targetname"  entity name
"include" allow this classname of monster, or monsters with this targetname, no matter what
"exclude" exclude this classname of monster, or monsters with this targetname, no matter what
*/
/*FGD
@PointClass base(Monsterjump, Bounds) = trigger_monsterjump_box : "Trigger: Monster jump. Monsters that touch this will 'jump' in the direction of the trigger's angle, if they meet its conditions.

Use the 'Only if target in front'/'below' spawnflags to prevent monsters from being thrown off of ledges away from the player after the player has climbed up there. 

Use the 'no large monsters', 'no small monsters', and 'only melee monsters' spawnflags to fine-tune which monsters jump and which don't if necessary. If this isn't fine-grained enough, the 'include' and 'exclude' keys can be set to specific monster classnames, or targetnames, to exempt matching monsters from those rules. If that isn't fine-grained enough, consider two overlapping monsterjumps with different, more specific rules.

Quoth2-style edict-saving bounding box trigger: define bounds size with 'size' - trigger volume will be centered on the trigger's origin." []
*/
void() trigger_monsterjump_box =
{
	if (!SUB_ShouldSpawn()) return;
	trigger_monsterjump_init();
	InitTriggerBounds();
	self.classname = "trigger_monsterjump";
}

