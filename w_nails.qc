/*
================
spawn_touchblood

only used by nailguns so now it's here
================
*/
void(float damage) spawn_touchblood =
{
	local vector	vel;

	vel = normalize(self.velocity) * -1;
	vel = normalize(vel + v_up*(random()- 0.5) + v_right*(random()- 0.5));
	
	//vel = vel + 2*trace_plane_normal;
	// nailguns don't do traces so there is no valid trace plane normal
	// (which explains why nailgun blood spurts always seemed to be caught in some strange wind)
	
	SpawnBlood (self.origin + vel, vel * 40, damage);
}



// --------------------------------

vector(vector muzzle) W_SpikeOrigin =
{
	return (self.origin + '0 0 16' + 
			11 * v_forward +
			muzzle_x * v_right +
			muzzle_z * v_up);
}

vector(vector fwd, float spread) W_SpikeDir =
{
	return normalize(fwd + (2 * v_right * crandom() + v_up * crandom()) * spread / 100);
}

void() W_FireNailgun =
{
	vector m, v, org, dir;
	// remember sv_aim
	v = vectoangles( aim( self, AUTOAIM_DIST ) );
	v_x *= -1;	// pitch comes back inverted from vectoangles :|
	makevectors( v );

	sound (self, CHAN_WEAPON, "weapons/rocket1i.wav", 1, ATTN_NORM);
	self.currentammo = self.ammo_nails = self.ammo_nails - 1;
	m = VEC_ORIGIN;
	if ( mod( self.cnt, 2 ) ) m_x = -2.5;
	else m_x = 2.5;	

	org = W_SpikeOrigin(m);
	dir = W_SpikeDir(v_forward, 0);

	// default sv_maxvelocity is 2000, any higher leads to weird 
	// angular offsets caused by clamping the velocity
	launch_nail(org, dir * 1996);
	self.attack_finished = time + 0.095;
}

void() spike_unfatten = { self.movetype = MOVETYPE_FLY; }

void() W_FirePerforator =
{
	vector m;
	sound (self, CHAN_WEAPON, "weapons/spike2.wav", 1, ATTN_NORM);
	self.currentammo = self.ammo_nails = self.ammo_nails - 2;
	
	if (mod(self.cnt, 4) == 0) m = '0 0 1.25';
	else if (mod(self.cnt, 4) == 1) m = '1 0 1';
	else if (mod(self.cnt, 4) == 2) m = '1.25 0 0';
	else if (mod(self.cnt, 4) == 3) m = '1 0 -1';
	
	entity spike1, spike2;
	spike1 = launch_nail(W_SpikeOrigin(m), W_SpikeDir(v_forward, 2) * (940 + random()*30));
	spike2 = launch_nail(W_SpikeOrigin(-m), W_SpikeDir(v_forward, 2) * (1020 + random()*30));

	// weaken the SNG at long distance while keeping the spread under control
	spike1.think = spike_unfatten;
	spike2.think = spike_unfatten;
	spike1.nextthink = time + 0.25;
	spike2.nextthink = time + 0.3;
	
	self.attack_finished = time + 0.095;
	
	if (has_quad(self))
	{
		// here's a silly thing:
		// one vanilla SNG nail does 18 dmg, 72 with quad, enough to gib zombies and grunts.
		// two copper nails do 9 each, 36 each with quad, for the same total damage, but that
		//   only kills grunts and knocks zombies down because the second nail doesn't hit.
		
		// the dumb solution is to make one nail do 0 dmg and the other do 18 in quad mode
		//   so the math works out like the old math and the quad SNG still feels right
		spike2.dmg = 18;
		spike1.dmg = 18;
		spike2.buddy = spike1;
		spike1.buddy = spike2;
		// first one to hit does its damage and then nerfs its 'buddy'
	}
}

void() W_FireSpikes =
{
	if (self.ammo_nails < 1 || (self.ammo_nails < 2 && !(self.items & IT_NAILGUN)))
	{
		W_SelectBestWeapon();
		return;
	}
	if (self.ammo_nails >= 2 && self.weapon == IT_SUPER_NAILGUN)
	{
		W_FirePerforator();
	}
	else
	{
		W_FireNailgun();
	}
	self.punchangle_x = -2;
	
	self.cnt = cycle(self.cnt,8);
}

float() CheckValidSpikeTouch =
{
	if (other == self.owner) return FALSE;
	if (other.solid == SOLID_TRIGGER) return FALSE;
	if (CheckProjectilePassthru()) return FALSE;

	if (pointcontents(self.origin) == CONTENT_SKY)
	{
		remove(self);
		return FALSE;
	}
	
	return TRUE;
}


void() spike_touch =
{
	if (!CheckValidSpikeTouch()) return;
	
	if (self.dmg)
	{
		if (other.takedamage)
		{
			spawn_touchblood (self.dmg);
			T_Damage (other, self, self.trueowner, self.dmg);
		}
		else
		{
			WriteByte (MSG_BROADCAST, SVC_TEMPENTITY);
			
			switch(self.classname)
			{
			case "wizspike":
				WriteByte (MSG_BROADCAST, TE_WIZSPIKE); break;
			case "knightspike":
				WriteByte (MSG_BROADCAST, TE_KNIGHTSPIKE); break;
			case "laser":
				WriteByte(MSG_BROADCAST, TE_GUNSHOT); break;
			default:
				WriteByte (MSG_BROADCAST, TE_SPIKE);
			}
			WriteCoord (MSG_BROADCAST, self.origin_x);
			WriteCoord (MSG_BROADCAST, self.origin_y);
			WriteCoord (MSG_BROADCAST, self.origin_z);
		}
		
		if (self.classname == "laser")
		{
			sound (self, CHAN_WEAPON, "enforcer/enfstop.wav", 1, ATTN_STATIC);
			particle (self.origin, self.velocity*-0.01, 235, 15);
		}
	}
	// nonsense for combining quad SNG spike damage
	if (self.buddy)
		self.buddy.dmg = 0;
	remove(self);
}


