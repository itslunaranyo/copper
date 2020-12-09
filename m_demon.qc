/*
==============================================================================

DEMON

==============================================================================
*/

$cd id1/models/demon3
$scale	0.8
$origin 0 0 24
$base base
$skin base

$frame stand1 stand2 stand3 stand4 stand5 stand6 stand7 stand8 stand9
$frame stand10 stand11 stand12 stand13

$frame walk1 walk2 walk3 walk4 walk5 walk6 walk7 walk8

$frame run1 run2 run3 run4 run5 run6

$frame leap1 leap2 leap3 leap4 leap5 leap6 leap7 leap8 leap9 leap10
$frame leap11 leap12

$frame pain1 pain2 pain3 pain4 pain5 pain6

$frame death1 death2 death3 death4 death5 death6 death7 death8 death9

$frame attacka1 attacka2 attacka3 attacka4 attacka5 attacka6 attacka7 attacka8
$frame attacka9 attacka10 attacka11 attacka12 attacka13 attacka14 attacka15

//============================================================================

// len = 650, ang = 25
float DEMON_LEAP_HVEL = 600;
float DEMON_LEAP_VVEL = 250;
float DEMON_LEAP_VEL = 650;
float DEMON_BLOCKED_HEAD = -1;
float DEMON_BLOCKED_TOE = -2;

void()	demon1_stand1	=[	$stand1,	demon1_stand2	] {ai_stand();}
void()	demon1_stand2	=[	$stand2,	demon1_stand3	] {ai_stand();}
void()	demon1_stand3	=[	$stand3,	demon1_stand4	] {ai_stand();}
void()	demon1_stand4	=[	$stand4,	demon1_stand5	] {ai_stand();}
void()	demon1_stand5	=[	$stand5,	demon1_stand6	] {ai_stand();}
void()	demon1_stand6	=[	$stand6,	demon1_stand7	] {ai_stand();}
void()	demon1_stand7	=[	$stand7,	demon1_stand8	] {ai_stand();}
void()	demon1_stand8	=[	$stand8,	demon1_stand9	] {ai_stand();}
void()	demon1_stand9	=[	$stand9,	demon1_stand10	] {ai_stand();}
void()	demon1_stand10	=[	$stand10,	demon1_stand11	] {ai_stand();}
void()	demon1_stand11	=[	$stand11,	demon1_stand12	] {ai_stand();}
void()	demon1_stand12	=[	$stand12,	demon1_stand13	] {ai_stand();}
void()	demon1_stand13	=[	$stand13,	demon1_stand1	] {ai_stand();}

void()	demon1_walk1	=[	$walk1,		demon1_walk2	] {
if (random() < 0.2)
    sound (self, CHAN_VOICE, "demon/idle1.wav", 1, ATTN_IDLE);
ai_walk(8);
}
void()	demon1_walk2	=[	$walk2,		demon1_walk3	] {ai_walk(6);}
void()	demon1_walk3	=[	$walk3,		demon1_walk4	] {ai_walk(6);}
void()	demon1_walk4	=[	$walk4,		demon1_walk5	] {ai_walk(7);}
void()	demon1_walk5	=[	$walk5,		demon1_walk6	] {ai_walk(4);}
void()	demon1_walk6	=[	$walk6,		demon1_walk7	] {ai_walk(6);}
void()	demon1_walk7	=[	$walk7,		demon1_walk8	] {ai_walk(10);}
void()	demon1_walk8	=[	$walk8,		demon1_walk1	] {ai_walk(10);}

// ai_run already concluded we can't leap, but make sure we can't just run up some stairs
float() DemonCheckCharge =
{
	// check for mad charge
	if (!enemy_vis)
		return FALSE;
	if (time < self.attack_finished)
		return FALSE;
		
	vector edir = self.origin - self.enemy.origin;
	if ( fabs(edir_z) > vlen(edir) / 2)
		return FALSE;		// too much height change
	
	if ( range(self.enemy) == RANGE_MELEE )
		return FALSE;		// defer to regular attack

	// charge		
	ai_attack_finished (0.5);
	demon1_charge1 ();
	return TRUE;
}

void()	demon1_run1	=[	$run1,		demon1_run2	] {ai_run(20);
	DemonCheckCharge();
}
void()	demon1_run2	=[	$run2,		demon1_run3	] {ai_run(15);}
void()	demon1_run3	=[	$run3,		demon1_run4	] {ai_run(36);}
void()	demon1_run4	=[	$run4,		demon1_run5	] {ai_run(20);}
void()	demon1_run5	=[	$run5,		demon1_run6	] {ai_run(15);}
void()	demon1_run6	=[	$run6,		demon1_run1	] {ai_run(36);
	if (random() < 0.2 && time > self.show_hostile)
		sound (self, CHAN_VOICE, "demon/idle1.wav", 1, ATTN_IDLE);
}

void()	demon1_charge1	=[	$run1,		demon1_charge2	] {ai_rush(20);DemonCheckAttack();}
void()	demon1_charge2	=[	$run2,		demon1_charge3	] {ai_rush(15);DemonCheckAttack();}
void()	demon1_charge3	=[	$run3,		demon1_charge4	] {ai_rush(36);DemonCheckAttack();}
void()	demon1_charge4	=[	$run4,		demon1_charge5	] {ai_rush(20);DemonCheckAttack();}
void()	demon1_charge5	=[	$run5,		demon1_charge6	] {ai_rush(15);DemonCheckAttack();}
void()	demon1_charge6	=[	$run6,		demon1_run1	] {ai_rush(36);DemonCheckAttack();}


void()	demon1_pain1	=[	$pain1,		demon1_pain2	] {}
void()	demon1_pain2	=[	$pain2,		demon1_pain3	] {}
void()	demon1_pain3	=[	$pain3,		demon1_pain4	] {}
void()	demon1_pain4	=[	$pain4,		demon1_pain5	] {}
void()	demon1_pain5	=[	$pain5,		demon1_pain6	] {}
void()	demon1_pain6	=[	$pain6,		demon1_run1	] {}

void(entity attacker, float damage)	demon1_pain =
{
	if (self.touch == Demon_JumpTouch)
	{
		return;
	}

	if (self.pain_finished > time)
		return;

	if (random()*200 > damage)
		return;		// didn't flinch
		
	PainFinished(1);
    sound (self, CHAN_VOICE, "demon/dpain1.wav", 1, ATTN_NORM);
	demon1_pain1 ();
}

void()	demon1_die1		=[	$death1,		demon1_die2	] {
sound (self, CHAN_VOICE, "demon/ddeath.wav", 1, ATTN_NORM);}
void()	demon1_die2		=[	$death2,		demon1_die3	] {}
void()	demon1_die3		=[	$death3,		demon1_die4	] {}
void()	demon1_die4		=[	$death4,		demon1_die5	] {self.solid = SOLID_NOT;}
void()	demon1_die5		=[	$death5,		demon1_die6	] {}
void()	demon1_die6		=[	$death6,		demon1_die7	] {}
void()	demon1_die7		=[	$death7,		demon1_die8	] {}
void()	demon1_die8		=[	$death8,		demon1_die9	] {}
void()	demon1_die9		=[	$death9,		demon1_die9 ] {}

void() demon_die =
{
	if (self.health < -80)
	{
		Gib ("progs/h_demon.mdl", self.health);
		return;
	}
	demon1_die1 ();
}


//============================================================================

void()	demon1_jumpabort =[ 	$leap10,	demon1_jump11	] {}

void()	demon1_jump1	=[	$leap1,		demon1_jump2	]
{
	ai_face();
	ai_attack_finished(1);	// from now until the airthink loop
	if (!self.height) {
		// something's effed in the jump decisionmaking
		demon1_run1();
		return;
	}
	sound (self, CHAN_VOICE, "demon/djump.wav", 1, ATTN_NORM);
	//bprint("  djump\n");
}
void()	demon1_jump2	=[	$leap2,		demon1_jump3	] {ai_face();}
void()	demon1_jump3	=[	$leap3,		demon1_jump4	] {ai_face();}
void()	demon1_jump4	=[	$leap4,		demon1_jump5	]
{
	ai_face();
	Demon_Jump();
}
void()	demon1_jump5	=[	$leap5,		demon1_jump6	] {}
void()	demon1_jump6	=[	$leap6,		demon1_jump7	] {}
void()	demon1_jump7	=[	$leap7,		demon1_jump8	] {}
void()	demon1_jump8	=[ 	$leap8,		demon1_jump9	] {}
void()	demon1_jump9	=[ 	$leap9,		demon1_jump10	] {}
void()	demon1_jump10	=[ 	$leap10,	demon1_airthink	] { 
	self.oldorigin = self.origin;
	self.lifetime_finished = time + 3;
}
void()	demon1_jump11	=[ 	$leap11,	demon1_jump12	] {}
void()	demon1_jump12	=[ 	$leap12,	demon1_run1	] {ai_face();}


void() demon1_airthink =
{
	self.think = demon1_airthink;
	self.nextthink = time + 0.1;
	
	// if three seconds pass, assume demon is stuck and jump again
	if (time >= self.lifetime_finished)
	{
		demon1_jump1();
		return;
	}
	// we aren't moving, assume leap is over so we don't get stuck with our arms up
	if (self.origin == self.oldorigin && self.flags & FL_ONGROUND)
	{
		demon1_jump11();
		return;
	}
	self.oldorigin = self.origin;
}

void()	Demon_JumpTouchGround =
{
	// FL_ONGROUND: in contact with a horizontal surface (cos < 0.7) in any way, always set by SV_Phys after impact
	// if we're not touching anything horizontal it's not the ground so we don't care
	if (!(self.flags & FL_ONGROUND)) return;
	
	self.touch = SUB_Null;
	
	// checkbottom: false if any corners are more than a step's height above the surface beneath
	if (checkbottom(self))		// safely on ground
	{
		// we didn't even complete the leap animation, meaning we hit world right away
		if (time < self.attack_finished)
		{
			ai_attack_finished(1);	// so don't keep doing it
		}
		demon1_jump11();
		return;
	}
	
	// jump randomly to not get hung up
	self.think = demon1_jump1;
	self.nextthink = time + 0.1;
}

void()	Demon_JumpTouch =
{
	local	float	ldmg;

	if (self.health <= 0)
		return;
		
	if (other.takedamage)
	{
		if ( vlen(self.velocity) > 300 )
		{
			if (other.classname != "player" || time > self.touch_time)	// fix for landing on the player's head
			{
				if (other.classname == "player")
				{
					self.touch_time = time + 0.2;
				}
				ldmg = 40 + 10 * random();
				T_Damage(other, self, self, ldmg);	// fiend leap counts as a ranged attack
				ai_attack_finished(0);	// free to keep going ham
			}
		}
	}

	Demon_JumpTouchGround();
}


void() Demon_Jump =
{
	vector leap;
	//self.origin_z += 1;
	if (!self.speed) self.speed = DEMON_LEAP_VEL;
	makevectors (self.angles);
	//bprint3("leaping at ", ftos(self.height), "\n");
	leap = SinCos(self.height);
	self.velocity = v_forward * leap_y;
	self.velocity_z = leap_x;
	self.velocity *= self.speed;
	self.touch = Demon_JumpTouch;
	self.flags = not(self.flags, FL_ONGROUND);
	self.height = 0;
}

//===========================================================================


/*
==============
Demon_JumpSweep

do a bunch of traces along the jump vector to ensure the takeoff path is clear, 
so we don't deflect off doorways and stairs and bounce around like an idiot
==============
*/
float(vector attack, float ang) Demon_JumpSweep =
{
	vector corner, wmins, dir, arc, hullsize;
	float headfails, stepfails;
	float sweepdist = 160;
	
	//bprint3("  sweep-checking ", ftos(ang), " degrees:\n");
	
	arc = SinCos(ang - 1);	// vert, horz
	dir = attack * arc_y;
	dir_z = arc_x;
	dir *= sweepdist;

	// early out check first from origin
	traceline(self.origin, self.origin+dir, TRUE, self);
	if (trace_fraction < 1)
		return FALSE;
	
	float x, y, z;
	wmins = self.origin + self.mins + '0 0 0.1';	// just off the ground
	hullsize = VEC_HULL2_MAX - VEC_HULL2_MIN;
	for (x=0; x<=1; x+=1) for (y=0; y<=1; y+=1) for (z=0; z<=1; z+=1)
	{
		// don't test the back corners
		//if (fabs(attack_x) > fabs(attack_y) && (attack_x > 0) != x) continue;
		//if (fabs(attack_y) > fabs(attack_x) && (attack_y > 0) != y) continue;
	
		// treat the bounding box as shambler height because the engine physics will
		corner = wmins + vec_scale(hullsize, Vector(x, y, z));
		traceline(corner, corner+dir, TRUE, self);
		//bprint5("   - sweeping from ", vtos(corner), " to ", vtos(corner+dir), "\n");
		if (trace_fraction < 1 || trace_startsolid || trace_allsolid )
		{
			//bprint5("   - HIT at ", vtos(trace_endpos), " frac ", ftos(trace_fraction), "\n");
			//if (fabs(trace_plane_normal * normalize(dir)) < 0.2)	// player and fiend are both along a wall
			//	continue;
			if (z) headfails++;
			else stepfails++;
			//bprint5(vtos(self.origin), ": ", vtos(corner), " + ", vtos(dir));
			//bprint("\n");
		}
	}
	//bprint5("  headfails: ", ftos(headfails), " stepfails: ", ftos(stepfails), "\n");
	// both = blocked by something vertical like a pillar, or otherwise hopelessly blocked
	if (headfails && stepfails) return FALSE;
	
	if (headfails) return DEMON_BLOCKED_HEAD;	// ceiling too low, should try to aim lower
	if (stepfails) return DEMON_BLOCKED_TOE;	// bottom blocked by a step or ledge, aim higher
	
	// head and toe both clear geo
	return TRUE;
}


float(vector attack) CheckDemonJumpClearance =
{
	//vector dir;
	float try, last;
	attack_z = 0;
	attack = normalize(attack);

	//bprint("checking clearance:\n");
	//self.speed = DEMON_LEAP_VEL;
	try = Demon_JumpSweep(attack, self.height);
	last = try;
	while (try < 0 && try == last)
	{
		if (try == DEMON_BLOCKED_HEAD && self.height >= 15)
		{
			//bprint("  - head blocked\n");
			self.speed += 25;
			self.height -= 10;
			try = Demon_JumpSweep(attack, self.height);
		}
		else if (try == DEMON_BLOCKED_TOE && self.height <= 35)
		{
			//bprint("  - foot blocked\n");
			self.height += 10;
			self.speed -= 25;
			try = Demon_JumpSweep(attack, self.height);
		}
		else break;
	}

	if (try > 0)
	{
		//bprint3(" - cleared to leap at ", ftos(self.height), " degrees\n");
		//self.height = ang;
		return TRUE;
	}
	self.height = 0;
	return FALSE;
}


/*
==============
CheckDemonJump
==============
*/
float()	CheckDemonJump =
{
	vector	org, dir, tgt, angles;
	float	d, ang;

	if (!(self.flags & FL_ONGROUND))
		return FALSE;
	
	dir = self.enemy.origin - self.origin;
	dir_z = max(0, dir_z * 2);
	d = vlen(dir);
	if (d < 120) {//bprint("too close\n");
	return FALSE;}
	if (d > 360 && random() < 0.9) {//bprint("too far-ish\n");
	return FALSE;}
	//if (d > DEMON_LEAP_HVEL) {//bprint("too far\n");
	//return FALSE;}
	
	org = self.origin;
	tgt = self.enemy.origin;
	if (!(self.enemy.flags & (FL_ONGROUND|FL_FLY)))
	{
		// wait if enemy is leaping through the air, or we'll make one of those high
		// arcs that looks OP and stupid
		if (self.enemy.velocity_z > 0) return FALSE;
		traceline(tgt,tgt-'0 0 96',TRUE,self.enemy);
		if (trace_fraction == 1.0) return FALSE;
		tgt = (tgt + trace_endpos) * 0.5;
	}
	
	if (self.enemy.origin_z < self.origin_z - 16)
	{
		// make sure our head can see their feet
		org_z += self.maxs_z;
		tgt_z += self.enemy.mins_z;
	}
	else if (self.enemy.origin_z > self.origin_z + 16)
	{
		// make sure our feet can see their head
		org_z += self.mins_z;
		tgt_z += self.enemy.maxs_z;
	}
	traceline(org,tgt,TRUE,self);
	if (trace_fraction != 1.0){//bprint("not clear\n");
	return FALSE;}	
	
	org = self.origin;
	d = hdist(tgt,org);
	// old demon aimed at a point 25 degrees up, so skew that triangle such that
	// we aim at a point the same height above the target's head
	tgt_z += DEMON_LEAP_VVEL * (d / DEMON_LEAP_HVEL);
	
	dir = normalize(tgt - org);	
	angles = vectoangles(dir);
	ang = angles_x;
	if (ang > 90) ang -= 360;
	
	if (ang > 45 || ang < -5 ){ //bprint("too steep\n");
	return FALSE;}
	
	self.speed = DEMON_LEAP_VEL;
	if (ang < 8)
	{
		self.speed -= (8-ang) * 15;	// super rough
		ang = 16 - ang;
	}
	self.height = ang;
	//bprint3("leap decided: ", ftos(ang)," degrees\n");
	return CheckDemonJumpClearance(dir);
}


//===========================================================================

void()	demon1_atta1	=[	$attacka1,		demon1_atta2	] {ai_charge(4);}
void()	demon1_atta2	=[	$attacka2,		demon1_atta3	] {ai_charge(0);}
void()	demon1_atta3	=[	$attacka3,		demon1_atta4	] {ai_charge(0);}
void()	demon1_atta4	=[	$attacka4,		demon1_atta5	] {ai_charge(1);}
void()	demon1_atta5	=[	$attacka5,		demon1_atta6	] {ai_charge(2); Demon_Melee(200);}
void()	demon1_atta6	=[	$attacka6,		demon1_atta7	] {ai_charge(1);}
void()	demon1_atta7	=[	$attacka7,		demon1_atta8	] {ai_charge(6);}
void()	demon1_atta8	=[	$attacka8,		demon1_atta9	] {ai_charge(8);}
void()	demon1_atta9	=[	$attacka9,		demon1_atta10] {ai_charge(4);}
void()	demon1_atta10	=[	$attacka10,		demon1_atta11] {ai_charge(2);}
void()	demon1_atta11	=[	$attacka11,		demon1_atta12] {Demon_Melee(-200);}
void()	demon1_atta12	=[	$attacka12,		demon1_atta13] {ai_charge(5);}
void()	demon1_atta13	=[	$attacka13,		demon1_atta14] {ai_charge(8);}
void()	demon1_atta14	=[	$attacka14,		demon1_atta15] {ai_charge(4);}
void()	demon1_atta15	=[	$attacka15,		demon1_run1]
{
	ai_charge(4);
	enemy_range = range(self.enemy);
	if (CheckDemonMelee()) self.think = demon1_atta1;	// skip the one flash of run1, it makes the feet jump
}

/*
==============
CheckDemonMelee

Returns TRUE if a melee attack would hit right now
==============
*/
float()	CheckDemonMelee =
{
	if ( !enemy_alive()	||						// is dead
		enemy_range > RANGE_MELEE ||			// can't reach
		!z_overlap(self.enemy) ||				// too high or low
		!CanDamage(self.enemy, self.origin) ) 	// can't hit
		return FALSE;
	return TRUE;
}

void(float side)	Demon_Melee =
{
	local	float	ldmg;
	local vector	delta;
	
	ai_face ();
	walkmove (self.ideal_yaw, 12);	// allow a little closing

	delta = self.enemy.origin - self.origin;

	if (vlen(delta) > 100)
		return;
	if (!CanDamage (self.enemy, self.origin))
		return;
		
    sound (self, CHAN_WEAPON, "demon/dhit2.wav", 1, ATTN_NORM);
	ldmg = 10 + 5*random();
	T_DamageMelee (self.enemy, self, ldmg);	

	makevectors (self.angles);
	SpawnMeatSpray (self.origin + v_forward*16, side * v_right);
}

//===========================================================================

float()	DemonCheckAttack =
{
	if (time < self.attack_finished) return FALSE;

	if (!CheckClearAttack())
		return FALSE;
	
	// if close enough for slashing, go for it
	if (CheckDemonMelee())
	{
		self.attack_state = AS_MELEE;
		return TRUE;
	}
	
	if (CheckDemonJump())
	{
		self.attack_state = AS_MISSILE;
		return TRUE;
	}
	
	// keep the stored jump decisions cleared
	self.speed = DEMON_LEAP_VEL;
	self.height = 0;
	return FALSE;
}




void() monster_demon_spawn =
{
	self.classname = "monster_demon1";
		
	self.solid = SOLID_SLIDEBOX;
	//self.movetype = MOVETYPE_STEP;

	setmodel (self, "progs/demon.mdl");

	//setsize (self, VEC_HULL2_MIN, VEC_HULL2_MAX);
	setsize (self, VEC_HULL2_MIN, '32 32 40');
	self.health = 300;
	
	self.yaw_speed = 30;
	self.customflags |= CFL_MELEEONLY;

	self.th_stand = demon1_stand1;
	self.th_walk = demon1_walk1;
	self.th_run = demon1_run1;
	self.th_die = demon_die;
	self.th_melee = demon1_atta1;
	self.th_missile = demon1_jump1;
	self.th_pain = demon1_pain;
	self.th_checkattack = DemonCheckAttack;
	
	if (self.deathtype == string_null)
		self.deathtype = "was eviscerated by a Fiend";

	walkmonster_start();
}

void() monster_demon_spawner = {mon_spawner_use(monster_demon_spawn);}

/*QUAKED monster_demon1 (1 0 0) (-32 -32 -24) (32 32 40) AMBUSH ? ? ? TRIGGERED NOTFOG NOTELEFRAG INSTAWAKE
Fiend (Demon), 300 health points.

Flags:
"ambush"	only wake up on seeing the player, not another monster getting angry
"Triggered"	will not spawn until triggered - triggering again will wake him up. Set 'count' to make this a multi-use spawner.
"NoTfog" 	supress teleport glitter when spawned with 'triggered'
"NoTelefrag" will silently fail to spawn if doing so would telefrag an existing monster. will try again automatically 2x/second until it succeeds.
"Instawake" spawn angry at activator

Keys:
"target" entity to trigger when killed
"targetname" entity name
"movedir" set to a velocity to make the monster jump on awakening
*/
/*FGD
@PointClass base(Monster) size(-32 -32 -24, 32 32 64) model({ "path": ":progs/demon.mdl" }) = monster_demon1 : "Fiend" []
*/
void() monster_demon1 =
{
	if (!SUB_ShouldSpawn()) return;
	if (nomonster()) return;
	if (deathmatch)
	{
		remove(self);
		return;
	}
	precache_model ("progs/demon.mdl");
	precache_model ("progs/h_demon.mdl");

	precache_sound ("demon/ddeath.wav");
	precache_sound ("demon/dhit2.wav");
	precache_sound ("demon/djump.wav");
	precache_sound ("demon/dpain1.wav");
	precache_sound ("demon/idle1.wav");
	precache_sound ("demon/sight2.wav");
	precache_sound ("misc/null.wav");

	self.health = 300;
	setsize (self, VEC_HULL2_MIN, '32 32 40');
	if ( monster_spawnsetup( monster_demon_spawner ) ) return;
	
	addmonster(1);
	monster_demon_spawn();
}
