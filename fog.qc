/*
====================

FOG

adapted from similar things czg did in honey_fog.qc god bless him

new skyfog stuff:
the skyfog keys will all be 0 in all existing maps, and therefore the desired
behavior when a skyfog key is 0 has to be "do not change the skyfog". -1 is
the new "actually mark it zero" for mappers, and just to make it harder and
more confusing for ourselves the code does the reverse: -1 means no change, 
all other values (including zero) will set skyfog. any entity with fog keys
has to swap the two upon spawning.

====================
*/

float FOG_INTERVAL = 0.05; //1/20;
/*FGD
@baseclass = Fog [ 
	fog_density(string) : "Fog Density" 
	fog_color(string) : "Fog Color" 
	fog_sky(string) : "Sky Fog Density (-1 for clear sky)" 
]
@baseclass = FogShift [ 
	fog_density(string) : "Start Fog Density" 
	fog_color(string) : "Start Fog Color" 
	fog_sky(string) : "Start Sky Fog Density (-1 for clear sky)" 
	fog_density2(string) : "End Fog Density" 
	fog_color2(string) : "End Fog Color" 
	fog_sky2(string) : "End Sky Fog Density (-1 for clear sky)" 
]
*/

void() fog_fixKeys =
{
	if (self.fog_sky == -1)
		self.fog_sky = 0;
	else if (self.fog_sky == 0)
		self.fog_sky = -1;
	if (self.fog_sky2 == -1)
		self.fog_sky2 = 0;
	else if (self.fog_sky2 == 0)
		self.fog_sky2 = -1;
}

float(entity e, float dens, vector col, float sky) fog_sigdif =
{
	float sig;
	
	if ((e.fog_density + dens) * 0.5 < 0.1) sig = 0.0025;
	else sig = 0.005;
	if (fabs(e.fog_density - dens) > sig) return TRUE;
	
	if ((e.fog_sky + sky) * 0.5 < 0.1) sig = 0.005;
	else sig = 0.01;
	if (fabs(e.fog_sky - sky) > sig) return TRUE;
	
	if ((e.fog_color_x + col_x) * 0.5 < 0.1) sig = 0.005;
	else sig = 0.01;
	if (fabs(e.fog_color_x - col_x) > sig) return TRUE;
	
	if ((e.fog_color_y + col_y) * 0.5 < 0.1) sig = 0.005;
	else sig = 0.01;
	if (fabs(e.fog_color_y - col_y) > sig) return TRUE;
	
	if ((e.fog_color_z + col_z) * 0.5 < 0.1) sig = 0.005;
	else sig = 0.01;
	if (fabs(e.fog_color_z - col_z) > sig) return TRUE;
	
	return FALSE;
}


/*
================
fog_save
================
*/
void( entity client, float density, vector color, float sky ) fog_save =
{
	if (client.classname != "player") return;
	
	// save whatever we set the client's fog to in case of saves/loads
	client.fog_density = density;
	client.fog_color = color;
	if (sky) client.fog_sky = sky;
}

/*
================
fog_setFromEnt
================
*/
void( entity client, entity fogger ) fog_setFromEnt =
{
	dprint("setting fog values\n");
	// don't set the fog if the entity has no values, because it might be a custom map with
	// _fog on the worldspawn instead
	// to actually get an entity to clear the fog, set a color but leave density at 0
	if (!fogger.fog_color)
		if (!fogger.fog_density)
			return;
	
	fog_set(client, fogger.fog_density, fogger.fog_color, fogger.fog_sky);
}

/*
================
fog_set
================
*/
void( entity client, float density, vector color, float sky ) fog_set =
{
	if (client.classname != "player") return;
	if (!cleanUpClientShit)
	{
		if (client.fog_density == density && client.fog_color == color && client.fog_sky == sky)
			return FALSE;
	}

	//stuffcmd(client, "r_showtris 0\n"); return;
	//dprint3("setting fog at ", ftos(time*1000), "\n");
	
	stuffcmd(client, "\nfog ");
	stuffcmd_float(client, density);
	stuffcmd(client, " ");
	stuffcmd_float(client, color_x * (icantsee + 1));
	stuffcmd(client, " ");
	stuffcmd_float(client, color_y * (icantsee + 1));
	stuffcmd(client, " ");
	stuffcmd_float(client, color_z * (icantsee + 1));
	stuffcmd(client, "\n");

	if (sky != -1 && client.fog_sky != sky)
	{
		stuffcmd(client, "r_skyfog ");
		stuffcmd_float(client, sky);
		stuffcmd(client, "\n");
	}	

	fog_save(client, density, color, sky);
}

/*
================
fog_blendTouch
================
*/
void() fog_blendTouch =
{
	if (!CheckValidTouch()) return;
	
	// fix for only first client getting a fog change when multiple coop clients are touching this at once
	if (time != self.rad_time)	// because fog is rad
		if (time < self.attack_finished)
			return;
		
	float f, ldensity, lsky, leaving, force, doSky;
	vector dorg, mid, ovel;
	vector lcolor;
	
	force = (time - self.invisible_time >= FOG_INTERVAL * 10);
	
	// if you run/fall through a fogblend fast enough you can come out the other side 
	// partially blended, so check if player will exit the trigger bounds before the 
	// next touch (same class of bug as leaping through lasers in Q2)
	ovel = (other.groundentity.velocity + other.velocity) * FOG_INTERVAL;
	leaving = ( (other.absmax_x + ovel_x < self.absmin_x) ||
				(other.absmax_y + ovel_y < self.absmin_y) ||
				(other.absmax_z + ovel_z < self.absmin_z) ||
				(other.absmin_x + ovel_x > self.absmax_x) ||
				(other.absmin_y + ovel_y > self.absmax_y) ||
				(other.absmin_z + ovel_z > self.absmax_z) );
				
	doSky = (self.fog_sky != -1) && (self.fog_sky2 != -1);
	
	if (leaving)
	{
		// last chance to set fog correctly, so snap it to the final values
		leaving = ovel * self.movedir;
		if (leaving > 0)
		{
			ldensity = self.fog_density2;
			lcolor = self.fog_color2;
			if (doSky) lsky = self.fog_sky2;
		}
		else
		{
			ldensity = self.fog_density;
			lcolor = self.fog_color;
			if (doSky) lsky = self.fog_sky;
		}
		force = TRUE;
	}
	else
	{
		// in transition, blend proportionally between the two fogs
		mid = (self.mins + self.maxs) * 0.5;
		dorg = other.origin + other.view_ofs - mid;
		
		f = dorg * self.movedir;
		f = (f / self.distance) + 0.5;
		
		ldensity = lerp(self.fog_density, self.fog_density2, f);
		lcolor = lerpVector(self.fog_color, self.fog_color2, f);
		if (doSky) lsky = lerp(self.fog_sky, self.fog_sky2, f);
	}
	
	if (force || fog_sigdif(other,ldensity,lcolor,lsky))
	{
		self.invisible_time = time;
		if (doSky) 
			fog_set(other, ldensity, lcolor, lsky);
		else
			fog_set(other, ldensity, lcolor, -1);
	}
	//fog_save(other, ldensity, lcolor);
	
	self.rad_time = time;
	self.attack_finished = time + FOG_INTERVAL / 2;
	
//	bprint(ftos(f*1000));
//	bprint("\n");
}


/*QUAKED trigger_fogblend (.5 .5 .2) ?
Acts as a smoothly blending portal between two zones of different fog. Sets the fog for any client passing through it, blending their global fog settings between "fog_color"/"fog_density" and "fog_color2"/"fog_density2" proportional to their position within the trigger.
"fog_sky"/"fog_sky2" will affect r_skyfog at the same time if both are non-zero. Use -1 if you really want 0.

The axis of motion on which the blend happens is defined by "angle", pointing to whatever zone has color2 and density2.  Trigger therefore has two 'sides' - the side that "angle" points to, and the opposite side.  

"distance" - override the length of the blend period in world units - defaults to bounds size 
	on 'angle' otherwise. this is only useful for diagonal triggers.

CAVEATS:
- will 'stuffcmd' 2 dozen times per frame so try not to make these huge
- a bug in most quake engine ports will reset the eye position smoothing that happens when climbing stairs or riding a plat on every frame that a 'stuffcmd' is sent, so fog transitions during upwards motion will cause noticeable stuttering.
*/
/*FGD
@SolidClass base(Appearflags, Targetname, Target, FogShift) = trigger_fogblend : 
"Trigger: Fog Blend
Acts as a smoothly blending portal between two zones of different fog. Sets the fog for any client passing through it, blending their global fog settings between start and end values proportional to their position within the trigger.
fog_sky/fog_sky2 will affect r_skyfog at the same time if both are non-zero. Use -1 if you really want 0.

- will 'stuffcmd' 2 dozen times per frame so try not to make these huge
- a bug in most quake engine ports will reset the eye position smoothing that happens when climbing stairs or riding a plat on every frame that a 'stuffcmd' is sent, so fog transitions during upwards motion will cause noticeable stuttering." 
[
	distance(integer) : "Length of blend distance (defaults to size of trigger)"
	angle(integer) : "Axis of motion of blend (points toward end values)"
]
*/
void() trigger_fogblend =
{
	if (!SUB_ShouldSpawn()) return;
	if (self.angles == '0 0 0')		// InitTrigger assumes angle 0 means no angle
		self.angles = '0 360 0';

	InitTrigger ();
	self.touch = fog_blendTouch;
	self.distance = zeroconvertdefault(self.distance, BoundsAngleSize(self.movedir, self.size));
	fog_fixKeys();
}



// ================================

void(float density, vector color, float sky) target_fogblend_save =
{
	if (self.spawnflags & 4)
	{
		entity pl;
		pl = nextent(world);
		while (pl.flags & FL_CLIENT)
		{
			fog_save(pl, density, color, sky);
			pl = nextent(pl);
		}
	}
	else
		fog_save(self.enemy, density, color, sky);
}

void(float density, vector color, float sky) target_fogblend_set =
{
	if (self.spawnflags & 4)
	{
		entity pl;
		pl = nextent(world);
		while (pl.flags & FL_CLIENT)
		{
			fog_set(pl, density, color, sky);
			pl = nextent(pl);
		}
	}
	else
		fog_set(self.enemy, density, color, sky);
}

/*
================
target_fogblend_use
================
*/
void() target_fogblend_use =
{
	float d, s;
	vector c;
	self.enemy = activator;
	if (self.enemy.classname != "player") return;
	if (!(self.spawnflags & 1))
		self.state = 1 - self.state;
	
	self.nextthink = time + self.delay;
	if (self.state)
	{
		self.pain_finished = time + self.delay + self.speed;
		d = self.fog_density2;
		c = self.fog_color2;
		s = self.fog_sky2;
	}
	else
	{
		self.pain_finished = time + self.delay + self.speed2;
		d = self.fog_density;
		c = self.fog_color;
		s = self.fog_sky;
	}
	target_fogblend_save(d, c, s);
	self.use = SUB_Null;	// don't allow retriggering before the blend is done or it looks super duper wacky
}

/*
================
fog_blendTimeThink
================
*/
void() fog_blendTimeThink =
{
	float f, d, s, doSky;
	vector c;
	
	if (time >= self.pain_finished)
	{
		f = 1;
		self.use = target_fogblend_use;
	}
	else
	{
		self.nextthink = time + FOG_INTERVAL;
		if (self.state && self.speed)
			f = 1 - (self.pain_finished - time) / self.speed;
		else if (self.speed2)
			f = 1 - (self.pain_finished - time) / self.speed2;
		else
			f = 1;
	}
	
	if (self.fog_sky != -1 && self.fog_sky2 != -1)
		doSky = TRUE;
	
	if (self.state)
	{
		d = lerpHermite(self.fog_density, self.fog_density2, f);
		c = lerpVectorHermite(self.fog_color, self.fog_color2, f);
		if (doSky)
			s = lerpHermite(self.fog_sky, self.fog_sky2, f);
	}
	else
	{
		d = lerpHermite(self.fog_density2, self.fog_density, f);
		c = lerpVectorHermite(self.fog_color2, self.fog_color, f);
		if (doSky)
			s = lerpHermite(self.fog_sky2, self.fog_sky, f);
	}
	if (doSky)
		target_fogblend_set(d, c, s);
	else
		target_fogblend_set(d, c, -1);
}

/*QUAKED target_fogblend (.5 .5 .2) (-8 -8 -8) (8 8 8) ONE_WAY REVERSE GLOBAL
Blends the fog for a client.  activator's fog will be blended from "fog_color" and "fog_density"
to "fog_color2" and "fog_density2".  Triggering again will blend it back, unless ONE_WAY is set.
"fog_sky"/"fog_sky2" will affect r_skyfog at the same time if both are non-zero. Use -1 if you really want 0.
Set REVERSE if you're tired of swapping the values by hand.
Set GLOBAL to affect all clients in multiplayer, not just the activator.

"delay" - pause before beginning to blend
"speed" - time to spend blending, -1 for an instant change to fog2.
"speed2" - time to spend blending back, if different than "speed". -1 for instant.

CAVEATS:
- will 'stuffcmd' 2 dozen times per frame so try not to make this take too long
- a bug in most quake engine ports will reset the eye position smoothing that happens when climbing stairs or riding a plat on every frame that a 'stuffcmd' is sent, so fog transitions during upwards motion will cause noticeable stuttering.
*/
/*FGD
@PointClass base(Appearflags, Targetname, FogShift) color(128 128 50) = target_fogblend : 
"Target: Fog Blend
Activator's fog will be blended over time from start to end values.

- will 'stuffcmd' 2 dozen times per frame so try not to make this take too long
- a bug in most quake engine ports will reset the eye position smoothing that happens when climbing stairs or riding a plat on every frame that a 'stuffcmd' is sent, so fog transitions during upwards motion will cause noticeable stuttering." 
[
	spawnflags(flags) = [
		1 : "One-Way Only" : 0
		2 : "Reverse Start/End" : 0
		4 : "All clients" : 0
	]
	delay(string) : "Pause before starting blend"
	speed(string) : "Time to blend (-1 for instant)"
	speed2(string) : "Time to blend back, if different (-1 for instant)"
]
*/
void() target_fogblend =
{
	if (!SUB_ShouldSpawn()) return;
	self.use = target_fogblend_use;
	self.think = fog_blendTimeThink;
	fog_fixKeys();
	if (self.spawnflags & 2)
		self.state = 1;
	else
		self.state = 0;
	if (self.spawnflags & 1)
		self.state = 1 - self.state;
	
	if (!self.speed) self.speed = 1;
	if (!self.speed2) self.speed2 = self.speed;
	
	if (self.speed == -1) self.speed = 0;
	if (self.speed2 == -1) self.speed2 = 0;
}