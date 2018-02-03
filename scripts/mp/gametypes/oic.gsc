#using scripts\shared\callbacks_shared;
#using scripts\shared\gameobjects_shared;
#using scripts\shared\math_shared;
#using scripts\shared\scoreevents_shared;
#using scripts\shared\util_shared;

#using scripts\shared\weapons\_weapon_utils;

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
	level.oic_weapon = GetWeapon( "pistol_m1911" );

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

	if ( weapon == level.oic_weapon && attacker.pers["clip_ammo"] < self.pers["clip_ammo"] )
		scoreevents::processScoreEvent( "kill_enemy_with_more_ammo_oic", attacker, self, weapon );

	if ( weapon_utils::isMeleeMOD( sMeansOfDeath ) )
		scoreevents::processScoreEvent( "knife_with_ammo_oic", attacker, self, weapon );

	if ( self.pers["lives"] == 0 )
		scoreevents::processScoreEvent( "eliminate_oic", attacker, self, weapon );

	attacker give_ammo();
}

function on_player_spawned()
{
	/#
	self thread m_util::spawn_bot_button();
	#/
	self thread weapon_fired_watcher();
}

function weapon_fired_watcher()
{
	self endon( "death" );
	self endon( "disconnect" );

	while ( true )
	{
		self waittill( "weapon_fired", weapon );

		if ( weapon == level.oic_weapon )
			self.pers["clip_ammo"] = self GetWeaponAmmoClip( level.oic_weapon );
	}
}

function give_ammo()
{
	clipAmmo = self GetWeaponAmmoClip( level.oic_weapon ) + 1;
	self SetWeaponAmmoClip( level.oic_weapon, clipAmmo );
	self.pers["clip_ammo"] = clipAmmo;
}

function giveCustomLoadout(first)
{
	self TakeAllWeapons();
	self ClearPerks();

	spawn_weapon = level.oic_weapon;

	clipAmmo = 1;
	stockAmmo = 0;
	self.pers["clip_ammo"] = clipAmmo;
	self.pers["stock_ammo"] = stockAmmo;

	self GiveWeapon( spawn_weapon );
	self SetWeaponAmmoClip( spawn_weapon, clipAmmo );
	self SetWeaponAmmoStock( spawn_weapon, stockAmmo );
	self SetSpawnWeapon( spawn_weapon );

	return spawn_weapon;
}
