/*
==============================================================================

WIZARD

==============================================================================
*/

$cd id1/models/a_wizard
$origin 0 0 24
$base wizbase	
$skin wizbase

$frame hover1 hover2 hover3 hover4 hover5 hover6 hover7 hover8
$frame hover9 hover10 hover11 hover12 hover13 hover14 hover15

$frame fly1 fly2 fly3 fly4 fly5 fly6 fly7 fly8 fly9 fly10
$frame fly11 fly12 fly13 fly14

$frame magatt1 magatt2 magatt3 magatt4 magatt5 magatt6 magatt7
$frame magatt8 magatt9 magatt10 magatt11 magatt12 magatt13

$frame pain1 pain2 pain3 pain4

$frame death1 death2 death3 death4 death5 death6 death7 death8

/*
=================
WizardCheckAttack
=================
*/
float()	WizardCheckAttack =
{
	vector	spot1, spot2;	
	float		chance;
	
	if (time < self.attack_finished)
		return FALSE;
	if (!enemy_vis)
		return FALSE;

	if (enemy_range >= RANGE_FAR)
	{
		self.attack_state = AS_STRAIGHT;
		return FALSE;
	}
	
	// see if any entities are in the way of the shot
	if (!has_invis(self.enemy))	// but not if we can't see him
	{
		// see if any entities are in the way of the shot
		spot1 = self.origin + self.view_ofs;
		spot2 = self.enemy.origin + self.enemy.view_ofs;

		traceline2(spot1, spot2, self, TRACE_WATER);

		if (trace_ent != self.enemy)
		{	// don't have a clear shot, so move to a side
			self.attack_state = AS_STRAIGHT;
			return FALSE;
		}
	}
	
	if (enemy_range == RANGE_MELEE)
		chance = 0.9;
	else if (enemy_range == RANGE_NEAR)
		chance = 0.6;
	else if (enemy_range == RANGE_MID)
		chance = 0.2;
	else
		chance = 0;

	if (random () < chance)
	{
		self.attack_state = AS_MISSILE;
		return TRUE;
	}

	if (enemy_range == RANGE_MID)
		self.attack_state = AS_STRAIGHT;
	else
		self.attack_state = AS_SLIDING;
	
	return FALSE;
}

/*
=================
WizardAttackFinished
=================
*/
void()	WizardAttackFinished =
{
	enemy_range = range(self.enemy);
	enemy_vis = visible(self.enemy);
	
	if (enemy_range != RANGE_NEAR || !enemy_vis || random() < 0.5)
		self.attack_state = AS_STRAIGHT;
	else
		self.attack_state = AS_SLIDING;
}

/*
==============================================================================

FAST ATTACKS

==============================================================================
*/

entity(vector org, vector vel) launch_wizspike =
{
	entity spike;
	
	if (skill == 3)
	{
		spike = launch_projectile(org, vel*720, "wizspike");	// FLYMISSILE
		spike.dmg = 20;
		SUB_ChangeModel (spike, "progs/w_spike2.mdl");
	}
	else
	{
		spike = launch_projectile(org, vel*600, "wizspike");	// FLYMISSILE
		spike.dmg = 9;
		SUB_ChangeModel (spike, "progs/w_spike.mdl");
	}
	spike.touch = spike_touch;
	
	return spike;	
}

void() Wiz_FastFire =
{
	vector vec;
	vector dst;
	entity wsp;

	if (self.owner.health > 0)
	{
		self.owner.effects = self.owner.effects | EF_MUZZLEFLASH;

		dst = enemy_vispos() - self.movedir;
	
		vec = normalize(dst - self.origin);
		sound (self, CHAN_WEAPON, "wizard/wattack.wav", 1, ATTN_NORM);
		wsp = launch_wizspike (self.origin, vec);
		wsp.owner = wsp.trueowner = self.owner;
	}

	remove (self);
}

void(float when, float where) Wiz_Shot =
{
	entity	missile;
	
	missile = spawn ();
	missile.owner = self;
	setsize (missile, '0 0 0', '0 0 0');		
	setorigin (missile, self.origin + '0 0 24' + v_forward * 14 + v_right * where);
	missile.enemy = self.enemy;
	missile.nextthink = time + when;
	missile.think = Wiz_FastFire;
	missile.movedir = v_right * where;
}

void() Wiz_StartFast =
{
	//sound (self, CHAN_WEAPON, "wizard/wattack.wav", 1, ATTN_NORM);
	self.v_angle = self.angles;
	makevectors (self.angles);

	Wiz_Shot(0.3, -13);
	Wiz_Shot(0.8, 13);
}



void() Wiz_idlesound =
{
	if (self.show_hostile > time) return;
local float wr;
	wr = random() * 5;

	if (self.wait < time)
	{
	 	self.wait = time + 2;
	 	if (wr > 4.5) 
	 		sound (self, CHAN_VOICE, "wizard/widle1.wav", 1,  ATTN_IDLE);
	 	if (wr < 1.5)
	 		sound (self, CHAN_VOICE, "wizard/widle2.wav", 1, ATTN_IDLE);
	}
	return;
}

void()	wiz_stand1	=[	$hover1,	wiz_stand2	] {ai_stand();}
void()	wiz_stand2	=[	$hover2,	wiz_stand3	] {ai_stand();}
void()	wiz_stand3	=[	$hover3,	wiz_stand4	] {ai_stand();}
void()	wiz_stand4	=[	$hover4,	wiz_stand5	] {ai_stand();}
void()	wiz_stand5	=[	$hover5,	wiz_stand6	] {ai_stand();}
void()	wiz_stand6	=[	$hover6,	wiz_stand7	] {ai_stand();}
void()	wiz_stand7	=[	$hover7,	wiz_stand8	] {ai_stand();}
void()	wiz_stand8	=[	$hover8,	wiz_stand9	] {ai_stand();}
void()	wiz_stand9	=[	$hover9,	wiz_stand10	] {ai_stand();}
void()	wiz_stand10	=[	$hover10,	wiz_stand11	] {ai_stand();}
void()	wiz_stand11	=[	$hover11,	wiz_stand12	] {ai_stand();}
void()	wiz_stand12	=[	$hover12,	wiz_stand13	] {ai_stand();}
void()	wiz_stand13	=[	$hover13,	wiz_stand14	] {ai_stand();}
void()	wiz_stand14	=[	$hover14,	wiz_stand15	] {ai_stand();}
void()	wiz_stand15	=[	$hover15,	wiz_stand1	] {ai_stand();}

void()	wiz_walk1	=[	$hover1,	wiz_walk2	] {ai_walk(8);Wiz_idlesound();}
void()	wiz_walk2	=[	$hover2,	wiz_walk3	] {ai_walk(8);}
void()	wiz_walk3	=[	$hover3,	wiz_walk4	] {ai_walk(8);}
void()	wiz_walk4	=[	$hover4,	wiz_walk5	] {ai_walk(8);}
void()	wiz_walk5	=[	$hover5,	wiz_walk6	] {ai_walk(8);}
void()	wiz_walk6	=[	$hover6,	wiz_walk7	] {ai_walk(8);}
void()	wiz_walk7	=[	$hover7,	wiz_walk8	] {ai_walk(8);}
void()	wiz_walk8	=[	$hover8,	wiz_walk9	] {ai_walk(8);}
void()	wiz_walk9	=[	$hover9,	wiz_walk10	] {ai_walk(8);Wiz_idlesound();}
void()	wiz_walk10	=[	$hover10,	wiz_walk11	] {ai_walk(8);}
void()	wiz_walk11	=[	$hover11,	wiz_walk12	] {ai_walk(8);}
void()	wiz_walk12	=[	$hover12,	wiz_walk13	] {ai_walk(8);}
void()	wiz_walk13	=[	$hover13,	wiz_walk14	] {ai_walk(8);}
void()	wiz_walk14	=[	$hover14,	wiz_walk15	] {ai_walk(8);}
void()	wiz_walk15	=[	$hover15,	wiz_walk1	] {ai_walk(8);}

void()	wiz_side1	=[	$hover1,	wiz_side2	] {
	if (self.attack_state == AS_STRAIGHT)
	{
		wiz_run1();
		return;
	}
	ai_run(8);
	Wiz_idlesound();
}
void()	wiz_side2	=[	$hover2,	wiz_side3	] {ai_run(8);}
void()	wiz_side3	=[	$hover3,	wiz_side4	] {ai_run(8);}
void()	wiz_side4	=[	$hover4,	wiz_side5	] {ai_run(8);}
void()	wiz_side5	=[	$hover5,	wiz_side6	] {ai_run(8);}
void()	wiz_side6	=[	$hover6,	wiz_side7	] {ai_run(8);}
void()	wiz_side7	=[	$hover7,	wiz_side8	] {ai_run(8);}
void()	wiz_side8	=[	$hover8,	wiz_side9	] {ai_run(8);}
void()	wiz_side9	=[	$hover9,	wiz_side10	] {ai_run(8);Wiz_idlesound();}
void()	wiz_side10	=[	$hover10,	wiz_side11	] {ai_run(8);}
void()	wiz_side11	=[	$hover11,	wiz_side12	] {ai_run(8);}
void()	wiz_side12	=[	$hover12,	wiz_side13	] {ai_run(8);}
void()	wiz_side13	=[	$hover13,	wiz_side14	] {ai_run(8);}
void()	wiz_side14	=[	$hover14,	wiz_side15	] {ai_run(8);}
void()	wiz_side15	=[	$hover15,	wiz_side1	] {ai_run(8);
	if (!enemy_vis)
	{
		self.attack_state = AS_STRAIGHT;	// we've casually strafed out of view like an idiot
		self.think = wiz_run1;
	}
}

void()	wiz_run1	=[	$fly1,		wiz_run2	] {
	if (self.attack_state == AS_SLIDING)
	{
		wiz_side1();
		return;
	}
	ai_run(16);
	Wiz_idlesound();
}
void()	wiz_run2	=[	$fly2,		wiz_run3	] {ai_run(16);}
void()	wiz_run3	=[	$fly3,		wiz_run4	] {ai_run(16);}
void()	wiz_run4	=[	$fly4,		wiz_run5	] {ai_run(16);}
void()	wiz_run5	=[	$fly5,		wiz_run6	] {ai_run(16);}
void()	wiz_run6	=[	$fly6,		wiz_run7	] {ai_run(16);}
void()	wiz_run7	=[	$fly7,		wiz_run8	] {ai_run(16);}
void()	wiz_run8	=[	$fly8,		wiz_run9	] {ai_run(16);}
void()	wiz_run9	=[	$fly9,		wiz_run10	] {ai_run(16);}
void()	wiz_run10	=[	$fly10,		wiz_run11	] {ai_run(16);}
void()	wiz_run11	=[	$fly11,		wiz_run12	] {ai_run(16);}
void()	wiz_run12	=[	$fly12,		wiz_run13	] {ai_run(16);}
void()	wiz_run13	=[	$fly13,		wiz_run14	] {ai_run(16);}
void()	wiz_run14	=[	$fly14,		wiz_run1	] {ai_run(16);}

void()	wiz_fast1	=[	$magatt1,		wiz_fast2	] {ai_face();Wiz_StartFast();}
void()	wiz_fast2	=[	$magatt2,		wiz_fast3	] {ai_face();}
void()	wiz_fast3	=[	$magatt3,		wiz_fast4	] {ai_face();}
void()	wiz_fast4	=[	$magatt4,		wiz_fast5	] {ai_face();}
void()	wiz_fast5	=[	$magatt5,		wiz_fast6	] {ai_face();}
void()	wiz_fast6	=[	$magatt6,		wiz_fast7	] {ai_face();}
void()	wiz_fast7	=[	$magatt7,		wiz_fast8	] {ai_face();}
void()	wiz_fast8	=[	$magatt8,		wiz_fast9	] {ai_face();}
void()	wiz_fast9	=[	$magatt10,		wiz_fast10	] {ai_face();}
void()	wiz_fast10	=[	$magatt12,		wiz_run1	] {ai_face();
	if (skill == 3)
		ai_attack_finished(3 * random()); 
	else
		ai_attack_finished(1.5 + random()); 
	WizardAttackFinished();
}

void()	wiz_pain1	=[	$pain1,		wiz_pain2	] {ai_nop();PainFinished(0.2);}
void()	wiz_pain2	=[	$pain2,		wiz_pain3	] {ai_nop();}
void()	wiz_pain3	=[	$pain3,		wiz_pain4	] {ai_nop();}
void()	wiz_pain4	=[	$pain4,		wiz_run1	] {ai_nop();}

void()	wiz_death1	=[	$death1,		wiz_death2	] {
	self.velocity_x = -200 + 400*random();
	self.velocity_y = -200 + 400*random();
	self.velocity_z = 100 + 100*random();
	self.flags = not(self.flags, FL_ONGROUND);
	sound (self, CHAN_VOICE, "wizard/wdeath.wav", 1, ATTN_NORM);
}
void()	wiz_death2	=[	$death2,		wiz_death3	] {}
void()	wiz_death3	=[	$death3,		wiz_death4	] {self.solid = SOLID_NOT; self.flags = not(self.flags, FL_ONGROUND);}
void()	wiz_death4	=[	$death4,		wiz_death5	] {}
void()	wiz_death5	=[	$death5,		wiz_death6	] {}
// would be nice to hold on frame 6 until the plunk, but SOLID_NOT things don't generate touch events
// if they did it would be a lot easier to remove dead scrags and heads in func_voids
void()	wiz_death6	=[	$death6,		wiz_death7	] {}
void()	wiz_death7	=[	$death7,		wiz_death8	] {}
void()	wiz_death8	=[	$death8,		SUB_Null	] {}// deathvoidcheck(); }

void() wiz_die =
{
// check for gib
	if (self.health < -40)
	{
		Gib ("progs/h_wizard.mdl", self.health);
		return;
	}

	wiz_death1 ();
}


void(entity attacker, float damage) Wiz_Pain =
{
	sound (self, CHAN_VOICE, "wizard/wpain.wav", 1, ATTN_NORM);
	if (random()*70 > damage)
		return;		// didn't flinch

	wiz_pain1 ();
}


void() monster_wizard_spawn =
{
	self.classname = "monster_wizard";
		
	self.solid = SOLID_SLIDEBOX;
	//self.movetype = MOVETYPE_STEP;

	setmodel (self, "progs/wizard.mdl");

	setsize (self, VEC_HULL_MIN, VEC_HULL_MAX);
	self.health = 80;

	self.th_stand = wiz_stand1;
	self.th_walk = wiz_walk1;
	self.th_run = wiz_run1;
	self.th_missile = wiz_fast1;
	self.th_pain = Wiz_Pain;
	self.th_die = wiz_die;
	self.th_checkattack = WizardCheckAttack;

	if (self.deathtype == string_null)
		self.deathtype = "was scragged by a Scrag";

	self.height = zeroconvertdefault(self.height, 35);
	self.jump_flag = self.height;	// remember original value for short term nav tweaking
	flymonster_start();
}

void() monster_wizard_spawner = {mon_spawner_use(monster_wizard_spawn);}

/*QUAKED monster_wizard (1 0 0) (-16 -16 -24) (16 16 40) AMBUSH ? ? ? TRIGGERED NOTFOG NOTELEFRAG INSTAWAKE
Scrag (the WIZARD), 80 health points.

Flags:
"ambush" only wake up on seeing the player, not another monster getting angry

"Triggered"	will not spawn until triggered - triggering again will wake him up. Set 'count' to make this a multi-use spawner.
"NoTfog" 	supress teleport glitter when spawned with 'triggered'
"NoTelefrag" will silently fail to spawn if doing so would telefrag an existing monster. will try again automatically 2x/second until it succeeds.
"Instawake" spawn angry at activator

Keys:
"target" entity to trigger when killed
"targetname" entity name
*/
/*FGD
@PointClass base(Monster) size(-16 -16 -24, 16 16 40) model({ "path": ":progs/wizard.mdl" }) = monster_wizard : "Scrag" []
*/
void() monster_wizard =
{
	if (!SUB_ShouldSpawn()) return;
	if (nomonster()) return;
	if (deathmatch)
	{
		remove(self);
		return;
	}
	precache_model ("progs/wizard.mdl");
	precache_model ("progs/h_wizard.mdl");
	precache_model ("progs/w_spike.mdl");
	precache_model ("progs/w_spike2.mdl");

	precache_sound ("wizard/hit.wav");		// used by c code
	precache_sound ("wizard/wattack.wav");
	precache_sound ("wizard/wdeath.wav");
	precache_sound ("wizard/widle1.wav");
	precache_sound ("wizard/widle2.wav");
	precache_sound ("wizard/wpain.wav");
	precache_sound ("wizard/wsight.wav");

	self.health = 80;
	//setsize (self, '-16 -16 -24', '16 16 40');
	setsize (self, VEC_HULL_MIN, VEC_HULL_MAX);
	if ( monster_spawnsetup( monster_wizard_spawner ) ) return;
	
	addmonster(1);
	monster_wizard_spawn();
}







/*
=============
LaunchMissile

Sets the given entities velocity and angles so that it will hit self.enemy
if self.enemy maintains it's current velocity
0.1 is moderately accurate, 0.0 is totally accurate
=============
*/
/*
void(entity missile, float mspeed, float accuracy) LaunchMissile =
{
	local	vector	vec, move;
	local	float	fly;

	makevectors (self.angles);
		
// set missile speed
	vec = self.enemy.origin + self.enemy.mins + self.enemy.size * 0.7 - missile.origin;

// calc aproximate time for missile to reach vec
	fly = vlen (vec) / mspeed;
	
// get the entities xy velocity
	move = self.enemy.velocity;
	move_z = 0;

// project the target forward in time
	vec = vec + move * fly;
	
	vec = normalize(vec);
	vec = vec + accuracy*v_up*(random()- 0.5) + accuracy*v_right*(random()- 0.5);
	
	missile.velocity = vec * mspeed;

	missile.angles = '0 0 0';
	missile.angles_y = vectoyaw(missile.velocity);

// set missile duration
	missile.nextthink = time + 5;
	missile.think = SUB_Remove;	
}

*/

