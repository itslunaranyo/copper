/*
================================================================

FX

================================================================
*/

void(vector org) gunshot =
{
	WriteByte (MSG_BROADCAST, SVC_TEMPENTITY);
	WriteByte (MSG_BROADCAST, TE_GUNSHOT);
	WriteCoord (MSG_BROADCAST, org_x);
	WriteCoord (MSG_BROADCAST, org_y);
	WriteCoord (MSG_BROADCAST, org_z);
}

void(vector a, vector b, entity who) fx_beam =
{
	WriteByte (MSG_BROADCAST, SVC_TEMPENTITY);
	WriteByte (MSG_BROADCAST, TE_LIGHTNING1);
	WriteEntity (MSG_BROADCAST, who);
	WriteCoord (MSG_BROADCAST, a_x);
	WriteCoord (MSG_BROADCAST, a_y);
	WriteCoord (MSG_BROADCAST, a_z);
	WriteCoord (MSG_BROADCAST, b_x);
	WriteCoord (MSG_BROADCAST, b_y);
	WriteCoord (MSG_BROADCAST, b_z);
}


void()	s_explode1	=	[0,		s_explode2] {}
void()	s_explode2	=	[1,		s_explode3] {}
void()	s_explode3	=	[2,		s_explode4] {}
void()	s_explode4	=	[3,		s_explode5] {}
void()	s_explode5	=	[4,		s_explode6] {}
void()	s_explode6	=	[5,		SUB_Remove] {}

// 0: original
// 1: grape
// 2: marshmallow
void(float blasttype) BecomeBlast = 
{
	WriteByte (MSG_BROADCAST, SVC_TEMPENTITY);
	if (blasttype == 1)
		WriteByte (MSG_BROADCAST, TE_TAREXPLOSION);
	else
		WriteByte (MSG_BROADCAST, TE_EXPLOSION);
	WriteCoord (MSG_BROADCAST, self.origin_x);
	WriteCoord (MSG_BROADCAST, self.origin_y);
	WriteCoord (MSG_BROADCAST, self.origin_z);
	
	if (blasttype == 2)
		setmodel (self, "progs/s_explo2.spr");
	else
		setmodel (self, "progs/s_explod.spr");
	
	self.movetype = MOVETYPE_NONE;
	self.velocity = '0 0 0';
	self.touch = SUB_Null;
	self.solid = SOLID_NOT;
	s_explode1 ();
}

void() BecomeExplosion = { BecomeBlast(0); }
void() BecomeTarExplosion = { BecomeBlast(1); }
void() BecomeWeakExplosion = { BecomeBlast(2); }

void() fx_explode =
{
	kaboom(self.origin, 0, self, 0);
}

/*
========
kaboom

for making explosions when and where you please
========
*/
entity(vector org, float damg, entity parent, float multi) kaboom =
{
	local entity boom;
	
	boom = spawn();
	setorigin(boom, org);
	boom.nextthink = time;
	boom.think = BecomeExplosion;
	
	if (damg > 0) T_RadiusMultiDamage (boom, parent, damg, boom, multi);
	
	return boom;
}

//=============================================================================

//flagrant abuse of particle()

void(vector a, vector b, float color) fx_trail =
{
	local float i, maxd;
	local vector dir;
	maxd = floor(vlen(b-a));
	dir = normalize(b-a);
	
	for (i=0; i<maxd; i+=8)
		particle(a + dir * i, dir, color, 2);
}

void(vector c, float r, float color) fx_ring =
{
	local float segments, ang, i;
	local vector a, b;
	segments = ceil(sqrt(2 * r));
	
	for (i=0; i<segments; i++)
	{
		ang = (360.0/segments) * i;
		makevectors('0 1 0' * ang);
		a = v_forward * r + c;
		ang = (360.0/segments) * (i + 1);
		makevectors('0 1 0' * ang);
		b = v_forward * r + c;
		fx_trail(a,b,color);
	}
}

//============================================================================


float PFIELD_START_ON = 1; 
float PFIELD_INWARD = 2; 
float PFIELD_OUTWARD = 4; 
float PFIELD_BURST = 8;

float() particlefield_should_sleep =
{
	if (self.distance <= 0) return FALSE;
	if (clients > 4) return FALSE;	// probably dropping tons of particles anyway, don't bother
	
	entity client = world;
	for (float i = 0; i < clients; i++)
	{
		client = nextent(client);
		if (vlen(BoundsCenter(self.buddy) - client.origin) < self.distance)
		{
			return FALSE;
		}
	}
	return TRUE;
}

vector(vector org) particlefield_dir =
{
	vector dir;
	dir = self.movedir;
	if (self.spawnflags & PFIELD_INWARD)	// in
	{
		dir -= org * vlen(self.movedir);
	}
	else if (self.spawnflags & PFIELD_OUTWARD)	// out
	{
		dir += org * vlen(self.movedir);
	}
	return dir;
}

void(float num) particlefield_sweep =
{
	/*
	call x and y the two axes perpendicular to the sweep, z the direction of the sweep
	random x and y are chosen
	z determined by projecting x and y down z axis onto wherever the plane should be
		ie solving plane equation for z by plugging in x and y
		ax + by + cz = d
		cz = d - ax - by
		z = (d-ax-by)/c
	*/
	float d, t, z, frac;
	vector plane, porg;
	
	// self.dest = transformed bounds
	// self.pos1 = transformed velocity
	
	plane = normalize(self.pos1);
	d = vabs(plane) * self.dest * 2;	// total distance
	
	// determine position in the cycle
	t = time - self.attack_finished;
	frac = t / (d / vlen(self.pos1));
	if (frac > 1)
	{
		if (self.spawnflags & PFIELD_BURST)
		{
			self.state = 0;
			self.buddy = world;
			return;	// done with a loop
		}
		frac = 0;
		self.attack_finished = time;
	}
	
	if (particlefield_should_sleep()) return;
	
	z = d * (frac - 0.5);
	while (num > 0)
	{
		num -= 1;
		// choose x and y randomly within field bounds
		porg_x = crandom() * self.dest_x;
		porg_y = crandom() * self.dest_y;
		// solve plane equation to derive z (if sweep vel is non-axial)
		porg_z = (z - plane_x * porg_x - plane_y * porg_y) / plane_z;
		if (fabs(porg_z) > self.dest_z)
			continue;	// reject outside bounds

		// transform result back
		if (self.worldtype == 0)	// sweeping down x
		{
			porg = Vector(porg_z, porg_x, porg_y);
		}
		else if (self.worldtype == 1)	// sweeping down y
		{
			porg = Vector(porg_x, porg_z, porg_y);
		}

		// add self.origin and go
		particle (porg + BoundsCenter(self.buddy), particlefield_dir(porg), self.health, self.speed2);
	}
}

void(float num) particlefield_burst =
{
	if (particlefield_should_sleep()) return;
	
	vector org, org2;
	while (num > 0)
	{
		num -= 1;
		org = Vector(crandom(), crandom(), crandom());
		org2 = vec_scale(org, self.size);
		
		particle (org2 + BoundsCenter(self.buddy), particlefield_dir(org), self.health, self.speed2);
	}
}

void() particlefield_think =
{
	if (self.finaldest == VEC_ORIGIN)
		particlefield_burst(floor(0.5 + self.speed / 10));
	else
		particlefield_sweep(self.speed);
	
	if (self.state)
		self.nextthink = time + self.wait;
}

void() particlefield_get_spot =
{
	if (self.buddy) return;
	
	if (self.target == string_null)
	{
		self.buddy = self;
	}
	else
	{
		self.buddy = find(world, targetname, self.target);
		if (!self.buddy) self.buddy = self;
	}
}

void() particlefield_use =
{
	if (self.spawnflags & PFIELD_BURST)
	{
		particlefield_get_spot();
		if (self.finaldest == VEC_ORIGIN)
		{
			particlefield_burst(self.speed);
			self.buddy = world;
		}
		else
		{
			self.attack_finished = time;
			self.state = 1;
			self.nextthink = time + self.wait;
			particlefield_sweep(self.speed);
		}
		return;
	}
	
	self.state = !self.state;
	if (self.state)
	{
		particlefield_get_spot();
		self.think = particlefield_think;
		self.nextthink = time + self.wait;
	}
	else
	{
		self.buddy = world;
	}
}


/*FGD
@baseclass color(0 128 224) = Particlefield [
	spawnflags(flags) = [
		1 : "Start on" : 0
		2 : "Suck inward" : 0
		4 : "Blow outward" : 0
		8 : "Single burst when triggered" : 0
	]
	speed(integer) : "Clumps per second" : 10
	speed2(integer) : "Dots per clump" : 16
	health(choices) : "Color" = [
		0   : "Dark grey"
		8   : "Light grey"
		16  : "Dark dirt brown"
		24  : "Light dirt brown"
		32  : "Dark sky blue"
		40  : "Light sky blue"
		48  : "Dark grass green"
		56  : "Light grass green"
		64  : "Dark red"
		72  : "Red"
		80  : "Dark green"
		88  : "Greenish orange "
		96  : "Copper"
		104 : "Gold"
		112 : "Dark flesh"
		120 : "Light flesh"
		128 : "Pale purple"
		136 : "Dull purple"
		144 : "Reddish purple"
		152 : "Dark reddish purple"
		160 : "Eggshell"
		168 : "Dark eggshell"
		176 : "Turquoise"
		184 : "Dark turquoise"
		192 : "Yellow"
		200 : "Dark yellow"
		208 : "Rich blue"
		216 : "Dark blue"
		224 : "Deep lava"
		232 : "Bright lava"
		240 : "Cyan/yellow/white confetti"
		248 : "Red/yellow/white confetti"
	]
	movedir(string) : "Velocity of particles (x y z)"
	wait(string) : "Interval" : "0.1"
	velocity(string) : "Direction of optional sweep effect (x y z)"
	distance(integer) : "Sleep if all players are further than this distance"
	target(target_source) : "Optional name of entity to center effect on"
]

@Pointclass base(Targetname, Appearflags, Bounds, Particlefield) size(16 16 16) = misc_particlefield_box : 
"Makes dots appear continuously within its bounds. Trigger to toggle on/off." []

@Solidclass base(Targetname, Appearflags, Particlefield) = misc_particlefield : 
"Makes dots appear continuously within its bounds. Trigger to toggle on/off." []

*/
/*QUAKED misc_particlefield_box (0 .6 1) (-8 -8 -8) (8 8 8) START_ON INWARD OUTWARD BURST
Makes dots appear continuously within its bounds. Trigger to toggle on or off. 

"size" dimensions of sparkly zone
"speed" number of clumps per second, default 10
"speed2" number of dots per clump, default 16
"health" color index (0-255). quake will use every color in the row (each row is 16 colors)
"movedir" give particles a velocity
"velocity" add a sweep effect - vector specifies direction and speed
"wait" dot interval, default 0.1
"distance" don't make dots if all players are farther away than this. 0 = always dots.

Flags:
INWARD		particles are sucked toward origin. additive with movedir.
OUTWARD		particles are blown out from origin. additive with movedir.
BURST		spew one second's worth of particles in one shot when triggered rather than toggling on/off

Color Reference:
0-15 grey (higher = lighter)
16-31 dirt brown (higher = lighter)
32-47 sky blue (higher = lighter)
48-63 grass green (higher = lighter)
64-79 red (higher = lighter)
80-95 green/orange (higher = lighter)
96-111 copper/gold (higher = lighter)
112-127 flesh tone (higher = lighter)
128-143 pale purple (higher = darker)
144-159 reddish purple (higher = darker)
160-175 pale beige (higher = darker)
176-191 turquoise (higher = darker)
192-207 yellow (higher = darker)
208-223 deep blue (higher = darker)
224-239 fire/lava (higher = lighter)
240-255 fullbright mess
*/
void() misc_particlefield_box =
{
	if (!SUB_ShouldSpawn()) return;
	self.think = particlefield_think;
	self.use = particlefield_use;
	
	if (!self.speed)
		self.speed = 10;
	if (!self.speed2)
		self.speed2 = 16;
	if (!self.wait)
		self.wait = 0.1;
	
	if (self.size == '0 0 0')
	{
		if (self.mangle != '0 0 0')
			self.size = self.mangle;
		else
			self.size = '64 64 64';
	}
	setsize(self, -self.size * 0.5, self.size * 0.5);	// set all values so we can see the field with r_showbboxes
	self.size = self.size * 0.5;
	
	self.finaldest = self.velocity;
	if (self.finaldest != VEC_ORIGIN)
	{
		self.velocity = VEC_ORIGIN;
		// transform so that the sweep axis is locally z to simplify later math
		float x, y, z;
		x = fabs(self.finaldest_x);
		y = fabs(self.finaldest_y);
		z = fabs(self.finaldest_z);
		
		if (z < y || z < x)
		{
			if (y < x)
			{	// sweeping down x
				self.worldtype = 0;
				self.dest = Vector(self.size_y, self.size_z, self.size_x);
				self.pos1 = Vector(self.finaldest_y, self.finaldest_z, self.finaldest_x);
			}
			else
			{	// sweeping down y
				self.worldtype = 1;
				self.dest = Vector(self.size_x, self.size_z, self.size_y);
				self.pos1 = Vector(self.finaldest_x, self.finaldest_z, self.finaldest_y);
			}
		}
		else
		{	// already z
			self.worldtype = 2;	
			self.dest = self.size;
			self.pos1 = self.finaldest;
		}
	}

	if (self.spawnflags & PFIELD_START_ON)
	{
		self.think = particlefield_use;
		self.nextthink = time + self.wait;
	}
	
	// innie and outie cancel
	if (self.spawnflags & (PFIELD_INWARD | PFIELD_OUTWARD) == (PFIELD_INWARD | PFIELD_OUTWARD))
		self.spawnflags -= 6;
}

/*QUAKED misc_particlefield (0 .6 1) ? START_ON INWARD OUTWARD BURST
Makes dots appear continuously within its bounds. Trigger to toggle on or off. 

"speed" number of clumps per second
"speed2" number of dots per clump
"health" color index (0-255). quake will use every color in the row (each row is 16 colors)
"movedir" give particles a velocity
"distance" don't make dots if all players are farther away than this. 0 = always dots.

Flags:
INWARD		particles are sucked toward origin. additive with movedir.
OUTWARD		particles are blown out from origin. additive with movedir.
BURST		spew one second's worth of particles in one shot when triggered rather than toggling on/off

Color Reference:
0-15 grey (higher = lighter)
16-31 dirt brown (higher = lighter)
32-47 sky blue (higher = lighter)
48-63 grass green (higher = lighter)
64-79 red (higher = lighter)
80-95 green/orange (higher = lighter)
96-111 copper/gold (higher = lighter)
112-127 flesh tone (higher = lighter)
128-143 pale purple (higher = darker)
144-159 reddish purple (higher = darker)
160-175 pale beige (higher = darker)
176-191 turquoise (higher = darker)
192-207 yellow (higher = darker)
208-223 deep blue (higher = darker)
224-239 fire/lava (higher = lighter)
240-255 fullbright mess
*/
void() misc_particlefield =
{
	setmodel(self,self.model);
	//self.mangle = self.size;
	setorigin(self,(self.absmin + self.absmax) * 0.5);
	self.modelindex = 0;
	self.model = string_null;
	self.mins = self.maxs = VEC_ORIGIN;
	misc_particlefield_box();
}

//=============================================================================


void(entity targ, float mag) screenshake_go =
{
	vector kick;
	
	// punchangle doesn't work when we're in an intermission camera, so do
	// this with actual angle offsets when intermission > 0
	if (intermission)
	{
		kick = Vector(crandom(),crandom(),crandom());
		kick *= clamp(mag,1,4);	// don't let vp wander too far, it might clip
		setorigin(targ, targ.goalentity.origin + kick);	// goalentity = current info_intermission
		
		// angle kicks look a lot harder in intermission for some reason, don't 
		// do them unless we mean it
		if (mag >= 1)
		{
			kick_z = crandom() * mag;
			mag *= 0.5;
			kick_x = crandom() * mag;
			kick_y = crandom() * mag;
			targ.angles = targ.mangle + kick;
			targ.fixangle = 1;
		}
		return;
	}	
	
	mag += 0.4;
	
	if (mag > 0.2)
	{
		targ.punchangle_x = crandom() * mag;
		targ.punchangle_y = crandom() * mag;
	}
	// the rolls feel a lot less violent, so bump them up a little
	if (mag > 0.1)
		targ.punchangle_z = crandom() * mag * 2;	
	
	// punchangle is integerized, so jitter viewpoint itself also for the feel of a faint 
	// rumble when the magnitude is low instead of just a dying fish kicking occasionally
	if (targ.health > 0) // view_ofs_z == 0 is a byword for 'dead' elsewhere :/
	{
		// quake only sends the z component of view_ofs over the network
		targ.view_ofs_z = crandom() * clamp(mag * 2, 0, 4) + 22;
	}	
}

void() screenshake_think =
{
	entity t;
	float mag, dmag;
	
	if (time > self.pain_finished)
	{
		t = nextent(world);
		while (t.classname == "player")
		{
			t.v_angle_z = 0;	// unroll
			if (intermission || t.health <= 0)
				t.view_ofs_z = 0;
			else
				t.view_ofs_z = 22;
			t = nextent(t);
		}
		self.state = 0;
		return;
	}
	
	if (time < self.super_time + self.delay)
	{
		self.state = 1;
		mag = 1 - ((self.super_time + self.delay) - time) / self.delay;
	}
	else if (time < self.super_time + self.delay + self.length)
	{
		self.state = 2;
		mag = 1;
	}
	else if (time < self.pain_finished)
	{
		mag = (self.pain_finished - time) / self.wait;
		self.state = 3;
	}
	else mag = 0;
	
	mag *= mag;	// power of 2 falloff seems smoother than linear
	
	t = nextent(world);
	while (t.classname == "player")
	{
		dmag = 1;
		if (self.distance)
			dmag = max(0, 1 - (vlen(self.origin - t.origin) / self.distance));
		if (dmag > 0)
			screenshake_go(t, self.strength * mag * dmag * dmag);
		t = nextent(t);
	}

	self.nextthink = time + 0.05;
}

void() screenshake_use =
{
	self.pain_finished = time + self.wait + self.delay + self.length;
	self.super_time = time;
	self.nextthink = time + 0.05;
	self.think = screenshake_think;
}


/*QUAKED target_screenshake (0 .5 .8) (-8 -8 -8) (8 8 8)
Shakes the screen. Jostles the view of all clients, but doesn't physically move their bounding boxes or apply velocities.
Keys
"length" Duration of full intensity quake. -1 will last literally forever.
"delay" Time to ramp up quake intensity from 0
"wait" Time to ramp down quake intensity to 0. Total quake duration is length + delay + wait.
"strength" Intensity of quake. 1 is a hearty rumble, 10 is spasmodic bordering on hilarious.
"distance" Fade the intensity to 0 at this distance from the entity. Default is 0 (global).
*/
/*FGD
@Pointclass base(Targetname, Appearflags) color(0 128 224) size(16 16 16) = target_screenshake : 
"Shakes the screen. Jostles the view of all clients, but doesn't physically move their bounding boxes or apply velocities.
Total shake duration is length + delay + wait." 
[
	length(string) : "Duration of full intensity (sustain)"
	delay(string) : "Time to ramp up from 0 (attack)"
	wait(string) : "Time to ramp down quake intensity to 0."
	strength(string) : "Intensity of quake. 1 is a hearty rumble, 10 is spasmodic bordering on hilarious." : "1.0"
	distance(integer) : "Attenuation distance; 0 is global" : 0
]
*/
void() target_screenshake =
{
	if (!SUB_ShouldSpawn()) return;
	self.wait = max(0, self.wait);
	self.delay = max(0, self.delay);
	self.length = max(0, self.length);
	self.distance = max(0, self.distance);
	
	if (!self.delay && !self.length && !self.wait)
		dprint("misc_screenshake will last 0 seconds\n");

	if (!self.strength)
	{
		if (self.volume)
			objerror("convert target_screenshake to .strength please");
		
		self.strength = 1;
	}
	self.use = screenshake_use;
}


void(float attack, float sustain, float release, float str) screenshake_oneshot =
{
	entity shake, oself;
	
	shake = spawn();
	
	shake.delay = attack;
	shake.length = sustain;
	shake.wait = release;
	shake.strength = str;
	
	oself = self;
	self = shake;
	
	target_screenshake();
	screenshake_use();
	
	self = oself;
}

//============================================================================

void() target_explosion_go =
{
	if (self.dmg) T_RadiusMultiDamage (self, self.enemy, self.dmg, self, 0);
	
	if (self.spawnflags & 1)
	{
		sound (self, CHAN_VOICE, "blob/death1.wav", 1, ATTN_NORM);
		BecomeBlast(1);
	}
	else if (self.spawnflags & 2)
		BecomeBlast(2);
	else
		BecomeBlast(0);
}

void() target_explosion_use =
{
	float i, tnext;
	entity bewm;
	vector offset;
	
	self.enemy = activator;
	
	playercount_convert(count);
	if (self.count == 1 && self.delay == 0 && self.rand == 0)
	{
		bewm = spawn();
		if (self.size != VEC_ORIGIN)
			offset = Vector(random() * self.size_x, random() * self.size_y, random() * self.size_z) - self.size * 0.5;
		setorigin(bewm, self.origin + offset);
		bewm.think = target_explosion_go;
		bewm.enemy = activator;
		bewm.spawnflags = self.spawnflags;
		bewm.nextthink = time;
		bewm.dmg = self.dmg;
		bewm.deathtype = self.deathtype;
		return;
	}
	
	tnext = self.delay + self.rand * random();
	for (i = 0; i < self.count; i++)
	{
		bewm = spawn();
		if (self.size != VEC_ORIGIN)
			offset = Vector(random() * self.size_x, random() * self.size_y, random() * self.size_z) - self.size * 0.5;
		setorigin(bewm, self.origin + offset);
		bewm.think = target_explosion_go;
		bewm.enemy = activator;
		bewm.spawnflags = self.spawnflags;
		bewm.nextthink = time + tnext;
		bewm.dmg = self.dmg;
		bewm.deathtype = self.deathtype;
		tnext += self.wait + random() * self.rand;
	}
}

/*QUAKED target_explosion (0 .5 .8) (-8 -8 -8) (8 8 8) TARBABY PUFF
Causes explosions, same appearance as a rocket/grenade blast. Set 'TARBABY' for a purple spawn-style explosion or 'PUFF' for the weak anti-shambler-style burst instead.

Keys
"count" number of times to explode after triggering, default 1
"delay" Time to wait before first explode
"wait" Static time to wait between explosions
"rand" Random time to wait before explosions (will sum both)
"dmg" Do splash damage, default 0
"deathtype" death message if the player is killed by your horrible trap
"size" explode somewhere randomly chosen within a box of this size
*/
/*FGD
@Pointclass base(Targetname, Appearflags, Deathtype) color(0 128 224) size(16 16 16) = target_explosion : 
"Causes one or more explosions when triggered, same appearance as a rocket/grenade blast." 
[
	spawnflags(flags) = [
		1 : "Tarbaby blast " : 0
		1 : "Puff blast" : 0
	]
	count(integer) : "Repeat count" : 1
	delay(string) : "Delay before first blast" : "0"
	wait(string) : "Wait between blasts" : "1"
	rand(string) : "Random extra wait before blasts" : "0"
	size(string) : "Explode somewhere randomly chosen within a box of this size (x y z)" : "0 0 0"
	dmg(integer) : "Splash damage" : 0
]
*/
void() target_explosion =
{
	if (!SUB_ShouldSpawn()) return;
	self.count = zeroconvertdefault(self.count, 1);
	self.use = target_explosion_use;
	if (self.spawnflags & 1)
		precache_sound_safe("blob/death1.wav");
	if (!self.wait)
		self.wait = 1;
	if (self.deathtype == string_null)
		self.deathtype = "joins the smithereens";
}

//============================================================================

void() target_telefog_use =
{
	float i, tnext;
	entity tfog;
	vector offset;
	
	playercount_convert(count);
	if (self.count == 1 && self.delay == 0 && self.rand == 0)
	{
		tfog = spawn();
		if (self.size != VEC_ORIGIN)
			offset = Vector(random() * self.size_x, random() * self.size_y, random() * self.size_z) - self.size * 0.5;
		setorigin(tfog, self.origin + offset);
		tfog.think = teleport_flasher;
		tfog.nextthink = time;
		return;
	}
	
	tnext = self.delay + self.rand * random();
	for (i = 0; i < self.count; i++)
	{
		tfog = spawn();
		if (self.size != VEC_ORIGIN)
			offset = Vector(random() * self.size_x, random() * self.size_y, random() * self.size_z) - self.size * 0.5;
		setorigin(tfog, self.origin + offset);
		tfog.think = teleport_flasher;
		tfog.nextthink = time + tnext;
		tnext += self.wait + self.rand * random();
	}
}

/*QUAKED target_telefog (0 .5 .8) (-8 -8 -8) (8 8 8) 
Causes a flash of teleport fog.

Keys
"count" number of times to flash after triggering, default 1
"delay" Time to wait before first flash
"wait" Static ime to wait between flashes
"rand" Random time to wait before flashes (will sum both)
"size" Flash somewhere randomly chosen within a box of this size
*/
/*FGD
@Pointclass base(Targetname, Appearflags) color(0 128 224) size(16 16 16) = target_telefog : 
"Causes a flash of teleport fog." 
[
	count(integer) : "Repeat count" : 1
	delay(string) : "Delay before first flash" : "0"
	wait(string) : "Wait between flashes" : "1"
	size(string) : "Flash somewhere randomly chosen within a box of this size (x y z)" : "0 0 0"
	rand(string) : "Random extra before flashes" : "0"
]
*/
void() target_telefog =
{
	if (!SUB_ShouldSpawn()) return;
	self.count = zeroconvertdefault(self.count, 1);
	self.use = target_telefog_use;
	if (!self.wait)
		self.wait = 1;
}




//============================================================================

//	bubbas
void() bubble_split =
{
	if (pointcontents(self.origin + '0 0 8') != self.watertype)
		return;
		
	entity	bubble;
	bubble = bubble_spawn(self.origin);
	bubble.frame = 1;
	bubble.cnt = floor(9 + random()*4);
	bubble.velocity = self.velocity + '0 0 2';
	self.frame = 1;
	self.cnt = 10;
}

void() bubble_remove =
{
	remove(self);
}

void() bubble_bob =
{
	float		rnd1, rnd2, rnd3;

	if (pointcontents(self.origin + '0 0 8') != self.watertype)
	{
		SUB_Remove();
		return;
	}
	
	if (random() < 0.65)
		self.cnt = self.cnt + 1;
		
	if (self.cnt >= 18)
		remove(self);
	if (self.cnt == 8)
		bubble_split();

	rnd1 = self.velocity_x + crandom() * 20;
	rnd2 = self.velocity_y + crandom() * 20;
	rnd3 = self.velocity_z + crandom() * 15;

	if (rnd1 > 10)
		rnd1 = 5;
	if (rnd1 < -10)
		rnd1 = -5;
		
	if (rnd2 > 10)
		rnd2 = 5;
	if (rnd2 < -10)
		rnd2 = -5;
		
	if (rnd3 < 20)
		rnd3 = 25;
	if (rnd3 > 40)
		rnd3 = 35;
	
	self.velocity_x = rnd1;
	self.velocity_y = rnd2;
	self.velocity_z = rnd3;
		
	self.nextthink = time + 0.25;
	self.think = bubble_bob;
}

entity(vector org) bubble_spawn =
{
	entity	bubble;

	bubble = spawn();
	bubble.watertype = pointcontents(org);
	setmodel (bubble, "progs/s_bubble.spr");
	setorigin (bubble, org);
	bubble.movetype = MOVETYPE_NOCLIP;
	bubble.solid = SOLID_NOT;
	setsize (bubble, '-8 -8 -8', '8 8 8');
	bubble.velocity = '0 0 18';
	//bubble.alpha = 0.5;
	
	bubble.nextthink = time + 0.25;
	bubble.think = bubble_bob;
	bubble.touch = SUB_RemoveSoon;
	bubble.classname = "bubble";
	if (random() < 0.2)
	{
		bubble.frame = 1;
		bubble.cnt = 11;
	}
	else
	{
		bubble.frame = 0;
		bubble.cnt = 0;
	}
	return bubble;
}

//============================================================================

// back compat named function, mostly for sock maps
void() make_bubbles =
{
	bubble_spawn(self.origin);
	self.nextthink = time + random() + 0.5;
	self.think = make_bubbles;
};


void() air_bubbles_make =
{
	vector org;
	org = self.origin;
	if (self.size != VEC_ORIGIN)
		org += Vector(random() * self.size_x, random() * self.size_y, random() * self.size_z) - self.size * 0.5;
		
	bubble_spawn(org);
}

void() air_bubbles_think =
{
	if (!self.state)
		return;
	
	if (!self.wait && !self.rand)
	{
		// fix for 1000cuts using info_nulls with this as a think instead of just
		// placing an air_bubbles, skipping the init and causing every one of the
		// dozens of them to vomit bubbles per frame until the edict limit is hit
		// and the game crashes:
		self.wait = zeroconvertdefault(self.wait, 1);
		self.rand = zeroconvertdefault(self.rand, 1);
	}
	
	if (!particlefield_should_sleep())
	{
		air_bubbles_make();
	}
	self.nextthink = time + random() * self.rand + self.wait;
	self.think = air_bubbles_think;
}

void() air_bubbles_use =
{
	if (self.spawnflags & 8)
	{
		if (particlefield_should_sleep())
			return;
		
		for (float i = 0; i < self.count; i++)
		{
			air_bubbles_make();
		}
		return;
	}
	self.state = !(self.state);
	if (self.state)
	{
		self.think = air_bubbles_think;
		self.nextthink = time + random() * self.rand + self.wait;
	}
}

/*QUAKED air_bubbles (0 .5 .8) (-8 -8 -8) (8 8 8) START_OFF ? ? BURST
air bubble emitter. always bubbles. trigger to toggle on or off. check BURST to make a one-time triggerable bubbler.

"wait" bubble interval, default 1
"rand" random extra interval, default 1
"size" size of random bubble emission zone, default '0 0 0'
"count" bubbles to emit at once if single burst
"distance" don't emit bubbles if no players are closer than this distance, default 1024
*/
/*FGD
@PointClass base(Appearflags, Targetname) color(0 150 220) = air_bubbles : "Air bubble emitter." 
[
	spawnflags(flags) = [
		1 : "Start off" : 0
		8 : "Single burst when triggered" : 0
	]
	wait(string) : "Bubble interval" : "1"
	rand(string) : "Random extra interval" : "1"
	size(string) : "Emit from random places within a box of this size" : "0 0 0"
	count(integer) : "Bubbles to emit at once if single burst" : 1
	distance(integer) : "Sleep if all players are further than this distance"
]
*/
void() air_bubbles =
{
	if (!SUB_ShouldSpawn()) return;
	if (deathmatch)
	{
		remove (self);
		return;
	}
	precache_model ("progs/s_bubble.spr");
	self.wait = zeroconvertdefault(self.wait, 1);
	self.rand = zeroconvertdefault(self.rand, 1);
	
	self.think = air_bubbles_think;
	if (self.targetname != string_null)
	{
		self.use = air_bubbles_use;
		self.state = !(self.spawnflags & 1);
		if (!self.state)
			return;
	}
	if (self.spawnflags & 8)
		return;
	self.nextthink = time + self.wait;
}

