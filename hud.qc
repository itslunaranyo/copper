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
float itemtimes[30];
float baralpha;
float hudstyle;
float coopdata;
float scr_tint;
vector scr_tintcolor;
float noTint;

const float MP_NARROW = 0;
const float MP_MEDIUM = 1;
const float MP_WIDE = 2;

float(float a, float m) clampf =
{
	if (a < 0) return 0;
	if (a > m) return m;
	return a;
}
string(float f, float chars, string lead) FormatFloat
{
	string s = ftos(f);
	while (strlen(s) < chars)
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

void(vector pos) Hud_DrawLevelInfoBar =
{
	string s;
	float mins, secs, w, kw, gap;

	drawpic(pos, "scorebar", '320 24', '1 1 1', baralpha, 0);

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

void(vector pos, float value, float threshhold, float left = FALSE, float zeropad = 0) Hud_DrawLargeValue =
{
	float c;
	float len;
	string s;

	s = FormatFloat(floor(value), zeropad, "0");
	len = strlen(s);
	if (!left)
		pos_x -= 24 * len;

	if (value <= threshhold)
	{	//use alternate (red) numbers

		while(len>0)
		{
			len--;
			c = str2chr(s, len);

			drawpic(pos + len * '24 0', anumber[c-'0'], '24 24', '1 1 1', 1, 0);
		}
	}
	else
	{	//use normal numbers

		while(len>0)
		{
			len--;
			c = str2chr(s, len);

			drawpic(pos + len * '24 0', number[c-'0'], '24 24', '1 1 1', 1, 0);
		}
	}
};

void(float type, vector pos) Hud_DrawAmmoCount =
{
	string s;
	float value;
	float len;
	float c;
	value = clampf(getstati(STAT_SHELLS + type),999);

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
		if (time < paintime + 0.2)
		{
			headpic = strcat("face_p", ftos(h));
		}
		else
		{
			headpic = strcat("face", ftos(h));
			/*
			if (time > paintime + 1.2)
			{	// peer left and right
				f = floor(time * 2 + lookseed);
				if (f % 23 == 0 || f % 17 == 0)
					headpic = strcat(headpic,"_l");
				else if (f % 29 == 0 || f % 11 == 0)
					headpic = strcat(headpic,"_r");				
			}
			*/
		}
	}
	drawpic(pos, headpic, '24 24', '1 1 1', 1, 0);
}

void Hud_DrawArmorIcon(vector pos)
{
	if (stat_items & IT_INVULNERABILITY)
	{
		// obviously paintime doesn't work when you're invulnerable because your health never changes ...
		/*
		if (time < paintime - 0.075)
			drawpic(pos, "sb_armor666_p1", '24 24', '1 1 1', 1, 0);
		else if (time < paintime)
			drawpic(pos, "sb_armor666_p2", '24 24', '1 1 1', 1, 0);
		else
		*/
			drawpic(pos, "sb_armor666", '24 24', '1 1 1', 1, 0);
	}
	else if (stat_items & IT_ARMOR3)
		drawpic(pos, "sb_armor3b", '24 24', '1 1 1', 1, 0);
	else if (stat_items & IT_ARMOR2)
		drawpic(pos, "sb_armor2b", '24 24', '1 1 1', 1, 0);
	else if (stat_items & IT_ARMOR1)
		drawpic(pos, "sb_armor1b", '24 24', '1 1 1', 1, 0);

}
void Hud_DrawCurrentAmmoIcon(vector pos)
{
	if (stat_items & IT_SHELLS)
		drawpic(pos, "sb_shells", '24 24', '1 1 1', 1, 0);
	else if (stat_items & IT_NAILS)
		drawpic(pos, "sb_nails", '24 24', '1 1 1', 1, 0);
	else if (stat_items & IT_ROCKETS)
		drawpic(pos, "sb_rocket", '24 24', '1 1 1', 1, 0);
	else if (stat_items & IT_CELLS)
		drawpic(pos, "sb_cells", '24 24', '1 1 1', 1, 0);
}

void Hud_DrawSBar(vector pos)
{
	float value;
	drawpic(pos, "sbar", '320 24', '1 1 1', baralpha, 0);

	value = clampf(stat_health, 999);

	Hud_DrawHead(pos + '112 0');
	Hud_DrawLargeValue(pos+'208 0', value, 25);

	value = clampf(getstatf(STAT_ARMOR), 999);
	Hud_DrawArmorIcon(pos + '1 0');
	if (stat_items & IT_INVULNERABILITY)
		Hud_DrawLargeValue(pos + '96 0', 666, 999);
	else
		Hud_DrawLargeValue(pos + '96 0', value, 25);

	value = clampf(getstatf(STAT_AMMO), 999);
	Hud_DrawCurrentAmmoIcon(pos + '224 0');
	Hud_DrawLargeValue(pos+'320 0', value, 10);
};

// ================================================================

// INVENTORY BAR

float HUD_FlashTime(float it)
{
	float t = time - itemtimes[it];

	if (t < 1)
		return flash[floor(t*10)];
	else
		return 0;
}

void Hud_DrawSuit(vector pos)
{
	drawpic(pos, strcat(powerupflash[HUD_FlashTime(21)], "suit"), '16 16', '1 1 1', 1, 0);
}
void Hud_DrawInvis(vector pos)
{
	drawpic(pos, strcat(powerupflash[HUD_FlashTime(19)], "invis"), '16 16', '1 1 1', 1, 0);
}
void Hud_DrawInvuln(vector pos)
{
	drawpic(pos, strcat(powerupflash[HUD_FlashTime(20)], "invul"), '16 16', '1 1 1', 1, 0);
}
void Hud_DrawQuad(vector pos)
{
	drawpic(pos, strcat(powerupflash[HUD_FlashTime(22)], "quad"), '16 16', '1 1 1', 1, 0);
}

float Hud_DrawKeys(vector pos, float it)
{
	if (!(stat_items & it))
		return 0;

	string s;
	if (keytype == 2)
		s = "gfx/sb_bkey";
	else if (keytype == 1)
		s = "gfx/sb_rkey";
	else
		s = "gfx/sb_mkey";

	float n = 0;
	if (it == IT_KEY2)
		n = 4;
	n = getstatbits(STAT_KEYCOUNTS, n, 4);
	if (n < 0) n = 0;	// happens in demos where .worldtype isn't increased
	
	if (it == IT_KEY1)
		s = strcat(s, "1");
	if (it == IT_KEY2)
		s = strcat(s, "2");

	drawsubpic(pos, '16 16', s, [n/16, 0], [1/16,1], '1 1 1', 1);
	return n + 1;
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
	
	drawpic(pos, pic, sz, '1 1 1', 1, 0);
};

void Hud_DrawSigils(vector pos)
{
	float pulse;
	if (stat_items2 & 32)
	{
		if (time < itemtimes[23] + 1.5) pulse = 1.2 - 2 * ((time - itemtimes[23]) % 0.5);
		else pulse = 1;
		drawpic(pos, "sb_sigil1", '8 16', '1 1 1', pulse, 0);
	}
	if (stat_items2 & 64)
	{
		if (time < itemtimes[24] + 1.5) pulse = 1.2 - 2 * ((time - itemtimes[24]) % 0.5);
		else pulse = 1;
		drawpic(pos + '9 0', "sb_sigil2", '8 16', '1 1 1', pulse, 0);
	}
	if (stat_items2 & 128)
	{
		if (time < itemtimes[25] + 1.5) pulse = 1.2 - 2 * ((time - itemtimes[25]) % 0.5);
		else pulse = 1;
		drawpic(pos + '16 0', "sb_sigil3", '8 16', '1 1 1', pulse, 0);
	}
	if (stat_items2 & 256)
	{
		if (time < itemtimes[26] + 1.5) pulse = 1.2 - 2 * ((time - itemtimes[26]) % 0.5);
		else pulse = 1;
		drawpic(pos + '24 0', "sb_sigil4", '8 16', '1 1 1', pulse, 0);
	}
}

void Hud_DrawMultiplayerSwatch(vector pos, float p)
{
	drawsubpic(pos, '8 8', "sb_teams", [0, stof(getplayerkeyvalue(p, "topcolor"))/16], [0.5,1/16], '1 1 1', 1);
	drawsubpic(pos, '8 8', "sb_teams", [0.5, stof(getplayerkeyvalue(p, "bottomcolor"))/16], [0.5,1/16], '1 1 1', 1);
}

void Hud_DrawMultiplayer(vector pos, vector offset, float width)
{
	float cnum, p, numclients;
	string cname, frags, lbl, ping;
	float lblw, isdead, clientbit;
	vector ofs;
	
	numclients = coopdata & 15;
	clientbit = 16;
	
	for (cnum = 0; cnum < numclients; cnum++)
	{
		if (width == MP_WIDE)
			p = -1 - cnum;	// sort by frags with the weird negative index
		else
			p = cnum;
		cname = getplayerkeyvalue(p, "name");
		frags = getplayerkeyvalue(p, "frags");
		ping = getplayerkeyvalue(p, "ping");
		
		if (coop)
		{
			lbl = cname;
			isdead = (clientbit & coopdata) == 0;
		}
		else // dm
			lbl = frags;
		
		if (width == MP_NARROW)	// try to cram three letters onto the classic hud
			lbl = substring(lbl, 0, 3);
		else
			lbl = substring(lbl, 0, 8);
		
		lblw = min(64, stringwidth(lbl, TRUE));
		if (width == MP_NARROW)
		{
			if (lblw < 24)
				ofs = '12 0';
			else
				ofs = '8 0';
		}
		else
		{
			ofs = '12 0';
		}
		
		Hud_DrawMultiplayerSwatch(pos, p);
		if (width == MP_WIDE)
		{
			drawstring(pos + '16 0', frags, '8 8', '1 1 1', 1, 0);
			drawstring(pos + '48 0', cname, '8 8', '1 1 1', 1, 0);
			drawstring(pos + '128 0', ping, '8 8', '1 1 1', 1, 0);
		}
		else
			drawstring(pos + ofs, lbl, '8 8', '1 1 1', 1, 0);

		if (isdead)	// cross out the names of the dead in coop
		{
			drawfill(pos + ofs + '0 3', [lblw, 1], '0.8 0 0', 1);
			drawfill(pos + ofs + '0 4', [lblw, 1], '0.6 0 0', 1);
		}
		clientbit *= 2;
		pos += offset;
	}
}

void Hud_DrawIBarWeapons(vector pos)
{
	float currweap = getstatf(STAT_ACTIVEWEAPON);
	float i;
	pos_y += 8;
	for (i = 0; i < 7; i++)
	{
		if (stat_items & weaponflags[i])
			Hud_DrawWeapon(i, pos + '24 0' * i, (currweap == weaponflags[i]));
	}
}

void Hud_DrawIBarPowerups(vector pos)
{
	if (stat_items & IT_SUIT)
		Hud_DrawSuit(pos + '32 0');
	if (stat_items & IT_INVISIBILITY) 
		Hud_DrawInvis(pos);
	if (stat_items & IT_INVULNERABILITY)
		Hud_DrawInvuln(pos + '16 0');
	if (stat_items & IT_QUAD)
		Hud_DrawQuad(pos + '48 0');
}

void Hud_DrawIBar(vector pos)
{
	if (baralpha < 1.0)
	{
		// put these behind the solid bar bc they have an outline
		drawpic(pos + '32 0',  "sb_ammos", '12 12', '1 1 1', 1, 0);
		drawpic(pos + '80 0',  "sb_ammon", '12 12', '1 1 1', 1, 0);
		drawpic(pos + '128 0', "sb_ammor", '12 12', '1 1 1', 1, 0);
		drawpic(pos + '176 0', "sb_ammoc", '12 12', '1 1 1', 1, 0);
	}
	drawpic(pos, "ibar", '320 24', '1 1 1', baralpha, 0);
	
	Hud_DrawAmmoCount(0, pos + '10 0');
	Hud_DrawAmmoCount(1, pos + '58 0');
	Hud_DrawAmmoCount(2, pos + '106 0');
	Hud_DrawAmmoCount(3, pos + '154 0');

	Hud_DrawIBarWeapons(pos);
	Hud_DrawKeys(pos + '192 8', IT_KEY1);
	Hud_DrawKeys(pos + '208 8', IT_KEY2);

	Hud_DrawIBarPowerups(pos + '224 8');
	Hud_DrawSigils(pos + '288 8');
		
	if (!coop && !deathmatch)
		return;

	Hud_DrawMultiplayer(pos + '192 0', '32 0', MP_NARROW);
};

// ================================================================

void Hud_DrawAmmo1(vector pos)
{
	if (baralpha < 1.0)
	{
		// put these behind the solid bar bc they have an outline
		drawpic(pos + '32 0', "sb_ammos", '12 12', '1 1 1', 1, 0);
		drawpic(pos + '80 0', "sb_ammon", '12 12', '1 1 1', 1, 0);
	}
	drawsubpic(pos, '96 10', "ibar", '0 0', '0.3 0.416666666666666', '1 1 1', baralpha);
	Hud_DrawAmmoCount(0, pos + '10 0');
	Hud_DrawAmmoCount(1, pos + '58 0');
}

void Hud_DrawAmmo2(vector pos)
{
	if (baralpha < 1.0)
	{
		// put these behind the solid bar bc they have an outline
		drawpic(pos + '32 0', "sb_ammor", '12 12', '1 1 1', 1, 0);
		drawpic(pos + '80 0', "sb_ammoc", '12 12', '1 1 1', 1, 0);
	}
	drawsubpic(pos, '96 10', "ibar", '0.3 0', '0.3 0.416666666666666', '1 1 1', baralpha);
	Hud_DrawAmmoCount(2, pos + '10 0');
	Hud_DrawAmmoCount(3, pos + '58 0');
}

void Hud_DrawModernLeft(vector pos, float expanded)
{
	float value;
	pos += '0 -24';
	value = clampf(stat_health, 999);
	Hud_DrawHead(pos);
	Hud_DrawLargeValue(pos + '100 0', value, 25);
	
	if (stat_items & IT_INVULNERABILITY || getstatf(STAT_ARMOR) > 0)
	{
		value = clampf(getstatf(STAT_ARMOR), 999);
		pos += '0 -24';
		Hud_DrawArmorIcon(pos);
		if (stat_items & IT_INVULNERABILITY)
			Hud_DrawLargeValue(pos + '100 0', 666, 999);
		else if (getstatf(STAT_ARMOR) > 0)
			Hud_DrawLargeValue(pos + '100 0', value, 25);
	}
	
	if (!expanded)
		return;
	
	pos += '4 -16';
	if (stat_items & IT_SUIT)
	{
		Hud_DrawSuit(pos);
		pos += '0 -16';
	}
	if (stat_items & IT_INVISIBILITY) 
	{
		Hud_DrawInvis(pos);
		pos += '0 -16';
	}
	if (stat_items & IT_INVULNERABILITY)
	{
		Hud_DrawInvuln(pos);
		pos += '0 -16';
	}
	if (stat_items & IT_QUAD)
	{
		Hud_DrawQuad(pos);
	}
	
}

void Hud_DrawModernRight(vector pos, float expanded)
{
	//if (getstatf(STAT_ACTIVEWEAPON) != IT_AXE)
	//{
		Hud_DrawCurrentAmmoIcon(pos + '-24 -24');
		Hud_DrawLargeValue(pos + '-32 -24', clampf(getstatf(STAT_AMMO), 999), 10);
	//}
	
	if (!expanded) return;
	pos += '0 -26';
	if (hudstyle == 2)
	{	
		Hud_DrawAmmo1(pos + '-96 -20');
		Hud_DrawAmmo2(pos + '-96 -10');
		pos += '0 -24';
	}
	
	if (Hud_DrawKeys(pos + '-20 -16', IT_KEY1))
		pos += '0 -16';
	Hud_DrawKeys(pos + '-20 -16', IT_KEY2);
}

void Hud_DrawModernWeapons(vector pos)
{
	pos += '0 -64';
	float currweap = getstatf(STAT_ACTIVEWEAPON);
	float i;
	for (i = 6; i >= 0; i--)
	{
		if (stat_items & weaponflags[i])
		{
			if (currweap == weaponflags[i])
				Hud_DrawWeapon(i, pos + '-24 0', TRUE);
			else
				Hud_DrawWeapon(i, pos + '-16 0', FALSE);
		}
		pos += '0 16';
	}
}

void Hud_DrawModernCenter(vector pos, float expanded)
{
	if ((world.model == "maps/start.bsp" && (stat_items2 & 480)) ||
		(itemtimes[23] && time < itemtimes[23] + 3) ||
		(itemtimes[24] && time < itemtimes[24] + 3) ||
		(itemtimes[25] && time < itemtimes[25] + 3) ||
		(itemtimes[26] && time < itemtimes[26] + 3) )
	{
		drawsubpic(pos + '-16 -32', '32 16', "ibar", '0.9 0.3333333333', '0.1 0.6666666667', '1 1 1', 1);
		Hud_DrawSigils(pos + '-16 -32');
	}
	
	if (hudstyle == 1 && expanded)
	{	
		Hud_DrawAmmo1(pos + '-96 -10');
		Hud_DrawAmmo2(pos + '0 -10');
	}
}

// ================================================================

void Hud_DrawRankings(vector pos)
{
	drawpic(pos + '78 0', "gfx/ranking.lmp", '164 24', '1 1 1', 1);
	
	Hud_DrawMultiplayer(pos + '72 32', '0 12', MP_WIDE);
}

// ================================================================

void() HUD_UpdateStats =
{
	float olditems, olditems2, i, f;
	
	olditems = stat_items;	
	olditems2 = stat_items2;	
	stat_items = getstatbits(STAT_ITEMS, 0, 23);
	stat_items2 = getstatbits(STAT_ITEMS, 23, 9);
	keytype = getstatbits(STAT_KEYCOUNTS, 8, 8);
	coopdata = getstatf(STAT_CLIENTDATA);
	scr_tint = getstatf(STAT_TINTAMOUNT);
	scr_tintcolor_x = getstatf(STAT_TINTCOLOR_R);
	scr_tintcolor_y = getstatf(STAT_TINTCOLOR_G);
	scr_tintcolor_z = getstatf(STAT_TINTCOLOR_B);
		
	skill = cvar("skill");
	// gl_cshiftpercent isn't native to OG quake, so the cvar call fails and returns 0 
	// in winquake/weird engines because the cvar doesn't exist, so use a cvar introduced
	// at the same time to determine if that 0 is valid
	noTint = (cvar("gl_cshiftpercent") < 90) && cvar("gl_farclip");
	
	f = 1;
	for (i = 0; i < 23; i++)
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
	f = 32;
	for (i = 0; i < 4; i++)
	{
		if ((stat_items2 & f) != (olditems2 & f))
		{
			if (stat_items2 & f)
				itemtimes[i + 23] = time;
			else if (olditems2 & f)
				itemtimes[i + 23] = 0;
		}
		f *= 2;
	}
	
	// update health and check for sudden reductions
	f = getstatf(STAT_HEALTH);
	if (stat_health - f > 1)
		paintime = time;	// flinch
	stat_health = f;
	
	// void tint covers the red pain flash when we die so replicate it here
	f = 1 + paintime - time;
	if (f < 0) f = 0;
	f *= f;
	scr_tintcolor_x = 160 * f + (1-f) * scr_tintcolor_x;
	scr_tintcolor_y = 0 + (1-f) * scr_tintcolor_y;
	scr_tintcolor_z = 0 + (1-f) * scr_tintcolor_z;
}

// cover the screen with a full color quad for hud-based fades
void(vector screensize) Hud_DrawTint =
{
	if (!noTint) return;
	
	vector color;
	float f;
	
	f = scr_tint / 255;
	color = scr_tintcolor / 255;

	drawfill('0 0', screensize, color, f, 0);
	
	/*
	vector hpanel, vpanel;
	hpanel_x = screensize_x;
	hpanel_y = screensize_y * 0.55 * f;
	vpanel_x = screensize_x * 0.55 * f;
	vpanel_y = screensize_y;
	
	drawfill('0 0', hpanel, color, 1, 0);
	drawfill(screensize - hpanel, hpanel, color, 1, 0);
	hpanel_x = 0;
	drawfill(hpanel, vpanel, color, 1, 0);
	hpanel_x = screensize_x - vpanel_x;
	drawfill(hpanel, vpanel, color, 1, 0);
	*/
}

void(vector screensize, float scoreboard) CSQC_DrawHud =
{
	if (intermission || coopdata == -1) return;
	float viewsize = cvar("viewsize");
	HUD_UpdateStats();
	Hud_DrawTint(screensize);
	
	if (viewsize > 110)
		return;

	vector pos;
	baralpha = cvar("scr_sbaralpha");
	hudstyle = max(cvar("saved1"), cvar("hudstyle"));	// catch ironwail hud cvar
	float margin, exp;

	exp = (viewsize <= 100);

	if (hudstyle)
	{
		margin = 4 * (floor(screensize_y / 120) - 1);
		
		if (scoreboard || stat_health <= 0)
		{
			Hud_DrawLevelInfoBar([screensize_x / 2, screensize_y] - '160 24');
			if (deathmatch)
			{
				Hud_DrawRankings([screensize_x / 2 - 160, screensize_y / 2 - 120]);
			}
			else if (screensize_x >= 500 && stat_health > 0)
			{
				Hud_DrawModernLeft([margin, screensize_y - margin], exp);
				Hud_DrawModernRight([screensize_x - margin, screensize_y - margin], exp);
			}
		}
		else
		{
			Hud_DrawModernLeft([margin, screensize_y - margin], exp);
			Hud_DrawModernCenter([screensize_x / 2, screensize_y - margin], exp);
			Hud_DrawModernRight([screensize_x - margin, screensize_y - margin], exp);
		}
		if (exp)
		{
			if ((deathmatch && !(scoreboard || stat_health <= 0)) || coop)
				Hud_DrawMultiplayer([margin, floor(screensize_y * 0.3)], '0 12', MP_MEDIUM);
			Hud_DrawModernWeapons([screensize_x, floor(screensize_y * 0.4)]);
		}		
	}
	else
	{
		pos = screensize;
		pos_x = screensize_x / 2;
		if (scoreboard || stat_health <= 0)
		{
			Hud_DrawLevelInfoBar(pos - '160 24');
			if (coop || deathmatch)
				Hud_DrawRankings([screensize_x / 2 - 160, screensize_y / 2 - 120]);
		}
		else
			Hud_DrawSBar(pos - '160 24');
		
		if (exp)
			Hud_DrawIBar(pos - '160 48');
	}
	
};

// ================================================================

// INTERMISSION

void(vector screensize, float scoreboard) CSQC_DrawScores =
{
	if (!intermission || coopdata == -1) return;
	vector pos, div;
	float value, mins, secs;
	string s;
	
	HUD_UpdateStats();
	pos = [screensize_x / 2 - 160, screensize_y / 2 - 120];
	
	if (deathmatch)
	{
		Hud_DrawRankings(pos);
		return;
	}
	
	drawpic(pos + '64 0', "gfx/complete.lmp", '196 24', '1 1 1', 1);

	s = strcat(world.message, " (", mapname, ")");
	Hud_ScrollTextBox(pos + '2 26', 0, 0, 320, 8, 8, s);
	if (skill == 0)
		drawstring(pos + '144 36', "Easy", '8 8', '1 1 1', 1, 0);
	if (skill == 1)
		drawstring(pos + '136 36', "Normal", '8 8', '1 1 1', 1, 0);
	if (skill == 2)
		drawstring(pos + '144 36', "Hard", '8 8', '1 1 1', 1, 0);
	if (skill == 3)
		drawstring(pos + '126 36', "\bNightmare\b", '8 8', '1 1 1', 1, 0);

	mins = floor(intermission_time / 60);
	secs = floor(intermission_time - mins * 60);

	pos += '12 0';
	div = '200 0';
	value = max(clampf(getstatf(STAT_MONSTERS), 9999), clampf(getstatf(STAT_SECRETS), 9999));
	value = max(value, mins);
	
	if (value > 9)
	{
		pos -= '12 0';
		div += '24 0';
	}
	if (value > 99)
	{
		pos -= '12 0';
		div += '24 0';
	}
	if (value > 999)
	{
		pos -= '12 0';
		div += '24 0';
	}
	
	// kills
	pos += '0 56';
	drawsubpic(pos + '51 2', '96 24', "gfx/inter.lmp", [8/160, 88/144], [96/160, 24/144], '1 1 1', 1);
	
	value = clampf(getstatf(STAT_MONSTERS), 9999);
	Hud_DrawLargeValue(pos+div, value, -1);
	drawpic(pos+div, "num_slash", '16 24', '1 1 1', 1);
	value = clampf(getstatf(STAT_TOTALMONSTERS), 9999);
	Hud_DrawLargeValue(pos+div + '16 0', value, -1, TRUE);
	
	// secrets
	pos += '0 36';
	drawsubpic(pos + '8 2', '136 24', "gfx/inter.lmp", [8/160, 48/144], [136/160, 24/144], '1 1 1', 1);
	
	value = clampf(getstatf(STAT_SECRETS), 9999);
	Hud_DrawLargeValue(pos+div, value, -1);
	drawpic(pos+div, "num_slash", '16 24', '1 1 1', 1);
	value = clampf(getstatf(STAT_TOTALSECRETS), 9999);
	Hud_DrawLargeValue(pos+div + '16 0', value, -1, TRUE);
	
	// time
	pos += '0 36';
	drawsubpic(pos + '67 2', '80 24', "gfx/inter.lmp", [8/160, 8/144], [80/160, 24/144], '1 1 1', 1);
	
	mins = clampf(mins, 999);
	Hud_DrawLargeValue(pos+div, mins, -1);
	drawpic(pos+div, "num_colon", '16 24', '1 1 1', 1);
	Hud_DrawLargeValue(pos+div + '16 0', secs, -1, TRUE, 2);
	
	if (coop)
		Hud_DrawMultiplayer(pos + '72 40', '0 12', MP_WIDE);
}

// ================================================================

void() Hud_Init
{
	float i;
	for (i = 0; i < 10; i++)
	{
		precache_pic(number[i], TRUE);
		precache_pic(anumber[i], TRUE);
	}
	for (i = 0; i < 6; i++)
	{
		precache_pic(strcat(powerupflash[i], "invis"), TRUE);
		precache_pic(strcat(powerupflash[i], "invul"), TRUE);
		precache_pic(strcat(powerupflash[i], "suit"), TRUE);
		precache_pic(strcat(powerupflash[i], "quad"), TRUE);
	}
	
	precache_pic("gfx/sb_mkey1", TRUE);
	precache_pic("gfx/sb_mkey2", TRUE);
	precache_pic("gfx/sb_rkey1", TRUE);
	precache_pic("gfx/sb_rkey2", TRUE);
	precache_pic("gfx/sb_bkey1", TRUE);
	precache_pic("gfx/sb_bkey2", TRUE);

	precache_pic("sbar", TRUE);
	/*
	// looking left and right frames - art not complete yet
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
	*/
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

	precache_pic("sb_ammos", TRUE);
	precache_pic("sb_ammoc", TRUE);
	precache_pic("sb_ammon", TRUE);
	precache_pic("sb_ammor", TRUE);
	
	precache_pic("sb_teams", TRUE);
	
	precache_pic("gfx/complete.lmp", FALSE);
	
	paintime = -1;
	lookseed = floor(random() * 100);

	//if (cvar("pr_checkextension"))
	//	if (checkextension("EXT_CSQC"))
	//		globalStatSupported = TRUE;
};

void(float apilevel, string enginename, float engineversion) CSQC_Init = {
	checkextension("FRIK_FILE");
	checkextension("FTE_STRINGS");
	Hud_Init();
}
