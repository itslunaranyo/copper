/*
===========================================
BUTTONS

button and multiple button
for all your button
===========================================
*/

void() button_wait =	// hit top
{
	self.state = STATE_TOP;
	self.nextthink = self.ltime + self.wait;
	self.think = button_return;
	activator = self.enemy;
	self.frame = 1;			// use alternate textures
	if (self.customflags & CFL_LOCKED) return;
	if (!SUB_UseTargetsAlt(target2))
		SUB_UseTargets();
}

void() button_done =	// hit bottom
{
	self.frame = 0;			// use normal textures
	self.state = STATE_BOTTOM;
	if (self.customflags & CFL_LOCKED) return;
	SUB_UseTargetsAlt(target4);
}

void() button_return =	// go down
{
	if (self.customflags & CFL_LOCKED) return;
	self.state = STATE_DOWN;
	SUB_CalcMove (self.pos1, self.speed, button_done);
	self.frame = 0;			// use normal textures
	if (self.health)
		self.takedamage = DAMAGE_YES;	// can be shot again
	SUB_UseTargetsAlt(target3);
}


void() button_blocked =
{	// do nothing, just don't ome all the way back out
}


void() button_fire =	// go up
{
	if (self.customflags & CFL_LOCKED) return;
	if (self.state == STATE_UP || self.state == STATE_TOP)
		return;

	if (self.noise != string_null)
		sound (self, CHAN_VOICE, self.noise, 1, ATTN_NORM);

	self.state = STATE_UP;
	SUB_UseTargetsAlt(target);
	SUB_CalcMove (self.pos2, self.speed, button_wait);
}


void() button_use =
{
	if (self.customflags & CFL_LOCKED) return;
	self.enemy = activator;
	
	if (self.state == STATE_UP || self.state == STATE_DOWN)
		return;
	
	button_fire ();
}

void() button_touch =
{
	if (self.customflags & CFL_LOCKED) return;
	if (other.classname != "player" || other.health <= 0)
		return;
		
	self.enemy = other;
	button_fire ();
}

// must preserve locked status until the end of the move so none of the four alt targets fire
void() button_done_unlock =
{
	button_done();
	self.customflags = not(self.customflags,CFL_LOCKED);	
}

void(float unlock) button_lock =
{
	if (unlock)
	{
		if (self.max_health)
		{
			self.takedamage = DAMAGE_YES;
			self.health = self.max_health;
		}
		self.frame = 0;			// use normal textures
		self.state = STATE_DOWN;
		SUB_CalcMove (self.pos1, self.speed, button_done_unlock);
	}
	else
	{
		self.customflags |= CFL_LOCKED;
		if (self.max_health)
			self.takedamage = DAMAGE_NO;
		self.state = STATE_UP;
		SUB_CalcMove (self.pos2, self.speed, button_wait);
	}
}

// failed experiment: this check kept moving farther and farther away from 
// button_killed until it had to go in every projectile's touch function, so 
// that the blood vs greydust feedback was correct. too much complexity.
/*
float(entity inflictor, entity attacker) button_check_attacker =
{
	if (attacker.classname != "player")
		return FALSE;
	
	switch(self.weapon) {
	// axe/lg/shotguns are instant, can just check immediate status
	case 1:
		return (self.customflags & CFL_AXEHITME);
	case 2:
	case 3:
		return (attacker.weapon == IT_SHOTGUN || attacker.weapon == IT_SUPER_SHOTGUN);
	case 8:
		return (self.customflags & CFL_ZAPPED);
	// projectiles must be checked directly since the player can fire and then switch weapons
	case 4:
	case 5:
		return (inflictor.classname == "spike");
	case 6:
		return (inflictor.classname == "grenade");
	case 7:
		return (inflictor.classname == "rocket");
	}
	return FALSE;
}
*/

void() button_killed =
{
	if (self.customflags & CFL_LOCKED) return;
	self.enemy = damage_attacker;
	self.health = self.max_health;
	self.takedamage = DAMAGE_NO;	// wil be reset upon return
	button_fire();
}

void(entity b) button_force =
{
	b.enemy = self;
	SUB_CallAsSelf(button_fire, b);
}

void() button_sounds =
{
	if (self.sounds == 0)
	{
		self.noise = "buttons/airbut1.wav";
	}
	else if (self.sounds == 1)
	{
		self.noise = "buttons/switch21.wav";
	}
	else if (self.sounds == 2)
	{
		self.noise = "buttons/switch02.wav";
	}
	else if (self.sounds == 3)
	{
		self.noise = "buttons/switch04.wav";
	}
	else if (self.sounds == 4)
	{
		self.noise = "misc/trigger1.wav";
	}
	precache_sound_safe (self.noise);
}

/*QUAKED func_button (0 .5 .8) ? - - - - - - - START_INVIS
When a button is touched, it moves some distance in the direction of its angle, triggers all of its targets, waits some time, then returns to its original position where it can be triggered again.
Acts as if touched when triggered. Will depress itself when locked by a target_lock to look inactive.

"angle"		determines the opening direction
"target"	all entities with a matching targetname will be used
"speed"		override the default 40 speed
"wait"		override the default 1 second wait (-1 = never return)
"lip"		override the default 4 pixel lip remaining at end of move
"health"	if set, the button must be killed instead of touched
"sounds"
0) steam metal
1) wooden clunk
2) metallic click
3) in-out
4) trigger noise (big light switch)

Alt Target Pattern: 'target' when touched, 'target2' when fully depressed, 'target3' when returning, 'target4' when fully out.
*/
/*FGD
@SolidClass base(Appearflags, Angle, Target, Targetname, Func, FuncInvis, AltTarget) = func_button : 
"Button. When a button is touched, it moves some distance in the direction of its angle, triggers all of its targets, waits some time, then returns to its original position where it can be triggered again.
Acts as if touched when triggered. Depresses itself when locked by a target_lock to look inactive.

Alt Target Pattern: 'target' when touched, 'target2' when fully depressed, 'target3' when returning, 'target4' when fully out." 
[
	speed(integer) : "Speed" : 40
	health(integer) : "Health (shootable if > 0)"
	lip(integer) : "Lip remaining at end of move" : 4
	distance(string) : "Distance to travel (overrides Lip)" : "0.0"
	sounds(choices) : "Sounds" = 
	[
		-1 : "None/Custom (set 'noise')"
		0 : "Steam metal"
		1 : "Wooden clunk"
		2 : "Metallic clink"
		3 : "In-out"
		4 : "Trigger noise (big light switch)"
	]
	wait(string) : "Delay before reset" : "1"
	message(string) : "Message" 
	noise(string) : "Wav to play if sounds is -1" 
]
*/
void() func_button =
{
	if (!SUB_ShouldSpawn()) return;
	button_sounds();
	SetMovedir ();

	if (!self.speed)
		self.speed = 40;
	if (!self.wait)
		self.wait = 1;
	if (!self.lip)
		self.lip = 4;

	self.state = STATE_BOTTOM;
	
	if (self.spawnflags & 128)
		self.use = func_button_spawn;
	else
		func_button_spawn();
}

void() func_button_spawn =
{
	self.movetype = MOVETYPE_PUSH;
	self.solid = SOLID_BSP;
	setmodel (self, self.model);

	// after setmodel so self.size is set
	self.distance = zeroconvertdefault(self.distance, 
		fabs(self.movedir*self.size) - self.lip);
	self.pos1 = self.origin;
	self.pos2 = self.pos1 + self.movedir * self.distance;

	self.blocked = button_blocked;
	self.use = button_use;
	self.lock = button_lock;

	if (self.health)
	{
		self.max_health = self.health;
		self.th_die = button_killed;
		self.takedamage = DAMAGE_YES;
	}
	else
		self.touch = button_touch;

	// do proper lock stuff in case the untriggered entity was locked
	if (self.customflags & CFL_LOCKED)
		button_lock(FALSE);
}


/*
===========================================
SKILL BUTTON

special button that has to react to other skill buttons being pressed, 
and the skill cvar changing at the console, and not be stupid about it

supports door fade lighting
hides like a locked button but doesn't count as locked status
registers itself with a global ent as a skill entity, chains itself
startframe checks for cvar change and walks the chain flipping status
===========================================
*/
entity skill_head;

void() skillbutton_go_up =
{
	if (self.state == STATE_UP || self.state == STATE_TOP) return;
	self.state = STATE_UP;
	self.frame = 1;
	if (self.noise != string_null)
		sound (self, CHAN_VOICE, self.noise, 1, ATTN_NORM);
	if (self.max_health)
	{
		self.takedamage = DAMAGE_NO;
	}
	SUB_CalcMove (self.pos2, self.speed, skillbutton_hit_top);
	SUB_UseTargetsAlt(target);
}

void() skillbutton_hit_top =
{
	self.state = STATE_TOP;
	if (!SUB_UseTargetsAlt(target2))
		SUB_UseTargetsSilent();
	
	// special message handling:
	// one button will always be set at map start, and we don't want a mystery message
	// printing when the start map loads announcing the skill you already have set at
	// the console
	if (self.enemy && self.enemy.classname == "player")
	{
		centerprintall(self.message);
		self.enemy = world;
	}
}

void() skillbutton_go_down =
{
	if (self.state == STATE_DOWN || self.state == STATE_BOTTOM) return;
	self.state = STATE_DOWN;
	self.enemy = world;	
	SUB_CalcMove (self.pos1, self.speed2, skillbutton_hit_bottom);
	SUB_UseTargetsAlt(target3);
}

void() skillbutton_hit_bottom =
{
	self.state = STATE_BOTTOM;
	self.frame = 0;	
	if (self.max_health)
	{
		self.takedamage = DAMAGE_YES;
		self.health = self.max_health;
	}
	SUB_UseTargetsAlt(target4);
}

// sadly this has to be sliiightly different than door_shadowmonitor or i'd reuse it
void() skillbutton_shadowmonitor_go =
{
	float frac;
	entity o = self.enemy;
	if (o.state == STATE_TOP)
		frac = 0;
	else if (o.state == STATE_BOTTOM)
		frac = 1;
	else
		frac = vlen(o.origin - o.pos2) / vlen(o.pos2 - o.pos1);
	
	bmodel_lightstyle(o, light_str(frac, o));
	
	// pay attention to owner state so we stop thinking when the door is done moving
	if (o.state == STATE_BOTTOM)
		return;

	if (o.state == STATE_TOP)
		self.nextthink = time + (o.nextthink - o.ltime);
	else
		self.nextthink = time + min(0.05, (o.nextthink - o.ltime));
		
	self.think = skillbutton_shadowmonitor_go;
}

void() skillbutton_activate =
{
	if (self.classname == "shadowmonitor")
		return;
	
	if (skill == self.strength)
		skillbutton_go_up();
	else
		skillbutton_go_down();
	
	// do this to catch the first frame one
	if (self.owner.classname == "shadowmonitor")
	{
		self = self.owner;
		skillbutton_shadowmonitor_go();
	}
}

void() skillbutton_touch =
{
	if (self.state != STATE_BOTTOM) return;
	self.enemy = other;
	cvar_set("skill", self.netname);
}
void() skillbutton_use =
{
	self.enemy = activator;
	cvar_set("skill", self.netname);
}
void() skillbutton_die =
{
	self.enemy = damage_attacker;
	cvar_set("skill", self.netname);
}


/*QUAKED func_button_skill (0 .5 .8) ? EASY NORMAL HARD NIGHTMARE SILENT
Special button for selecting skill level. Will always be pressed when the skill corresponding to the chosen spawnflag is set. Changes its state automatically when other skill buttons are pressed, when trigger_setskills are touched, or when skill is changed live at the console.

"message"	override message printed to clients when button is touched or used (or use SILENT spawnflag for no message)
"angle"		determines the opening direction
"target"	all entities with a matching targetname will be used
"speed"		override the default 40 speed
"wait"		override the default 1 second wait (-1 = never return)
"lip"		override the default 4 pixel lip remaining at end of move
"health"	if set, the button must be killed instead of touched
"sounds"
0) steam metal
1) wooden clunk
2) metallic click
3) in-out
4) trigger noise (big light switch)

Alt Target Pattern: 'target' when touched, 'target2' when fully depressed, 'target3' when returning, 'target4' when fully out.
*/
/*FGD
@SolidClass base(Appearflags, Angle, Target, Func, AltTarget) = func_button_skill : 
"Special button for selecting skill level. Will always be pressed when the skill corresponding to the chosen spawnflag is set. Changes its state automatically when other skill buttons are pressed, when trigger_setskills are touched, or when skill is changed live at the console.

Alt Target Pattern: 'target' when touched, 'target2' when fully depressed, 'target3' when returning, 'target4' when fully out." 
[
	spawnflags(Flags) = [
		1 : "Easy" : 0
		2 : "Normal" : 1
		4 : "Hard" : 0
		8 : "Nightmaaare" : 0
		16 : "No centerprint" : 0
	]
	speed(integer) : "Speed" : 40
	health(integer) : "Health (shootable if > 0)"
	lip(integer) : "Lip remaining at end of move" : 4
	distance(string) : "Distance to travel (overrides Lip)" : "0.0"
	sounds(choices) : "Sounds" = 
	[
		-1 : "None/Custom (set 'noise')"
		0 : "Steam metal"
		1 : "Wooden clunk"
		2 : "Metallic clink"
		3 : "In-out"
		4 : "Trigger noise (big light switch)"
	]
	message(string) : "Override skill selected message" 
	noise(string) : "Wav to play if sounds is -1" 
]
*/void() func_button_skill =
{
	if (!SUB_ShouldSpawn()) return;

	button_sounds();
	SetMovedir ();

	if (!self.speed)
		self.speed = 40;
	if (!self.speed2)
		self.speed2 = self.speed;
	if (!self.lip)
		self.lip = 4;

	if (skill_head)
		self.owner = skill_head;
	if (self.style || self.switchshadstyle)
	{
		entity m = spawn();
		m.classname = "shadowmonitor";
		m.enemy = self;
		m.owner = skill_head;
		self.owner = m;
		if (self.style < 0)
		{
			self.style *= -1;
			self.customflags |= CFL_INVLIGHT;
		}
		bmodel_lightstyle(self, light_str(1, self));
	}
	skill_head = self;

	self.state = STATE_BOTTOM;
	self.movetype = MOVETYPE_PUSH;
	self.solid = SOLID_BSP;
	setmodel (self, self.model);
	self.distance = zeroconvertdefault(self.distance, 
		fabs(self.movedir*self.size) - self.lip);
	self.pos1 = self.origin;
	self.pos2 = self.pos1 + self.movedir * self.distance;

	self.blocked = button_blocked;
	self.use = skillbutton_use;

	if (self.health)
	{
		self.max_health = self.health;
		self.th_die = skillbutton_die;
		self.takedamage = DAMAGE_YES;
	}
	else
		self.touch = skillbutton_touch;

	if (self.spawnflags & 1)
	{
		self.strength = 0;
		self.netname = "0";
	}
	else if (self.spawnflags & 4)
	{
		self.strength = 2;
		self.netname = "2";
	}
	else if (self.spawnflags & 8)
	{
		self.strength = 3;
		self.netname = "3";
	}
	else	// 2 or default
	{
		self.strength = 1;
		self.netname = "1";
	}

	if (self.spawnflags & 16)	// silent
		self.message = string_null;
	else if (self.message == string_null)
	{
		if (self.spawnflags & 1)
			self.message = "EASY skill selected";
		else if (self.spawnflags & 4)
			self.message = "HARD skill selected";
		else if (self.spawnflags & 8)
			self.message = "\bNIGHTMARE\b skill selected";
		else	// 2 or default
			self.message = "NORMAL skill selected";
	}

	self.think = skillbutton_activate;	// assume correct position and set up any related target states
	self.nextthink = 0.1;
}