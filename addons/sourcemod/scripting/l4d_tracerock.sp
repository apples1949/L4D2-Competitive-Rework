#pragma semicolon 1
#pragma newdecls required	 //強制1.7以後的新語法

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <sdktools_functions>

#define FilterSelf				 0
#define FilterSelfAndPlayer		 1
#define FilterSelfAndSurvivor	 2
#define FilterSelfAndInfected	 3
#define FilterSelfAndPlayerAndCI 4

#define SurvivorTeam			 2
#define InfectedTeam			 3
#define MissileTeam				 1

#define IsTank(%1)				(1 <= %1 <= MaxClients && IsClientInGame(%1) && !IsFakeClient(%1) && GetClientTeam(%1) == 3	&& GetEntProp(%1, Prop_Send, "m_zombieClass") == 8)

ConVar l4d_tracerock_enable;

ConVar l4d_tracerock_speed;
ConVar l4d_tracerock_Glow_Type;
ConVar l4d_tracerock_Glow_Range;
ConVar l4d_tracerock_Glow_Color;
ConVar l4d_tracerock_Glow_Flashing;
ConVar l4d_tracerock_ClearTime;
ConVar l4d_tracerock_TraceInterval;

int	   g_iVelocity;
float  g_fRockTraceTime[2048 + 1];

int	   ColorRed;
int	   ColorGreen;
int	   ColorBlue;
int	   ColorPurple;
int	   ColorCyan;
int	   ColorOrange;
int	   ColorWhite;
int	   ColorPink;
int	   ColorLime;
int	   ColorMaroon;
int	   ColorTeal;
int	   ColorYellow;
int	   ColorGrey;

public Plugin myinfo =
{
	name		= "Tank Trace Rock",
	author		= "",
	description = ".",
	version		= "1.3",
	url			= ""

}

bool		  L4D2Version;
GlobalForward g_hForwardTraceRock;

forward void  L4D_OnTraceRockCreated(int client, int &trace);

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion test = GetEngineVersion();

	if (test == Engine_Left4Dead)
	{
		L4D2Version = false;
	}
	else if (test == Engine_Left4Dead2)
	{
		L4D2Version = true;
	}
	else
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 1 & 2.");
		return APLRes_SilentFailure;
	}
	RegPluginLibrary("L4D_OnTraceRockCreated");
	g_hForwardTraceRock = new GlobalForward("L4D_OnTraceRockCreated", ET_Event, Param_Cell, Param_CellByRef);
	return APLRes_Success;
}

public void OnPluginStart()
{
	g_iVelocity			 = FindSendPropInfo("CBasePlayer", "m_vecVelocity[0]");
	l4d_tracerock_enable = CreateConVar("l4d_tracerock_enable", "1", " 0=Disable, 1=Enable this plugin ", FCVAR_NOTIFY, true, 0.0, true, 1.0);

	l4d_tracerock_speed	 = CreateConVar("l4d_tracerock_speed", "650", "Trace rock's speed", FCVAR_NOTIFY, true, 0.0);

	if (L4D2Version)
	{
		l4d_tracerock_Glow_Type		= CreateConVar("l4d_tracerock_glow_type", "0", "设置跟踪岩石的发光类型。0 =关闭，1 =使用（效果不好），2 =观看（效果不好），3 =恒定（效果更好）", FCVAR_NOTIFY, true, 0.0, true, 3.0);
		l4d_tracerock_Glow_Range	= CreateConVar("l4d_tracerock_glow_range", "1500", "Set trace rock's glow range", FCVAR_NOTIFY, true, 0.0);
		l4d_tracerock_Glow_Color	= CreateConVar("l4d_tracerock_glow_color", "-1 -1 -1", "设置跟踪岩石的发光颜色。RGB颜色255-红绿色蓝。[-1 -1 -1：随机]", FCVAR_NOTIFY);
		l4d_tracerock_Glow_Flashing = CreateConVar("l4d_tracerock_glow_flashing", "1", "在发光的岩石上添加闪烁效果。（0 =关闭，1 =打开）", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	}
	l4d_tracerock_ClearTime		= CreateConVar("l4d_tracerock_kill", "30.0", "设置跟踪岩石的自毁时间.", FCVAR_NOTIFY, true, 0.0);
	l4d_tracerock_TraceInterval = CreateConVar("l4d_tracerock_time_interval", "0.1", "跟踪岩石更新时间间隔.", FCVAR_NOTIFY, true, 0.0);
	//AutoExecConfig(true, "l4d_tracerock");

	GetCvars();
	l4d_tracerock_enable.AddChangeHook(ConVarChanged_Cvars);

	l4d_tracerock_speed.AddChangeHook(ConVarChanged_Cvars);
	if (L4D2Version)
	{
		l4d_tracerock_Glow_Type.AddChangeHook(ConVarChanged_Cvars);
		l4d_tracerock_Glow_Range.AddChangeHook(ConVarChanged_Cvars);
		l4d_tracerock_Glow_Color.AddChangeHook(ConVarChanged_Cvars);
	}
	l4d_tracerock_ClearTime.AddChangeHook(ConVarChanged_Cvars);
	l4d_tracerock_TraceInterval.AddChangeHook(ConVarChanged_Cvars);

	SetRandomColor();
}

public void ConVarChanged_Cvars(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
}

bool  bl4d_tracerock_enable, bl4d_tracerock_Glow_Flashing;
int	  il4d_tracerock_Glow_Range, il4d_tracerock_Glow_Type;
float fl4d_tracerock_speed, fl4d_tracerock_ClearTime, fl4d_tracerock_TraceInterval;
char  g_sCvarCols[12];
int	  g_iCvarCols;
void  GetCvars()
{
	bl4d_tracerock_enable = l4d_tracerock_enable.BoolValue;
	fl4d_tracerock_speed  = l4d_tracerock_speed.FloatValue;
	if (L4D2Version)
	{
		il4d_tracerock_Glow_Type	 = l4d_tracerock_Glow_Type.IntValue;
		il4d_tracerock_Glow_Range	 = l4d_tracerock_Glow_Range.IntValue;
		bl4d_tracerock_Glow_Flashing = l4d_tracerock_Glow_Flashing.BoolValue;
		l4d_tracerock_Glow_Color.GetString(g_sCvarCols, sizeof(g_sCvarCols));
		g_iCvarCols = GetColor(g_sCvarCols);
	}
	fl4d_tracerock_ClearTime	 = l4d_tracerock_ClearTime.FloatValue;
	fl4d_tracerock_TraceInterval = l4d_tracerock_TraceInterval.FloatValue;
}

public void OnMapStart()
{
	if (L4D2Version)
	{
		PrecacheModel("materials/sprites/laserbeam.vmt");
	}
	else
	{
		PrecacheModel("materials/sprites/laser.vmt");
	}
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (bl4d_tracerock_enable == false) return;

	if (strcmp(classname, "tank_rock") == 0)
	{
		SDKHook(entity, SDKHook_SpawnPost, OnRockpSpawn);
	}
}

void OnRockpSpawn(int rock)
{
	int owner = GetEntPropEnt(rock, Prop_Data, "m_hOwnerEntity");
	if (IsTank(owner))
	{
		int trace;
		Call_StartForward(g_hForwardTraceRock);
		Call_PushCell(owner);
		Call_PushCellRef(trace);
		Call_Finish();

		if (trace) CreateTimer(0.8, StartTimer, EntIndexToEntRef(rock), TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action StartTimer(Handle timer, any ref)
{
	int entity;
	if (ref && (entity = EntRefToEntIndex(ref)) != INVALID_ENT_REFERENCE)
	{
		if (GetEntProp(entity, Prop_Send, "m_iTeamNum") >= 0)
		{
			StartRockTrace(entity);
		}
	}

	return Plugin_Continue;
}
void StartRockTrace(int ent)
{
	g_fRockTraceTime[ent] = 0.0;
	SDKHook(ent, SDKHook_Think, PreThink);

	if (L4D2Version)
	{
		SetEntProp(ent, Prop_Send, "m_iGlowType", il4d_tracerock_Glow_Type);
		SetEntProp(ent, Prop_Send, "m_nGlowRange", il4d_tracerock_Glow_Range);
		SetEntProp(ent, Prop_Send, "m_bFlashing", bl4d_tracerock_Glow_Flashing);

		int iTempColor;
		if (strcmp(g_sCvarCols, "-1 -1 -1", false) == 0)
		{
			int iRandom = GetRandomInt(1, 13);
			switch (iRandom)
			{
				case 1: iTempColor = ColorRed;
				case 2: iTempColor = ColorGreen;
				case 3: iTempColor = ColorBlue;
				case 4: iTempColor = ColorPurple;
				case 5: iTempColor = ColorCyan;
				case 6: iTempColor = ColorOrange;
				case 7: iTempColor = ColorWhite;
				case 8: iTempColor = ColorPink;
				case 9: iTempColor = ColorLime;
				case 10: iTempColor = ColorMaroon;
				case 11: iTempColor = ColorTeal;
				case 12: iTempColor = ColorYellow;
				case 13: iTempColor = ColorGrey;
			}
		}
		else
		{
			iTempColor = g_iCvarCols;
		}

		SetEntProp(ent, Prop_Send, "m_glowColorOverride", iTempColor);
	}

	CreateTimer(fl4d_tracerock_ClearTime, Timer_KillRock, EntIndexToEntRef(ent), TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_KillRock(Handle timer, int ref)
{
	if (ref && EntRefToEntIndex(ref) != INVALID_ENT_REFERENCE)
	{
		SetEntityRenderFx(ref, RENDERFX_FADE_FAST);	   // RENDERFX_FADE_SLOW 3.5
		CreateTimer(1.5, _KillEntity, ref, TIMER_FLAG_NO_MAPCHANGE);
	}

	return Plugin_Continue;
}

public Action _KillEntity(Handle timer, int ref)
{
	if (ref && EntRefToEntIndex(ref) != INVALID_ENT_REFERENCE)
	{
		RemoveEntity(ref);
	}

	return Plugin_Continue;
}

public void PreThink(int ent)
{
	TraceMissile(ent, 0.05);
}

void TraceMissile(int ent, float duration)
{
	if (GetEngineTime() - g_fRockTraceTime[ent] < fl4d_tracerock_TraceInterval) return;
	g_fRockTraceTime[ent] = GetEngineTime();

	static float velocitymissile[3];
	GetEntDataVector(ent, g_iVelocity, velocitymissile);
	// if(GetVectorLength(velocitymissile) < 50.0) return;

	static float posmissile[3];
	GetEntPropVector(ent, Prop_Send, "m_vecOrigin", posmissile);

	NormalizeVector(velocitymissile, velocitymissile);

	int			 enemy = GetEnemy(posmissile, velocitymissile);

	static float velocityenemy[3];
	static float vtrace[3];

	vtrace[0] = vtrace[1] = vtrace[2] = 0.0;
	bool		 visible			  = false;
	static float missionangle[3];

	float		 disenemy = 1000.0;

	// PrintToChatAll("%d rock traces %N", ent, enemy);

	if (enemy > 0)
	{
		static float posenemy[3];
		GetClientEyePosition(enemy, posenemy);

		disenemy = GetVectorDistance(posmissile, posenemy);

		visible	 = IfTwoPosVisible(posmissile, posenemy, ent);

		// if(visible)PrintToChatAll("%N visible %f ", client, disenemy);
		GetEntDataVector(enemy, g_iVelocity, velocityenemy);

		ScaleVector(velocityenemy, duration);

		AddVectors(posenemy, velocityenemy, posenemy);
		MakeVectorFromPoints(posmissile, posenemy, vtrace);
		// PrintToChatAll("%N lock %N D:%f", client,enemy, disenemy);
	}

	////////////////////////////////////////////////////////////////////////////////////
	GetVectorAngles(velocitymissile, missionangle);

	static float vleft[3];
	static float vright[3];
	static float vup[3];
	static float vdown[3];
	static float vfront[3];
	static float vv1[3];
	static float vv2[3];
	static float vv3[3];
	static float vv4[3];
	static float vv5[3];
	static float vv6[3];
	static float vv7[3];
	static float vv8[3];

	vfront[0] = vfront[1] = vfront[2] = 0.0;

	float factor2					  = 0.5;
	float factor1					  = 0.2;
	float t;
	float base = 1500.0;
	if (visible)
	{
		base = 80.0;
	}
	{
		// PrintToChatAll("%f %f %f %f %f",front, up, down, left, right);
		int	  flag	= FilterSelfAndSurvivor;
		int	  self	= ent;
		float front = CalRay(posmissile, missionangle, 0.0, 0.0, vfront, self, flag);
		// float disobstacle=CalRay(posmissile, missionangle, 0.0, 0.0, vfront, self, FilterSelf);

		float down	= CalRay(posmissile, missionangle, 90.0, 0.0, vdown, self, flag);
		float up	= CalRay(posmissile, missionangle, -90.0, 0.0, vup, self);
		float left	= CalRay(posmissile, missionangle, 0.0, 90.0, vleft, self, flag);
		float right = CalRay(posmissile, missionangle, 0.0, -90.0, vright, self, flag);

		float f1	= CalRay(posmissile, missionangle, 30.0, 0.0, vv1, self, flag);
		float f2	= CalRay(posmissile, missionangle, 30.0, 45.0, vv2, self, flag);
		float f3	= CalRay(posmissile, missionangle, 0.0, 45.0, vv3, self, flag);
		float f4	= CalRay(posmissile, missionangle, -30.0, 45.0, vv4, self, flag);
		float f5	= CalRay(posmissile, missionangle, -30.0, 0.0, vv5, self, flag);
		float f6	= CalRay(posmissile, missionangle, -30.0, -45.0, vv6, self, flag);
		float f7	= CalRay(posmissile, missionangle, 0.0, -45.0, vv7, self, flag);
		float f8	= CalRay(posmissile, missionangle, 30.0, -45.0, vv8, self, flag);

		NormalizeVector(vfront, vfront);
		NormalizeVector(vup, vup);
		NormalizeVector(vdown, vdown);
		NormalizeVector(vleft, vleft);
		NormalizeVector(vright, vright);
		NormalizeVector(vtrace, vtrace);

		NormalizeVector(vv1, vv1);
		NormalizeVector(vv2, vv2);
		NormalizeVector(vv3, vv3);
		NormalizeVector(vv4, vv4);
		NormalizeVector(vv5, vv5);
		NormalizeVector(vv6, vv6);
		NormalizeVector(vv7, vv7);
		NormalizeVector(vv8, vv8);

		if (front > base) front = base;
		if (up > base) up = base;
		if (down > base) down = base;
		if (left > base) left = base;
		if (right > base) right = base;

		if (f1 > base) f1 = base;
		if (f2 > base) f2 = base;
		if (f3 > base) f3 = base;
		if (f4 > base) f4 = base;
		if (f5 > base) f5 = base;
		if (f6 > base) f6 = base;
		if (f7 > base) f7 = base;
		if (f8 > base) f8 = base;

		t = -1.0 * factor1 * (base - front) / base;
		ScaleVector(vfront, t);

		t = -1.0 * factor1 * (base - up) / base;
		ScaleVector(vup, t);

		t = -1.0 * factor1 * (base - down) / base;
		ScaleVector(vdown, t);

		t = -1.0 * factor1 * (base - left) / base;
		ScaleVector(vleft, t);

		t = -1.0 * factor1 * (base - right) / base;
		ScaleVector(vright, t);

		t = -1.0 * factor1 * (base - f1) / f1;
		ScaleVector(vv1, t);

		t = -1.0 * factor1 * (base - f2) / f2;
		ScaleVector(vv2, t);

		t = -1.0 * factor1 * (base - f3) / f3;
		ScaleVector(vv3, t);

		t = -1.0 * factor1 * (base - f4) / f4;
		ScaleVector(vv4, t);

		t = -1.0 * factor1 * (base - f5) / f5;
		ScaleVector(vv5, t);

		t = -1.0 * factor1 * (base - f6) / f6;
		ScaleVector(vv6, t);

		t = -1.0 * factor1 * (base - f7) / f7;
		ScaleVector(vv7, t);

		t = -1.0 * factor1 * (base - f8) / f8;
		ScaleVector(vv8, t);

		if (disenemy >= 500.0) disenemy = 500.0;
		t = 1.0 * factor2 * (1000.0 - disenemy) / 500.0;
		ScaleVector(vtrace, t);

		AddVectors(vfront, vup, vfront);
		AddVectors(vfront, vdown, vfront);
		AddVectors(vfront, vleft, vfront);
		AddVectors(vfront, vright, vfront);

		AddVectors(vfront, vv1, vfront);
		AddVectors(vfront, vv2, vfront);
		AddVectors(vfront, vv3, vfront);
		AddVectors(vfront, vv4, vfront);
		AddVectors(vfront, vv5, vfront);
		AddVectors(vfront, vv6, vfront);
		AddVectors(vfront, vv7, vfront);
		AddVectors(vfront, vv8, vfront);

		AddVectors(vfront, vtrace, vfront);
		NormalizeVector(vfront, vfront);
	}

	float a	   = GetAngle(vfront, velocitymissile);
	float amax = 3.14159 * duration * 1.5;

	if (a > amax) a = amax;

	ScaleVector(vfront, a);

	// PrintToChat(client, "max %f %f  ",amax , a);
	float newvelocitymissile[3];
	AddVectors(velocitymissile, vfront, newvelocitymissile);

	float speed = fl4d_tracerock_speed;
	if (speed < 60.0) speed = 60.0;
	NormalizeVector(newvelocitymissile, newvelocitymissile);
	ScaleVector(newvelocitymissile, speed);

	SetEntityGravity(ent, 0.01);
	TeleportEntity(ent, NULL_VECTOR, NULL_VECTOR, newvelocitymissile);
}

int GetEnemy(float pos[3], float vec[3])
{
	float min = 4.0;
	float pos2[3];
	float t;
	int	  s = 0;

	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && GetClientTeam(client) == 2 && IsPlayerAlive(client) && !IsPlayerIncapOrHanging(client))
		{
			GetClientEyePosition(client, pos2);
			MakeVectorFromPoints(pos, pos2, pos2);
			t = GetAngle(vec, pos2);
			// PrintToChatAll("%N %f", client, 360.0*t/3.1415926/2.0);
			if (t <= min)
			{
				min = t;
				s	= client;
			}
		}
	}
	return s;
}
void CopyVector(float source[3], float target[3])
{
	target[0] = source[0];
	target[1] = source[1];
	target[2] = source[2];
}

bool IfTwoPosVisible(float pos1[3], float pos2[3], int self)
{
	bool   r = true;
	Handle trace;
	trace = TR_TraceRayFilterEx(pos2, pos1, MASK_SOLID, RayType_EndPoint, DontHitSelfAndSurvivor, self);
	if (TR_DidHit(trace))
	{
		r = false;
	}
	delete trace;
	return r;
}

float CalRay(float posmissile[3], float angle[3], float offset1, float offset2, float force[3], int ent, int flag = FilterSelf)
{
	float ang[3];
	CopyVector(angle, ang);
	ang[0] += offset1;
	ang[1] += offset2;
	GetAngleVectors(ang, force, NULL_VECTOR, NULL_VECTOR);
	float dis = GetRayDistance(posmissile, ang, ent, flag);
	// PrintToChatAll("%f %f, %f", dis, offset1, offset2);
	return dis;
}

float GetAngle(float x1[3], float x2[3])
{
	return ArcCosine(GetVectorDotProduct(x1, x2) / (GetVectorLength(x1) * GetVectorLength(x2)));
}

public bool DontHitSelf(int entity, int mask, any data)
{
	if (entity == data)
	{
		return false;
	}
	return true;
}

public bool DontHitSelfAndPlayer(int entity, int mask, any data)
{
	if (entity == data)
	{
		return false;
	}
	else if (entity > 0 && entity <= MaxClients)
	{
		if (IsClientInGame(entity))
		{
			return false;
		}
	}
	return true;
}

public bool DontHitSelfAndPlayerAndCI(int entity, int mask, any data)
{
	if (entity == data)
	{
		return false;
	}
	else if (entity > 0 && entity <= MaxClients)
	{
		if (IsClientInGame(entity))
		{
			return false;
		}
	}
	else
	{
		if (IsValidEntity(entity) && IsValidEdict(entity))
		{
			static char edictname[128];
			GetEdictClassname(entity, edictname, 128);
			if (StrContains(edictname, "infected") >= 0)
			{
				return false;
			}
		}
	}
	return true;
}

public bool DontHitSelfAndMissile(int entity, int mask, any data)
{
	if (entity == data)
	{
		return false;
	}
	else if (entity > MaxClients)
	{
		if (IsValidEntity(entity) && IsValidEdict(entity))
		{
			static char edictname[128];
			GetEdictClassname(entity, edictname, 128);
			if (StrContains(edictname, "prop_dynamic") >= 0)
			{
				return false;
			}
		}
	}
	return true;
}

public bool DontHitSelfAndSurvivor(int entity, int mask, any data)
{
	if (entity == data)
	{
		return false;
	}
	else if (entity > 0 && entity <= MaxClients)
	{
		if (IsClientInGame(entity) && GetClientTeam(entity) == 2 && !IsPlayerIncapOrHanging(entity))
		{
			return false;
		}
	}
	return true;
}

public bool DontHitSelfAndInfected(int entity, int mask, any data)
{
	if (entity == data)
	{
		return false;
	}
	else if (entity > 0 && entity <= MaxClients)
	{
		if (IsClientInGame(entity) && GetClientTeam(entity) == 3)
		{
			return false;
		}
	}
	return true;
}
float GetRayDistance(float pos[3], float angle[3], int self, int flag)
{
	float hitpos[3];
	GetRayHitPos(pos, angle, hitpos, self, flag);
	return GetVectorDistance(pos, hitpos);
}

int GetRayHitPos(float pos[3], float angle[3], float hitpos[3], int self, int flag)
{
	Handle trace;
	int	   hit = 0;
	if (flag == FilterSelf)
	{
		trace = TR_TraceRayFilterEx(pos, angle, MASK_SOLID, RayType_Infinite, DontHitSelf, self);
	}
	else if (flag == FilterSelfAndPlayer)
	{
		trace = TR_TraceRayFilterEx(pos, angle, MASK_SOLID, RayType_Infinite, DontHitSelfAndPlayer, self);
	}
	else if (flag == FilterSelfAndSurvivor)
	{
		trace = TR_TraceRayFilterEx(pos, angle, MASK_SOLID, RayType_Infinite, DontHitSelfAndSurvivor, self);
	}
	else if (flag == FilterSelfAndInfected)
	{
		trace = TR_TraceRayFilterEx(pos, angle, MASK_SOLID, RayType_Infinite, DontHitSelfAndInfected, self);
	}
	else if (flag == FilterSelfAndPlayerAndCI)
	{
		trace = TR_TraceRayFilterEx(pos, angle, MASK_SOLID, RayType_Infinite, DontHitSelfAndPlayerAndCI, self);
	}
	if (TR_DidHit(trace))
	{
		TR_GetEndPosition(hitpos, trace);
		hit = TR_GetEntityIndex(trace);
	}
	delete trace;
	return hit;
}
int GetColor(char[] sTemp)
{
	if (strcmp(sTemp, "-1 -1 -1", false) == 0) return 0;

	if (sTemp[0] == 0)
		return 0;

	char sColors[3][4];
	int	 color = ExplodeString(sTemp, " ", sColors, sizeof(sColors), sizeof(sColors[]));

	if (color != 3)
		return 0;

	color = StringToInt(sColors[0]);
	color += 256 * StringToInt(sColors[1]);
	color += 65536 * StringToInt(sColors[2]);

	return color;
}

bool IsPlayerIncapOrHanging(int client)
{
	if (GetEntProp(client, Prop_Send, "m_isIncapacitated"))
		return true;
	if (GetEntProp(client, Prop_Send, "m_isHangingFromLedge"))
		return true;

	return false;
}

void SetRandomColor()
{
	ColorRed	= GetColor("255 0 0");
	ColorGreen	= GetColor("0 255 0");
	ColorBlue	= GetColor("0 0 255");
	ColorPurple = GetColor("155 0 255");
	ColorCyan	= GetColor("0 255 255");
	ColorOrange = GetColor("255 155 0");
	ColorWhite	= GetColor("255 255 255");
	ColorPink	= GetColor("255 0 150");
	ColorLime	= GetColor("128 255 0");
	ColorMaroon = GetColor("128 0 0");
	ColorTeal	= GetColor("0 128 128");
	ColorYellow = GetColor("255 255 0");
	ColorGrey	= GetColor("50 50 50");
}