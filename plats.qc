/*
=============================================================================

LIFTS AND TRAINS

=============================================================================
*/

float PLAT_LOW_TRIGGER = 1;

float() plat_try_find_trigger =
{
	entity t;
	t = find (world, targetname, self.target);
	if (!t)
	{
		dprint("plat with unmatched target\n");
		return FALSE;
	}
	else if ( (t.classname != "trigger_once") && (t.classname != "trigger_multiple") && (t.classname != "trigger_multiple_box") ) 
	{
		dprint("plat targets a non-trigger\n");
		return FALSE;
	}
	else
	{
		dprint3("plat trigger found, ", t.classname, "\n");
		t.touch = plat_center_touch;
		t.think = SUB_Null;
		t.movetype = MOVETYPE_NONE;
		t.enemy = self;
		self.trigger_field = t;
		self.target = "";
	}
	self.think = SUB_Null;
	return TRUE;
}

void() plat_spawn_inside_trigger =
{
	entity t;
	vector tmin, tmax;

	if (self.target != string_null)
	{
		dprint("overriding plat trigger\n");
		// find overridden trigger for custom trigger zones
		if (plat_try_find_trigger())
			return;
	}
	
	// touch zone should extend from the top of the plat in its lowest position
	// to 8 units above the top of the plat in its highest position. pos1 cannot
	// be assumed to be the highest position.
	t = spawn();
	local float high, low;
	
	high = max(self.pos1_z, self.pos2_z) + self.maxs_z;
	low = min(self.pos1_z, self.pos2_z) + self.maxs_z;
	
	tmin = self.mins + '25 25 0';
	tmax = self.maxs - '25 25 0';
	if (self.size_x <= 50)
	{
		tmin_x = (self.mins_x + self.maxs_x) / 2;
		tmax_x = tmin_x + 1;
	}
	if (self.size_y <= 50)
	{
		tmin_y = (self.mins_y + self.maxs_y) / 2;
		tmax_y = tmin_y + 1;
	}
	
	tmin_z = low;
	if (self.spawnflags & PLAT_LOW_TRIGGER)
		tmax_z = low + 8;
	else
		tmax_z = high + 8;
	
	t.solid = SOLID_TRIGGER;
	setsize (t, tmin, tmax);
	
	t.touch = plat_center_touch;
	t.think = SUB_Null;
	t.movetype = MOVETYPE_NONE;
	t.enemy = self;
	self.trigger_field = t;
}

void() plat_hit_top =
{
	sound (self, CHAN_VOICE, self.noise1, 1, ATTN_NORM);
	self.state = STATE_TOP;
	self.think = plat_go_down;
	self.nextthink = self.ltime + self.wait;
	SUB_UseTargetsAlt(target2);
}

void() plat_hit_bottom =
{
	sound (self, CHAN_VOICE, self.noise1, 1, ATTN_NORM);
	self.state = STATE_BOTTOM;
	SUB_UseTargetsAlt(target4);
}

void() plat_go_down =
{
	sound (self, CHAN_VOICE, self.noise, 1, ATTN_NORM);
	self.state = STATE_DOWN;
	SUB_CalcMove (self.pos2, self.speed, plat_hit_bottom);
	SUB_UseTargetsAlt(target3);
}

void() plat_go_up =
{
	sound (self, CHAN_VOICE, self.noise, 1, ATTN_NORM);
	self.state = STATE_UP;
	SUB_CalcMove (self.pos1, self.speed, plat_hit_top);
	SUB_UseTargetsAlt(target);
}

// ---------------------------------------------------------
// plat_can_go
//
// plats are guaranteed to split the party in coop, requiring multiple 
// players who want to take the same plat to stop at the edge, hold
// hands, and jump together - not foolproof in netquake. so, if any
// clients are about to get on the plat with us, just wait a moment
// so players can take the actions they want to take and not have to
// be so precious
// ---------------------------------------------------------
float() plat_can_go =
{
	if (!coop) return TRUE;

	// currently waiting
	if (time < self.attack_finished)
		return FALSE;
	
	// wait completed, don't wait more than once
	if (self.attack_finished > 0)
	{
		self.attack_finished = 0;
		return TRUE;
	}
	
	if (plat_check_other_clients())
	{
		// play a sound
		sound (self.enemy, CHAN_VOICE, self.enemy.noise1, 1, ATTN_NORM);
		self.attack_finished = time + 1.2;
		return FALSE;
	}
	return TRUE;
}

float() plat_check_other_clients =
{
	// self is trigger, other is player
	float cl = 0;
	entity pl = world;
	entity oself;
	while (cl < clients)
	{
		pl = find(pl, classname, "player");
		if (!pl) break;
		
		if (pl != self &&	// players can't block themselves
			vlen(other.origin - pl.origin) < 192 && // within 192u
			!EntitiesTouching(pl,self) && // not already aboard
			normalize(other.origin - pl.origin) * pl.velocity > -100 ) // not moving away
		{
			oself = self;
			self = other;
			if (visible(pl))	// visible to the first player
			{
				self = oself;
				return TRUE;
			}
			self = oself;
		}
		cl++;
	}
	return FALSE;
}

void() plat_center_touch =
{
	if (!CheckValidTouch()) return;

	if (self.enemy.state == STATE_BOTTOM)
	{
		if (plat_can_go())
			SUB_CallAsSelf(plat_go_up, self.enemy);
	}
	else if (self.enemy.state == STATE_TOP)
		self.enemy.nextthink = max(self.enemy.nextthink, self.enemy.ltime + 1);	// delay going down
}
/*
void() plat_outside_touch =
{
	if (!CheckValidTouch()) return;
		
//dprint ("plat_outside_touch\n");
	self = self.enemy;
	if (self.state == STATE_TOP)
		plat_go_down ();
}
*/
void() plat_trigger_use =
{
	if (self.think)
		return;		// already activated
	plat_go_down();
}


void() plat_crush =
{
//dprint ("plat_crush\n");

	T_Damage (other, self, self, 1);
	
	if (self.state == STATE_UP)
		plat_go_down ();
	else if (self.state == STATE_DOWN)
		plat_go_up ();
	else
		dprint("plat_crush: bad self.state\n");
}

void(entity p) plat_force = 
{
	if (p.state == STATE_TOP || p.state == STATE_UP)
		SUB_CallAsSelf(plat_go_down, p);
	else
		SUB_CallAsSelf(plat_go_up, p);
}

void() plat_use =
{
	self.use = SUB_Null;
	if (self.state != STATE_UP)
		dprint("plat_use: not in up state\n");
	plat_go_down();
}

void(float unlock) plat_lock =
{
	if (unlock)
	{
		self.trigger_field.touch = plat_center_touch;
		if (self.targetname != string_null)
			self.use = plat_use;
		self.customflags = not(self.customflags, CFL_LOCKED);
	}
	else
	{
		self.trigger_field.touch = SUB_Null;
		self.use = SUB_Null;
		self.customflags |= CFL_LOCKED;
	}
}

void() plat_finalize =
{
	plat_spawn_inside_trigger ();	// the "start moving" trigger	
	// delayed to finalize() bc if the plat spawns before the trigger this will fail

	// also delayed so all targeters can spawn:
	if (self.targetname != string_null && !door_getslocked(self))
	{
		setorigin (self, self.pos1);
		self.state = STATE_UP;
		self.use = plat_use;
	}
	else
	{
		setorigin (self, self.pos2);
		self.state = STATE_BOTTOM;
	}
}

/*QUAKED func_plat (0 .5 .8) ? PLAT_LOW_TRIGGER
Plats are always drawn in the extended position, so they will light correctly.
If the plat is the target of another trigger or button, it will start out disabled in the top position until it is triggered, when it will lower and become a normal plat.
If the plat targets a trigger once/multiple/multiple_box, it will override the plat's default activation zone (consuming the trigger).

"PLAT_LOW_TRIGGER" activation zone will only be at the bottom of the movement course, instead of the whole vertical

"speed"		default 150
"lip"		implicitly determine the distance the plat moves
"height"	explicitly determine the distance the plat moves
"pos1"&"pos2"	directly override top and bottom positions - plat can be built anywhere else in the map
"wait"		time to pause at apex in seconds, default 3
"sounds"
	1: base fast
	2: chain slow (default if 0)
	-1: silent
*/
/*FGD
@SolidClass base(Appearflags, Targetname, Func, Target, AltTarget) = func_plat : "Elevator platform.
Plats are always drawn in the extended position, so they will light correctly.
If the plat is the target of another trigger or button, it will start out disabled in the top position until it is triggered, when it will lower and become a normal plat.
If the plat targets a trigger once/multiple/multiple_box, it will override the plat's default activation zone (consuming the trigger).

Movement distance can be defined with 'height' or 'lip'. By instead setting 'pos1' & 'pos2' you can directly override the top and bottom positions, allowing the plat to be built anywhere else in the map. This is useful for building a plat where it will be lit the best.

The 'low trigger volume' spawnflag will put the activation zone only at the bottom of the movement course, instead of the whole vertical.

Alt Target Pattern: 'target' upon rising, 'target2' upon reaching top, 'target3' upon descending, 'target4' upon reaching bottom." 
[	
	spawnflags(Flags) =
	[
		1 : "Low trigger volume" : 0
	]
	target(target_destination) : "Custom activation trigger"
	speed(integer) : "Speed" : 150
	height(integer) : "Travel altitude (can be negative)" : 0
	lip(integer) : "Lip remaining at bottom of move" : 8
	wait(string) : "Apex pause time" : "3"
	pos1(string) : "Override top position (x y z)"
	pos2(string) : "Override bottom position (x y z)"
	sounds(choices) : "Sound" : 2 =
	[
		-1: "Silent"
		1: "Base fast"
		2: "Chain Slow"
	]
]	
*/
void() func_plat =
{
	if (!SUB_ShouldSpawn()) return;

	precache_model_safe(self.model);

	if (self.sounds == 0)
		self.sounds = 2;
	// FIXME load generic plat sound

	if (self.sounds == -1)
	{
		if (!self.noise)
			self.noise = ("misc/null.wav");
		if (!self.noise1)
			self.noise1 = ("misc/null.wav");
		precache_sound_safe(self.noise);
		precache_sound_safe(self.noise1);
	}
	if (self.sounds == 1)
	{
		precache_sound_safe ("plats/plat1.wav");
		precache_sound_safe ("plats/plat2.wav");
		self.noise = "plats/plat1.wav";
		self.noise1 = "plats/plat2.wav";
	}

	if (self.sounds == 2)
	{
		precache_sound_safe ("plats/medplat1.wav");
		precache_sound_safe ("plats/medplat2.wav");
		self.noise = "plats/medplat1.wav";
		self.noise1 = "plats/medplat2.wav";
	}

	self.mangle = self.angles;
	self.angles = '0 0 0';

//	self.classname = "plat";
	self.solid = SOLID_BSP;
	self.movetype = MOVETYPE_PUSH;
	setorigin (self, self.origin);	
	setmodel (self, self.model);
	setsize (self, self.mins, self.maxs);

	if (!self.speed)
		self.speed = 150;
	if (!self.wait)
		self.wait = 3;
	
	if (!self.height)
	{
		if (self.distance)
			self.height = self.distance;
		else
		{
			if (!self.lip) self.lip = 8;
			self.height = self.size_z - self.lip;
		}
	}	
		
	if (!self.pos1 && !self.pos2)
	{
		// pos1 is the top position, pos2 is the bottom
		self.pos1 = self.origin;
		self.pos2 = self.origin;
		if (self.height)
			self.pos2_z = self.origin_z - self.height;
	}
	self.blocked = plat_crush;
	self.use = plat_trigger_use;
	self.lock = plat_lock;

	self.think = plat_finalize;
	self.nextthink = self.ltime + 0.1;
}

//============================================================================

const float TRAIN_INHERIT = 1;
const float TRAIN_TOGGLE = 2;
const float TRAIN_SMOOTHSPEED = 4;

void() train_sounds =
{
	if (self.sounds == 0)
	{
		if (!self.noise)
			self.noise = ("misc/null.wav");
		if (!self.noise1)
			self.noise1 = ("misc/null.wav");
		precache_sound_safe(self.noise);
		precache_sound_safe(self.noise1);
	}

	if (self.sounds == 1)
	{
		self.noise = ("plats/train2.wav");
		precache_sound_safe ("plats/train2.wav");
		self.noise1 = ("plats/train1.wav");
		precache_sound_safe ("plats/train1.wav");
	}
	if (self.sounds == 2)
	{
		precache_sound_safe ("plats/plat1.wav");
		precache_sound_safe ("plats/plat2.wav");
		self.noise1 = "plats/plat1.wav";
		self.noise = "plats/plat2.wav";
	}

}

/*FGD
@baseclass = TrainSounds [
	sounds(choices) : "Sound" : 1 =
	[
		0: "Silent/Override"
		1: "Ratchet Metal"
		2: "Base Lift"
	]
]
@baseclass base(Appearflags, Targetname, TrainSounds, Func, AltTarget) = Train [
	speed(integer) : "Speed (units per second)" : 64
	target(target_source) : "Target to start at"
	dmg(integer) : "Damage on block" : 2
	noise(string) : "Override stop sound"
	noise1(string) : "Override move sound"
	pausetime(string) : "Default wait time" : "0.1"
]
*/

void() flytrain_ghost_die =
{
	if (self.owner.th_melee)
		SUB_CallAsSelf(self.owner.th_melee, self.owner);
	else
		remove(self.owner);
	remove(self);
}

void() flytrain_ghost_resume =
{
	if (self.state == STATE_OFF)	// already deactivated
		return;	
	if (self.pos2)
		// we were stopped along a bezier curve, resume with saved values
		SUB_CalcMoveCurveSeg();
	else
		SUB_CalcMove (self.enemy.origin - self.movedir, self.speed, self.th_stand);
}

void() flytrain_ghost_blocked =
{
	if (self.state == STATE_OFF)	// already deactivated
		return;	
	self.velocity = VEC_ORIGIN;
	self.think = flytrain_ghost_resume;
	self.nextthink = localtime(self) + 0.05;
}

// if the flytrain is blocked, it has to halt its buddy's movement and schedule it to restart immediately
void() flytrain_blocked =
{
	if (self.buddy.state == STATE_ON)
		SUB_CallAsSelf(flytrain_ghost_blocked, self.buddy);

	if (time < self.attack_finished)
		return;
	self.attack_finished = time + self.dmgtime;
	T_Damage (other, self, self, self.dmg);
}

void() flytrain_killed =
{
	if (self.customflags & CFL_LOCKED) return;
	activator = damage_attacker;
	self.health = self.max_health;
	SUB_CallAsSelf(train_use, self.buddy);
}

void() flytrain_think =
{
	vector delta, wishvel;

	if (time > self.pain_finished)
	{
		self.pain_finished = time + 0.5;
		self.pos1_x = crandom() * self.width;
		self.pos1_y = crandom() * self.width;
		self.pos1_z = crandom() * self.height;
		if (self.buddy.velocity != VEC_ORIGIN)
			self.pos1 = self.pos1 * 0.5;
	}
	
	delta = (self.buddy.origin + self.pos1) - self.origin - self.movedir;
	wishvel = self.buddy.velocity;
	
	self.takedamage = self.buddy.takedamage;
	
	// if the ghost train hits a speed -1 teleport corner we have to teleport with it, not zoom to it
	if (self.buddy.teleport_time)
	{
		self.buddy.teleport_time = 0;
		setorigin(self, self.buddy.origin - self.movedir);
	}
	else
		wishvel += delta;
	
	self.velocity = (self.velocity * 4 + wishvel) * 0.2;
	self.nextthink = localtime(self) + 0.05;
}

void() flytrain_init =
{
	dprint("in flytrain_init\n");
	setorigin (self, self.buddy.origin - self.movedir);
	self.think = flytrain_think;
	flytrain_think();
}

void() flytrain_setup =
{
	if (!self.target)
		objerror("flytrain without a target");
		
	dprint("in flytrain_setup\n");
	// spawn a nonsolid point ent to follow our path sensibly and 
	//	handle all train-like logic, bc it's a func_train
	// we shadow it at all times with floaty drifty movement to keep 
	//	that logic separate from train behavior and allow us to sludge
	//	the velocity over a few frames for rubber-bandy motion without
	//	colliding with state changes
	self.buddy = spawn();
	self.buddy.spawnflags = self.spawnflags | TRAIN_INHERIT | TRAIN_SMOOTHSPEED; // flytrains always inherit speed
	self.buddy.speed = self.speed;
	self.dmg = zeroconvertdefault(self.dmg, 2);
	if (!self.dmgtime)
		self.dmgtime = 0.5;
	self.buddy.pausetime = self.pausetime;
	self.buddy.health = self.health;
	self.buddy.sounds = self.sounds;
	self.buddy.solid = -1;
	SUB_CopyTargets(self.buddy);
	self.buddy.targetname = self.targetname;
	self.buddy.owner = self;
	
	SUB_CallAsSelf(func_train_point, self.buddy);
	self.buddy.classname = "func_flytrain_ghost";
	self.buddy.th_stand = train_wait;
	self.buddy.th_melee = flytrain_ghost_die;
	
	self.width = zeroconvertdefault(self.width, 8);
	self.height = zeroconvertdefault(self.height, 8);
	self.max_health = 0;

	self.blocked = flytrain_blocked;
	self.solid = zeroconvertdefault(self.solid, SOLID_BSP);
	if (!self.solid)
		self.movetype = MOVETYPE_NOCLIP;
	else
	{
		self.movetype = MOVETYPE_PUSH;
		if (self.health)
		{
			self.max_health = self.health;
			self.th_die = flytrain_killed;
			self.takedamage = DAMAGE_YES;
		}
	}
	
	self.think = flytrain_init;	// wait for buddy to call train_find
	self.nextthink = localtime(self) + 0.25; // magic amount of time :|
}

/*QUAKED func_flytrain (0 .5 .8) ? - TOGGLE
Acts as a func_train with PATH_SPEED and SMOOTH_SPEED set, with additional random motion and and gentle smoothing at stops, starts, and hard corners.

"width"		Horizontal drift range, default 8 (-1 for 0)
"height"	Vertical drift range, default 8 (-1 for 0)
"lip"		Length of 'leash', default 64 (increase if train jumps around at high speeds)
"sounds"
0) none, or, set your own with 'noise' (stop sound) and 'noise1' (move sound)
1) ratchet metal
2) base plat
*/
/*FGD
@baseclass base(Train) = Flytrain [
	width(string) : "Horizontal drift range" : "8"
	height(string) : "Vertical drift range" : "8"
]
@SolidClass base(Flytrain) = func_flytrain : 
"Acts as a func_train with PATH_SPEED and SMOOTH_SPEED set, with additional random motion and and gentle smoothing at stops, starts, and hard corners. Will fire all targets of a pathcorner on arrival, but does not normally fire its own targets.

Alt Target Pattern: 'target' selects path start, 'target2' on each pathcorner arrival, 'target3' on each departure, 'target4' on termination"
[
	width(string) : "Horizontal drift range" : "8"
	height(string) : "Vertical drift range" : "8"
]
*/
void() func_flytrain =
{
	if (!SUB_ShouldSpawn()) return;
	dprint("in flytrain\n");
	flytrain_setup();
	
	precache_model_safe(self.model);
	setmodel (self, self.model);
	setsize (self, self.mins , self.maxs);
	self.movedir = (self.mins + self.maxs) * 0.5;
}

/*QUAKED func_flytrain_point (0 .5 .8) (-8 -8 -8) (8 8 8) - TOGGLE
Acts as a func_train with PATH_SPEED and SMOOTH_SPEED set, with additional random motion and and gentle smoothing at stops, starts, and hard corners.

"model"		model to use
"width"		Horizontal drift range, default 8 (-1 for 0)
"height"	Vertical drift range, default 8 (-1 for 0)
"lip"		Length of 'leash', default 64 (increase if train jumps around at high speeds)
"sounds"
0) none, or, set your own with 'noise' (stop sound) and 'noise1' (move sound)
1) ratchet metal
2) base plat
*/
/*FGD
@PointClass base(Flytrain) size(16 16 16) = func_flytrain_point : 
"Acts as a func_train with PATH_SPEED and SMOOTH_SPEED set, with additional random motion and and gentle smoothing at stops, starts, and hard corners. Will fire all targets of a pathcorner on arrival, but does not normally fire its own targets.

Alt Target Pattern: 'target' selects path start, 'target2' on each pathcorner arrival, 'target3' on each departure, 'target4' on termination"
[
	model(string) : "Model to use"
]
*/
void() func_flytrain_point =
{	
	if (!SUB_ShouldSpawn()) return;

	flytrain_setup();
	precache_model_safe(self.model);
	setmodel (self, self.model);
	setsize (self, self.mins , self.maxs);
	self.classname = "func_flytrain";
	self.movedir = '0 0 0';
}

//============================================================================

void() train_blocked =
{
	if (time < self.attack_finished)
		return;
	self.attack_finished = time + self.dmgtime;
	T_Damage (other, self, self, self.dmg);
}

void() train_killed =
{
	if (self.customflags & CFL_LOCKED) return;
	activator = damage_attacker;
	self.health = self.max_health;
	train_use();
}

void(float unlock) train_lock =
{
	if (unlock)
	{
		self.customflags = not(self.customflags, CFL_LOCKED);
		if (self.max_health)
		{
			self.health = self.max_health;
			self.takedamage = DAMAGE_YES;
		}
	}
	else
	{
		self.customflags |= CFL_LOCKED;
		self.takedamage = DAMAGE_NO;
	}
}

void() train_off =
{
	self.state = STATE_OFF;
	if (self.customflags & CFL_LOCKED) return;
	if (self.max_health)
	{
		self.health = self.max_health;
		self.takedamage = DAMAGE_YES;
	}
}
void() train_on =
{
	self.state = STATE_ON;
	if (self.max_health && !(self.spawnflags & TRAIN_TOGGLE))
		self.takedamage = DAMAGE_NO;
}

void() train_use =
{
	if ((self.spawnflags & TRAIN_TOGGLE) && (self.origin + self.movedir) != self.enemy.origin)
	{
		if (self.state == STATE_ON)
		{
			train_off();
			self.velocity = VEC_ORIGIN;
			self.nextthink = 0;
			sound (self, CHAN_VOICE, self.noise, 1, ATTN_NORM);
		}
		else
		{
			train_on();
			sound (self, CHAN_VOICE, self.noise1, 1, ATTN_NORM);
			if (self.pos2)
				// we were stopped along a bezier curve, resume with saved values
				SUB_CalcMoveCurveSeg();
			else
				SUB_CalcMove (self.enemy.origin - self.movedir, self.speed, self.th_stand);
		}
		return;
	}

	if (self.state == STATE_ON)	// already activated
		return;	
	train_next();
}

void() train_wait =	// arrival at a pathcorner
{
	entity corner = self.enemy;
	
	SUB_UseTargetsAlt(target2);

	if (self.wait == -1)
	{
		train_off();
		self.use = train_use;
		sound (self, CHAN_VOICE, self.noise, 1, ATTN_NORM);
	}
	else if (self.wait > 0)
	{
		train_off();	// allow triggering while waiting
		self.think = train_next;
		self.nextthink = localtime(self) + self.wait;
		if (self.wait > 0.1)
			sound (self, CHAN_VOICE, self.noise, 1, ATTN_NORM);
	}
	else 	// self.wait is 0 or a garbage value
	{
		train_next();
	}
	
	// trains now fire their pathcorners' targets on arrival
	// if a player is riding the train, treat them as activator
	if (activator.classname != "player")
		activator = get_closest_client();
	SUB_UseEntTargets(corner);
	// fire them after sorting corner wait stuff, in case the corner triggers
	// the train itself (useful for wait-locking a pathcorner with a relay)
}

void() train_next =	// departure for next pathcorner
{
	entity corner, ctrl;
	float dspeed, segs;
	corner = findunlockedtarget(self.enemy, world);
	if (!corner)
	{
		dprint("train_next: no next target\n");
		// .th_melee is a train's "expire at end of path" function, because .th_die
		// has to be reserved for shootable trains to work with T_Damage()/Killed()
		if (self.th_melee)
			self.th_melee();
		else
			remove(self);
		SUB_UseTargetsAlt(target4);
		return;
	}
	self.oldenemy = self.enemy;
	if (corner.spawnflags & 16)
	{
		ctrl = corner;
		corner = findunlockedtarget(ctrl, world);
		if (!corner)
		{
			dprint("train_next: no next target after curve point\n");
			if (self.th_melee)
				self.th_melee();
			else
				remove(self);
			SUB_UseTargetsAlt(target4);
			return;
		}
	}
	if (corner.wait)
		self.wait = corner.wait;
	else
		self.wait = self.pausetime;
	
	self.enemy = corner;
	SUB_UseTargetsAlt(target3);
	train_on();
	
	if (self.oldenemy.speed == -1)
	{
		setorigin(self, corner.origin - self.movedir);
		self.teleport_time = time;
		self.th_stand();
		return;
	}
	else if (self.oldenemy.speed > 0 && self.spawnflags & TRAIN_INHERIT)
		self.speed = self.oldenemy.speed;

	sound (self, CHAN_VOICE, self.noise1, 1, ATTN_NORM);
	
	if (ctrl)
	{
		if ((self.spawnflags & TRAIN_INHERIT) && (self.spawnflags & TRAIN_SMOOTHSPEED) && corner.speed > 0)
			dspeed = corner.speed;
		else
			dspeed = self.speed;
		
		if (ctrl.count)
			segs = ctrl.count;
		else
			// chop the curve into roughly 200ms segments
			segs = ceil(5 * bez_lenApprox(self.origin, ctrl.origin, corner.origin) / ((self.speed + dspeed) / 2));

		SUB_CalcMoveCurve(corner.origin - self.movedir, ctrl.origin - self.movedir, segs, self.speed, dspeed, self.th_stand);
		return;
	}
	
	if ((self.spawnflags & TRAIN_INHERIT) && (self.spawnflags & TRAIN_SMOOTHSPEED) && self.enemy.speed > 0)
	{
		// 'curved' motion in a straight line, for the speed stepping
		vector travel = (corner.origin - self.movedir) - self.origin;
		segs = max( 2, floor( vlen(travel) / 64 ) );	// pick an intelligent segment count
		SUB_CalcMoveCurve(corner.origin - self.movedir, self.origin + travel * 0.5, segs, self.speed, self.enemy.speed, self.th_stand);
	}
	else
		SUB_CalcMove (corner.origin - self.movedir, self.speed, self.th_stand);
}

void() func_train_find =
{
	entity corner;

	corner = findunlockedtarget(self, world);
	self.enemy = corner;
	//self.target = corner.target;
	setorigin (self, corner.origin - self.movedir);
	if ((self.spawnflags & TRAIN_INHERIT) && corner.speed > 0)
		self.speed = corner.speed;
	if (self.targetname == string_null)
	{	// not triggered, so start immediately
		train_on();
		self.nextthink = localtime(self) + 0.1;
		self.think = train_next;
	}
}

void() func_train_setup =
{
	if (!self.speed)
		self.speed = 100;
	if (!self.target)
		objerror("func_train without a target");
	self.dmg = zeroconvertdefault(self.dmg, 2);
	if (!self.dmgtime)
		self.dmgtime = 0.5;
	self.pausetime = zeroconvertdefault(self.pausetime, 0.1);
	self.wait = 0;	// this is american mcgee's fault

	train_sounds();

//	self.cnt = 1;
	self.solid = zeroconvertdefault(self.solid, SOLID_BSP);
	if (!self.solid)
		self.movetype = MOVETYPE_NOCLIP;
	else
		self.movetype = MOVETYPE_PUSH;
	self.blocked = train_blocked;
	self.use = train_use;
	self.lock = train_lock;
	self.classname = "train";
	
	self.max_health = 0;
	if (self.health)
	{
		self.max_health = self.health;
		self.th_die = train_killed;
		self.takedamage = DAMAGE_YES;
	}
	train_off();

	// start trains on the second frame, to make sure their targets have had
	// a chance to spawn
	self.nextthink = localtime(self) + 0.1;
	self.think = func_train_find;

}

/*QUAKED func_train (0 .5 .8) ? PATH_SPEED TOGGLE SMOOTHSPEED
Trains are moving platforms that players can ride. Its origin is the min corner of the train. 
The train spawns at the first target it is pointing at. If the train is the target of a button or trigger, it will not begin moving until activated.
A train will fire all targets of a pathcorner on arrival.

Keys:
"speed"	default 100
"dmg"	default	2
"sounds"
	0) none, or, set your own with 'noise' (stop sound) and 'noise1' (move sound)
	1) ratchet metal
	2) base plat
"pausetime"	pausetime at a pathcorner that doesn't specify a wait, default 0.1, -1 for continuous motion
"health" allow the train to be shot to trigger it whenever it could normally be triggered (toggle spawnflag applies)

Spawnflags:
PATH_SPEED: train will inherit 'speed' value from path_corners as it reaches them
If a path_corner's speed is -1, the func_train's move when LEAVING that corner will be to snap instantly to the next corner.
TOGGLE: allow starting/stopping motion anywhere on its path (default is to ignore triggerings when in motion)
SMOOTH_SPEED: if PATH_SPEED, train will smoothly blend to its destination's 'speed' as it travels to it
*/
/*FGD
@SolidClass base(Train) = func_train : "Moving platform that players can ride. 
Its origin is the min corner of the train. 
The train spawns at the first target it is pointing at. If the train is the target of a button or trigger, it will not begin moving until activated.
Will fire all targets of a pathcorner on arrival, but does not normally fire its own targets.


If 'Speed from path' is set, the train will inherit the 'speed' value from path_corners as it reaches them. If 'blend speed smoothly' is also set, the train will instead smoothly blend to its destination's 'speed' as it travels to it.
If a path_corner's speed is -1, the func_train's move when LEAVING that corner will be to snap instantly to the next corner.
The 'Toggle' spawnflag allows starting and stopping the motion anywhere on the train's path (default is to ignore triggerings when in motion).
Setting 'health' will allow the train to be shot to trigger it whenever it could normally be triggered (toggle spawnflag applies). 

Alt Target Pattern: 'target' selects path start, 'target2' on each pathcorner arrival, 'target3' on each departure, 'target4' on termination"
[
	spawnflags(Flags) = [
		1 : "Speed from path" : 0
		2 : "Toggle" : 0
		4 : "Blend speed smoothly" : 0
	]
	health(integer) : "Health (shootable if > 0)"
]
*/
void() func_train =
{	
	if (!SUB_ShouldSpawn()) return;
	func_train_setup();
	
	self.th_stand = train_wait;
	
	precache_model_safe(self.model);
	setmodel (self, self.model);
	setsize (self, self.mins , self.maxs);
	setorigin (self, self.origin);
	self.movedir = self.mins;
}

/*QUAKED func_train_point (0 .5 .8) (-8 -8 -8) (8 8 8) PATH_SPEED
Trains are moving platforms that players can ride.
The targets origin specifies the min point of the train at each corner. The train spawns at the first target it is pointing at.
If the train is the target of a button or trigger, it will not begin moving until activated.
A train will fire all targets of a pathcorner on arrival.
Keys:
"model" model to use
"speed"	default 100
"dmg"	default	2
"sounds"
	0) none, or, set your own with 'noise' (stop sound) and 'noise1' (move sound)
	1) ratchet metal
	2) base plat
"pausetime"	pausetime at a pathcorner that doesn't specify a wait, default 0.1, -1 for continuous motion

Spawnflags:
PATH_SPEED: train will inherit 'speed' value from path_corners as it reaches them
*/
/*FGD
@PointClass base(Train) = func_train_point : "Moving platform that players can ride. 
The point entity is the origin, even if a model is specified.
The train spawns at the first target it is pointing at. If the train is the target of a button or trigger, it will not begin moving until activated.
Will fire all targets of a pathcorner on arrival, but does not normally fire its own targets.

If 'Speed from path' is set, the train will inherit the 'speed' value from path_corners as it reaches them. If 'blend speed smoothly' is also set, the train will instead smoothly blend to its destination's 'speed' as it travels to it.
If a path_corner's speed is -1, the func_train's move when LEAVING that corner will be to snap instantly to the next corner.
The 'Toggle' spawnflag allows starting and stopping the motion anywhere on the train's path (default is to ignore triggerings when in motion).

Alt Target Pattern: 'target' selects path start, 'target2' on each pathcorner arrival, 'target3' on each departure, 'target4' on termination"
[
	model(string) : "Model to use"
	spawnflags(Flags) = [
		1 : "Speed from path" : 0
		2 : "Toggle" : 0
		4 : "Blend speed smoothly" : 0
	]
]
*/
void() func_train_point =
{	
	if (!SUB_ShouldSpawn()) return;
	func_train_setup();
	
	self.th_stand = train_wait;
	
	precache_model_safe(self.model);
	setmodel (self, self.model);
	setsize (self, self.mins, self.maxs);
	setorigin (self, self.origin);
	self.movedir = VEC_ORIGIN;
}

// =======================================

/*
	FUNC_BOBBING

a lot has been done here to never ever rely on values that are repeatedly summed
over time, as floating point error will cause gradual drift.

usually, movers use self.ltime so that time doesn't advance for them while they're
blocked, preventing SUB_CalcMove from being shifted off the end of its motion and
screwing up doors. we don't do that here, because accumulated time error in .ltime  
will cause bobbings to slowly slide out of phase with each other and not keep good 
time. if the mapper sets an oscillation period of 5.0 seconds, the mover damn sure
better oscillate once every exactly 5 seconds, not '5-ish'.

engine structure requires that mover thinks be scheduled using .ltime because that's
what it compares a MOVETYPE_PUSH's nextthink against, but we can use global time for
actual positioning/velocity. it requires some particular gymnastics in the .blocked()
function, but the result is precise and seamless.

.wait: wavelength in seconds
.delay: current phase offset (0-1)
.search_time: origin point in time of the cosine wave. whenever we save it, we shift
	it backwards by the current .delay * .wait
.length: think rate, usually 0.1 but can be lower on hyperactive bobbers
*/

const float SFLAG_BOB_CRUSHER = 2;
const float SFLAG_BOB_STOPLOW = 4;
const float SFLAG_BOB_STOPMID = 8;
const float SFLAG_BOB_STOPHI = 16;
const float SFLAG_BOB_STOP = 4+8+16;

void() func_bobbing_blocked = 
{
	T_Damage (other, self, self, self.dmg);
	
	if (self.spawnflags & SFLAG_BOB_CRUSHER)	// don't reverse
		return;
	
	// reversing direction entails reversing the phase
	self.delay = (self.delay * -1) + 1 + (self.length / self.wait);
	// put it one think in the future too
	
	// set new starting conditions to reanchor the reverse movement at
	// the moment of contact
	self.search_time = time - self.delay * self.wait - self.length;
	// subtracting .length puts the reversed wave one more think in the past.
	// if we don't we'll get a frame of 0 movement
	
	// start new movement now or we'll be a CRUSHER anyway
	func_bobbing_think();
}

void() func_bobbing_use = 
{
	self.think = func_bobbing_think;
	
	if (self.state == 2)	// a future stop was requested but we never reached it
		self.state = 1;		// go back to being plain old 'on'
	else
		self.state = !self.state;
	
	if (self.state)	// start immediately
	{
		self.search_time = time - self.delay * self.wait;
		sound (self, CHAN_VOICE, self.noise1, 1, ATTN_NORM);	// move
		self.think();
		return;
	}
	
	if (self.spawnflags & SFLAG_BOB_STOP)	// stop at an apex, not immediately
	{
		self.state = 2;
		return;
	}
	
	// stop immediately
	sound (self, CHAN_VOICE, self.noise, 1, ATTN_NORM);	// cut off move sound with stop sound
	self.nextthink = 0;
}

vector(float phase) func_bobbing_pos =
{
	vector pos;
	float cosD;
	
	cosD = (1 - cos(360 * phase)) / 2;	// flip -1/1 and scale to 0-1
	pos = self.pos1 + (cosD * (self.pos2 - self.pos1));
	return pos;
}

void() func_bobbing_think =
{
	if (!self.state)
	{
		self.velocity = VEC_ORIGIN;
		return;
	}

	vector dst;
	float phase;
	float atLow, atHigh, stop;
	
	// always derive current phase from a fixed starting time rather than
	// summing an offset every think, or we'll accumulate error and drift
	phase = ((time - self.search_time) / self.wait) % 1;
	if (phase < self.delay)
		phase += 1;	// don't wrap yet
	
	atLow = (self.delay < 0.5 && phase >= 0.5);
	atHigh = (self.delay < 1 && phase >= 1);
	
	if (self.state == 2) // stop at our earliest convenience
	{
		if (atLow && (self.spawnflags & SFLAG_BOB_STOPLOW))
		{
			phase = 0.5;
			stop = TRUE;
		}
		else if (atHigh && (self.spawnflags & SFLAG_BOB_STOPHI))
		{
			phase = 0;
			stop = TRUE;
		}
		else if (self.spawnflags & SFLAG_BOB_STOPMID)
		{
			if (self.delay < 0.25 && phase >= 0.25)
			{
				phase = 0.25;
				stop = TRUE;
			}
			else if (self.delay < 0.75 && phase >= 0.75)
			{
				phase = 0.75;
				stop = TRUE;
			}		
		}
	}	
	else if ( atLow || atHigh )
	{
		// when we pass either apex, repeat the noises
		sound (self, CHAN_VOICE, self.noise1, 1, ATTN_NORM);	// move
		sound (self, CHAN_BODY, self.noise, 1, ATTN_NORM);	// stop
	}
	
	if (stop)
	{
		self.state = 0;
		sound (self, CHAN_VOICE, self.noise, 1, ATTN_NORM);	// cut off move sound with stop sound
	}
	
	self.delay = phase;
	if (self.delay > 1)	// now we can wrap
		self.delay -= 1;
	
	// whither are we going
	dst = func_bobbing_pos(phase);
	
	self.velocity = (dst - self.origin) / self.length;
	self.nextthink = self.ltime + self.length;
}

/*QUAKED func_bobbing (0 .5 .8) ? START_OFF CRUSHER STOP_LOW STOP_MID STOP_HIGH - - START_INVIS
Bobbing platform. Moves in a smooth sine wave. Build at the center of motion, specify 'wait' for the wavelength in seconds and 'distance' for the amplitude (distance from end to end) in units.
Trigger to freeze/reactivate.

"angle" set bob axis
"distance" total distance of bob, will move half this far in either direction
"pos1"/"pos2" ignore angle/distance and set apex offsets directly
"wait" wavelength of bob in seconds
"delay" phase offset to start at (0 = pos1, 0.5 = pos2, 1.0 = back at pos1 again)
"sounds"
0) none, or, set your own with 'noise' (stop sound) and 'noise1' (move sound)
1) ratchet metal
2) base plat

Spawnflags
START_OFF	start off
CRUSHER		don't reverse when blocked
STOP_*		when triggered off, keep oscillating until reaching the low/high/midpoint and stop there. checking more than one adds eligible stopping places, and the bobber will stop at the first one reached.
*/
/*FGD
@baseclass base(Appearflags, Targetname, TrainSounds, Angle, Func, FuncInvis) = Bob
[
	spawnflags(flags) = [
		1 : "Start off" : 0
		2 : "Crusher (no reverse)" : 0
		4 : "Don't stop until low pos" : 0
		8 : "Don't stop until mid pos" : 0
		16 : "Don't stop until high pos" : 0
	]
	wait(string) : "Period (Wavelength)" : "4"
	distance(integer) : "Length (Amplitude)" : 64
	delay(string) : "Starting offset (0-1) (Phase)" : "0.0"
	dmg(integer) : "Damage when blocked" : 2
	noise(string) : "Override stop sound"
	noise1(string) : "Override move sound"
	pos1(string) : "Override peak position (relative)"
	pos2(string) : "Override trough position (relative)"
]
@SolidClass base(Bob) = func_bobbing : "Bobbing platform.
Moves in a smooth sine wave. Build at the center of motion, specify 'wait' for the wavelength in seconds and 'distance' for the amplitude (distance from end to end) in units. Use 'delay' to set a phase offset (0-1).
Trigger to freeze in place or reactivate. If any 'don't stop until' spawnflags are checked, the bobber will keep oscillating until it reaches one of the designated positions and stop there.

Set both 'pos1' & 'pos2' to override the two apex positions (ends of the bob) to build and light your plat wherever."  []
*/
void() func_bobbing =
{
	if (!SUB_ShouldSpawn()) return;
	
	precache_model_safe(self.model);
	train_sounds();

	SetMovedir();
	if (!self.distance)
		self.distance = 64;
	if (self.wait <= 0)
		self.wait = 4;
	
	self.dmg = zeroconvertdefault(self.dmg, 2);
	
	if (!self.pos1 && !self.pos2)
	{
		self.pos1 = self.origin + self.distance * 0.5 * self.movedir;
		self.pos2 = self.origin - self.distance * 0.5 * self.movedir;
	}
	self.length = min(0.1, self.wait / 6);

	if (self.spawnflags & 128)
		self.use = func_bobbing_spawn;
	else
		func_bobbing_spawn();
}

void() func_bobbing_spawn =
{
	if (!(self.spawnflags & START_OFF))
	{
		self.think = func_bobbing_use;
		self.nextthink = 0.3;	// wait for items and monsters to rest on it
	}
	
	self.use = func_bobbing_use;
	self.blocked = func_bobbing_blocked;
	
	self.solid = zeroconvertdefault(self.solid, SOLID_BSP);
	if (!self.solid)
		self.movetype = MOVETYPE_NOCLIP;
	else
		self.movetype = MOVETYPE_PUSH;

	setmodel (self, self.model);
	setsize (self, self.mins, self.maxs);
	setorigin (self, func_bobbing_pos(self.delay));
}


/*QUAKED func_bobbing_point (0 .5 .8) (-8 -8 -8) (8 8 8) START_OFF CRUSHER STOP_LOW STOP_MID STOP_HIGH - - START_INVIS
Bobbing platform. Moves in a smooth sine wave. Build at the center of motion, specify 'wait' for the wavelength in seconds and 'distance' for the amplitude (distance from end to end) in units.
Trigger to freeze/reactivate.

"angle" set bobaxis
"distance" total distance of bob, will move half this far in either direction
"pos1"/"pos2" ignore angle/distance and set apex offsets directly
"wait" wavelength of bob in seconds
"delay" phase offset to start at (0 = pos1, 0.5 = pos2, 1.0 = back at pos1 again)
"sounds"
0) none, or, set your own with 'noise' (stop sound) and 'noise1' (move sound)
1) ratchet metal
2) base plat

Spawnflags
START_OFF	start off
CRUSHER		don't reverse when blocked
STOP_*		when triggered off, keep oscillating until reaching the low/high/midpoint and stop there. checking more than one adds eligible stopping places, and the bobber will stop at the first one reached.
*/
/*FGD
@PointClass size(16 16 16) base(Bob) = func_bobbing_point : "Bobbing platform.
Moves in a smooth sine wave. Build at the center of motion, specify 'wait' for the wavelength in seconds and 'distance' for the amplitude (distance from end to end) in units. Use 'delay' to set a phase offset (0-1).
Trigger to freeze in place or reactivate. If any 'don't stop until' spawnflags are checked, the bobber will keep oscillating until it reaches one of the designated positions and stop there.

Set both 'pos1' & 'pos2' to override the two apex positions (ends of the bob) to build and light your plat wherever."  [
	model(string) : "Model to use"
]
*/
void() func_bobbing_point = {func_bobbing();}

// =======================================

void() teleball_init =
{
	//dprint("in teleball_init\n");
	if (self.spawnflags & 1)
	{
		self.spawnflags -= 1;
		setmodel (self, "progs/teleport.mdl");
		setsize (self, VEC_ORIGIN, VEC_ORIGIN);	
	}
	
	self.avelocity = 50 * Vector(crandom(), crandom(), crandom());
	self.use = SUB_Null;
}

/*QUAKED misc_teleporttrain (0 .5 .8) (-16 -16 -16) (16 16 16) START_INVIS
Annoying spiky ball which players who have beaten Quake understand as a moving teleport target.

Inherits movement speed from each path_corner's "speed" key. 

Spawnflags
START_INVIS	Invisible until triggered
*/
/*FGD
@PointClass base(Flytrain) size(32 32 32) color(0 128 200) model({ "path": ":progs/teleport.mdl" }) = misc_teleporttrain : "Flying teleporter destination
Annoying spiky ball which players who have beaten Quake understand as a moving teleport target. The teleball itself behaves like a func_flytrain."
[
	target(string) : "First stop target"
	spawnflags(flags) =
	[
		1 : "Start invisible" : 0
	]
]
*/
void() misc_teleporttrain =
{	
	if (!SUB_ShouldSpawn()) return;
	
	precache_model2 ("progs/teleport.mdl");
	
	// emulate old "spawn where you were placed and then move to the first pathcorner"
	// behavior so udob_end isn't broken by the first path_corner's targets not firing
	setorigin (self, self.origin);
	entity path = spawn();
	setorigin(path, self.origin);
	path.classname = "path_corner";
	path.targetname = vtos(self.origin);	// dumb, but unique!
	path.target = self.target;
	self.target = path.targetname;
	// do this first so train_find finds it
	
	if (!self.speed) self.speed = 100;
	self.pausetime = -1;
	self.solid = -1;
	
	flytrain_setup();
	self.movetype = MOVETYPE_NOCLIP;	// for avelocity
	
	if (!(self.spawnflags & 1))
	{
		teleball_init();
		setmodel (self, "progs/teleport.mdl");
		setsize (self, VEC_ORIGIN, VEC_ORIGIN);	
	}
	else
	{
		self.use = teleball_init;
	}
}

