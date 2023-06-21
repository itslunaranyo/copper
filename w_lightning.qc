
/*
===============

LIGHTNING

===============
*/


/*
=================
Chain Lightning

damage repeats outward from the target to more behind them, halving damage each time

search around a little left or right behind the target so the lightning can appear 
to arc, so it isn't just a high speed railgun
=================
*/
void(vector start, entity from, float dmg) W_ChainLightning =
{
	entity head, targ;
	float len, dist, dot, zpc;
	vector dir, h_org;
	dir = normalize(start - self.origin);	// self still attacker (player)

	head = findradius(start + dir * 120, 100);
	
	targ = from;
	len = A_SHITLOAD;

	// find another enemy who hasn't been zapped yet
	while (head)
	{
		if (head != from && 
			head.takedamage && 
			!(head.customflags & CFL_ZAPPED) && 
			(head.movetype >= MOVETYPE_WALK && head.movetype <= MOVETYPE_FLY))
		{
			h_org = BoundsCenter(head);
			traceline2(start, h_org, from, 0);
			if (trace_ent == head)
			{	
				// rank by distance
				dist = vlen(h_org - start);
				// only jump to monsters within a narrow cone, so the player still has to
				// reposition smartly to get lightning to link downrange
				dot = normalize(h_org - start) * dir;
				if (dist <= len)
				{
					zpc = pointcontents(from.origin);
					if ( dot > 0.825 || 
						(dist < 72 && dot > 0.725) ||
						// extra-wide zappy cone for anyone underwater
						(dot > 0.25 && (zpc == CONTENT_WATER || zpc == CONTENT_SLIME) && pointcontents(head.origin) == zpc ) )
					{
						targ = head;
						len = dist;
					}
				}
			}
		}
		head = head.chain;
	}
	
	if (targ != from)
	{
		LightningBeam(start, targ.origin, from, dmg);
	}
}



/*
=================
LightningBeam
=================
*/
void(vector start, vector limit, entity from, float damage) LightningBeam =
{
	// from is the originator of the beam - this is the shot monster when chaining
	// self always remains the actual attacker
	vector left, end;
	entity targ;
	// fix for wonky 'three beams' bug:
	left = limit - start;
	left = Vector(0 - left_y, left_x, 0);
	if (left) {
		left = normalize(left) * 12;
	} else {
		// if beam is straight up or down, take the orientation from the source entity
		makevectors(from.angles);
		left = v_right * -12;
	}

	traceline2(start, limit, from, 0);
	end = trace_endpos;
	if (trace_ent.takedamage && !(trace_ent.customflags & CFL_ZAPPED))
	{
		targ = trace_ent;
		targ.customflags |= CFL_ZAPPED;

		// don't chain from doors, buttons, or special wonky shootable triggers
		if ((targ.solid == SOLID_BBOX || targ.solid == SOLID_SLIDEBOX) && 
			targ.movetype && targ.movetype != MOVETYPE_PUSH)
		{
			end = trace_endpos;
			
			if (self.classname == "player")
			{
				// have the arc pull into the target a little
				if (targ.maxs_x <= 32)	// not for cthon/etc, he's too big
					end = (trace_endpos + targ.origin) * 0.5;
				if (targ.classname == "player")
					targ.velocity_z = targ.velocity_z + 400;
				
				if (damage > 4)
					W_ChainLightning(end, targ, ceil(damage / 3 + 2)); // 30 12 6 4
			}
		}
		// we go through multidamage here because T_Damage clears ZAPPED and we
		// need to preserve that flag until we're done so we don't double damage
		AddMultiDamage (targ, damage);
		// clear and apply multidamage must be called in an enclosing function!
		particle (end, '0 0 100', 225, damage*4);
	}
	
	// we do the lightning beam after the chain lightning recursion as the stack unwinds,
	// so that the closest beam gets sent last. this way, if quake runs out of beams 
	// in a big LG vs shambler showdown, we're likely to only overwrite the furthest 
	// and least noticeable beams
	if (self.classname == "monster_shambler")
	{
		WriteByte (MSG_BROADCAST, SVC_TEMPENTITY);
		WriteByte (MSG_BROADCAST, TE_LIGHTNING1);
	}
	else
	{
		sound (targ, CHAN_BODY, "weapons/lhit.wav", 1, ATTN_NORM);
		WriteByte (MSG_BROADCAST, SVC_TEMPENTITY);
		WriteByte (MSG_BROADCAST, TE_LIGHTNING2);
	}
	// quake immediately reuses beams that come from the same entity, so the
	// entity the lightning jumped from has to own the next leg of lightning
	// or else they auto-overwrite and only the final (nearest) one appears
	WriteEntity (MSG_BROADCAST, from);
	WriteCoord (MSG_BROADCAST, start_x);
	WriteCoord (MSG_BROADCAST, start_y);
	WriteCoord (MSG_BROADCAST, start_z);
	WriteCoord (MSG_BROADCAST, end_x);
	WriteCoord (MSG_BROADCAST, end_y);
	WriteCoord (MSG_BROADCAST, end_z);


	damage *= 0.3;	// tone down the side prongs or the LG is a total scythe vs crowds
	traceline2(start + left, end + left, from, 0);
	if (trace_ent.takedamage && !(trace_ent.customflags & CFL_ZAPPED))	// don't add damage to any target twice
	{
		trace_ent.customflags |= CFL_ZAPPED;
		particle (trace_endpos, '0 0 100', 225, damage*4);
		AddMultiDamage (trace_ent, damage);
	}

	traceline2(start - left, end - left, from, 0);
	if (trace_ent.takedamage && !(trace_ent.customflags & CFL_ZAPPED))
	{
		trace_ent.customflags |= CFL_ZAPPED;
		particle (trace_endpos, '0 0 100', 225, damage*4);
		AddMultiDamage (trace_ent, damage);
	}
}



/*
float LG_DMG_OUT = 10;
float LG_DMG_IN = 2;

float(entity src, entity att, float dmg) W_ChainLightning =
{
	vector org, dir, dst, h_org;
	entity head, targ1, targ2;
	float dist, dot, len1, len2, dmgback;
	vector hit1, hit2;
	
	dmgback = dmg;
	src.customflags |= CFL_ZAPPED;
	
	// stop at three iterations (potentially 7 targets). more than that looks bad as quake 
	// runs out of lightning t_entities at 24 beam segments (32 in fitzquakes)
	if (dmg > 32 - LG_DMG_OUT * 2)
	{
		// look mostly behind the target, so the lightning spreads
		// predominantly in the direction the gun is being fired
		dir = normalize(src.origin - att.origin);
		dir_z = 0;
		// zero z after normalizing so if the player is firing down from above, the 
		// lightning will spread in every direction
		org = BoundsCenter(src);
		head = findradius(org + dir * 64, 180);
		
		targ1 = targ2 = src;
		len1 = len2 = A_SHITLOAD;
		
		// find two enemies who haven't been zapped yet
		while (head)
		{
			if (head != att && 
				head.takedamage && 
				!(coop && head.classname == att.classname) && // prooobably not fair to unavoidably electrocute your friends
				!(head.customflags & CFL_ZAPPED) && 
				(head.movetype >= MOVETYPE_WALK && head.movetype <= MOVETYPE_FLY))
			{
				h_org = BoundsCenter(head);
				traceline2(org, h_org, src, 0);
				if (trace_ent == head)
				{	
					// rank by distance
					dist = vlen(org - h_org);
					
					// bias toward monsters behind and to either side of the target, so lightning
					// visibly spreads like the end of raiders of the lost ark
					dot = normalize(org - h_org) * dir;
					if (dot > 0.7)
						dot = 1.4 - dot;	// not directly behind if we an help it, can't see it
					dist *= dot + 1;
					
					if (dist <= len1)
					{
						targ2 = targ1;
						len2 = len1;
						hit2 = hit1;
						targ1 = head;
						len1 = dist;
						hit1 = trace_endpos;
					}
					else if (dist <= len2)
					{
						targ2 = head;
						len2 = dist;
						hit2 = trace_endpos;
					} 
				}
			}
			head = head.chain;
		}
		
		if (targ1 != src) {
			dst = BoundsCenter(targ1);
			
			WriteByte (MSG_BROADCAST, SVC_TEMPENTITY);
			WriteByte (MSG_BROADCAST, TE_LIGHTNING2);
			WriteEntity (MSG_BROADCAST, targ1);
			
			// shave a little off each end of the beam - it'll still be inside both
			// monsters' bounds but it'll save us a t_ent here and there, and reduces
			// the likelihood the beam sticks out the far side of the target
			dir = normalize(dst - org) * 12;
			WriteCoord (MSG_BROADCAST, org_x + dir_x);
			WriteCoord (MSG_BROADCAST, org_y + dir_y);
			WriteCoord (MSG_BROADCAST, org_z + dir_y);
			WriteCoord (MSG_BROADCAST, dst_x - dir_x);
			WriteCoord (MSG_BROADCAST, dst_y - dir_y);
			WriteCoord (MSG_BROADCAST, dst_z - dir_z);					
			dmgback = W_ChainLightning(targ1, att, dmg - LG_DMG_OUT);
			particle (hit1, '0 0 100', 225, 3 * dmgback);
			
			if (targ2 != src) {
				dst = BoundsCenter(targ2);
				
				WriteByte (MSG_BROADCAST, SVC_TEMPENTITY);
				WriteByte (MSG_BROADCAST, TE_LIGHTNING2);
				WriteEntity (MSG_BROADCAST, targ2);
				
				dir = normalize(dst - org) * 12;
				WriteCoord (MSG_BROADCAST, org_x + dir_x);
				WriteCoord (MSG_BROADCAST, org_y + dir_y);
				WriteCoord (MSG_BROADCAST, org_z + dir_y);
				WriteCoord (MSG_BROADCAST, dst_x - dir_x);
				WriteCoord (MSG_BROADCAST, dst_y - dir_y);
				WriteCoord (MSG_BROADCAST, dst_z - dir_z);					
				dmgback = min(dmgback, W_ChainLightning(targ1, att, dmg - LG_DMG_OUT));
				particle (hit2, '0 0 100', 225, 3 * dmgback);
			}
		}
	}
	T_Damage (src, att, att, dmgback);
	
	return dmgback + LG_DMG_IN;
}
*/


void() W_FireLightning =
{
	local	vector		org;
	local	float		cells;

	if (self.ammo_cells < 1)
	{
		W_SelectBestWeapon();
		return;
	}

// explode if under water
	if (self.waterlevel > 1)
	{
		cells = self.ammo_cells;
		self.ammo_cells = 0;
		W_SetCurrentAmmo ();
		T_RadiusDamage (self, self, 35*cells, world);
		return;
	}

	if (self.width < time)
	{
		sound (self, CHAN_WEAPON, "weapons/lhit.wav", 1, ATTN_NORM);
		self.width = time + 0.6;
	}
	self.punchangle_x = -2;

	self.currentammo = self.ammo_cells = self.ammo_cells - 1;
	org = self.origin + '0 0 16'+ v_forward * 8;
	
	traceline2(org, org + v_forward * 720, self, TRACE_NOMONSTERS);

	ClearMultiDamage();
	LightningBeam(org, trace_endpos + v_forward * 8, self, 30);
	ApplyMultiDamage();
	
/*	WriteByte (MSG_BROADCAST, SVC_TEMPENTITY);
	WriteByte (MSG_BROADCAST, TE_LIGHTNING2);	// kabewm
	WriteEntity (MSG_BROADCAST, self);
	WriteCoord (MSG_BROADCAST, org_x);
	WriteCoord (MSG_BROADCAST, org_y);
	WriteCoord (MSG_BROADCAST, org_z);
	WriteCoord (MSG_BROADCAST, trace_endpos_x);
	WriteCoord (MSG_BROADCAST, trace_endpos_y);
	WriteCoord (MSG_BROADCAST, trace_endpos_z);

	if (trace_ent.takedamage) {
		//trace_ent.customflags = trace_ent.customflags | CFL_ZAPPED;
		org = trace_endpos;
		particle (org, '0 0 100', 225, 3 * W_ChainLightning(trace_ent, self, 32));
	}
*/
}

