/*
===========================================
BUTTONS

button and multiple button
for all your button
===========================================
*/

void() button_wait =
{
	self.state = STATE_TOP;
	self.nextthink = self.ltime + self.wait;
	self.think = button_return;
	activator = self.enemy;
	self.frame = 1;			// use alternate textures
	if (self.customflags & CFL_LOCKED) return;
	SUB_UseTargets();
}

void() button_done =
{
	self.state = STATE_BOTTOM;
}

void() button_return =
{
	if (self.customflags & CFL_LOCKED) return;
	self.state = STATE_DOWN;
	SUB_CalcMove (self.pos1, self.speed, button_done);
	self.frame = 0;			// use normal textures
	if (self.health)
		self.takedamage = DAMAGE_YES;	// can be shot again
}


void() button_blocked =
{	// do nothing, just don't ome all the way back out
}


void() button_fire =
{
	if (self.customflags & CFL_LOCKED) return;
	if (self.state == STATE_UP || self.state == STATE_TOP)
		return;

	if (self.noise != string_null)
		sound (self, CHAN_VOICE, self.noise, 1, ATTN_NORM);

	self.state = STATE_UP;
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

void(entity b) button_lock =
{
	entity oself;
	b.customflags |= CFL_LOCKED;
	if (b.max_health)
		b.takedamage = DAMAGE_NO;
	b.state = STATE_UP;
	oself = self;
	self = b;
	SUB_CalcMove (self.pos2, self.speed, button_wait);
	self = oself;
}
void(entity b) button_unlock =
{
	entity oself;
	b.customflags = not(b.customflags,CFL_LOCKED);
	if (b.max_health)
	{
		b.takedamage = DAMAGE_YES;
		b.health = b.max_health;
	}
	b.frame = 0;			// use normal textures
	b.state = STATE_DOWN;
	oself = self;
	self = b;
	SUB_CalcMove (self.pos1, self.speed, button_done);
	self = oself;
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

/*QUAKED func_button (0 .5 .8) ?
When a button is touched, it moves some distance in the direction of its angle, triggers all of its targets, waits some time, then returns to its original position where it can be triggered again.

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
*/
/*FGD
@SolidClass base(Appearflags,Angle,Target,Targetname) = func_button : 
"Button. When a button is touched, it moves some distance in the direction of its angle, triggers all of its targets, waits some time, then returns to its original position where it can be triggered again.
Acts as if touched when triggered." 
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
	if (self.sounds == 0)
	{
		self.noise = "buttons/airbut1.wav";
	}
	if (self.sounds == 1)
	{
		self.noise = "buttons/switch21.wav";
	}
	if (self.sounds == 2)
	{
		self.noise = "buttons/switch02.wav";
	}
	if (self.sounds == 3)
	{
		self.noise = "buttons/switch04.wav";
	}
	if (self.sounds == 4)
	{
		self.noise = "misc/trigger1.wav";
	}
	precache_sound_safe (self.noise);
	
	SetMovedir ();

	self.movetype = MOVETYPE_PUSH;
	self.solid = SOLID_BSP;
	setmodel (self, self.model);

	self.blocked = button_blocked;
	self.use = button_use;

	if (self.health)
	{
		self.max_health = self.health;
		self.th_die = button_killed;
		self.takedamage = DAMAGE_YES;
	}
	else
		self.touch = button_touch;

	if (!self.speed)
		self.speed = 40;
	if (!self.wait)
		self.wait = 1;
	if (!self.lip)
		self.lip = 4;

	if (!self.lip)
		self.lip = 4;
	self.distance = zeroconvertdefault(self.distance, 
		fabs(self.movedir*self.size) - self.lip);

	self.state = STATE_BOTTOM;

	self.pos1 = self.origin;
	self.pos2 = self.pos1 + self.movedir * self.distance;
}

