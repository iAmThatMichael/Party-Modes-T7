#using scripts\shared\array_shared;
#using scripts\shared\gameobjects_shared;
#using scripts\shared\math_shared;
#using scripts\shared\util_shared;

#insert scripts\shared\shared.gsh;

#using scripts\mp\gametypes\_globallogic;
#using scripts\mp\gametypes\_globallogic_audio;
#using scripts\mp\gametypes\_globallogic_score;
#using scripts\mp\gametypes\_spawning;
#using scripts\mp\gametypes\_spawnlogic;
#using scripts\mp\killstreaks\_killstreaks;

#using scripts\mp\_util;

#using scripts\m_shared\array_shared;
#using scripts\m_shared\util_shared;

#precache( "string", "OBJECTIVES_DM" );
#precache( "string", "OBJECTIVES_DM_SCORE" );
#precache( "string", "OBJECTIVES_DM_HINT" );

#define SUPPLY_DROP_NAME "supply_drop"

#define SUPPY_DROP_ON_TARGET_DISTANCE					3.7
#define SUPPY_DROP_NAV_MESH_VALID_LOCATION_BOUNDARY		12
#define SUPPY_DROP_NAV_MESH_VALID_LOCATION_TOLERANCE	4

function main()
{
	globallogic::init();

	util::registerTimeLimit( level.shrpWeaponCount * level.shrpWeaponTimer / 60, level.shrpWeaponCount * level.shrpWeaponTimer / 60 );
	util::registerScoreLimit( 0, 50000 );
	util::registerRoundLimit( 0, 10 );
	util::registerRoundWinLimit( 0, 10 );
	util::registerNumLives( 0, 100 );

	globallogic::registerFriendlyFireDelay( level.gameType, 0, 0, 1440 );

	level.onStartGameType = &onStartGameType;
	level.onPlayerKilled = &onPlayerKilled;
	level.onSpawnPlayer = &onSpawnPlayer;
	level.giveCustomLoadout = &giveCustomLoadout; // set up our loadout
	level.forceAutoAssign = true;

	gameobjects::register_allowed_gameobject( level.gameType );

	globallogic_audio::set_leader_gametype_dialog ( "startFreeForAll", "hcStartFreeForAll", "gameBoost", "gameBoost" );

	// Sets the scoreboard columns and determines with data is sent across the network
	globallogic::setvisiblescoreboardcolumns( "pointstowin", "kills", "deaths", "kdratio", "score" );
}


function setupTeam( team )
{
	util::setObjectiveText( team, &"OBJECTIVES_DM" );
	if ( level.splitscreen )
	{
		util::setObjectiveScoreText( team, &"OBJECTIVES_DM" );
	}
	else
	{
		util::setObjectiveScoreText( team, &"OBJECTIVES_DM_SCORE" );
	}
	util::setObjectiveHintText( team, &"OBJECTIVES_DM_HINT" );

	spawnlogic::add_spawn_points( team, "mp_dm_spawn" );
	spawnlogic::place_spawn_points( "mp_dm_spawn_start" );

	level.spawn_start = spawnlogic::get_spawnpoint_array( "mp_dm_spawn_start" );

}

function onStartGameType()
{
	setClientNameMode("auto_change");

	// now that the game objects have been deleted place the influencers
	spawning::create_map_placed_influencers();

	level.spawnMins = ( 0, 0, 0 );
	level.spawnMaxs = ( 0, 0, 0 );

	foreach( team in level.teams )
	{
		setupTeam( team );
	}

	spawning::updateAllSpawnPoints();

	level.mapCenter = math::find_box_center( level.spawnMins, level.spawnMaxs );
	setMapCenter( level.mapCenter );

	spawnpoint = spawnlogic::get_random_intermission_point();
	setDemoIntermissionPoint( spawnpoint.origin, spawnpoint.angles );
}

function onSpawnPlayer(predictedSpawn)
{
	if( !level.inPrematchPeriod )
	{
		level.useStartSpawns = false;
	}

	spawning::onSpawnPlayer(predictedSpawn);
}

function onPlayerKilled( eInflictor, attacker, iDamage, sMeansOfDeath, weapon, vDir, sHitLoc, psOffsetTime, deathAnimDuration )
{
	if ( !isPlayer( attacker ) || ( self == attacker ) )
		return;
}


function giveCustomLoadout()
{
	self TakeAllWeapons();
	self ClearPerks();

	spawn_weapon = GetWeapon( "pistol_standard" );

	self GiveWeapon( spawn_weapon );
	self GiveMaxAmmo( spawn_weapon );
	self SetSpawnWeapon( spawn_weapon );

	return spawn_weapon;
}

function do_drop_point()
{
	context = SpawnStruct();
	context.radius = level.killstreakCoreBundle.ksAirdropSupplydropRadius;
	context.dist_from_boundary = SUPPY_DROP_NAV_MESH_VALID_LOCATION_BOUNDARY;
	context.max_dist_from_location = SUPPY_DROP_NAV_MESH_VALID_LOCATION_TOLERANCE;
	context.perform_physics_trace = true;
	context.isLocationGood = &determine_location;
	context.objective = &"airdrop_supplydrop";
	context.validLocationSound = level.killstreakCoreBundle.ksValidCarepackageLocationSound;
	context.tracemask = PHYSICS_TRACE_MASK_PHYSICS | PHYSICS_TRACE_MASK_WATER;
	context.dropTag = "tag_attach";
	context.dropTagOffset = ( -32, 0, 23 );
	context.killstreakType = SUPPLY_DROP_NAME;

	[[context.isLocationGood]]( location, context );
}

function determine_location( location, context )
{
	//check no similar zones
	foreach( dropLocation in level.dropLocations )
	{
		if( Distance2DSquared( dropLocation, location ) < 60 * 60 )
			return false;
	}

	if ( context.perform_physics_trace === true )
	{
		mask = ( isdefined( context.tracemask ) ? context.tracemask : PHYSICS_TRACE_MASK_PHYSICS );

		radius = context.radius;
		trace = PhysicsTrace( location + ( 0,0, 5000 ), location + ( 0, 0, 10 ), ( -radius, -radius, 0 ), ( radius, radius, 2 * radius ), undefined, mask );

		if( trace["fraction"] < 1 )
		{
			return false;
		}
	}

	// check for a valid start node
	closestPoint = GetClosestPointOnNavMesh( location, max( context.max_dist_from_location, 24 ), context.dist_from_boundary );

	isValidPoint = isdefined( closestPoint );

	// make sure the selected point is roughly on the same floor
	if ( isValidPoint && context.check_same_floor === true && Abs( location[2] - closestPoint[2] ) > 96 )
		isValidPoint = false;

	if ( isValidPoint && Distance2DSquared( location, closestPoint ) > SQR( context.max_dist_from_location ) )
		isValidPoint = false;

	return isValidPoint;
}