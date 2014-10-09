/*
[TF2] Throw Sapper
Allows you to throw a sapper, sapping buildings around it.
By: Chdata

Credits to the creator playpoints from which I used sapper code from.
-Tak (Chaosxk)

Also credits to the maker of the RMF ability pack, from which playpoints was probably made from.
-RIKUSYO

*/

#pragma semicolon 1

#include <sourcemod>
#include <tf2>
#include <tf2_stocks>

#define PLUGIN_VERSION "0x05"

//#define MDL_THROW_SAPPER "models/weapons/c_models/c_sapper/c_sapper.mdl" //Sadly, this conflicts with some custom skins or something
#define MDL_SAPPER   "models/weapons/w_models/w_sapper.mdl"
#define MDL_RECORDER "models/weapons/w_models/w_sd_sapper.mdl"
#define MDL_WHEATLEY "models/weapons/c_models/c_p2rec/c_p2rec.mdl"
#define MDL_FESTIVE  "models/weapons/c_models/c_sapper/c_sapper_xmas.mdl"
#define MDL_BREAD    "models/weapons/c_models/c_breadmonster_sapper/c_breadmonster_sapper.mdl"
#define SOUND_BOOT "weapons/weapon_crit_charged_on.wav"
#define SOUND_SAPPER_REMOVED "weapons/sapper_removed.wav"
#define SOUND_SAPPER_THROW "weapons/knife_swing.wav"
#define SOUND_SAPPER_NOISE "weapons/sapper_timer.wav"
#define SOUND_SAPPER_NOISE2 "player/invulnerable_off.wav"
#define SOUND_SAPPER_PLANT "weapons/sapper_plant.wav"
//#define SOUND_SAPPER_DENY "tools/ifm/ifm_denyundo.wav"
#define EFFECT_TRAIL_RED "stunballtrail_red_crit"
#define EFFECT_TRAIL_BLU "stunballtrail_blue_crit"
#define EFFECT_CORE_FLASH "sapper_coreflash"
#define EFFECT_DEBRIS "sapper_debris"
#define EFFECT_FLASH "sapper_flash"
#define EFFECT_FLASHUP "sapper_flashup"
#define EFFECT_FLYINGEMBERS "sapper_flyingembers"
#define EFFECT_SMOKE "sapper_smoke"
#define EFFECT_SENTRY_FX "sapper_sentry1_fx"
#define EFFECT_SENTRY_SPARKS1 "sapper_sentry1_sparks1"
#define EFFECT_SENTRY_SPARKS2 "sapper_sentry1_sparks2"
#define SPRITE_ELECTRIC_WAVE "sprites/laser.vmt"

#define MAX_TARGET_BUILDING (MAXPLAYERS-1)*4 //31 x 4

//#define TEAM_SPEC	0
#define TEAM_RED	2
#define TEAM_BLU	3

/*
#define SOUND_RECORDER_NOISE "weapons/spy_tape_0" X.wav" X = 1-5
#define SOUND_WHEATLEY_NOISE "vo/items/wheatley_sapper/wheatley_sapper_hacking" XX.wav" XX = 02-37

#define SOUND_SAPPER_PLANT "vo/items/wheatley_sapper/wheatley_sapper_pulledout" XX.wav" XX = 01-09 || 11-14 || 16 || 18-26 || 29 || 36-41 || 44 || 46 || 59-60 || 64
#define SOUND_SAPPER_PLANT2 "vo/items/wheatley_sapper/wheatley_sapper_attached" XX.wav" XX = 05-06 || 09-10 || 13-14 || 16 || 18-20 || 22-23 || 26

#define SOUND_WHEATLEY_REMOVED "vo/items/wheatley_sapper/wheatley_sapper_putback" XX.wav" XX = 01-11 || 12, 15, 17, 20 || 22-24 || 26-27 || 37, 44 || 47-50 || 53

new VoiceOffset = GetRandomInt(2, 37);
decl String:s[PLATFORM_MAX_PATH];
decl String:z[4];

if (VoiceOffset >= 10) Format(z, sizeof(z), "%i", VoiceOffset);
else Format(z, sizeof(z), "0%i", VoiceOffset);

Format(s, PLATFORM_MAX_PATH, "vo/items/wheatley_sapper/wheatley_sapper_hacking%s.wav", z);
*/

new bool:Enabled;
new g_EffectSprite;
//new g_CalCharge[MAXPLAYERS + 1];										//Holds the charge amount for being able to throw a sapper.
new g_SapperModel[MAXPLAYERS + 1];										//Holds the entity index of spawned sappers.
new g_iTargetBuilding[MAXPLAYERS + 1][MAX_TARGET_BUILDING];				//Holds the entity index of buildings targetted by a sapper.

new Handle:cvarEnabled = INVALID_HANDLE;
new Handle:cvarSapRadius = INVALID_HANDLE;

//new Handle:tChargeTimer[MAXPLAYERS + 1] = INVALID_HANDLE;
new Handle:tTimerLoop[MAXPLAYERS + 1] = INVALID_HANDLE;
//new Handle:hHudCharge = INVALID_HANDLE;

public Plugin:myinfo =
{
	name = "[TF2] Throwsap",
	description = "Throw your sapper!",
	author = "Chdata",
	version = PLUGIN_VERSION,
	url = "http://steamcommunity.com/groups/tf2data"
};

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	new String:Game[32];
	GetGameFolderName(Game, sizeof(Game));
	if (!StrEqual(Game, "tf"))
	{
		Format(error, err_max, "[throwsap] This plugin only works for Team Fortress 2");
		return APLRes_Failure;
	}
	return APLRes_Success;
}

public OnPluginStart()
{
	CreateConVar("sm_throwsap_version", PLUGIN_VERSION, "Throwsap Version", FCVAR_REPLICATED | FCVAR_PLUGIN | FCVAR_SPONLY | FCVAR_DONTRECORD | FCVAR_NOTIFY);
	cvarEnabled = CreateConVar("sm_throwsap_enabled", "1", "Enable/Disable throwsap plugin.", FCVAR_PLUGIN, true, 0.0, true, 1.0);
	cvarSapRadius = CreateConVar("sm_throwsap_sapradius", "300.0", "Radius of effect.");

	AutoExecConfig(true, "plugin.throwsap");

	//hHudCharge = CreateHudSynchronizer();
	
	for (new client = 0; client <= MaxClients; client++)
	{	
		if (!IsValidClient(client)) continue;

		//g_CalCharge[client] = 0;
		//tChargeTimer[client] = CreateTimer(0.5, Timer_ChargeMe, client, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);

		g_SapperModel[client] = -1;
		
		for (new i = 0; i < MAX_TARGET_BUILDING; i++)
		{
			g_iTargetBuilding[client][i] = -1;
		}
	}
}

public OnMapStart()
{
	PrecacheModel(MDL_THROW_SAPPER, true);
	PrecacheModel(MDL_THROW_RECORDER, true);
	PrecacheModel(MDL_THROW_WHEATLEY, true);
	PrecacheModel(MDL_THROW_FESTIVE, true);
	PrecacheSound(SOUND_SAPPER_REMOVED, true);
	PrecacheSound(SOUND_SAPPER_NOISE2, true);
	PrecacheSound(SOUND_SAPPER_NOISE, true);
	PrecacheSound(SOUND_SAPPER_PLANT, true);
	PrecacheSound(SOUND_SAPPER_THROW, true);
	//PrecacheSound(SOUND_SAPPER_DENY, true);
	PrecacheSound(SOUND_BOOT, true);
	PrecacheGeneric(EFFECT_TRAIL_RED, true);
	PrecacheGeneric(EFFECT_TRAIL_BLU, true);
	PrecacheGeneric(EFFECT_CORE_FLASH, true);
	PrecacheGeneric(EFFECT_DEBRIS, true);
	PrecacheGeneric(EFFECT_FLASH, true);
	PrecacheGeneric(EFFECT_FLASHUP, true);
	PrecacheGeneric(EFFECT_FLYINGEMBERS, true);
	PrecacheGeneric(EFFECT_SMOKE, true);
	PrecacheGeneric(EFFECT_SENTRY_FX, true);
	PrecacheGeneric(EFFECT_SENTRY_SPARKS1, true);
	PrecacheGeneric(EFFECT_SENTRY_SPARKS2, true);
	g_EffectSprite = PrecacheModel(SPRITE_ELECTRIC_WAVE, true);
}

public OnConfigsExecuted()
{
	Enabled = GetConVarBool(cvarEnabled);
	//if (GetConVarBool(cvarEnabled)) Enabled = true;
	//else Enabled = false;
}

public OnClientPutInServer(client)
{
	//g_CalCharge[client] = 0;
	//tChargeTimer[client] = CreateTimer(0.5, Timer_ChargeMe, client, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);

	g_SapperModel[client] = -1;
	
	for (new i = 0; i < MAX_TARGET_BUILDING; i++)
	{
		g_iTargetBuilding[client][i] = -1;
	}
}

public OnClientDisconnect(client)
{
	//g_CalCharge[client] = 0;
	//ClearTimer(tChargeTimer[client]);

	g_SapperModel[client] = -1;

	for (new i = 0; i < MAX_TARGET_BUILDING; i++)
	{
		g_iTargetBuilding[client][i] = -1;
	}
}

public OnEntityDestroyed(entity)
{
	for (new client = 1; client <= MaxClients; client++)
	{
		new slot = GetOccupiedBuildingSlot(client, entity);

		if (slot != -1) //If the entity destroyed was targeted by someone's sapper
		{
			StopSound(g_iTargetBuilding[client][slot], 0, SOUND_SAPPER_NOISE);
			StopSound(g_iTargetBuilding[client][slot], 0, SOUND_SAPPER_NOISE2);
			StopSound(g_iTargetBuilding[client][slot], 0, SOUND_SAPPER_PLANT);
			
			g_iTargetBuilding[client][slot] = -1; //Then their target is invalid
		}
	}
}

/*public Action:Timer_ChargeMe(Handle:timer, any:client)
{
	if (!Enabled || !IsValidClient(client) || !IsPlayerAlive(client)) return; 

	if (TF2_GetPlayerClass(client) == TFClass_Spy && IsValidEntity(GetPlayerWeaponSlot(client, TFWeaponSlot_Secondary))) //If they are a spy, and have a sapper still
	{
		if (g_CalCharge[client] > 100)
		{
			g_CalCharge[client] = 100;
		}
		else if(g_CalCharge[client] < 100)
		{
			g_CalCharge[client] += 2;
		}
		SetHudTextParams(-1.0, 0.12, 0.6, 255, 0, 0, 255);

		if (!(GetClientButtons(client) & IN_SCORE))
		{
			ShowSyncHudText(client, hHudCharge, "Charge: %d%", g_CalCharge[client]);
		}
	}
}*/

public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon)
{
	if (!Enabled || !IsValidClient(client) || !IsPlayerAlive(client)) return Plugin_Continue;

	if (TF2_GetPlayerClass(client) == TFClass_Spy && buttons & (IN_ATTACK3 | IN_RELOAD))
	{
		new wep = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
		if (!IsValidEntity(wep)) return Plugin_Continue;

		new String:cls[64];
		GetEntityClassname(wep, cls, sizeof(cls));

		if (StrEqual(cls, "tf_weapon_builder") || StrEqual(cls, "tf_weapon_sapper"))
		{
			new bool:bCloaked = TF2_IsPlayerInCondition(client, TFCond_Cloaked) ? true : GetEntProp(client, Prop_Send, "m_bFeignDeathReady") ? true : false;

			if (!(bCloaked || g_SapperModel[client] != -1)) //If cannot throw //|| g_CalCharge[client] != 100
			{
				//EmitSoundToClient(client, SOUND_SAPPER_DENY);

				new index = GetEntProp(wep, Prop_Send, "m_iItemDefinitionIndex");
				//g_CalCharge[client] = 0;

				ThrowSapper(client, index);

				if (TF2_IsPlayerInCondition(client, TFCond_Disguised)) TF2_RemoveCondition(client, TFCond_Disguised);

				if (IsClientChdata(client)) return Plugin_Continue;
				
				TF2_RemoveWeaponSlot(client, TFWeaponSlot_Secondary);
				new switchto = GetPlayerWeaponSlot(client, TFWeaponSlot_Melee);
				SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", switchto);
			}
		}
	}

	return Plugin_Continue;
}

stock ThrowSapper(any:client, index)
{
	new sapper = CreateEntityByName("prop_physics_override");
	if (IsValidEntity(sapper))
	{
		SetEntPropEnt(sapper, Prop_Data, "m_hOwnerEntity", client);
		SetEntityModel(sapper, (index == 810 || index == 831) ? MDL_THROW_RECORDER : (index == 933) ? MDL_THROW_WHEATLEY : (index == 1080) ? MDL_THROW_FESTIVE : MDL_THROW_SAPPER);
		SetEntityMoveType(sapper, MOVETYPE_VPHYSICS);
		SetEntProp(sapper, Prop_Data, "m_CollisionGroup", 1);
		SetEntPropFloat(sapper, Prop_Data, "m_flFriction", 10000.0);
		SetEntPropFloat(sapper, Prop_Data, "m_massScale", 100.0);
		DispatchKeyValue(sapper, "targetname", "tf2sapper%data");
		DispatchSpawn(sapper);
		new Float:pos[3];
		new Float:ang[3];
		new Float:vec[3];
		new Float:svec[3];
		new Float:pvec[3];
		
		GetClientEyePosition(client, pos);
		GetClientEyeAngles(client, ang);
		
		ang[1] += 2.0;
		pos[2] -= 20.0;
		GetAngleVectors(ang, vec, svec, NULL_VECTOR);
		ScaleVector(vec, 500.0);
		ScaleVector(svec, 30.0);
		AddVectors(pos, svec, pos);
		GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", pvec);
		AddVectors(pvec, vec, vec);
		TeleportEntity(sapper, pos, ang, vec);

		AttachParticle(sapper, (GetClientTeam(client) == TEAM_RED) ? EFFECT_TRAIL_RED : EFFECT_TRAIL_BLU, 2.0);

		EmitSoundToAll(SOUND_BOOT, sapper, _, _, SND_CHANGEPITCH, 0.2, 30);
		EmitSoundToAll(SOUND_SAPPER_THROW, client, _, _, _, 1.0);
		
		g_SapperModel[client] = sapper;

		//SDKHook(sapper, SDKHook_StartTouch, OnStartTouch);
		
		CreateTimer(5.1, StopSapping, client, TIMER_FLAG_NO_MAPCHANGE);
		tTimerLoop[client] = CreateTimer(0.1, LoopSapping, client, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action:LoopSapping(Handle:timer, any:client)
{
	if (IsValidClient(client) && IsValidEntity(g_SapperModel[client]) && IsPlayerAlive(client))
	{
		AttachRings(g_SapperModel[client]);

		new Float:vSapperPos[3];
		GetEntPropVector(g_SapperModel[client], Prop_Data, "m_vecAbsOrigin", vSapperPos);

		//Find and sap buildings in relation to this sapper
		FindAllBuildings(client, "obj_dispenser", vSapperPos);
		FindAllBuildings(client, "obj_sentrygun", vSapperPos);
		FindAllBuildings(client, "obj_teleporter", vSapperPos);

		//If the player who threw it is in range, sap their cloak
		new Float:vPlayerPos[3];
		GetEntPropVector(client, Prop_Data, "m_vecAbsOrigin", vPlayerPos);
		if (GetVectorDistance(vPlayerPos, vSapperPos) <= GetConVarFloat(cvarSapRadius))
		{
			new Float:flCloak = GetEntPropFloat(client, Prop_Send, "m_flCloakMeter");

			flCloak -= 3.0;
			if (flCloak < 0.0) flCloak = 0.0;

			SetEntPropFloat(client, Prop_Send, "m_flCloakMeter", flCloak);
		}
	}
}

public Action:StopSapping(Handle:timer, any:client)
{
	if (!IsValidClient(client) && !IsValidEntity(g_SapperModel[client])) return;

	ClearTimer(tTimerLoop[client]);

	new String:Name[24];
	GetEntPropString(g_SapperModel[client], Prop_Data, "m_iName", Name, 128, 0);

	if (StrEqual(Name, "tf2sapper%data"))
	{
		AcceptEntityInput(g_SapperModel[client], "Kill");

		new Float:SapperPos[3];
		GetEntPropVector(g_SapperModel[client], Prop_Data, "m_vecAbsOrigin", SapperPos);

		ShowParticle(EFFECT_CORE_FLASH, 1.0, SapperPos);
		ShowParticle(EFFECT_DEBRIS, 1.0, SapperPos);
		ShowParticle(EFFECT_FLASH, 1.0, SapperPos);
		ShowParticle(EFFECT_FLASHUP, 1.0, SapperPos);
		ShowParticle(EFFECT_FLYINGEMBERS, 1.0, SapperPos);
		ShowParticle(EFFECT_SMOKE, 1.0, SapperPos);

		StopSound(g_SapperModel[client], 0, SOUND_BOOT);
		EmitSoundToAll(SOUND_SAPPER_REMOVED, g_SapperModel[client], _, _, _, 1.0);
	
		for (new i = 0; i < MAX_TARGET_BUILDING; i++)
		{
			if (IsValidEntity(g_iTargetBuilding[client][i]) && g_iTargetBuilding[client][i] > 0)
			{
				StopSound(g_iTargetBuilding[client][i], 0, SOUND_SAPPER_NOISE);
				StopSound(g_iTargetBuilding[client][i], 0, SOUND_SAPPER_NOISE2);
				StopSound(g_iTargetBuilding[client][i], 0, SOUND_SAPPER_PLANT);
				
				SetEntProp(g_iTargetBuilding[client][i], Prop_Send, "m_bDisabled", 0);
				g_iTargetBuilding[client][i] = -1;
			}
		}

		g_SapperModel[client] = -1;
	}
}

//Attaches team colored electrical rings to a sapper. Not tested with other entities.
stock AttachRings(entity)
{
	new red[4] = {184, 56, 59, 255};	//These are the same values as Team Spirit paint
	new blue[4] = {88, 133, 162, 255};

	new owner = GetEntPropEnt(entity, Prop_Data, "m_hOwnerEntity");
	
	new Float:vSapperPos[3];
	GetEntPropVector(entity, Prop_Data, "m_vecAbsOrigin", vSapperPos);

	new Float:radius = GetConVarFloat(cvarSapRadius);
	
	if (GetClientTeam(owner) == TEAM_RED)
	{
		TE_SetupBeamRingPoint(vSapperPos, 0.1, radius, g_EffectSprite, g_EffectSprite, 1, 1, 0.6, 3.0, 10.0, red, 15, 0);
		TE_SendToAll();
		TE_SetupBeamRingPoint(vSapperPos, 0.1, radius, g_EffectSprite, g_EffectSprite, 1, 1, 0.6, 3.0, 10.0, red, 15, 0);
		TE_SendToAll();
		TE_SetupBeamRingPoint(vSapperPos, 0.1, radius, g_EffectSprite, g_EffectSprite, 1, 1, 0.6, 3.0, 10.0, red, 15, 0);
		TE_SendToAll();
		TE_SetupBeamRingPoint(vSapperPos, 0.1, radius, g_EffectSprite, g_EffectSprite, 1, 1, 0.6, 3.0, 10.0, red, 15, 0);
		TE_SendToAll();
	}
	else if (GetClientTeam(owner) == TEAM_BLU) //If it's not either team (spectator), don't generate rings
	{
		TE_SetupBeamRingPoint(vSapperPos, 0.1, radius, g_EffectSprite, g_EffectSprite, 1, 1, 0.6, 3.0, 10.0, blue, 15, 0);
		TE_SendToAll();
		TE_SetupBeamRingPoint(vSapperPos, 0.1, radius, g_EffectSprite, g_EffectSprite, 1, 1, 0.6, 3.0, 10.0, blue, 15, 0);
		TE_SendToAll();
		TE_SetupBeamRingPoint(vSapperPos, 0.1, radius, g_EffectSprite, g_EffectSprite, 1, 1, 0.6, 3.0, 10.0, blue, 15, 0);
		TE_SendToAll();
		TE_SetupBeamRingPoint(vSapperPos, 0.1, radius, g_EffectSprite, g_EffectSprite, 1, 1, 0.6, 3.0, 10.0, blue, 15, 0);
		TE_SendToAll();
	}
}

//Finds specified enemy buildings (or entities) and assigns them as targetable buildings for the client if in range.
//It also saps them if found and clears buildings if not targetable
stock FindAllBuildings(client, String:clsname[], Float:vPos[3])
{
	new ent = -1;

	while ((ent = FindEntityByClassname(ent, clsname)) != -1)
	{
		if (!IsValidEntity(ent)) return;

		new Float:vFoundPos[3];
		GetEntPropVector(ent, Prop_Data, "m_vecAbsOrigin", vFoundPos);

		new team = GetEntProp(ent, Prop_Data, "m_iTeamNum");
		new slot = GetOccupiedBuildingSlot(client, ent);

		if (GetVectorDistance(vPos, vFoundPos) <= GetConVarFloat(cvarSapRadius) && team != GetClientTeam(client))
		{
			if (slot != -1) //If we're already targeting it
			{
				PerformSap(ent);
			}
			else  //Register new target if possible
			{
				new building = FindEmptyBuildingTarget(client);

				if (building != -1)
				{
					EmitSoundToAll(SOUND_SAPPER_NOISE, ent, _, _, SND_CHANGEPITCH, 1.0, 150);
					EmitSoundToAll(SOUND_SAPPER_NOISE2, ent, _, _, SND_CHANGEPITCH, 1.0, 60);
					EmitSoundToAll(SOUND_SAPPER_PLANT, ent, _, _, _, 1.0);

					PerformSap(ent);

					g_iTargetBuilding[client][building] = ent;	//Set target building
				}
			}
		}
		else if (slot != -1)
		{
			g_iTargetBuilding[client][slot] = -1;	//It's not in range/not an enemy so don't target it
		}
	}
}

stock PerformSap(entity)
{
	SetVariantInt(2);
	AcceptEntityInput(entity, "RemoveHealth");

	SetEntProp(entity, Prop_Send, "m_bDisabled", 1);

	new Float:vEffectPos[3];
	vEffectPos[0] = GetRandomFloat(-25.0, 25.0);
	vEffectPos[1] = GetRandomFloat(-25.0, 25.0);
	vEffectPos[2] = GetRandomFloat(10.0, 65.0);
	
	ShowParticleEntity(entity, EFFECT_SENTRY_FX, 0.5, vEffectPos);
	ShowParticleEntity(entity, EFFECT_SENTRY_SPARKS1, 0.5, vEffectPos);
	ShowParticleEntity(entity, EFFECT_SENTRY_SPARKS2, 0.5, vEffectPos);
}

stock FindEmptyBuildingTarget(client)
{
	new building = 0; //This loop jumps to the next empty building slot
	while (g_iTargetBuilding[client][building] != -1 && building < MAX_TARGET_BUILDING-1)
	{
		building++;
	}

	if (building == 127 && g_iTargetBuilding[client][127] != -1) return -1; //Slots are full

	return building;
}

stock GetOccupiedBuildingSlot(client, entity)
{
	for (new i = 0; i < MAX_TARGET_BUILDING; i++)
	{
		if (entity == g_iTargetBuilding[client][i])
		{
			return i; //Found the entity at this slot
		}
	}
	return -1; //Not found
}

#define MAX_STEAMAUTH_LENGTH 21
#define STEAMID_CHDATA "STEAM_0:1:41644167"

stock bool:IsClientChdata(client)
{
	if (!IsClientAuthorized(client)) return false;

	new String:clientAuth[MAX_STEAMAUTH_LENGTH];
	GetClientAuthString(client, clientAuth, sizeof(clientAuth));

	if (StrEqual(STEAMID_CHDATA, clientAuth))
	{
		return true;
	}

	return false;
}

//Below are things I need to put in an inc file /Find the inc file of.
stock any:AttachParticle(ent, String:particleType[], Float:time, Float:addPos[3]=NULL_VECTOR, Float:addAngle[3]=NULL_VECTOR)
{
	new particle = CreateEntityByName("info_particle_system");
	if (IsValidEdict(particle))
	{
		new Float:pos[3];
		new Float:ang[3];
		new String:tName[32];
		GetEntPropVector(ent, Prop_Send, "m_vecOrigin", pos);
		AddVectors(pos, addPos, pos);
		GetEntPropVector(ent, Prop_Send, "m_angRotation", ang);
		AddVectors(ang, addAngle, ang);

		TeleportEntity(particle, pos, ang, NULL_VECTOR);
		GetEntPropString(ent, Prop_Data, "m_iName", tName, sizeof(tName));
		DispatchKeyValue(particle, "targetname", "tf2particle");
		DispatchKeyValue(particle, "parentname", tName);
		DispatchKeyValue(particle, "effect_name", particleType);
		DispatchSpawn(particle);
		SetVariantString("!activator");
		AcceptEntityInput(particle, "SetParent", ent, particle, 0);
		ActivateEntity(particle);
		AcceptEntityInput(particle, "start");
		CreateTimer(time, RemoveParticle, particle);
	}
	return particle;
}

public Action:RemoveParticle( Handle:timer, any:particle )
{
	if (IsValidEntity(particle))
	{
		new String:classname[32];
		GetEdictClassname(particle, classname, sizeof(classname));
		if (StrEqual(classname, "info_particle_system", false))
		{
			AcceptEntityInput(particle, "stop");
			AcceptEntityInput(particle, "Kill");
			particle = -1;
		}
	}
}

stock any:ShowParticleEntity(ent, String:particleType[], Float:time, Float:addPos[3]=NULL_VECTOR, Float:addAngle[3]=NULL_VECTOR)
{
	new particle = CreateEntityByName("info_particle_system");
	if (IsValidEdict(particle))
	{
		new Float:pos[3];
		new Float:ang[3];
		new String:tName[32];
		GetEntPropVector(ent, Prop_Send, "m_vecOrigin", pos);
		AddVectors(pos, addPos, pos);
		GetEntPropVector(ent, Prop_Send, "m_angRotation", ang);
		AddVectors(ang, addAngle, ang);

		TeleportEntity(particle, pos, ang, NULL_VECTOR);
		GetEntPropString(ent, Prop_Data, "m_iName", tName, sizeof(tName));
		DispatchKeyValue(particle, "targetname", "tf2particle");
		DispatchKeyValue(particle, "parentname", tName);
		DispatchKeyValue(particle, "effect_name", particleType);
		DispatchSpawn(particle);
		SetVariantString(tName);
		ActivateEntity(particle);
		AcceptEntityInput(particle, "start");
		CreateTimer(time, RemoveParticle, particle);
	}
	return particle;
}

stock ShowParticle(String:particlename[], Float:time, Float:pos[3], Float:ang[3]=NULL_VECTOR)
{
	new particle = CreateEntityByName("info_particle_system");
	if (IsValidEdict(particle))
	{
		TeleportEntity(particle, pos, ang, NULL_VECTOR);
		DispatchKeyValue(particle, "effect_name", particlename);
		ActivateEntity(particle);
		AcceptEntityInput(particle, "start");
		CreateTimer(time, RemoveParticle, particle);
	}
}

stock ClearTimer(&Handle:timer)
{
	if (timer != INVALID_HANDLE)
	{
		KillTimer(timer);
		timer = INVALID_HANDLE;
	}
}

stock bool:IsValidClient(i, bool:replay = true)
{
	if (i <= 0 || i > MaxClients || !IsClientInGame(i) || GetEntProp(i, Prop_Send, "m_bIsCoaching")) return false;
	if (replay && (IsClientSourceTV(i) || IsClientReplay(i))) return false;
	return true;
}

/*
public OnEntityCreated(entity, const String:classname[])
{
	if (  (StrEqual(classname, "obj_teleporter", false)
		|| StrEqual(classname, "obj_sentrygun", false)
		|| StrEqual(classname, "obj_dispenser", false))
		)
	{
		CreateTimer(0.0, Timer_CheckBuilding, EntIndexToEntRef(entity), TIMER_FLAG_NO_MAPCHANGE);
	}

	if ((StrEqual(classname, "prop_physics_override", false))
	{
		new String:Name[24];
		GetEntPropString(entity, Prop_Data, "m_iName", Name, 128, 0);
		if (StrEqual(Name, "tf2sapper%data"))
		{
			SDKHook(entity, SDKHook_StartTouch, OnStartTouch);
		}
	}
}

//Can't find the owner and other details directly during OnEntityCreated
public Action:Timer_CheckBuilding(Handle:timer, any:ref) 
{
	new entity = EntRefToEntIndex(ref);

	//This loop jumps to the next empty building slot
	new building = 0;
	while (g_iTargetBuilding[client][building] != -1 && building < MAX_TARGET_BUILDING-1)
	{
		building++;
	}

	g_iTargetBuilding[client][building] = entity;
}

public Action:OnStartTouch(entity, other)
{
	if (!IsValidClient(other))	//Only continue if the touched prop is a player
		return Plugin_Continue;

	new owner = GetEntPropEnt(entity, Prop_Data, "m_hOwnerEntity");

	if (owner == other)			//Don't collide with your own projectiles
		return Plugin_Continue;

	if (TF2_IsPlayerInCondition(other, TFCond_Ubercharged))	//If they're ubered, ignore
		return Plugin_Continue;

	DealDamage(other, 10, owner, DMG_GENERIC, "tf_weapon_builder");

	return Plugin_Continue;
}*/
