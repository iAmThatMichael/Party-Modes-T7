#using scripts\shared\callbacks_shared;
#using scripts\shared\gameobjects_shared;
#using scripts\shared\math_shared;
#using scripts\shared\util_shared;

#insert scripts\shared\shared.gsh;

#using scripts\mp\gametypes\_globallogic;
#using scripts\mp\gametypes\_globallogic_audio;
#using scripts\mp\gametypes\_spawning;
#using scripts\mp\gametypes\_spawnlogic;

#using scripts\mp\_util;

#using scripts\m_shared\util_shared;

#precache( "string", "OBJECTIVES_DM" );
#precache( "string", "OBJECTIVES_DM_SCORE" );
#precache( "string", "OBJECTIVES_DM_HINT" );

function main()
{
	globallogic::init();

	util::registerTimeLimit( 0, 1440 );
	util::registerScoreLimit( 0, 50000 );
	util::registerRoundLimit( 0, 10 );
	util::registerRoundWinLimit( 0, 10 );
	util::registerNumLives( 0, 100 );

	globallogic::registerFriendlyFireDelay( level.gameType, 0, 0, 1440 );

	level.onStartGameType = &onStartGameType;
	level.onPlayerDamage = &onPlayerDamage;
	level.onPlayerKilled = &onPlayerKilled;
	level.onSpawnPlayer = &onSpawnPlayer;
	level.giveCustomLoadout = &giveCustomLoadout; // set up our loadout

	level.forceAutoAssign = true; // force game to select team

	callback::on_spawned( &on_player_spawned ); // extra code on spawning

	gameobjects::register_allowed_gameobject( level.gameType );

	globallogic_audio::set_leader_gametype_dialog ( "startFreeForAll", "hcStartFreeForAll", "gameBoost", "gameBoost" );

	// Sets the scoreboard columns and determines with data is sent across the network
	globallogic::setvisiblescoreboardcolumns( "pointstowin", "kills", "deaths", "stabs", "survived" );
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

function onPlayerDamage( eInflictor, eAttacker, iDamage, iDFlags, sMeansOfDeath, sWeapon, vPoint, vDir, sHitLoc, psOffsetTime )
{
	// ensure damage is 1 hit
	if ( sWeapon.rootWeapon.name == "pistol_m1911" )
		iDamage = self.maxhealth + 1;

	return iDamage;
}

function onPlayerKilled( eInflictor, attacker, iDamage, sMeansOfDeath, weapon, vDir, sHitLoc, psOffsetTime, deathAnimDuration )
{
	if ( !isPlayer( attacker ) || ( self == attacker ) )
		return;

	attacker PlayLocalSound( "mpl_oic_bullet_pickup" );
}

function on_player_spawned()
{
	/#
	self thread m_util::spawn_bot_button();
	#/
}

function giveCustomLoadout(first)
{
	self TakeAllWeapons();
	self ClearPerks();

	clipAmmo = 1;
	SET_IF_DEFINED( clipAmmo, self.pers["clip_ammo"] );
	stockAmmo = 0;
	SET_IF_DEFINED( stockAmmo, self.pers["stock_ammo"] );

	spawn_weapon = GetWeapon( "pistol_m1911" );

	self GiveWeapon( spawn_weapon );
	self SetWeaponAmmoClip( spawn_weapon, clipAmmo );
	self SetWeaponAmmoStock( spawn_weapon, stockAmmo );
	self SetSpawnWeapon( spawn_weapon );

	return spawn_weapon;
}
