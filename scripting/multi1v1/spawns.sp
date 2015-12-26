#define SAME_ARENA_THRESHOLD 1600.0

/**
 * Loads the spawn positions from the map and updates global spawn arrays.
 */
public void Spawns_MapStart() {
    // Note: these are arrays of arrays!
    // Each index corresponds to the data for THAT arena.
    // Example: g_TspawnsList[0] has a handle to another adt array - that array contains
    //   the 3-vectors of spawns.
    g_TSpawnsList = new ArrayList();
    g_TAnglesList = new ArrayList();
    g_CTSpawnsList = new ArrayList();
    g_CTAnglesList = new ArrayList();

    bool verbose = g_VerboseSpawnModeCvar.IntValue != 0;

    int maxEnt = GetMaxEntities();
    char sClassName[64];
    float spawn[3];
    float angle[3];

    // Check if each entity is a spawn and add it
    for (int i = MaxClients; i < maxEnt; i++) {
        bool valid = IsValidEdict(i) && IsValidEntity(i);
        if (valid && GetEdictClassname(i, sClassName, sizeof(sClassName))) {

            if (StrEqual(sClassName, "info_player_terrorist")) {
                GetEntPropVector(i, Prop_Data, "m_vecOrigin", spawn);
                GetEntPropVector(i, Prop_Data, "m_angRotation", angle);
                AddSpawn(spawn, angle, g_TSpawnsList, g_TAnglesList);
                if (verbose)
                    LogMessage("T spawn (ent %d) %f %f %f",
                               i, spawn[0], spawn[1], spawn[2]);

            }  else if (StrEqual(sClassName, "info_player_counterterrorist")) {
                GetEntPropVector(i, Prop_Data, "m_vecOrigin", spawn);
                GetEntPropVector(i, Prop_Data, "m_angRotation", angle);
                AddSpawn(spawn, angle, g_CTSpawnsList, g_CTAnglesList);
                if (verbose)
                    LogMessage("CT spawn (ent %d) %f %f %f",
                               i, spawn[0], spawn[1], spawn[2]);
            }
        }
    }

    int ct = GetArraySize(g_CTSpawnsList);
    int t = GetArraySize(g_TSpawnsList);
    g_maxArenas = (ct < t) ? ct : t;

    bool[] takenTSpawns = new bool[g_maxArenas];
    for (int i = 0; i < g_maxArenas; i++)
        takenTSpawns[i] = false;


    // Looping through CT spawn clusters, matching the nearest T spawn cluster to each
    for (int i = 0; i < g_maxArenas; i++) {
        ArrayList ct_spawns = view_as<ArrayList>(g_CTSpawnsList.Get(i));

        int closestIndex = -1;
        float closestDist = 0.0;

        for (int j = 0; j < g_maxArenas; j++) {
            if (takenTSpawns[j])
                continue;

            ArrayList t_spawns = view_as<ArrayList>(g_TSpawnsList.Get(j));
            float vec1[3];
            float vec2[3];
            ct_spawns.GetArray(0, vec1);
            t_spawns.GetArray(0, vec2);
            float dist = GetVectorDistance(vec1, vec2);

            if (closestIndex < 0 || dist < closestDist) {
                closestIndex = j;
                closestDist = dist;
            }
        }

        SwapArrayItems(g_TSpawnsList, i, closestIndex);
        SwapArrayItems(g_TAnglesList, i, closestIndex);
        takenTSpawns[i] = true;
    }

    Call_StartForward(g_hOnSpawnsFound);
    Call_PushCell(g_CTSpawnsList);
    Call_PushCell(g_CTAnglesList);
    Call_PushCell(g_TSpawnsList);
    Call_PushCell(g_TAnglesList);
    Call_Finish();

    // More Helpful logging for map developers
    if (verbose) {
        for (int i = 0; i < g_maxArenas; i++) {
            LogMessage("Cluster %d:", i + 1);

            ArrayList ct_spawns = view_as<ArrayList>(g_CTSpawnsList.Get(i));
            for (int j = 0; j < GetArraySize(ct_spawns); j++) {
                float vec[3];
                ct_spawns.GetArray(j, vec);
                LogMessage("  CT Spawn %d: %f %f %f", j + 1, vec[0], vec[1], vec[2]);
            }

            ArrayList t_spawns = view_as<ArrayList>(g_TSpawnsList.Get(i));
            for (int j = 0; j < GetArraySize(t_spawns); j++) {
                float vec[3];
                t_spawns.GetArray(j, vec);
                LogMessage("  T Spawn  %d: %f %f %f", j + 1, vec[0], vec[1], vec[2]);
            }

        }
    }

    if (g_maxArenas <= 0) {
        LogError("No arenas could be found for this map!");
    }
}

static void AddSpawn(float spawn[3], float angle[3], ArrayList spawnList, ArrayList angleList) {
    // First scan for a nearby arena to place this spawn into.
    // If one is found - these spawn is pushed onto that arena's list.
    for (int i = 0; i < GetArraySize(spawnList); i++) {
        ArrayList spawns = view_as<ArrayList>(spawnList.Get(i));
        ArrayList angles = view_as<ArrayList>(angleList.Get(i));
        int closestIndex = NearestNeighborIndex(spawn, spawns);

        if (closestIndex >= 0) {
            float closestSpawn[3];
            spawns.GetArray(closestIndex, closestSpawn);
            float dist = GetVectorDistance(spawn, closestSpawn);

            if (dist < SAME_ARENA_THRESHOLD) {
                spawns.PushArray(spawn);
                angles.PushArray(angle);
                return;
            }
        }
    }

    // If no nearby arena was found - create a new list for this newly found arena and push it.
    ArrayList spawns = new ArrayList(3);
    ArrayList angles = new ArrayList(3);
    spawns.PushArray(spawn);
    angles.PushArray(angle);
    PushArrayCell(spawnList, spawns);
    PushArrayCell(angleList, angles);
}

public void Spawns_MapEnd() {
    CloseNestedList(g_TSpawnsList);
    CloseNestedList(g_TAnglesList);
    CloseNestedList(g_CTSpawnsList);
    CloseNestedList(g_CTAnglesList);
}

public float DistanceToSpawns(const float[3] origin, ArrayList spawns) {
    float tmp[3];
    float minDist = 1.0e300;
    for (int i = 0; i < spawns.Length; i++) {
        spawns.GetArray(i, tmp, sizeof(tmp));
        minDist = fmin(minDist, GetVectorDistance(origin, tmp));
    }
    return minDist;
}

public float DistanceToArena(const float[3] origin, int arena) {
    ArrayList tSpawns = view_as<ArrayList>(g_TSpawnsList.Get(arena - 1));
    ArrayList ctSpawns = view_as<ArrayList>(g_CTSpawnsList.Get(arena - 1));
    return fmin(DistanceToSpawns(origin, tSpawns),
                DistanceToSpawns(origin, ctSpawns));
}

public int FindClosestArenaNumber(const float[3] origin) {
    float minDist = 0.0;
    int minArena = 0;
    for (int i = 1; i <= g_maxArenas; i++) {
        float dist = DistanceToArena(origin, i);
        if (minArena < 1 || dist < minDist) {
            minArena = i;
            minDist = dist;
        }
    }
    return minArena;
}
