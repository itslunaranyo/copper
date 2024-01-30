/*
=============
THE VOID

The bottoms of pits have to be lit so scrags are lit, but then you can see their bodies at 
the bottom along with heads and shit.  Dead things are problematic to remove since they're 
all SOLID_NOT and don't touch triggers, and trying to undo that requires hacky stuff like 
thinking trigger bodies, and if you cover the bottom with a func static to just hide them 
inside it, the player still sees all the garbage when he falls down there and dies himself.

thus, a func_void:
- Sets itself as an invisible trigger that kills whatever touches it
- Creates a nonsolid 'ghost object' 32 units higher using its own brushmodel that hides 
	accumulated garbage
- Creates another trigger a specified height above itself that fades out players' view 
	when they fall through it

A player's screen has fully faded to black by the time he hits the ghost, so he doesn't
see the trash underneath.  Since he doesn't know he's not still falling, we can hold him 
in stasis for a little while longer before we splat him, to imply the pit is deeper than 
it really is (often not that deep).

===============
*/

const float CSHIFT_CUTOFF = 90;
nosave float noTint;

/*
============
TintScreen
============
*/
void(entity who, float amt) TintScreen
{
//	bprint(ftos(amt)); bprint("\n");
	if (noTint)
	{
		who.tint = amt;
		who.tint_color = '0 0 0';
	}
	else
	{
		stuffcmd(who, "\nv_cshift 0 0 0 ");
		stuffcmd(who, ftos(amt));
		stuffcmd(who, "\n");
	}
}


/*
============
TintScreenColor
============
*/
void(entity who, float amt, vector color) TintScreenColor
{
	// cshifts are 0-255
	if (color_x <= 1 && color_y <= 1 && color_z <= 1)
		color *= 255;
	color_x = ceil(color_x);
	color_y = ceil(color_y);
	color_z = ceil(color_z);
	
	if (noTint)
	{
		who.tint = amt;
		who.tint_color = color;
	}
	else
	{
		// ugh:
		stuffcmd(who, "\nv_cshift ");
		stuffcmd(who, ftos(color_x));
		stuffcmd(who, " ");
		stuffcmd(who, ftos(color_y));
		stuffcmd(who, " ");
		stuffcmd(who, ftos(color_z));
		stuffcmd(who, " ");
		stuffcmd(who, ftos(amt));
		stuffcmd(who, "\n");
	}
}

/*
============
TintScreenFog

an ugly substitute for cshift
============
*/
void(entity who, float amt, vector color) TintScreenFog
{
	float s, d, dx;
	vector c;
	
	// initially store player's existing fog so we know what we're blending from
	if (!who.fog_density2)
	{
		if (!who.fog_density)
		{
			who.fog_density2 = -1;
			who.fog_color = color;
			who.fog_color2 = color;
		}
		else
		{
			who.fog_color2 = who.fog_color;
			who.fog_density2 = who.fog_density;
			who.fog_sky2 = who.fog_sky;
		}
	}
	
	// fog is 0-1
	if (color_x > 1 || color_y > 1 || color_z > 1)
		color /= 255;
	
	c = lerpVector(who.fog_color2, color, amt);
	s = lerp(who.fog_sky2, 1, amt);
	
	// the fog density ramp in fitzquakes is astounding
	// this doesn't match it, but it looks right for the usual range of fogs maps have
	d = sqrt(sqrt(who.fog_density2));	// un-steepen the existing value so we can map it linearly
	d = lerp(d, 1, amt);
	d = d * d * d * d;	// the re-steepening
	if (d > 0.5)
	{
		// add additional even more density, bc density 1 is only opaque at ~128u 
		// away and we want a solid screen by the time we hit bottom
		dx = (d-0.5) * 2;
		d += dx*dx*20;
	}
	
	noTint = 0;	// hack
	fog_set(who, d, c, s);
	noTint = 1;
}


// --------------------------------
// void_unplunge
// player was rescued, somehow, probably by being a noclipping whore
// --------------------------------
void(entity e) void_unplunge =
{
	e.customflags &~= CFL_PLUNGE;
	//e.flags &~= FL_NOTARGET;
	e.takedamage = DAMAGE_AIM;
	e.solid = SOLID_SLIDEBOX;
	if (e.movetype != MOVETYPE_NOCLIP)
		e.movetype = MOVETYPE_WALK;
	e.model = "progs/player.mdl";

	SUB_CallAsSelf(W_ResetWeaponState, e);	// restore weaponmodel
	TintScreen(e,0);
}

// --------------------------------
// void_salvation
// sometimes we don't want to instantly murder the player for minor navigational errors
// --------------------------------
float(entity me, entity o) void_salvation =
{
	// if this func_void targets a teledest, it's only for light punishment
	entity spot = void_find_teleport(me);
	if (!spot)
		return FALSE;
	
	// light punishment is still lethal, proceed with the display
	if ( DamageCanKill(o, me.dmg) )
		return FALSE;
	
	void_unplunge(o);
	o.velocity = '0 0 0';
	// damage has to come before the teleport, because in coop a player
	// might get put in teleport limbo and be TAKEDAMAGE_NO until reappearing
	if (me.dmg > 0)
	{
		T_Damage(o, me, me, me.dmg, DMGTYPE_FALLING);
		teleport(o, spot, TRUE, TRUE);	
		sound (o, CHAN_VOICE, "player/land2.wav", 1, ATTN_NORM);
	}
	else
		teleport(o, spot, TRUE, TRUE);	
	return TRUE;
}

// --------------------------------
// void_func_touch
// player hit the physical bottom of the pit but may not have hit the implied bottom
// --------------------------------
void() void_func_touch =
{
	if ( other.solid == SOLID_BSP || other.solid == SOLID_TRIGGER )
		return;
	
	if ( CheckValidTouch() )	// a living player not in noclip
	{

	//	other.customflags = not(other.customflags, CFL_UNDYING);
	//	other.customflags = not(other.customflags, CFL_PLUNGE);
		
		TintScreenColor(other, 255, self.fadecolor);
		other.velocity = '0 0 0';
		other.solid = SOLID_NOT;
		other.movetype = MOVETYPE_NONE;
		//other.flags = other.flags | FL_NOTARGET;
		other.weaponmodel = string_null;
		other.model = string_null;
		
		if (!(other.customflags & CFL_PLUNGE))	
		{
			// this is non-optimal - means the player got in under a plunge trigger somehow.
			// can happen if the pit is wider at the top than the bottom, and the func_void
			// was made only as wide as the bottom
			other.armorvalue = 0;
			if (!void_salvation(self, other))		// maybe save him anyway?
				T_Damage(other, self, self, 5000, DMGTYPE_FALLING);	// or just blast him now and forget about it
			return;
		}
		
		other.takedamage = DAMAGE_NO;
		return;
	}
	else if (other.classname != "player")	// not a living player who IS in noclip
	{
		if (other.takedamage)
		{
			other.customflags |= CFL_PLUNGE;	// set this so Killed() doesn't throw gibs
			//T_Damage(other, self, other.enemy, other.health + 10);
			if (other.enemy.classname == "player")
				Killed(other,other.enemy, DMGTYPE_FALLING);
			else if (other.oldenemy.classname == "player")
				Killed(other,other.oldenemy, DMGTYPE_FALLING);
			// attacker must be the monster's enemy, so that players still count as the 
			// killer if they boosh monsters into a pit
			return;
		}

		// anything else just vanishes
		SUB_CallAsSelf(SUB_Remove,other);
	}
}


// --------------------------------
// void_hitbottom
// player hit the implied fake bottom (ie fell for 'delay' seconds), time to die
// --------------------------------
void() void_fall_hitbottom =
{
	self.enemy.takedamage = DAMAGE_YES;	// need this first for salvation damage check
	if (void_salvation(self.owner.owner, self.enemy))
		return;
	
	self.enemy.customflags = not(self.enemy.customflags, CFL_UNDYING);
	self.enemy.flags = not(self.enemy.flags, FL_GODMODE);
	
	// a pent will not save you from THE LEVEL DESIGNER
	if (has_invuln(self.enemy))
	{
		self.enemy.items = self.enemy.items - (self.enemy.items & IT_INVULNERABILITY);
		self.enemy.invincible_finished = 0;
		self.enemy.invincible_time = 0;
	}
	
	self.enemy.armorvalue = 0;
	T_Damage(self.enemy, self.owner, self.owner, 5000, DMGTYPE_FALLING);
	
	SUB_RemoveSoon();
}


void() void_fall_unplunge =
{
	void_unplunge(self.enemy);
}

// --------------------------------
// void_fallthink
// timer for fading out the player's view as he's falling
// --------------------------------
void() void_fallthink =
{
	local float plummet;
	
	if ( self.enemy.origin_z > self.oldorigin_z		// player rose back up out of the pit, mostly convenience for noclipping around
		|| self.owner.flags & CFL_LOCKED )			// player fell into a void as it was LOCKed :(
	{		
		void_fall_unplunge();
		SUB_RemoveSoon();
		return;
	}
	
	if (self.enemy.customflags & CFL_LIMBO)
	{
//		bprint("fallthink in limbo\n");
		self.nextthink = time + 0.1;
		self.pain_finished += 0.1;	// don't instagib the player while waiting for the salvation spot to clear
		return;
	}
	
	if ( self.enemy.movetype == MOVETYPE_NONE )	// has touched the func
	{
		if (self.pain_finished <= time)
		{
			void_fall_hitbottom();
		}
		else
		{
			self.think = void_fall_hitbottom;
			self.nextthink = self.pain_finished;
		}
		return;
	}
	
	plummet = (self.enemy.origin_z - self.lip) / self.height;
	bprint2(ftos(plummet), "\n");
	plummet = 1 - plummet * plummet;	// exponential falloff seems to look more linear, since the player accelerates exponentially
	plummet = min( ceil( plummet * 255 ), 255);
	
	TintScreenColor(self.enemy, plummet, self.fadecolor);
	
	self.nextthink = time + 0.0333;
}

void() player_void_monitor_think =
{
	// stop when body comes to rest or player respawns
	if (self.owner.flags & FL_ONGROUND || self.owner.deadflag == DEAD_NO )
	{
		remove(self);
		return;
	}
	
	// FIXME: falling fast through too narrow a void fall trigger can still skip through it
	setorigin (self, self.owner.origin + self.owner.view_ofs);
	self.velocity = self.owner.velocity;
	self.nextthink = time + 0.05;
}

// --------------------------------
// player_spawn_void_monitor
// buddy entity that follows a dead player (or head) to trigger the void fade
// if they die above a pit and then fall in
// --------------------------------
void() player_spawn_void_monitor =
{
	entity vmon = spawn();
	
	// self is the dying player at the moment
	vmon.owner = self;
	vmon.classname = "player_voidmonitor";
	vmon.movetype = MOVETYPE_TOSS;
	vmon.solid = SOLID_BBOX;
	setsize (vmon, VEC_ORIGIN, VEC_ORIGIN);
	setorigin (vmon, self.origin + self.view_ofs);
	vmon.velocity = self.velocity;

	vmon.think = player_void_monitor_think;
	vmon.nextthink = time;
}

// --------------------------------
// void_trigger_touch
// the is-now-irretrievably-falling trigger
// --------------------------------
void() void_trigger_touch =
{
	entity e;
	if (other.classname == "player_voidmonitor")
	{
		e = other.owner;
		other.think = SUB_Remove;
		e.movetype = MOVETYPE_TOSS; // so gib head doesn't bounce 'out' of the fog
		if (e.customflags & CFL_PLUNGE) return;
	}
	else
	{
		if (!CheckValidTouch()) return;
		e = other;
		if (e.customflags & CFL_PLUNGE) return;	// don't touch the trigger a bunch of times on the way down
		// we could set a refire time on the trigger but players in coop could go over the edge simultaneously
		sound (e, CHAN_VOICE, self.noise, 1, ATTN_NONE);
	}
	
	if (time > self.attack_finished)
	{
		activator = e;
		SUB_UseTargets();
		self.attack_finished = time + 0.5;
	}
	
	e.customflags = e.customflags | CFL_PLUNGE;
	
	e.weaponmodel = string_null;
	
	local entity fall;
	
	fall = spawn();
	fall.classname = "trigger_void";
	fall.deathtype = self.deathtype;
	fall.nextthink = time + 0.05;
	fall.think = void_fallthink;
	fall.enemy = e;
	fall.owner = self.owner;
	fall.height = self.height;
	fall.oldorigin = e.origin;	// track player's descent
	fall.lip = e.origin_z - self.height; // z at bottom
	fall.pain_finished = time + self.wait;
	fall.fadecolor = self.fadecolor;
	
	eprint(fall);
	
	// gl_cshiftpercent isn't native to OG quake, so the cvar call fails and returns 0 
	// in winquake/weird engines because the cvar doesn't exist, so use a cvar introduced
	// at the same time to determine if that 0 is valid
	noTint = (cvar("gl_cshiftpercent") < CSHIFT_CUTOFF) && cvar("gl_farclip") && !coop;
	// doesn't work in coop bc the server's values will be used to determine tint/fog for clients
}


entity(entity me) void_find_teleport =
{
	if (me.target == string_null &&
		me.target2 == string_null &&
		me.target3 == string_null &&
		me.target4 == string_null)
		return world;

	entity head;
	head = world;
	while (1)
	{
		head = find(head, targetname, me.target);
		if (!head)
			break;
		if (head.classname == "info_teleport_destination" && !(head.customflags & CFL_LOCKED))
			return head;
	}
	head = world;
	while (1)
	{
		head = find(head, targetname, me.target2);
		if (!head)
			break;
		if (head.classname == "info_teleport_destination" && !(head.customflags & CFL_LOCKED))
			return head;
	}
	head = world;
	while (1)
	{
		head = find(head, targetname, me.target3);
		if (!head)
			break;
		if (head.classname == "info_teleport_destination" && !(head.customflags & CFL_LOCKED))
			return head;
	}
	head = world;
	while (1)
	{
		head = find(head, targetname, me.target4);
		if (!head)
			break;
		if (head.classname == "info_teleport_destination" && !(head.customflags & CFL_LOCKED))
			return head;
	}

	return world;
}

void(float unlock) void_lock =
{
	// self: solid bottom surface, invisible
	// self.buddy: nonsolid bottom cover, visible
	// self.enemy: plunge trigger
	
	if (unlock)
	{
		self.solid = SOLID_TRIGGER;
		self.enemy.touch = void_trigger_touch;
		self.buddy.modelindex = self.modelindex;
		
		self.flags = not(self.flags, CFL_LOCKED);
		self.enemy.flags = not(self.enemy.flags, CFL_LOCKED);
		self.buddy.flags = not(self.buddy.flags, CFL_LOCKED);
	}
	else
	{
		self.solid = SOLID_NOT;
		self.enemy.touch = SUB_Null;
		self.buddy.modelindex = 0;
		
		self.flags |= CFL_LOCKED;
		self.enemy.flags |= CFL_LOCKED;
		self.buddy.flags |= CFL_LOCKED;
	}
}

/*QUAKED func_void (.5 .2 0) ?
for holes into which one should not fall

Texture this with black (or sky?) and cover the bottom of the pit with it.  Automatically offsets its own visual model upward, to hide pesky heads and scrag corpses underneath.  Also automatically spawns a start-of-plunge trigger of the same size "height" units above itself that plays a yell sound and fades out the view of clients as they start to fall in.

The player's view will have faded completely by the time they touch the bottom, so we hold them in stasis for a little while longer there before splatting them, to imply the pit is deeper than it really is. The player can therefore feel like they fall for a long time before crash landing in darkness without you having to build a pit that deep.

Keyvalues
"delay" how long the player should 'fall' before the splat, default 3
"height" how high above the func_void the plunge trigger should spawn. do not make this high enough that players will touch it without falling in or they'll hear random screaming noises as they walk around and that'll be strange. default 128
"lip" distance to raise the visual model, default 32
"fadecolor" color to fade the screen to while falling, default black
"noise"/"noise2" override fall and splat sounds

Fires all "target"s/"killtarget"s when a client touches the plunge trigger (ie the yell, not the splat).
If the func_void's first target is an info_teleport_destination, it will hurt the player for "dmg" damage and teleport him to the destination. If "dmg" is enough to kill the player when he falls in, it continues with the fade and splat as normal.
*/
/*FGD
@SolidClass base(Target, Appearflags) color(128 50 0) = func_void : 
"for holes into which one should not fall

Texture this with black (or sky?) and cover the bottom of the pit with it.  Automatically offsets its own visual model upward, to hide pesky heads and scrag corpses underneath.  Also automatically spawns a start-of-plunge trigger of the same size 'height' units above itself that plays a yell sound and fades out the view of clients as they start to fall in.

The player's view will have faded completely by the time they touch the bottom, so we hold them in stasis for a little while longer there before splatting them, to imply the pit is deeper than it really is. The player can therefore feel like they fall for a long time before crash landing in darkness without you having to build a pit that deep.

Fires all targets when a client touches the plunge trigger (ie the yell, not the splat).

If the func_void's first target is an info_teleport_destination, it will hurt the player and teleport him to the destination. If the damage is enough to kill the player, it continues with the fade and splat as normal without teleporting."
[
	delay(string) : "how long the player should 'fall' before the splat" : "3"
	height(integer) : "how high above the func_void the plunge trigger should spawn. do not make this high enough that players will touch it without falling in or they'll hear random screaming noises as they walk around and that'll be strange." : 128
	lip(integer) : "distance to raise the visual model" : 32
	dmg(integer) : "pain to apply before salvation teleport" : 60
	fadecolor(string) : "color to fade the screen to while falling" : "0 0 0"
	noise(string) : "fall sound" : "player/q3fall.wav"
	noise2(string) : "splat sound" : "player/splat1.wav"
]
*/
void() func_void =
{
	if (!SUB_ShouldSpawn()) return;
	vector offset;
	
	if (self.noise == string_null) self.noise = "player/q3fall.wav";
	if (self.noise2 == string_null) self.noise2 = "player/splat1.wav";
	precache_sound3(self.noise);
	precache_sound3(self.noise2);
	
	// set own model to link into world, then set to null to be solid but invisible
	self.solid = SOLID_TRIGGER;
	self.movetype = MOVETYPE_NONE;
	setmodel (self, self.model);
	self.touch = void_func_touch;
	
	// recycle the same model on a nonsolid entity 32 units higher to hide detritus
	self.lip = zeroconvertdefault(self.lip, 32);
	offset = VEC_UP * self.lip;
	self.buddy = spawn();
	self.buddy.solid = SOLID_NOT;
	self.buddy.movetype = MOVETYPE_NONE;
	setorigin(self.buddy, offset);
	setmodel (self.buddy, self.model);
	self.buddy.modelindex = self.modelindex;
	self.buddy.classname = "void_ghost";
	self.buddy.owner = self;

	self.model = string_null;
	
	if (!self.height) self.height = 128;	// height above func to spawn plunge trigger
	self.delay = zeroconvertdefault(self.delay,3);	// time to spend "falling" after touching plunge trigger	
	
	// wait for other things to spawn
	//self.think = void_find_teleports;
	//self.nextthink = time + 0.1;
	self.dmg = zeroconvertdefault(self.dmg, 60);
	
	// create another solid entity with the same bounds with solid_trigger as a catch on the way down
	self.enemy = spawn();
	self.enemy.classname = "void_plunge_trigger";
	self.enemy.movetype = MOVETYPE_NONE;
	self.enemy.solid = SOLID_TRIGGER;
	self.enemy.owner = self;
	self.enemy.touch = void_trigger_touch;
	self.enemy.height = self.height + 32;
	self.enemy.wait = self.delay;	// if trigger has 'delay' field it adds a delay to its own usetargets
	self.enemy.deathtype = self.deathtype;
	self.enemy.fadecolor = self.fadecolor;
	self.enemy.noise = self.noise;
	self.enemy.noise2 = self.noise2;
	
	SUB_CopyTargets(self.enemy);
	self.enemy.targetname = self.targetname;

	offset = VEC_UP * self.height;
	
	// fatten by 64u vertically to make it hard to fall through it at high speed without touching it
	setsize (self.enemy, self.mins + offset - '0 0 32', self.maxs + offset + '0 0 32');
	
	self.lock = void_lock;

	eprint(self);
	eprint(self.enemy);
}
