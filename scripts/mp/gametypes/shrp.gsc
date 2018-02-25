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

function main()
{
	globallogic::init();

	level.pointsPerWeaponKill = GetGametypeSetting( "pointsPerWeaponKill" );
	level.pointsPerMeleeKill = GetGametypeSetting( "pointsPerMeleeKill" );
	level.shrpWeaponTimer = GetGametypeSetting( "weaponTimer" );
	level.shrpWeaponCount = GetGametypeSetting( "weaponCount" );

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

	thread shrp();
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


function shrp()
{
	level endon( "game_ended" );

	build_weapon_list();

	if ( level.inPrematchPeriod )
		level waittill( "prematch_over" );

	while ( level.shrpWeaponNumber != level.shrpWeaponCount )
	{
		level.shrpWeapon = GetWeapon( level.shrpWeaponList[level.shrpWeaponNumber] );
		IPrintLn( level.shrpWeapon.rootWeapon.name + " | " + level.shrpWeaponNumber + " | " + level.shrpWeaponCount );
		array::thread_all( level.activeplayers, level.giveCustomLoadout );
		wait( level.shrpWeaponTimer );
		level.shrpWeaponNumber++;
	}
}

function build_weapon_list()
{
	level.shrpWeaponList = [];
	level.shrpWeaponNumber = 0;

	a_grouptypes = Array( "weapon_pistol", "weapon_assault", "weapon_smg", "weapon_lmg", "weapon_sniper", "weapon_cqb", "weapon_special"/*, "weapon_launcher", "weapon_knife"*/ );

	do
	{
		// pick a random weapon
		id = m_array::randomized_selection( level.tbl_weaponIDs );
		// avoid any weapon that isn't part of the group
		if ( !IsInArray( a_grouptypes, id["group"] ) )
			continue;
		// get the weapon name
		baseWeaponName = id[ "reference" ];
		// avoid any nulls or dw weapons or same weapon
		if ( IsInArray( level.shrpWeaponList, baseWeaponName ) || baseWeaponName == "weapon_null" || baseWeaponName == "ball" || baseWeaponName == "minigun" || StrEndsWith( baseWeaponName, "_dw" ) )
			continue;
		// get the weapon struct
		ARRAY_ADD( level.shrpWeaponList, baseWeaponName );
		//
		WAIT_SERVER_FRAME;
	} while( level.shrpWeaponList.size != level.shrpWeaponCount );

	level.shrpWeapon = GetWeapon( level.shrpWeaponList[0] );
}

function giveCustomLoadout()
{
	self TakeAllWeapons();
	self ClearPerks();

	spawn_weapon = level.shrpWeapon;

	self GiveWeapon( spawn_weapon );
	self GiveMaxAmmo( spawn_weapon );
	self SetSpawnWeapon( spawn_weapon );
	self SwitchToWeapon( spawn_weapon );

	if ( level.shrpWeapon === level.weaponBallisticKnife )
	{
		self.grenadeTypePrimary = level.shrpWeapon; // satisfy _weaponobjects in order to pickup equipment
		self.grenadeTypePrimaryCount = level.shrpWeapon.maxAmmo;
	}
	return spawn_weapon;
}
