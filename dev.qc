/*
==============================================================================

DEV COMMANDS

==============================================================================
*/

void() dev_test =
{
	local vector org;
	makevectors(self.v_angle);
	org = self.origin + self.view_ofs;
	traceline2(org, org + v_forward * 8192, self, 0);

	if (trace_fraction == 1.0 || !trace_ent)
		return;

	entity head = findalltargets(trace_ent);
	while(head)
	{
		bprint4(head.classname, " @ ", vtos(head.origin), "\n");
		head =  head.chain;
	}
	bprint("-----\n");
}

void() dev_tracetest =
{
	local vector org;
	makevectors(self.v_angle);
	org = self.origin + self.view_ofs;
	
	traceline (org, org + v_forward * 2048, FALSE, self);
	
	bprint3("startpos: ", vtos(org), "\n");
	bprint3("endpos: ", vtos(trace_endpos), "\n");
	bprint3("water: ", ftos(trace_inwater), "\n");
	bprint3("open: ", ftos(trace_inopen), "\n");
	bprint3("allsolid: ", ftos(trace_allsolid), "\n");
	
	traceline2 (org, org + v_forward * 2048, self, 0);
	
	bprint3("startpos: ", vtos(org), "\n");
	bprint3("endpos: ", vtos(trace_endpos), "\n");
	bprint3("water: ", ftos(trace_inwater), "\n");
	bprint3("open: ", ftos(trace_inopen), "\n");
	bprint3("allsolid: ", ftos(trace_allsolid), "\n");
}

void() dev_hitpoints =
{
	if (!cvar("developer"))
	{
		bprint("start the map with developer 1 first\n");
		return;
	}
	float zdif;
	
	bprint("----------\nRockets: ");
	bprint(ftos(num_rockets));
	bprint(" Zombies: ");
	bprint(ftos(num_zombies));
	
	zdif = num_rockets - num_zombies;
	zdif = max(0,num_rockets);
	ammo_total += zdif * DEBUG_DMG_PER_ROCKET;
	
	bprint("\nMonster HP: ");
	bprint(ftos(monster_health));
	bprint("\nAmmo DP: ");
	bprint(ftos(ammo_total));
	bprint("\nRATIO: ");
	bprint(ftos(ammo_total / monster_health));
	bprint("\n");
}

void() dev_warp =
{
	if(deathmatch || coop)
		return;
	local vector org;
	makevectors(self.v_angle);
	org = self.origin + self.view_ofs;
	traceline (org, org + v_forward * 8192, FALSE, self);

	if (trace_fraction < 1.0)
	{
		org = trace_endpos;
		org += trace_plane_normal * 40;
	}
	setorigin(self,org);
}

void() dev_serverflags =
{
	bprint3("SERVER FLAGS:\n========\n  ",ftos(serverflags),"  \n");
	if (serverflags & SVFL_EPISODE1)	bprint("  episode 1 completed\n");
	if (serverflags & SVFL_EPISODE2)	bprint("  episode 2 completed\n");
	if (serverflags & SVFL_EPISODE3)	bprint("  episode 3 completed\n");
	if (serverflags & SVFL_EPISODE4)	bprint("  episode 4 completed\n");
	if (serverflags & SVFL_ALLEPISODES == SVFL_ALLEPISODES)	bprint("  all of quake completed\n");
}


// this is the most fun cheat code in the history of anything:
void() dev_invoke =
{
	if ((deathmatch || coop) && !cvar("developer"))
		return;
	local vector org;
	makevectors(self.v_angle);
	org = self.origin + self.view_ofs;
	traceline2(org, org + v_forward * 8192, self, 0);
	if (trace_fraction < 1.0 && trace_ent)
	{
		activator = self;
		
		if (trace_ent.flags & FL_CLIENT)
			sound (trace_ent, CHAN_VOICE, "player/plyrjmp8.wav", 1, ATTN_NORM);	
		else if (trace_ent.flags & FL_MONSTER)
			monster_kill(trace_ent);
		else if (trace_ent.classname == "func_door")
			door_force(trace_ent);
		else if (trace_ent.classname == "func_button")
			button_force(trace_ent);
		else if (trace_ent.classname == "func_plat")
			plat_force(trace_ent);
		else if (trace_ent.classname == "monster_boss")
			SUB_CallAsSelf(boss_death1, trace_ent);	
		else if (trace_ent.use)
			SUB_CallAsSelf(trace_ent.use, trace_ent);		
	}
}

void() dev_reveal =
{
//	bprint("dev\n");
	local vector org;
	makevectors(self.v_angle);
	org = self.origin + self.view_ofs;
	traceline (org, org + v_forward * 8192, FALSE, self);

	if (trace_fraction < 1.0 && trace_ent)
	{
	//	trace_ent.developer = 1;
		//bprint("hit entity:\n");
		bprint3("time: ", ftos(time), "\n");
		eprint(trace_ent);
		//bprint("hit ent's enemy:\n");
		//eprint(trace_ent.enemy);
		if (trace_ent.flags & FL_ONGROUND) bprint("  entity is ONGROUND\n");
		if (trace_ent.flags & FL_PARTIALGROUND) bprint("  entity is PARTIAL_GROUND\n");
		if (checkbottom(trace_ent)) bprint("  checkbottom is true\n");
		else bprint("  checkbottom is FALSE\n");
	}
}

void() dev_trigger =
{
	if(deathmatch || coop)
		return;
	entity t;
	
	dprint3("dev trigger impulse firing '", self.netname, "'\n");
	activator = self;
	t = world;
	do	{
		t = SUB_UseNextTarget( t, self.netname );
		activator = self;
		if (!t) break;
		dprint3("  fired a ", t.classname, "\n");
	} while ( 1 );
}

void(float i) dev_impulse =
{
	bprint3("dev impulse ", ftos(i), " triggering\n");
	entity t;
	activator = self;
	t = world;
	do	{
		t = find(t, classname, "tg_imp");
		if (t.impulse == i)
			SUB_CallAsSelf(t.owner.use, t.owner);
	} while ( t != world );
}

void() dev_impulse_list =
{
	bprint("dev impulses:\n");
	entity t;
	t = world;
	do	{
		t = find(t, classname, "tg_imp");
		if (t)
		{
			bprint4("  ", ftos(t.impulse), ": ", t.owner.classname);
			if (t.owner.targetname != string_null)
				bprint3(", tname: ", t.owner.targetname, "\n");
			else
				bprint("\n");
		}
	} while ( t != world );
	bprint("end of list.\n");
}

void() dev_enemychain =
{
	local vector org;
	makevectors(self.v_angle);
	org = self.origin + self.view_ofs;
	traceline (org, org + v_forward * 8192, FALSE, self);

	entity e;
	float i;
	i = 0;
	if (trace_fraction < 1.0 && trace_ent)
	{
		e = trace_ent;
		do
		{
			bprint5(ftos(i),": ",e.classname," at ~ ",vtos((e.absmin + e.absmax)* 0.5));
			bprint("\n");
			e = e.enemy;
			i += 1;
		}
		while (e != trace_ent);
	}
}


void() dev_remaining_monsters
{
	entity mon = world;
	bprint("Remaining monsters and spawners:\n");
	do {
		mon = nextent(mon);
		if (mon.flags & FL_MONSTER)
		{
			if (mon.health <= 0 || mon.deadflag || 
				(mon.type == "zombie" && mon.customflags & CFL_RETURNED)) // no returned zombies on nightmare
				continue;
			bprint4(mon.classname, " at ", vtos(mon.origin), "\n");
		}
		else if (mon.customflags & CFL_SPAWNER)
		{
			if (mon.count <= 0) continue;
			bprint4(mon.classname, " at ", vtos(mon.origin), " (spawner: ");
			bprint_int(mon.count);
			bprint3(" remaining, named '", mon.targetname ,"')\n");
		}
	} while (mon != world);
	bprint("end of list.\n----------\n");
}


// for when i light a map at 1am and then play it again the next afternoon
void() dev_i_cant_see =
{
	if (icantsee)
		lightstyle(0, "m");
	else
		lightstyle(0, "z");
	icantsee = !icantsee;
	initCleanup = 2;
}


void() dev_whatami =
{
	eprint(self);
}

// ====================================
// meatballs: fake clients for testing coop with fudged playercounts
// ... or playing solo in 'stupid crazy challenge' mode

void() dev_add_meatball =
{
	if (!coop) return;
	entity meatball = spawn();
	entity spot = SelectSpawnPoint();
	
	meatball.classname = "meatball";
	setmodel(meatball, "progs/player.mdl");
	setsize(meatball,VEC_HULL_MIN, VEC_HULL_MAX);
	setorigin(meatball,spot.origin);
	meatball.angles = spot.mangle;
	meatball.solid = SOLID_NOT;
	meatball.movetype = MOVETYPE_NONE;
	
	meatball.pos1 = '12 12 16';
	meatball.frame = 12;
	meatball.think = misc_model_animate;
	meatball.speed = 0.1;
	meatball.nextthink = time + 0.1;
	
	sound (meatball, CHAN_VOICE, "items/itembk2.wav", 1, ATTN_NONE);
	
	clients += 1;
	clientsAlive += 1;
}

void() dev_remove_meatball =
{
	if (!coop) return;
	entity meatball = find(world,classname,"meatball");
	if (meatball)
	{
		sound (meatball, CHAN_BODY, "player/tornoff2.wav", 1, ATTN_NONE);
		remove(meatball);
		clients -= 1;
		clientsAlive -= 1;
	}
}