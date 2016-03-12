/**
 * This plugin is intended to provide a simple example of how to add round types via the natives provided.
 * If you really only wanted knife rounds, it would be simpler to only modify the configs/multi1v1_customrounds.cfg
 * file.
 */

#include <sourcemod>
#include <sdktools>
#include <clientprefs>
#include <multicolors>
#include <sdkhooks>
#include "multi1v1.inc"
#include "multi1v1/generic.sp"
#include "multi1v1/version.sp"

#pragma semicolon 1

new bool:hs[MAXPLAYERS+1];

public Plugin myinfo = {
    name = "CS:GO Multi1v1: Only HS option",
    author = "Franc1sco franug",
    description = "Adds an HS mode",
    version = "1.2",
    url = "http://steamcommunity.com/id/franug"
};

bool g_GiveFlash[MAXPLAYERS+1];
Handle g_hFlashCookie = INVALID_HANDLE;

public void OnPluginStart() {
	LoadTranslations("multi1v1.phrases");
	g_hFlashCookie = RegClientCookie("multi1v1_onlyhs", "Multi-1v1 allow only HeadShot in rounds", CookieAccess_Protected);
	
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i))
		{
			SDKHook(i, SDKHook_OnTakeDamage, OnTakeDamage);
		}
	}
}

public void OnClientPutInServer(int i)
{
	SDKHook(i, SDKHook_OnTakeDamage, OnTakeDamage);
}

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	if(!hs[victim]) return Plugin_Continue;
	
	
	if(damagetype & CS_DMG_HEADSHOT)
		return Plugin_Continue;

		
	if (attacker < 1 || attacker > MaxClients || !IsClientInGame(attacker)) 
		return Plugin_Continue; 
		
		
	decl String:sWeapon[32]; 
	GetClientWeapon(attacker, sWeapon, sizeof(sWeapon)); 
     
	if (StrContains(sWeapon, "knife", false) != -1 || StrContains(sWeapon, "bayonet", false) != -1 || StrContains(sWeapon, "taser", false) != -1) 
	{ 
		return Plugin_Continue; 
	} 
	return Plugin_Handled;
}

public void OnClientConnected(int client) {
    g_GiveFlash[client] = false;
}

public void Multi1v1_OnGunsMenuCreated(int client, Menu menu) {
    char enabledString[32];
    GetEnabledString(enabledString, sizeof(enabledString), g_GiveFlash[client], client);
    AddMenuOption(menu, "onlyheadshot", "Only HeadShot: %s", enabledString);
}

public void Multi1v1_GunsMenuCallback(Menu menu, MenuAction action, int param1, int param2) {
    if (action == MenuAction_Select) {
        int client = param1;
        char buffer[128];
        menu.GetItem(param2, buffer, sizeof(buffer));
        if (StrEqual(buffer, "onlyheadshot")) {
            g_GiveFlash[client] = !g_GiveFlash[client];
            SetCookieBool(client, g_hFlashCookie, g_GiveFlash[client]);
            Multi1v1_GiveWeaponsMenu(client, GetMenuSelectionPosition());
        }
    }
}

public void Multi1v1_AfterPlayerSetup(int client) {
    if (!IsActivePlayer(client)) {
        return;
    }

    hs[client] = false;
	
    int arena = Multi1v1_GetArenaNumber(client);
    int p1 = Multi1v1_GetArenaPlayer1(arena);
    int p2 = Multi1v1_GetArenaPlayer2(arena);

    if (p1 >= 0 && p2 >= 0 && g_GiveFlash[p1] && g_GiveFlash[p2]) {
		if(Multi1v1_GetCurrentRoundType(arena) == Multi1v1_GetRoundTypeIndex("knife")) return;
		hs[client] = true;
		CreateTimer(2.0, pasado, GetClientUserId(client));
		CPrintToChat(client, " {lime}ONLY HEADSHOT ENABLED IN THIS ROUND");
    }
}

public Action:pasado(Handle:timer, any:userid)
{
	new client = GetClientOfUserId(userid);
	
	if(client == 0 || !IsClientInGame(client)) return;
	decl String:input[512];
	Format(input, 512, "<font color='#0066FF'>ONLY HEADSHOT ENABLED IN THIS ROUND</font>");
	new Handle:pb = StartMessageOne("HintText", client);
	PbSetString(pb, "text", input);
	EndMessage();
}

public void OnClientCookiesCached(int client) {
    if (IsFakeClient(client))
        return;
    g_GiveFlash[client] = GetCookieBool(client, g_hFlashCookie);
}
