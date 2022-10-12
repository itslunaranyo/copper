/*
=============================================================================

LIFTS AND TRAINS

=============================================================================
*/

float PLAT_LOW_TRIGGER = 1;

void() plat_try_find_trigger =
{
	entity t;
	t = find (world, targetname, self.target);
	self.target = "";
	if (!t)
	{
		dprint("plat with unmatched target");
		plat_spawn_inside_trigger();
	}
	else if ( (t.classname != "trigger_once") && (t.classname != "trigger_multiple") && (t.classname != "trigger_multiple_box") ) 
	{
		dprint("plat targets a non-trigger");
		plat_spawn_inside_trigger();
	}
	else
	{
		dprint3("plat trigger found, ", t.classname, "\n");
		t.touch = plat_center_touch;
		t.think = SUB_Null;
		t.movetype = MOVETYPE_NONE;
		t.enemy = self;
		self.trigger_field = t;
	}
	self.think = SUB_Null;
}

void() plat_spawn_inside_trigger =
{
	entity t;
	vector tmin, tmax;

	if (self.target != string_null)
	{
		dprint("overriding plat trigger\n");
		// find overridden trigger for custom trigger zones
		// if the plat spawns before the trigger this will fail, so delay the search to let triggers spawn
		self.think = plat_try_find_trigger;
		self.nextthink = time + 0.1;
		
		return;
	}
	else
	{
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
	}
	
	t.touch = plat_center_touch;
	t.think = SUB_Null;
	t.movetype = MOVETYPE_NONE;
	t.enemy = self;
	self.trigger_field = t;
	
	self.target = "";
}

void() plat_hit_top =
{
	sound (self, CHAN_VOICE, self.noise1, 1, ATTN_NORM);
	self.state = STATE_TOP;
	self.think = plat_go_down;
	self.nextthink = self.ltime + self.wait;
}

void() plat_hit_bottom =
{
	sound (self, CHAN_VOICE, self.noise1, 1, ATTN_NORM);
	self.state = STATE_BOTTOM;
}

void() plat_go_down =
{
	sound (self, CHAN_VOICE, self.noise, 1, ATTN_NORM);
	self.state = STATE_DOWN;
	SUB_CalcMove (self.pos2, self.speed, plat_hit_bottom);
}

void() plat_go_up =
{
	sound (self, CHAN_VOICE, self.noise, 1, ATTN_NORM);
	self.state = STATE_UP;
	SUB_CalcMove (self.pos1, self.speed, plat_hit_top);
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

void(entity p) plat_lock =
{
	p.trigger_field.touch = SUB_Null;
	p.use = SUB_Null;
	p.customflags |= CFL_LOCKED;
}

void(entity p) plat_unlock =
{
	p.trigger_field.touch = plat_center_touch;
	if (p.targetname != string_null)
		p.use = plat_use;
	p.customflags = not(p.customflags, CFL_LOCKED);
}


/*QUAKED func_plat (0 .5 .8) ? PLAT_LOW_TRIGGER
Plats are always drawn in the extended position, so they will light correctly.
If the plat is the target of another trigger or button, it will start out disabled in the top position until it is triggered, when it will lower and become a normal plat.
If the plat targets a trigger once/multiple/multiple_box, it will override the plat's default activation zone (consuming the trigger).

"PLAT_LOW_TRIGGER" activation zone will only be at the bottom of the movement course, instead of the whole vertical

"speed"		default 150
"height"	implicitly determine the distance the plat moves
"pos1"&"pos2"	directly override top and bottom positions - plat can be built anywhere else in the map
"wait"		time to pause at apex in seconds, default 3
"sounds"
	1: base fast
	2: chain slow (default if 0)
	-1: silent
*/
/*FGD
@SolidClass base(Appearflags, Targetname, Func) = func_plat : "Elevator platform.
Plats are always drawn in the extended position, so they will light correctly.
If the plat is the target of another trigger or button, it will start out disabled in the top position until it is triggered, when it will lower and become a normal plat.
If the plat targets a trigger once/multiple/multiple_box, it will override the plat's default activation zone (consuming the trigger).

By setting 'pos1' & 'pos2' you can directly override the top and bottom positions, allowing the plat to be built anywhere else in the map. This is useful for building a plat where it will be lit the best.

The 'low trigger volume' spawnflag will put the activation zone only at the bottom of the movement course, instead of the whole vertical." 
[	
	spawnflags(Flags) =
	[
		1 : "Low trigger volume" : 0
	]
	target(target_destination) : "Custom activation trigger"
	speed(integer) : "Speed" : 150
	height(integer) : "Travel altitude (can be negative)" : 0
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

	self.blocked = plat_crush;
	if (!self.speed)
		self.speed = 150;
	if (!self.wait)
		self.wait = 3;

	if (!self.height && self.distance)
		self.height = self.distance;
		
	if (!self.pos1 && !self.pos2)
	{
		// pos1 is the top position, pos2 is the bottom
		self.pos1 = self.origin;
		self.pos2 = self.origin;
		if (self.height)
			self.pos2_z = self.origin_z - self.height;
		else
			self.pos2_z = self.origin_z - self.size_z + 8;
	}
	self.use = plat_trigger_use;

	plat_spawn_inside_trigger ();	// the "start moving" trigger	

	//if (self.targetname)
	if (self.targetname != string_null)
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

//============================================================================

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

void() flytrain_think = 
{
	self.think1();
	self.nextthink = self.ltime + 0.1;
	
//	dprint(ftos(vlen(self.velocity)));
//	dprint("\n");
}

void() flytrain_use =
{
	dprint("in flytrain_use\n");
	if (self.think1 == fly_idle)
		fly_newgoal( 1, 0 );
}

void() flytrain_init2 =
{
	//dprint("in flytrain_init2\n");
	fly_newgoal( 1, 0 );
	
	self.think = flytrain_think;
	flytrain_think();

	//dprint("end of flytrain_init2\n");
}

// flytrain_init
// switch the light and sparklies on
void() flytrain_init =
{
	//dprint("in flytrain_init\n");
	self.goalentity = self;		// haaax
	self.use = flytrain_use;
	self.think = flytrain_init2;
	self.nextthink = self.ltime + 0.1;
	//dprint("end of flytrain_init\n");
}

void() flytrain_stop =
{
	setorigin(self, self.goalentity.origin);
	self.velocity = '0 0 0';
	self.nextthink = -1;
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
@baseclass base(Appearflags, Targetname, TrainSounds, Func) = Train [
	speed(integer) : "Speed (units per second)" : 64
	target(target_source) : "Target to start at"
	dmg(integer) : "Damage on block" : 2
	noise(string) : "Override stop sound"
	noise1(string) : "Override move sound"
	pausetime(string) : "Default wait time" : "0.1"
]
*/

/*QUAKED func_flytrain (0 .5 .8) ?
A func_train that follows a curved flypath and variable speed rules. Inherits movement speed from each path_corner's "speed" key.  
If the train is the target of a button or trigger, it will not begin moving until activated.

Movement is smoothed out so it doesn't move in straight lines between waypoints. Sharp turns near walls could make it clip out of the level and disappear for a moment, so place pathcorners carefully. Generally, expect it to overshoot every pathcorner after passing through it.

"sounds"
0) none, or, set your own with 'noise' (stop sound) and 'noise1' (move sound)
1) ratchet metal
2) base plat
*/
/*FGD
@SolidClass base(Train) = func_flytrain : 
"A func_train that follows a curved flypath and variable speed rules. Inherits movement speed from each path_corner's 'speed' key.

Movement is smoothed out so it doesn't move in straight lines between waypoints. Sharp turns near walls could make it clip out of the level and disappear for a moment, so place pathcorners carefully. Generally, expect it to overshoot every pathcorner after passing through it." []
*/
void() func_flytrain =
{
	if (!SUB_ShouldSpawn()) return;
	if (!self.target)
		objerror ("func_train without a target");
	
	self.dmg = zeroconvertdefault(self.dmg,2);
	if (!self.speed) {
		self.speed2 = 128;
		self.speed = 128;
	}
	train_sounds();

	self.use = flytrain_init;
	self.th_die = flytrain_stop;
	self.th_stand = SUB_Null;
	
	self.solid = zeroconvertdefault(self.solid, SOLID_BSP);
	if (!self.solid)
		self.movetype = MOVETYPE_NOCLIP;
	else
		self.movetype = MOVETYPE_PUSH;
	self.blocked = train_blocked;
	//self.classname = "train";
		
	setmodel (self, self.model);
	setsize (self, self.mins, self.maxs);
	setorigin (self, self.origin);
	
	self.movedir = self.origin - BoundsCenter(self); // offset so _point and bmodel types can work the same
}

/*QUAKED func_flytrain_point (0 .5 .8) (-8 -8 -8) (8 8 8)
A func_train that follows a curved flypath and variable speed rules. Inherits movement speed from each path_corner's "speed" key.  
If the train is the target of a button or trigger, it will not begin moving until activated.

Movement is smoothed out so it doesn't move in straight lines between waypoints. Sharp turns near walls could make it clip out of the level and disappear for a moment, so place pathcorners carefully. Generally, expect it to overshoot every pathcorner after passing through it.

"sounds"
0) none, or, set your own with 'noise' (stop sound) and 'noise1' (move sound)
1) ratchet metal
2) base plat
*/
/*FGD
@PointClass base(Train) size(16 16 16) = func_flytrain_point : 
"A func_train that follows a curved flypath and variable speed rules. Inherits movement speed from each path_corner's 'speed' key.

Movement is smoothed out so it doesn't move in straight lines between waypoints. Sharp turns near walls could make it clip out of the level and disappear for a moment, so place pathcorners carefully. Generally, expect it to overshoot every pathcorner after passing through it."
[
	model(string) : "Model to use"
]
*/
void() func_flytrain_point =
{	
	if (!SUB_ShouldSpawn()) return;

	precache_model_safe(self.model);
	func_flytrain();
	self.classname = "func_flytrain";
	self.movedir = '0 0 0';
}

//============================================================================

float TRAIN_INHERIT = 1;

void() train_blocked =
{
	if (time < self.attack_finished)
		return;
	self.attack_finished = time + self.dmgtime;
	T_Damage (other, self, self, self.dmg);
}

void() train_use =
{
	if ((self.spawnflags & 2) && (self.origin + self.mins) != self.enemy.origin)
	{
		if (self.state == STATE_ON)
		{
			self.state = STATE_OFF;
			self.velocity = VEC_ORIGIN;
			self.nextthink = 0;
			sound (self, CHAN_VOICE, self.noise, 1, ATTN_NORM);
		}
		else
		{
			self.state = STATE_ON;
			sound (self, CHAN_VOICE, self.noise1, 1, ATTN_NORM);
			SUB_CalcMove (self.enemy.origin - self.mins, self.speed, train_wait);
		}
		return;
	}

	if (self.state == STATE_ON)	// already activated
		return;	
	train_next();
}

void() train_wait =
{
	// trains now fire their pathcorners' targets on arrival
	// if a player is riding the train, treat them as activator
	if (activator.classname != "player")
		activator = get_closest_client();
	SUB_UseEntTargets(self.enemy);
	
	// inherit speed from path_corners on arrival
	if (self.enemy.speed > 0 && self.spawnflags & TRAIN_INHERIT)
		self.speed = self.enemy.speed;
	
	if (self.wait == -1)
	{
		self.state = STATE_OFF;
		self.use = train_use;
		sound (self, CHAN_VOICE, self.noise, 1, ATTN_NORM);
	}
	else if (self.wait > 0)
	{
		self.state = STATE_OFF;	// allow triggering while waiting
		self.think = train_next;
		self.nextthink = self.ltime + self.wait;
		if (self.wait > 0.1)
			sound (self, CHAN_VOICE, self.noise, 1, ATTN_NORM);
	}
	else 	// self.wait is 0 or a garbage value
	{
		train_next();
	}
}

void() train_next =
{
	entity corner, oself;

	oself = self;
	self = self.enemy;
	corner = findunlockedtarget(world);
	self = oself;
	
	if (!corner)
	{
		dprint("train_next: no next target\n");
		if (self.th_die)
			self.th_die();
		else
			remove(self);
		return;
	}
	oself = self.enemy;
	self.enemy = corner;
	if (corner.wait)
		self.wait = corner.wait;
	else
		self.wait = self.pausetime;
	self.state = STATE_ON;
	if (oself.speed == -1)
	{
		setorigin(self, corner.origin - self.mins);
		train_wait();
		return;
	}
	sound (self, CHAN_VOICE, self.noise1, 1, ATTN_NORM);
	SUB_CalcMove (corner.origin - self.mins, self.speed, train_wait);
}

void() func_train_find =
{
	entity corner;

	corner = findunlockedtarget(world);
	self.enemy = corner;
	//self.target = corner.target;
	setorigin (self, corner.origin - self.mins);
	if ((self.spawnflags & TRAIN_INHERIT) && corner.speed > 0)
		self.speed = corner.speed;
	if (self.targetname == string_null)
	{	// not triggered, so start immediately
		self.state = STATE_ON;
		self.nextthink = self.ltime + 0.1;
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
	self.classname = "train";
	self.state = STATE_OFF;

	// start trains on the second frame, to make sure their targets have had
	// a chance to spawn
	self.nextthink = self.ltime + 0.1;
	self.think = func_train_find;

}

/*QUAKED func_train (0 .5 .8) ? PATH_SPEED TOGGLE
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

Spawnflags:
PATH_SPEED: train will inherit 'speed' value from path_corners as it reaches them
If a path_corner's speed is -1, the func_train's move when LEAVING that corner will be to snap instantly to the next corner.
TOGGLE: allow starting/stopping motion anywhere on its path (default is to ignore triggerings when in motion)
*/
/*FGD
@SolidClass base(Train) = func_train : "Moving platform that players can ride. 
Its origin is the min corner of the train. 
The train spawns at the first target it is pointing at. If the train is the target of a button or trigger, it will not begin moving until activated.
A train will fire all targets of a pathcorner on arrival.

If 'Speed from path' is set, the train will inherit the 'speed' value from path_corners as it reaches them.
If a path_corner's speed is -1, the func_train's move when LEAVING that corner will be to snap instantly to the next corner.
The 'Toggle' spawnflag allows starting and stopping the motion anywhere on the train's path (default is to ignore triggerings when in motion)."
[
	spawnflags(Flags) = [
		1 : "Speed from path" : 0
		2 : "Toggle" : 0
	]
]
*/
void() func_train =
{	
	if (!SUB_ShouldSpawn()) return;
	func_train_setup();
	
	precache_model_safe(self.model);
	setmodel (self, self.model);
	setsize (self, self.mins , self.maxs);
	setorigin (self, self.origin);
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
Its origin is the min corner of the train. 
The train spawns at the first target it is pointing at. If the train is the target of a button or trigger, it will not begin moving until activated.
A train will fire all targets of a pathcorner on arrival.

If 'Speed from path' is set, the train will inherit the 'speed' value from path_corners as it reaches them.
If a path_corner's speed is -1, the func_train's move when LEAVING that corner will be to snap instantly to the next corner."
[
	model(string) : "Model to use"
	spawnflags(Flags) = [
		1 : "Speed from path" : 0
	]
]
*/
void() func_train_point =
{	
	if (!SUB_ShouldSpawn()) return;
	func_train_setup();
	
	precache_model_safe(self.model);
	setmodel (self, self.model);
	setsize (self, self.mins, self.maxs);
	setorigin (self, self.origin);
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

/*QUAKED func_bobbing (0 .5 .8) ? START_OFF CRUSHER STOP_LOW STOP_MID STOP_HIGH
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
@baseclass base(Appearflags, Targetname, TrainSounds, Angle, Func) = Bob
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
Trigger to freeze in place or reactivate. If any "don't stop until" spawnflags are checked, the bobber will keep oscillating until it reaches one of the designated positions and stop there.

Set both 'pos1' & 'pos2' to override the two apex positions (ends of the bob) to build and light your plat wherever."  []
*/
void() func_bobbing =
{
	if (!SUB_ShouldSpawn()) return;

	self.solid = zeroconvertdefault(self.solid, SOLID_BSP);
	if (!self.solid)
		self.movetype = MOVETYPE_NOCLIP;
	else
		self.movetype = MOVETYPE_PUSH;

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
	self.use = func_bobbing_use;
	self.blocked = func_bobbing_blocked;
	
	self.length = min(0.1, self.wait / 6);
	
	train_sounds();
	
	if (!(self.spawnflags & START_OFF))
	{
		self.think = func_bobbing_use;
		self.nextthink = 0.3;	// wait for items and monsters to rest on it
	}
	
	precache_model_safe(self.model);
	setmodel (self, self.model);
	setsize (self, self.mins, self.maxs);
	setorigin (self, func_bobbing_pos(self.delay));
}

/*QUAKED func_bobbing_point (0 .5 .8) (-8 -8 -8) (8 8 8) START_OFF CRUSHER STOP_LOW STOP_MID STOP_HIGH
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
Trigger to freeze in place or reactivate. If any "don't stop until" spawnflags are checked, the bobber will keep oscillating until it reaches one of the designated positions and stop there.

Set both 'pos1' & 'pos2' to override the two apex positions (ends of the bob) to build and light your plat wherever."  [
	model(string) : "Model to use"
]
*/
void() func_bobbing_point = {func_bobbing();}

// =======================================

void() teleball_think = 
{
	self.think1();
	self.nextthink = time + 0.1;
}

void() teleball_use =
{
	self.avelocity = 50 * Vector(crandom(), crandom(), crandom());
	if (self.think1 == fly_idle)
		fly_newgoal( 1, 0 );
}

void() teleball_init2 =
{
	fly_newgoal( 1, 0 );
	self.think = teleball_think;
	teleball_think();
}

void() teleball_init =
{
	//dprint("in teleball_init\n");
	if (self.spawnflags & 1)
	{
		setmodel (self, "progs/teleport.mdl");
		setsize (self, VEC_ORIGIN, VEC_ORIGIN);	
	}
	
	self.avelocity = 50 * Vector(crandom(), crandom(), crandom());
	self.goalentity = self;		// haaax
	self.use = teleball_use;
	self.think = teleball_init2;
	self.nextthink = time + 0.1;
}

void() misc_teleball_curvy = 
{
	//dprint("in misc_teleball\n");
	setorigin (self, self.origin);
	if (!(self.spawnflags & 1))
	{
		teleball_init();
		setmodel (self, "progs/teleport.mdl");
	}
	setsize (self, VEC_ORIGIN, VEC_ORIGIN);	
	self.movetype = MOVETYPE_NOCLIP;
	
	if (!self.speed) {
		self.speed2 = 100;
		self.speed = 100;
	}
	
	self.use = teleball_init;
	self.th_die = SUB_Remove;
	self.th_stand = SUB_Null;
}


void() teletrain_use =
{
	self.state = !self.state;
	if (self.state)
	{
		teletrain_go();
	}
	else
	{
		self.velocity = VEC_ORIGIN;
		self.target = self.enemy.targetname;
		self.nextthink = 0;
	}
}

// special linear move function for the dumb teletrain so it doesn't have to be MOVETYPE_PUSH
void() teletrain_go =
{
	float l;
	vector dir;
	
	if (self.spawnflags & 1)
	{
		setmodel (self, "progs/teleport.mdl");
		setsize (self, VEC_ORIGIN, VEC_ORIGIN);	
		self.spawnflags -= 1;
	}

	self.enemy = find(world, targetname, self.target);
	self.target = self.enemy.target;
	
	dir = (self.enemy.origin + self.pos1) - self.origin;
	l = vlen(dir);
	self.velocity = normalize(dir) * self.speed;
	self.nextthink = time + (l / self.speed);
	self.think = teletrain_go;
}

void() teletrain_find =
{
	self.enemy = find(world, targetname, self.target);
	//self.target = self.enemy.target;
	setorigin(self, self.enemy.origin + self.pos1);
}

/*QUAKED misc_teleporttrain (0 .5 .8) (-16 -16 -16) (16 16 16) START_INVIS CURVY
Annoying spiky ball which players who have beaten Quake understand as a moving teleport target.

Inherits movement speed from each path_corner's "speed" key. 

Spawnflags
START_INVIS	Invisible until triggered
CURVY	behaves like a func_flytrain, following path_corners, waiting at them (a wait of -1 on a path_corner will stop the ball until triggered again), then disappearing at the last path_corner. Movement is smoothed out so it doesn't move in straight lines between waypoints. Sharp turns near walls could make it clip out of the level and disappear for a moment, so place pathcorners carefully. Generally, expect it to overshoot every pathcorner after passing through it.
*/
/*FGD
@PointClass base(Appearflags, Targetname) size(32 32 32) color(0 128 200) model({ "path": ":progs/teleport.mdl" }) = misc_teleporttrain : "Flying teleporter destination
Annoying spiky ball which players who have beaten Quake understand as a moving teleport target.

If the 'curving path' spawnflag is set, the teleball behaves like a func_flytrain, smoothed out so it doesn't move in straight lines between waypoints. Sharp turns near walls could make it clip out of the level and disappear for a moment, so place pathcorners carefully. Generally, expect it to overshoot every pathcorner after passing through it."
[
	target(string) : "First stop target"
	spawnflags(flags) =
	[
		1 : "Start invisible" : 0
		2 : "Curving path" : 0
	]
]
*/
void() misc_teleporttrain =
{	
	if (!SUB_ShouldSpawn()) return;
	
	precache_model2 ("progs/teleport.mdl");
	if (self.spawnflags & 2)
	{
		misc_teleball_curvy();
		return;
	}
	
	if (!self.speed)
		self.speed = 100;
	if (!self.target)
		objerror("misc_teleporttrain without a target");

	self.solid = SOLID_NOT;
	self.movetype = MOVETYPE_NOCLIP;
	self.use = teletrain_use;
	self.state = 0;

	if (!(self.spawnflags & 1))
		setmodel (self, "progs/teleport.mdl");
	setsize (self, self.mins, self.maxs);
	self.pos1 = 0.5 * (self.maxs - self.mins);
	setorigin (self, self.origin);
	
	self.think = teletrain_find;
	self.nextthink = time + 0.1;
}

