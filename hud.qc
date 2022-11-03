const string number[10] = { "num_0", "num_1", "num_2", "num_3", "num_4", "num_5", "num_6", "num_7", "num_8", "num_9"};
const string anumber[10] = { "anum_0", "anum_1", "anum_2", "anum_3", "anum_4", "anum_5", "anum_6", "anum_7", "anum_8", "anum_9"};

const string powerupflash[6] = { "gfx/sb_","gfx/sba1_","gfx/sba2_","gfx/sba3_","gfx/sba4_","gfx/sba5_" };
const float flash[11] = {2,3,4,5,2,3,4,5,1,0,0};

const float weaponflags[7] = {
	IT_SHOTGUN,
	IT_SUPER_SHOTGUN,
	IT_NAILGUN,
	IT_SUPER_NAILGUN,
	IT_GRENADE_LAUNCHER,
	IT_ROCKET_LAUNCHER,
	IT_LIGHTNING
};
const string weaponflash[6] = { "gfx/inv_","gfx/inv2_","gfx/inva2_","gfx/inva3_","gfx/inva4_","gfx/inva5_" };	// use selected glow as a better last frame
const string weaponlabel[7] = {	"shotgun","sshotgun","nailgun","snailgun","rlaunch","srlaunch","lightng" };

float stat_items, stat_items2, stat_health, keytype;
float paintime, lookseed;
float itemtimes[23];

const float HUD_FACELEFT = 0;
const float HUD_FACEFWD = 1;
const float HUD_FACERIGHT = 2;

string(float f, float chars, string lead) FormatFloat
{
	string s = ftos(f);
	if (f < 10 && chars >= 3)
		s = strcat(lead, lead, s);
	else if (f < 10 && chars == 2)
		s = strcat(lead, s);
	else if (f < 100 && chars >= 3)
		s = strcat(lead, s);
	return s;
};

// ================================================================

// MAP STAT BAR

void(vector pos, float bx, float by, float bwidth, float bheight, float pixelspeed, string draw_str) Hud_ScrollTextBox =
{
	local float str_width, str_double, str_speed;
	local string wide_str;
	
	// draw debug visual box to show area on screen
	//drawfill( pos+[bx,by], [bwidth,bheight], '1 1 1', 0.1, 0);

	// Find out width of string in pixels (using font 8)
	str_width = stringwidth( draw_str, TRUE, '8 8');
	// String less than window width?
	if (str_width < bwidth) {
		// Center the map name string in the box area
		str_double = (bwidth - str_width) / 2;
		// Display string normally (no scrolling required)
		drawstring( pos+[bx+str_double, by], draw_str, '8 8', '1 1 1', 1, 0);
	}
	else {
		// Create double length string with boundary marker
		wide_str = strcat(draw_str, " /// ", draw_str);
		// Setup clip (scissor) area for exclusive drawing
		drawsetcliparea( pos_x + bx, pos_y + by, bwidth, bheight);
		str_double = stringwidth( wide_str, TRUE, '8 8');
		// create offset of string to make it look like its scrolling
		str_speed = mod(cltime * pixelspeed, (str_double - str_width));
		// draw string (with offset) inside of clip (scissor) area only
		drawstring( pos+[bx - str_speed, by], wide_str, '8 8', '1 1 1', 1, 0);
		// Reset clip string area to default
		drawresetcliparea();
	}
};

void(vector pos, float balpha) Hud_DrawLevelInfoBar =
{
	string s;
	float mins, secs, w, kw, gap;

	drawpic(pos, "scorebar", '320 24', '1 1 1', balpha, 0);

	s = strcat(world.message, " (", mapname, ")");
	Hud_ScrollTextBox(pos, 8, 4, 304, 8, 16, s);

	s = strcat("kills: ", FormatFloat(getstatf(STAT_MONSTERS), 0, " "), "/", FormatFloat(getstatf(STAT_TOTALMONSTERS), 0, " "));
	kw = stringwidth(s, TRUE, '8 8');
	drawstring(pos + '8 12', s, '8 8', '1 1 1', 1, 0);
	gap = 304 - kw;
	
	s = strcat("secrets: ", FormatFloat(getstatf(STAT_SECRETS), 0, " "), "/", FormatFloat(getstatf(STAT_TOTALSECRETS), 0, " "));
	w = stringwidth(s, TRUE, '8 8');
	drawstring(pos + '312 12' - '1 0' * w, s, '8 8', '1 1 1', 1, 0);
	gap -= w;

	mins = floor(time/60);
	secs = floor(time - mins*60);
	s = strcat(ftos(mins), ":", FormatFloat(secs, 2, "0"));
	w = stringwidth(s, TRUE, '8 8');
	drawstring(pos + '8 12' + '1 0' * kw + '0.5 0 0' * (gap - w), s, '8 8', '1 1 1', 1, 0);
};

// ================================================================

// STATUS BAR

void(vector pos, float value, float threshhold) Hud_DrawLargeValue =
{
	float c;
	float len;
	string s;
	if (value < 0)
		value = 0;	//hrm
	if (value>999)
		value = 999;

	s = ftos(floor(value));
	len = strlen(s);

	pos_x += 24 * (3-len);
	

	if (value <= threshhold)
	{	//use alternate (red) numbers

		while(len>0)
		{
			len--;
			c = str2chr(s, len);

			drawpic(pos+len * '24 0', anumber[c-'0'], '24 24', '1 1 1', 1, 0);
		}
	}
	else
	{	//use normal numbers

		while(len>0)
		{
			len--;
			c = str2chr(s, len);

			drawpic(pos+len * '24 0', number[c-'0'], '24 24', '1 1 1', 1, 0);
		}
	}
};

void(float type, vector pos, float drawback) Hud_DrawAmmoCount =
{
	string s;
	float value;
	float len;
	float c;
	value = getstati(STAT_SHELLS + type);
	if (value < 0)
		value = 0;	//hrm
	if (value>999)
		value = 999;

	s = ftos(floor(value));
	len = strlen(s);

	pos_x += 8 * (3-len);
	while(len>0)
	{
		len--;
		c = str2chr(s, len);
		drawcharacter(pos+len * '8 0', (18-'0') + c, '8 8', '1 1 1', 1, 0);
	}
};

void Hud_DrawHead(vector pos)
{
	float h, f;
	string headpic;
		
	h = 5 - floor(stat_health/20);
	if (h < 1) h = 1;
	if (h > 5) h = 5;
	
	f = (stat_items & (IT_QUAD|IT_INVULNERABILITY|IT_INVISIBILITY)) / IT_INVISIBILITY;
	switch(f)
	{
	case 1:
		headpic = "face_invis";
		break;
	case 2:
		headpic = "face_invul2";
		break;
	case 3:
		headpic = "face_inv2";
		break;
	case 8:
		headpic = "face_quad";
		break;
	case 9:
		headpic = "face_invisquad";
		break;
	case 10:
		headpic = "face_invulquad";
		break;
	case 11:
		headpic = "face_allpups";
		break;
	default:
		if (time < paintime)
		{
			headpic = strcat("face_p", ftos(h));
		}
		else
		{
			headpic = strcat("face", ftos(h));
			if (time > paintime + 1)
			{	// peer left and right
				f = floor(time * 2 + lookseed);
				if (f % 23 == 0 || f % 17 == 0)
					headpic = strcat(headpic,"_l");
				else if (f % 29 == 0 || f % 11 == 0)
					headpic = strcat(headpic,"_r");				
			}
		}
	}
	drawpic(pos, headpic, '24 24', '1 1 1', 1, 0);
}

void Hud_DrawSBar(vector pos, float balpha)
{
	drawpic(pos, "sbar", '320 24', '1 1 1', balpha, 0);

	Hud_DrawHead(pos + '112 0');

	if (stat_items & IT_INVULNERABILITY)
	{
		/*
		if (time < paintime - 0.075)
			drawpic(pos + '1 0', "sb_armor666_p1", '24 24', '1 1 1', 1, 0);
		else if (time < paintime)
			drawpic(pos + '1 0', "sb_armor666_p2", '24 24', '1 1 1', 1, 0);
		else
		*/
			drawpic(pos + '1 0', "sb_armor666", '24 24', '1 1 1', 1, 0);
		Hud_DrawLargeValue(pos+'24 0', 666, 999);
	}
	else
	{
		Hud_DrawLargeValue(pos+'24 0', getstatf(STAT_ARMOR), 25);
		if (stat_items & IT_ARMOR3)
			drawpic(pos + '1 0', "sb_armor3b", '24 24', '1 1 1', 1, 0);
		else if (stat_items & IT_ARMOR2)
			drawpic(pos + '1 0', "sb_armor2b", '24 24', '1 1 1', 1, 0);
		else if (stat_items & IT_ARMOR1)
			drawpic(pos + '1 0', "sb_armor1b", '24 24', '1 1 1', 1, 0);
	}

	Hud_DrawLargeValue(pos+'136 0', stat_health, 25);

	if (stat_items & IT_SHELLS)
		drawpic(pos+'224 0', "sb_shells", '24 24', '1 1 1', 1, 0);
	else if (stat_items & IT_NAILS)
		drawpic(pos+'224 0', "sb_nails", '24 24', '1 1 1', 1, 0);
	else if (stat_items & IT_ROCKETS)
		drawpic(pos+'224 0', "sb_rocket", '24 24', '1 1 1', 1, 0);
	else if (stat_items & IT_CELLS)
		drawpic(pos+'224 0', "sb_cells", '24 24', '1 1 1', 1, 0);
	Hud_DrawLargeValue(pos+'248 0', getstatf(STAT_AMMO), 10);
};

// ================================================================

// INVENTORY BAR

void Hud_DrawKeys(vector pos, float it)
{
	if (!(stat_items & it))
		return;

	string s;
	float n;
	
	if (it == IT_KEY1)
	{
		n = getstatbits(STAT_KEYCOUNTS, 0, 4)-1;
		if (n < 0) n = 0;	// happens in demos where .worldtype isn't increased
		if (keytype == 2)
			s = strcat("gfx/sb_bkey1_", ftos(n + 1));
		else if (keytype == 1)
			s = strcat("gfx/sb_rkey1_", ftos(n + 1));
		else
			s = strcat("gfx/sb_key1_", ftos(n + 1));
			
		drawpic(pos+'192 8', s, '16 16', '1 1 1', 1, 0);
	}
	if (it == IT_KEY2)
	{
		n = getstatbits(STAT_KEYCOUNTS, 4, 4)-1;
		if (n < 0) n = 0;	// happens in demos where .worldtype isn't increased
		if (keytype == 2)
			s = strcat("gfx/sb_bkey2_", ftos(n + 1));
		else if (keytype == 1)
			s = strcat("gfx/sb_rkey2_", ftos(n + 1));
		else
			s = strcat("gfx/sb_key2_", ftos(n + 1));
			
		drawpic(pos+'208 8', s, '16 16', '1 1 1', 1, 0);
	}
}

float HUD_FlashTime(float it)
{
	float t = time - itemtimes[it];

	if (t < 1)
		return flash[floor(t*10)];
	else
		return 0;
}

void(float wnum, vector pos, float sel) Hud_DrawWeapon
{
	vector sz;
	float fram;
	
	fram = HUD_FlashTime(wnum);
	if (sel && fram == 0) fram = 1;	// selected weapon glow
	
	sz = '24 16';
	if (wnum == 6) sz = '48 16';
	
	string pic = strcat(weaponflash[fram], weaponlabel[wnum]);
	
	drawpic(pos+'24 0'*wnum, pic, sz, '1 1 1', 1, 0);
};

void Hud_DrawIBar(vector pos, float balpha)
{
	string s;
	float currweap = getstatf(STAT_ACTIVEWEAPON);
	float i;
	
	drawpic(pos, "ibar", '320 24', '1 1 1', balpha, 0);
	
	for (i = 0; i < 7; i++)
	{
		if (stat_items & weaponflags[i])
			Hud_DrawWeapon(i, pos+'0 8', (currweap == weaponflags[i]));
	}
	
	Hud_DrawAmmoCount(0, pos + '10 0', FALSE);
	Hud_DrawAmmoCount(1, pos + '58 0', FALSE);
	Hud_DrawAmmoCount(2, pos + '106 0', FALSE);
	Hud_DrawAmmoCount(3, pos + '154 0', FALSE);

	keytype = getstatbits(STAT_KEYCOUNTS, 8, 8);
	Hud_DrawKeys(pos, IT_KEY1);
	Hud_DrawKeys(pos, IT_KEY2);

	if (stat_items & IT_INVISIBILITY) 
	{
		s = strcat(powerupflash[HUD_FlashTime(19)], "invis");
		drawpic(pos+'224 8', s, '16 16', '1 1 1', 1, 0);
	}
	if (stat_items & IT_INVULNERABILITY)
	{
		s = strcat(powerupflash[HUD_FlashTime(20)], "invul");
		drawpic(pos+'240 8', s, '16 16', '1 1 1', 1, 0);
	}
	if (stat_items & IT_SUIT)
	{
		s = strcat(powerupflash[HUD_FlashTime(21)], "suit");
		drawpic(pos+'256 8', s, '16 16', '1 1 1', 1, 0);
	}
	if (stat_items & IT_QUAD)
	{
		s = strcat(powerupflash[HUD_FlashTime(22)], "quad");
		drawpic(pos+'272 8', s, '16 16', '1 1 1', 1, 0);
	}
	
	if (stat_items2 & 32)
		drawpic(pos+'288 8', "sb_sigil1", '8 16', '1 1 1', 1, 0);
	if (stat_items2 & 64)
		drawpic(pos+'296 8', "sb_sigil2", '8 16', '1 1 1', 1, 0);
	if (stat_items2 & 128)
		drawpic(pos+'304 8', "sb_sigil3", '8 16', '1 1 1', 1, 0);
	if (stat_items2 & 256)
		drawpic(pos+'312 8', "sb_sigil4", '8 16', '1 1 1', 1, 0);
		
	if (!cvar("coop") && !cvar("deathmatch"))
		return;

	float p, numclients, scorew;
	string score;
	numclients = getstatf(STAT_CLIENTS);
	for (p = 0; p < numclients; p++)
	{
		drawpic(pos + '192 0'+ '32 0' * p, strcat("shirt", getplayerkeyvalue(p, "topcolor")), '8 8', '1 1 1', 1, 0);
		drawpic(pos + '192 0'+ '32 0' * p, strcat("pants", getplayerkeyvalue(p, "bottomcolor")), '8 8', '1 1 1', 1, 0);
		score = getplayerkeyvalue(p, "frags");
		scorew = stringwidth(score, TRUE);
		if (scorew <= 16)
			drawstring(pos + '192 0'+ '32 0' * p + '12 0', score, '8 8', '1 1 1', 1, 0);
		else if (scorew <= 24)
			drawstring(pos + '192 0'+ '32 0' * p + '8 0', score, '8 8', '1 1 1', 1, 0);
		else
			drawstring(pos + '192 0'+ '32 0' * p, score, '8 8', '1 1 1', 1, 0);
	}
};

// ================================================================

void() HUD_UpdateStats =
{
	float olditems, i, f;
	
	olditems = stat_items;	
	stat_items = getstatbits(STAT_ITEMS, 0, 23);
	stat_items2 = getstatbits(STAT_ITEMS, 23, 9);
	
	f = 1;
	for (i=0;i<23;i++)
	{
		if ((stat_items & f) != (olditems & f))
		{
			if (stat_items & f)
				itemtimes[i] = time;
			else if (olditems & f)
				itemtimes[i] = 0;
		}
		f *= 2;
	}
	
	// update health and check for sudden reductions
	f = getstatf(STAT_HEALTH);
	if (stat_health - f > 0 && f < getstatf(STAT_MAXHEALTH) || stat_health - f > 3)
	{
		paintime = time + 0.15;	// flinch
	}
	stat_health = f;
}

void(vector screensize, float scoreboard) CSQC_DrawHud =
{
	vector pos;
	float viewsize = cvar("viewsize");
	float baralpha = cvar("scr_sbaralpha");

	pos_x = (screensize_x-320)/2;
	pos_y = screensize_y;

	HUD_UpdateStats();

	if (viewsize <= 110)
	{
		if (scoreboard || stat_health <= 0)
			Hud_DrawLevelInfoBar(pos - '0 24', baralpha);
		else
			Hud_DrawSBar(pos - '0 24', baralpha);
	}	
	if (viewsize <= 100)
		Hud_DrawIBar(pos - '0 48', baralpha);
};

// ================================================================

void() Hud_Init
{
	float i;
	for (i = 0; i < 10; i++)
	{
		precache_pic(number[i], TRUE);
		precache_pic(anumber[i], TRUE);
	}
	for (i = 0; i < 16; i++)
	{
		precache_pic(strcat("gfx/sb_key1_", ftos(i+1)), TRUE);
		precache_pic(strcat("gfx/sb_key2_", ftos(i+1)), TRUE);
		precache_pic(strcat("gfx/sb_rkey1_", ftos(i+1)), TRUE);
		precache_pic(strcat("gfx/sb_rkey2_", ftos(i+1)), TRUE);
		precache_pic(strcat("gfx/sb_bkey1_", ftos(i+1)), TRUE);
		precache_pic(strcat("gfx/sb_bkey2_", ftos(i+1)), TRUE);
	}
	for (i = 0; i < 6; i++)
	{
		precache_pic(strcat(powerupflash[i], "invis"), TRUE);
		precache_pic(strcat(powerupflash[i], "invul"), TRUE);
		precache_pic(strcat(powerupflash[i], "suit"), TRUE);
		precache_pic(strcat(powerupflash[i], "quad"), TRUE);
	}
	for (i = 0; i < 14; i++)
	{
		precache_pic(strcat("shirt", ftos(i)), TRUE);
		precache_pic(strcat("pants", ftos(i)), TRUE);
	}
	
	precache_pic("sbar", TRUE);
	precache_pic("face1_l", TRUE);
	precache_pic("face1_r", TRUE);
	precache_pic("face2_l", TRUE);
	precache_pic("face2_r", TRUE);
	precache_pic("face3_l", TRUE);
	precache_pic("face3_r", TRUE);
	precache_pic("face4_l", TRUE);
	precache_pic("face4_r", TRUE);
	precache_pic("face5_l", TRUE);
	precache_pic("face5_r", TRUE);
	
	precache_pic("face_invis", TRUE);
	precache_pic("face_inv2", TRUE);
	precache_pic("face_invul2", TRUE);
	precache_pic("face_quad", TRUE);
	precache_pic("face_invulquad", TRUE);
	precache_pic("face_invisquad", TRUE);
	precache_pic("face_allpups", TRUE);
	precache_pic("sb_armor1b", TRUE);
	precache_pic("sb_armor2b", TRUE);
	precache_pic("sb_armor3b", TRUE);
	precache_pic("sb_armor666", TRUE);
	//precache_pic("sb_armor666_p1", TRUE);
	//precache_pic("sb_armor666_p2", TRUE);
	
	paintime = -1;
	lookseed = floor(random() * 100);
};

void(float apilevel, string enginename, float engineversion) CSQC_Init = {Hud_Init();}
