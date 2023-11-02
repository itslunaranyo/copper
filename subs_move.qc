/*
================================================================

			MOVEMENT SUBS

================================================================
*/

/*
=============
SetMovedir
===============
*/
void() SetMovedir =
{
	if (self.movedir != VEC_ORIGIN) return;	// we already did
	
	vector t_angle;
	t_angle = '0 0 0';
	if (self.mangle != '0 0 0')
	{
		t_angle = self.angles;
		if (t_angle == '0 -1 0')
			t_angle = '0 -90 0';
		else if (t_angle == '0 -2 0')
			t_angle = '0 90 0';
		
	//	self.angles_x = self.mangle_y;
	//	self.angles_y = self.mangle_x;
	//	self.angles_z = self.mangle_z;
		self.angles = Vector(self.mangle_y,self.mangle_x,self.mangle_z);
	}
	
	if (self.angles == '0 -1 0')
		self.movedir = '0 0 1';
	else if (self.angles == '0 -2 0')
		self.movedir = '0 0 -1';
	else
	{
		makevectors (self.angles);
		self.movedir = v_forward;
	}
	
	self.angles = t_angle;
}

// ================================================================

/*
=============
SUB_CalcMoveDone
===============
*/
void()  SUB_CalcMoveDone =
{
// After moving, set origin to exact final destination
	setorigin(self, self.finaldest);
	self.velocity = '0 0 0';
	self.nextthink = -1;
	if (self.think1)
		self.think1();
}

/*
=============
SUB_CalcMove

calculate self.velocity and self.nextthink to reach dest from
self.origin traveling at speed
===============
*/
void(vector tdest, float tspeed, void() func) SUB_CalcMove =
{
	vector	vdestdelta;
	float	len, traveltime;
	float	chron = localtime(self);

	if (!tspeed)
		objerror( "No speed is defined!" );

	self.think1 = func;
	self.finaldest = tdest;
	self.think = SUB_CalcMoveDone;

	if (tdest == self.origin)
	{
		self.velocity = '0 0 0';
		self.nextthink = chron + 0.1;
		return;
	}
		
// set destdelta to the vector needed to move
	vdestdelta = tdest - self.origin;
	
// calculate length of vector
	len = vlen (vdestdelta);
	
// divide by speed to get time to reach dest
	traveltime = len / tspeed;

	if (traveltime < 0.1)
	{
		self.velocity = '0 0 0';
		self.nextthink = chron + 0.1;
		return;
	}
	
// set nextthink to trigger a think when dest is reached
	self.nextthink = chron + traveltime;

// scale the destdelta vector by the time spent traveling to get velocity
	self.velocity = vdestdelta * (1/traveltime);	// qcc won't take vec/float
}

/*
=============
SUB_CalcMoveEnt
===============
*/
void(entity ent, vector tdest, float tspeed, void() func) SUB_CalcMoveEnt =
{
	local entity stemp;
	stemp = self;
	self = ent;

	SUB_CalcMove (tdest, tspeed, func);
	self = stemp;
}


// ================================================================

void() shadowmonitor_think =
{
	float frac;
	entity o = self.owner;
	
	frac = vlen(o.origin - self.pos2) / vlen(self.pos2 - self.pos1);
	if (self.customflags & CFL_INVLIGHT)
		frac = 1 - frac;
	bmodel_lightstyle(o, frac);
	
	self.nextthink = time + min(0.05, (o.nextthink - o.ltime));

	// remove last so we don't miss a final eval
	if (self.nextthink <= time || 
		time > self.lifetime_finished || 
		self.state != o.state)
		remove(self);
}

// move while blending lightstyles smoothly over the distance traveled

// to avoid damaging existing movement logic with extra thinks, we wrap
// it and create a helper entity to do this instead
void(vector tstart, vector tdest, float tspeed, void() endfn, float invert) SUB_CalcMoveLight =
{
	entity mon = spawn();
	mon.classname = "shadowmonitor";
	mon.owner = self;
	mon.state = self.state;	// removes self if these stop matching
	mon.lifetime_finished = time + vlen(tdest - self.origin) / tspeed;
	mon.think = shadowmonitor_think;
	mon.nextthink = time;
	mon.pos1 = tstart;
	mon.pos2 = tdest;
	if (invert)
		mon.customflags |= CFL_INVLIGHT;
		
	SUB_CalcMove(tdest, tspeed, endfn);
}


// ================================================================

/*
CURVACEOUS MOVE

pathcorners can have a curve spawnflag that marks them as bezier control points
bezier path corners affect the curve but will never be visited
	this means they don't affect speed, don't fire targets, etc
*/

void() SUB_CalcMoveCurveSeg =
{
	float chron = localtime(self);
	// self.cnt is number of steps we've passed through
	// (when self.cnt == nodeCtrl.count we should be at nodeEnd)
	if (self.cnt == self.count)
	{
		self.pos2 = VEC_ORIGIN;
		SUB_CalcMoveDone();
		return;
	}
	self.cnt += 1;
	
	float t = self.cnt / self.count;
	vector destdelta = bez(self.pos1, self.pos2, self.finaldest, t) - self.origin;
	
	float wishspeed = lerp(self.speed, self.speed2, t);
	float traveltime = vlen(destdelta) / wishspeed;
	if (traveltime < 0.05)
	{
		self.velocity = VEC_ORIGIN;
		self.nextthink = chron + 0.05;
		self.think = SUB_CalcMoveDone;
		return;
	}	
	self.velocity = destdelta * (1/traveltime);
	self.think = SUB_CalcMoveCurveSeg;
	self.nextthink = chron + traveltime;
}

// init curved motion
void(vector end, vector ctrl, float segs, float speedStart, float speedEnd, void() fnDone) SUB_CalcMoveCurve =
{
	// self.oldenemy is current pathcorner already
	self.pos1 = self.origin;
	self.pos2 = ctrl;
	self.finaldest = end;
	self.speed = speedStart;
	self.speed2 = speedEnd;
	self.cnt = 0;
	self.count = segs;
	self.think1 = fnDone;
	
	SUB_CalcMoveCurveSeg();
}



// ================================================================


/*
=============
SUB_CalcAngleMoveDone
===============
*/
void() SUB_CalcAngleMoveDone =
{
// After rotating, set angle to exact final angle
	self.angles = self.dest2;
	self.avelocity = '0 0 0';
	self.nextthink = -1;
	if (self.think1)
		self.think1();
}

/*
=============
SUB_CalcAngleMove

calculate self.avelocity and self.nextthink to reach destangle from
self.angles rotating 

The calling function should make sure self.think is valid
===============
*/
void(vector destangle, float tspeed, void() func) SUB_CalcAngleMove =
{
local vector	destdelta;
local float		len, traveltime;

	if (!tspeed)
		objerror( "No speed is defined!");
		
// set destdelta to the vector needed to move
	destdelta = destangle - self.angles;
	
// calculate length of vector
	len = vlen (destdelta);
	
// divide by speed to get time to reach dest
	traveltime = len / tspeed;

// set nextthink to trigger a think when dest is reached
	self.nextthink = self.ltime + traveltime;

// scale the destdelta vector by the time spent traveling to get velocity
	self.avelocity = destdelta * (1 / traveltime);
	
	self.think1 = func;
	self.dest2 = destangle;
	self.think = SUB_CalcAngleMoveDone;
}

/*
=============
SUB_CalcAngleMoveEnt
===============
*/
void(entity ent, vector destangle, float tspeed, void() func) SUB_CalcAngleMoveEnt =
{
	local entity stemp;
	stemp = self;
	self = ent;
	SUB_CalcAngleMove (destangle, tspeed, func);
	self = stemp;
}