#pragma semicolon 1

#define PLUGIN_AUTHOR "AI"
#define PLUGIN_VERSION "0.1.0"

#include <sourcemod>
#include <sdkhooks>
#include <smlib/effects>
#include <smlib/entities>

#define LASER_TEXTURE	"sprites/laserbeam.vmt"
#define HALO_TEXTURE	"materials/sprites/halo01.vmt"

#define BOX_WIDTH		5.0
#define VEC_BOX_WIDTH	{BOX_WIDTH, BOX_WIDTH, BOX_WIDTH}

bool g_bEnabled[MAXPLAYERS+1] = {false, ...};

int g_iAnchorEntity[MAXPLAYERS+1] = {INVALID_ENT_REFERENCE, ...};
float g_vecAnchorPos[MAXPLAYERS+1][3];
float g_vecMaxDistance[MAXPLAYERS+1][3];

int g_iLaser;
int g_iHalo;

public Plugin myinfo = {
	name = "Distances Travelled",
	author = PLUGIN_AUTHOR,
	description = "Track maximum distances to the player",
	version = PLUGIN_VERSION,
	url = "https://github.com/geominorai/smdt"
};

public void OnPluginStart() {
	RegConsoleCmd("sm_dt", cmdDT, "Toggle showing distances");
}

public void OnMapStart() {
	g_iLaser = PrecacheModel(LASER_TEXTURE);
	g_iHalo = PrecacheModel(HALO_TEXTURE);
}

public void OnClientDisconnect(int iClient) {
	g_bEnabled[iClient] = false;
	g_iAnchorEntity[iClient] = INVALID_ENT_REFERENCE;
}

// Custom callbacks

public void PostThink_Client(int iClient) {
	float vecAnchorPos[3];

	int iAnchorEntity = EntRefToEntIndex(g_iAnchorEntity[iClient]);
	if (iAnchorEntity != INVALID_ENT_REFERENCE) {
		Entity_GetAbsOrigin(iAnchorEntity, vecAnchorPos);
		g_vecAnchorPos[iClient] = vecAnchorPos;
	} else {
		vecAnchorPos = g_vecAnchorPos[iClient];
	}

	float vecBottomCorner[3], vecUpperCorner[3];
	AddVectors(vecAnchorPos, VEC_BOX_WIDTH, vecUpperCorner);
	SubtractVectors(vecAnchorPos, VEC_BOX_WIDTH, vecBottomCorner);

	Effect_DrawBeamBoxToClient(iClient, vecBottomCorner, vecUpperCorner, g_iLaser, g_iHalo, 0, 66, 0.1, 0.5, 0.5, 1, 0.0, {255, 0, 0, 255});

	ShowDistancePanel(iClient);
}

public bool TraceFilter_Environment(int iEntity, int iMask) {
	return false;
}

// Commands

public Action cmdDT(int iClient, int iArgC) {
	if (!iClient) {
		ReplyToCommand(iClient, "[SM] Cannot run this command from console.");
		return Plugin_Handled;
	}

	if (iArgC == 0) {
		g_bEnabled[iClient] = !g_bEnabled[iClient];

		if (g_bEnabled[iClient]) {
			g_iAnchorEntity[iClient] = INVALID_ENT_REFERENCE;
			g_vecMaxDistance[iClient] = NULL_VECTOR;

			GetClientAbsOrigin(iClient, g_vecAnchorPos[iClient]);

			SDKHook(iClient, SDKHook_PostThink, PostThink_Client);
		} else {
			SDKUnhook(iClient, SDKHook_PostThink, PostThink_Client);
		}

		return Plugin_Handled;
	}

	SDKUnhook(iClient, SDKHook_PostThink, PostThink_Client);

	char sArg1[32];
	GetCmdArg(1, sArg1, sizeof(sArg1));

	int iEntity = StringToInt(sArg1);
	if (iEntity > 0 && IsValidEntity(iEntity)) {
		g_iAnchorEntity[iClient] = EntIndexToEntRef(iEntity);
		g_bEnabled[iClient] = true;
	} else {
		if ((iEntity = FindTarget(iClient, sArg1, false, false)) != -1) {
			g_iAnchorEntity[iClient] = EntIndexToEntRef(iEntity);
			g_bEnabled[iClient] = true;
		} else {
			g_iAnchorEntity[iClient] = INVALID_ENT_REFERENCE;
			g_bEnabled[iClient] = false;
		}
	}

	if (g_bEnabled[iClient]) {
		g_vecMaxDistance[iClient] = NULL_VECTOR;
		SDKHook(iClient, SDKHook_PostThink, PostThink_Client);
	}

	return Plugin_Handled;
}

// Helpers

void GetClientDistance(int iClient, float vecAnchorPos[3], float vecDistance[3]) {
	float vecClientPos[3];
	GetClientAbsOrigin(iClient, vecClientPos);

	SubtractVectors(vecClientPos, vecAnchorPos, vecDistance);

	vecDistance[0] = FloatAbs(vecDistance[0]);
	vecDistance[1] = FloatAbs(vecDistance[1]);
	vecDistance[2] = FloatAbs(vecDistance[2]);
}

// Menus

public void ShowDistancePanel(int iClient) {
	Panel hPanel = new Panel();

	float vecDistance[3];
	GetClientDistance(iClient, g_vecAnchorPos[iClient], vecDistance);

	static char sBuffer[64];
	
	FormatEx(sBuffer, sizeof(sBuffer), "Distance: %.2f", GetVectorLength(vecDistance));
	hPanel.DrawText(sBuffer);
	
	FormatEx(sBuffer, sizeof(sBuffer), "dX: %.2f  dY: %.2f  dZ: %.2f", vecDistance[0], vecDistance[1], vecDistance[2]);
	hPanel.DrawText(sBuffer);

	hPanel.DrawText(" ");

	float vecMaxDistance[3];
	vecMaxDistance = g_vecMaxDistance[iClient];

	vecMaxDistance[0] = vecDistance[0] > vecMaxDistance[0] ? vecDistance[0] : vecMaxDistance[0];
	vecMaxDistance[1] = vecDistance[1] > vecMaxDistance[1] ? vecDistance[1] : vecMaxDistance[1];
	vecMaxDistance[2] = vecDistance[2] > vecMaxDistance[2] ? vecDistance[2] : vecMaxDistance[2];

	g_vecMaxDistance[iClient] = vecMaxDistance;

	FormatEx(sBuffer, sizeof(sBuffer), "Max Distance: %.2f", GetVectorLength(vecMaxDistance));
	hPanel.DrawText(sBuffer);
	
	FormatEx(sBuffer, sizeof(sBuffer), "dX: %.2f  dY: %.2f  dZ: %.2f", vecMaxDistance[0], vecMaxDistance[1], vecMaxDistance[2]);
	hPanel.DrawText(sBuffer);

	hPanel.DrawText(" ");

	hPanel.DrawItem("Retarget Aim");
	hPanel.DrawItem("Retarget Self");
	hPanel.DrawItem("Reset Max");
	hPanel.DrawText(" ");
	
	hPanel.DrawItem("Print");
	hPanel.DrawText(" ");
	
	hPanel.CurrentKey = 10;
	hPanel.DrawItem("Exit");

	hPanel.Send(iClient, MenuHandler_DistancePanel, 1);

	delete hPanel;
}

public int MenuHandler_DistancePanel(Menu hMenu, MenuAction iAction, int iParam1, int iParam2) {
	switch (iAction) {
		case MenuAction_Select: {
			if (!g_bEnabled[iParam1]) {
				return;
			}

			switch (iParam2) {
				case 1: {
					float vecClientEyePos[3];
					GetClientEyePosition(iParam1, vecClientEyePos);

					float vecClientEyeAng[3];
					GetClientEyeAngles(iParam1, vecClientEyeAng);

					TR_TraceRayFilter(vecClientEyePos, vecClientEyeAng, MASK_SHOT_HULL, RayType_Infinite, TraceFilter_Environment);
					if (TR_DidHit()) {
						TR_GetEndPosition(g_vecAnchorPos[iParam1]);
						g_iAnchorEntity[iParam1] = INVALID_ENT_REFERENCE;
						g_vecMaxDistance[iParam1] = NULL_VECTOR;
					}
				}
				case 2: {
					g_iAnchorEntity[iParam1] = INVALID_ENT_REFERENCE;
					GetClientAbsOrigin(iParam1, g_vecAnchorPos[iParam1]);
					g_vecMaxDistance[iParam1] = NULL_VECTOR;
				}
				case 3: {
					g_vecMaxDistance[iParam1] = NULL_VECTOR;
				}
				case 4: {
					float vecDistance[3];
					GetClientDistance(iParam1, g_vecAnchorPos[iParam1], vecDistance);

					PrintToChat(iParam1, "Distance: %.2f (dX: %.2f  dY: %.2f  dZ: %.2f)", GetVectorLength(vecDistance), vecDistance[0], vecDistance[1], vecDistance[2]);
					PrintToChat(iParam1, "Max Distance: %.2f (dX: %.2f  dY: %.2f  dZ: %.2f)", GetVectorLength(g_vecMaxDistance[iParam1]), g_vecMaxDistance[iParam1][0], g_vecMaxDistance[iParam1][1], g_vecMaxDistance[iParam1][2]);
				}
				default: {
					g_bEnabled[iParam1] = false;
					SDKUnhook(iParam1, SDKHook_PostThink, PostThink_Client);
				}
			}
		}
	}
}
