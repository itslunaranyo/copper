/*
==============================================================================

MEAT FIREWORKS

moved from player.qc

the rule: gibs pass through .notrace monsterclip but heads do not, because heads
are kind of the trophies for gibbing something and should hang around rather
than fall through grates (also they look too big)

==============================================================================
*/

vector(float dm) GibVelocityForHealth =
{
	vector v;
	float voom;
	
	v_x = 150 * crandom();
	v_y = 150 * crandom();
	v_z = 150 + 150 * random();

	voom = max(1, min(10, dm * dm / 5000));
	
	return v * voom;
}

entity(string gibname, vector vel) ThrowGib =
{
	entity gib;
	gib = spawn();
	
	// gibs have to be thinking ballistic projectiles to pass through monsterclip/notrace
	gib.owner = gib.trueowner = self;
	gib.touch = projectile_touch_null;
	gib.th_die = SUB_Remove;
	gib.think = projectile_toss_think;
	gib.nextthink = time;
	gib.touch = projectile_touch_null;
	gib.lifetime_finished = time + 6 + random() * 6;

	setmodel(gib, gibname);
	setsize (gib, VEC_ORIGIN, VEC_ORIGIN);
	setorigin (gib, self.origin);

	gib.velocity = gib.oldvelocity = vel;	
	gib.avelocity = Vector(random(),random(),random()) * 600;

	gib.movetype = MOVETYPE_BOUNCE;
	
	gib.type = "gib";
	
	return gib;
}

void(string gibname, float dm) ThrowHead =
{
	setmodel (self, gibname);
	self.frame = 0;
	self.think = SUB_Null;
	self.nextthink = 0;
	
	self.movetype = MOVETYPE_BOUNCE;
	self.takedamage = DAMAGE_NO;
	self.solid = SOLID_NOT;
	self.view_ofs = '0 0 8';
	setsize (self, '-16 -16 0', '16 16 56');
	self.velocity += GibVelocityForHealth(dm);
	self.origin_z = self.origin_z - 24;
	self.flags = self.flags - (self.flags & FL_ONGROUND);
	self.type = "head";
	self.avelocity = crandom() * '0 600 0';
}


// Gib & GibSpray are split up since some monsters play special gib sounds (zombies/players)
void(string headmdl, float dm) GibSpray =
{
	ThrowGib ("progs/gib1.mdl", GibVelocityForHealth(dm));
	ThrowGib ("progs/gib2.mdl", GibVelocityForHealth(dm));
	ThrowGib ("progs/gib3.mdl", GibVelocityForHealth(dm));
	
	if (self.classname != "player" && damage_attacker.classname == "func_void" )
	{
		SUB_Remove();
		return;
	}
		
	ThrowHead (headmdl, dm);
}

void(string headmdl, float dm) Gib =
{
	sound (self, CHAN_VOICE, "player/udeath.wav", 1, ATTN_NORM);
	
	GibSpray(headmdl, dm);
}


/*
================
SpawnMeatSpray
================
*/
void(vector org, vector vel) SpawnMeatSpray =
{
	entity meat;
	vector mvel;
	
	mvel = vel;
	mvel_z += 250 + 50 * random();

	meat = toss_projectile(org, mvel, "gib");
	//meat.solid = SOLID_NOT;
	meat.type = "gib";
	meat.avelocity = '3000 1000 2000';
	meat.lifetime_finished = time + 1;
	
	SUB_ChangeModel(meat, "progs/zom_gib.mdl");
}

/*
================
SpawnBlood
================
*/
void(vector org, vector vel, float damage) SpawnBlood =
{
	particle (org, vel*0.1, 73, damage*2);
}

//============================================================================

// meat noise
// meat noise
// play that funky meat noise
void() meat_noise =
{
	float r = random();
	if (r < 0.25)
		sound (self, CHAN_BODY, "player/teledth1.wav", 1, ATTN_NORM);
	else if (r < 0.5)
		sound (self, CHAN_BODY, "player/tornoff2.wav", 1, ATTN_NORM);
	else if (r < 0.75)
		sound (self, CHAN_BODY, "player/udeath.wav", 1, ATTN_NORM);
	else
		sound (self, CHAN_BODY, "player/gib.wav", 1, ATTN_NORM);
}

void(string gibname) target_meat_fireworks_do =
{
	vector spray;
	entity gib;
	spray = '1 1 1' - self.owner.mangle;
	spray_x = spray_x * crandom() + self.owner.mangle_x * 4;
	spray_y = spray_y * crandom() + self.owner.mangle_y * 4;
	spray_z = spray_z * crandom() + self.owner.mangle_z * 4;
	spray *= self.owner.speed * 2;
	
	gib = ThrowGib(gibname, spray);
	setorigin(gib, self.origin + self.pos1);
}

void() target_meat_fireworks_go =
{
	vector spray;
	float i;
	meat_noise();
	
	self.pos1_x = (random()-0.5) * self.owner.size_x;
	self.pos1_y = (random()-0.5) * self.owner.size_y;
	self.pos1_z = (random()-0.5) * self.owner.size_z;

	for (i = 0; i < 3; i++)
	{
		spray = '1 1 1' - self.owner.mangle;
		spray_x *= crandom();
		spray_y *= crandom();
		spray_z *= crandom();
		spray += self.owner.mangle;
		SpawnMeatSpray(self.origin + self.pos1, spray * self.owner.speed * 4);
	}
	
	target_meat_fireworks_do(self.owner.model);
	
	if (self.owner.cnt == 2)
		target_meat_fireworks_do(self.owner.model2);
	else
		target_meat_fireworks_do(self.owner.model);
		
	if (self.owner.cnt == 3)
		target_meat_fireworks_do(self.owner.model3);
	else
		target_meat_fireworks_do(self.owner.model);
}

void() target_meat_fireworks_use =
{
	float i, tnext;
	entity meats;
	
	playercount_convert(count);
	if (self.count == 1 && self.delay == 0 && self.rand == 0)
	{
		target_meat_fireworks_go();
		return;
	}
	
	tnext = self.delay + self.rand * random();
	for (i = 0; i < self.count; i++)
	{
		meats = spawn();
		meats.owner = self;
		setorigin(meats, self.origin);
		meats.think = target_meat_fireworks_go;
	//	meats.mangle = self.mangle;
	//	meats.speed = self.speed;
	//	meats.size = self.size;
		meats.nextthink = time + tnext;
		tnext += self.wait + self.rand * random();
	}
}

/*QUAKED target_meat_fireworks (0.7 .0 .2) (-16 -16 -16) (16 16 16)
trigger for meat

Keys
"count" number of times of meat after triggering, default 1
"delay" time to wait before first meat
"wait" time to wait between meat
"rand" max random additional to wait before meat
"speed" speed of meat
"mangle" override meat direction, defaults to up
"size" random location of bursts within bounds of this size
*/
/*FGD
@PointClass base(Appearflags, Targetname) size(32 32 32) color(180 0 50) = target_meat_fireworks : "trigger for meat"
[
	count(integer) : "Repeat meat" : 1
	delay(string) : "Delay before first meat" : "0"
	wait(string) : "Wait between meat" : "1"
	rand(string) : "Random extra wait before meat" : "0"
	size(string) : "Random location within bounds" : "0 0 0"
	speed(integer) : "Speed of meat" : 128
	mangle(string) : "Override meat vector" : "0 0 1"
]
*/
void() target_meat_fireworks =
{
	dprint("target_meat_fireworks\n");
	
	if (!SUB_ShouldSpawn()) return;
	self.owner = self;	// delayed emitters have owner as this also
	self.speed = zeroconvertdefault(self.speed, 128);
	self.count = zeroconvertdefault(self.count, 1);
	self.use = target_meat_fireworks_use;
	if (!self.wait)
		self.wait = 1;
	
	if (self.mangle == VEC_ORIGIN)
	{
		self.mangle = VEC_UP;
	}
	else
	{
		self.mangle = normalize(self.mangle);
	}
	
	if (self.model != string_null)
	{
		precache_model(self.model);
		self.cnt = 1;
		if (self.model2 != string_null)
		{
			precache_model(self.model2);
			self.cnt = 2;
			if (self.model3 != string_null)
			{
				precache_model(self.model3);
				self.cnt = 3;
			}
		}
	}
	else
	{
		self.cnt = 3;
		self.model = "progs/gib1.mdl";
		self.model2 = "progs/gib2.mdl";
		self.model3 = "progs/gib3.mdl";
	}
}

void() misc_meat_fireworks = {target_meat_fireworks();}