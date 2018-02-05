#using scripts\shared\callbacks_shared;
#using scripts\shared\gameobjects_shared;
#using scripts\shared\math_shared;
#using scripts\shared\scoreevents_shared;
#using scripts\shared\util_shared;

#using scripts\shared\weapons\_weapon_utils;

#insert scripts\shared\shared.gsh;

#using scripts\mp\gametypes\_globallogic;
#using scripts\mp\gametypes\_globallogic_audio;
#using scripts\mp\gametypes\_globallogic_score;
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
	level.onPlayerKilled = &onPlayerKilled;
	level.onSpawnPlayer = &onSpawnPlayer;
	level.giveCustomLoadout = &giveCustomLoadout; // set up our loadout

	level.forceAutoAssign = true;

	level.pointsPerPrimaryKill = GetGametypeSetting( "pointsPerPrimaryKill" );
	level.pointsPerSecondaryKill = GetGametypeSetting( "pointsPerSecondaryKill" );
	level.pointsPerPrimaryGrenadeKill = GetGametypeSetting( "pointsPerPrimaryGrenadeKill" );
	level.pointsPerMeleeKill = GetGametypeSetting( "pointsPerMeleeKill" );

	callback::on_spawned( &on_player_spawned ); // extra code on spawning

	gameobjects::register_allowed_gameobject( level.gameType );

	globallogic_audio::set_leader_gametype_dialog ( "startFreeForAll", "hcStartFreeForAll", "gameBoost", "gameBoost" );

	// Sets the scoreboard columns and determines with data is sent across the network
	globallogic::setvisiblescoreboardcolumns( "pointstowin", "kills", "deaths", "tomahawks", "humiliated" );
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

function on_player_spawned()
{
	/#
	self thread m_util::spawn_bot_button();
	#/
}


function giveCustomLoadout()
{
	primary_weapon = GetWeapon( "special_crossbow" );
	secondary_weapon = GetWeapon( "knife_ballistic" );
	equipment = GetWeapon( "hatchet" );

	self GiveWeapon( primary_weapon );
	self SetWeaponAmmoClip( primary_weapon, 6 );
	self SetWeaponAmmoStock( primary_weapon, 0 );

	self GiveWeapon( secondary_weapon );
	self SetWeaponAmmoClip( secondary_weapon, 1 );
	self SetWeaponAmmoStock( secondary_weapon, 2 );

	self GiveWeapon( equipment );
	self SetWeaponAmmoClip( equipment, 1 );
	self SwitchToOffHand( equipment );
	self.grenadeTypePrimary = equipment; // satisfy _weaponobjects in order to pickup equipment
	self.grenadeTypePrimaryCount = 1;

	self SetSpawnWeapon( primary_weapon );

	return primary_weapon;
}

function onPlayerKilled( eInflictor, attacker, iDamage, sMeansOfDeath, weapon, vDir, sHitLoc, psOffsetTime, deathAnimDuration )
{
	if ( IsPlayer( attacker ) && attacker != self )
	{
		if ( weapon_utils::isMeleeMOD( sMeansOfDeath ) )
		{
			attacker globallogic_score::givePointsToWin( level.pointsPerMeleeKill );
		}
		else if ( weapon.rootWeapon.name == "special_crossbow" )
		{
			attacker globallogic_score::givePointsToWin( level.pointsPerPrimaryKill );
		}
		else if ( weapon.rootWeapon.name == "knife_ballistic")
		{
			attacker globallogic_score::givePointsToWin( level.pointsPerSecondaryKill );
		}
		else if ( weapon.rootWeapon.name == "hatchet" )
		{
			scoreevents::processScoreEvent( "humiliation_gun", attacker, self, weapon );

			attacker globallogic_score::givePointsToWin( level.pointsPerPrimaryGrenadeKill );

			self globallogic_score::setPointsToWin( 0 );
			self.pers["humiliated"]++;
			self.humiliated = self.pers["humiliated"];
			self PlayLocalSound( "mod_wm_humiliation" );
			attacker PlayLocalSound( "mod_wm_bankrupt" );
		}
	}
	else
	{
		self globallogic_score::setPointsToWin( 0 );
		self.pers["humiliated"]++;
		self.humiliated = self.pers["humiliated"];
		self PlayLocalSound( "mod_wm_humiliation" );
	}
}