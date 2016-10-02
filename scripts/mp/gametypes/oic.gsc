#using scripts\shared\array_shared;
#using scripts\shared\callbacks_shared;
#using scripts\shared\gameobjects_shared;
#using scripts\shared\math_shared;
#using scripts\shared\util_shared;
#using scripts\mp\gametypes\_globallogic;
#using scripts\mp\gametypes\_globallogic_audio;
#using scripts\mp\gametypes\_globallogic_score;
#using scripts\mp\gametypes\_spawning;
#using scripts\mp\gametypes\_spawnlogic;
#using scripts\mp\killstreaks\_killstreaks;
#using scripts\mp\_util;

#insert scripts\shared\shared.gsh;

/*
	Deathmatch
	Objective: 	Score points by eliminating other players
	Map ends:	When one player reaches the score limit, or time limit is reached
	Respawning:	No wait / Away from other players

	Level requirements
	------------------
		Spawnpoints:
			classname		mp_dm_spawn
			All players spawn from these. The spawnpoint chosen is dependent on the current locations of enemies at the time of spawn.
			Players generally spawn away from enemies.

		Spectator Spawnpoints:
			classname		mp_global_intermission
			Spectators spawn from these and intermission is viewed from these positions.
			Atleast one is required, any more and they are randomly chosen between.

	Level script requirements
	-------------------------
		Team Definitions:
			game["allies"] = "marines";
			game["axis"] = "nva";
			Because Deathmatch doesn't have teams with regard to gameplay or scoring, this effectively sets the available weapons.

		If using minefields or exploders:
			load::main();

	Optional level script settings
	------------------------------
		Soldier Type and Variation:
			game["soldiertypeset"] = "seals";
			This sets what character models are used for each nationality on a particular map.

			Valid settings:
				soldiertypeset	seals
*/

#precache("string", "MOD_OIC_PLAYER_KILLED");
#precache("string", "MOD_OIC_PLAYER_ELIMINATED");
#precache("string", "MOD_OIC_PLAYER_SURVIVOR");

function main()
{
	globallogic::init();

	util::registerTimeLimit( 0, 1440 );
	util::registerScoreLimit( 0, 50000 );
	util::registerRoundLimit( 0, 10 );
	util::registerRoundWinLimit( 0, 10 );
	util::registerNumLives( 0, 100 );

	globallogic::registerFriendlyFireDelay( level.gameType, 0, 0, 1440 );
	// moved to GetDvarInt, GetGametypeSetting wasn't working
	level.pointsPerWeaponKill = GetDvarInt( "pointsPerWeaponKill" );
	level.pointsPerMeleeKill = GetDvarInt( "pointsPerMeleeKill" );
	level.pointsForSurvivalBonus = GetDvarInt( "pointsForSurvivalBonus" );
	
	level.onStartGameType =&onStartGameType;
	level.onPlayerDamage = &onPlayerDamage;
	level.onPlayerKilled =&onPlayerKilled;
	level.onSpawnPlayer =&onSpawnPlayer;
	level.giveCustomLoadout = &giveCustomLoadout;

	//callback::on_connect( &on_player_connect ); // force teams on connecting
	
	gameobjects::register_allowed_gameobject( level.gameType );
	
	globallogic_audio::set_leader_gametype_dialog ( undefined, undefined, "gameBoost", "gameBoost" );

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
	
	level.displayRoundEndText = false;

	if ( !util::isOneRound() )
	{
		level.displayRoundEndText = true;
	}
	
	level thread watchElimination();
	level thread watchEndGame();
}

function on_player_connect()
{
	// get our team selection based on if we got an infected game going
	team = "free";
	self.pers["team"] = team;
	// moving to a built-in, still setting a team just in case.
	self SetTeam( team );
	// set this before to satisfy the spawnClient, need to fill in broken statement _globalloigc_spawn::836 
	self.waitingToSpawn = true;
	// something to satisfy matchRecordLogAdditionalDeathInfo 5th parameter (_globallogic_player)
	self.class_num = 0;
	// satisfy _loadout
	self.class_num_for_global_weapons = 0;
	// set the team
	self [[level.teamMenu]](team);
	// close the "Choose Class" menu
	self CloseMenu( MENU_CHANGE_CLASS );
}

function watchElimination()
{
	level endon( "game_ended" );
	
	for ( ;; )
	{
		level waittill( "player_eliminated" );
		foreach(player in level.players)
		{
			if ( IsDefined( player ) && ( IsAlive( player ) || !player IsPlayerEliminated() ) )
			{				
				player LUINotifyEvent( &"score_event", 3, &"MOD_OIC_PLAYER_SURVIVOR", 5, 0 );
				player globallogic_score::givePointsToWin( level.pointsForSurvivalBonus );
			}
		}
		alive_players = GetAlivePlayers();
		if(alive_players.size == 2)
		{
			foreach(player in alive_players)
			{
				SetTeamSpyplane( player.team, 1 );
				util::set_team_radar( player.team, 1 );					
			}
		}
	}
}

function watchEndGame()
{
	level waittill("game_ended");

	IPrintLn("One in the Chamber brought to you by: DidUknowiPwn");
	IPrintLn("YouTube: iPwnAtZombies, Twitter: CookiesAreLaw");
	IPrintLn("Check out UGX-Mods.com for more mods!");

}

function GetAlivePlayers()
{
	level endon("game_ended");

	players = [];
	foreach(player in level.players)
	{
		if(!player IsPlayerEliminated())
			array::add(players, player); 
	}

	return players;
}

function onEndGame( winningPlayer )
{
	if ( IsDefined( winningPlayer ) && isPlayer( winningPlayer ) )
		[[level._setPlayerScore]]( winningPlayer, winningPlayer [[level._getPlayerScore]]() + 1 );
}

function onSpawnPlayer(predictedSpawn)
{
	if( !level.inPrematchPeriod )
	{
		level.useStartSpawns = false;
	}
	
	spawning::onSpawnPlayer(predictedSpawn);

	lives = self.pers["lives"];

	if(lives < 3)
	{
		str = " lives ";
		if(lives == 2) // 1 life remaining
			str = " life ";
		str += "remaining";
		self IPrintLnBold(lives - 1 + str);
	}
}

function onPlayerDamage( eInflictor, eAttacker, iDamage, iDFlags, sMeansOfDeath, sWeapon, vPoint, vDir, sHitLoc, psOffsetTime )
{
	if ( ( sMeansOfDeath == "MOD_PISTOL_BULLET" ) || ( sMeansOfDeath == "MOD_RIFLE_BULLET" ) || ( sMeansOfDeath == "MOD_HEAD_SHOT" ) )
		iDamage = self.maxhealth + 1;
	
	return iDamage;
}

function onPlayerKilled( eInflictor, attacker, iDamage, sMeansOfDeath, weapon, vDir, sHitLoc, psOffsetTime, deathAnimDuration )
{
	if ( isDefined( attacker ) && isPlayer( attacker ) && self != attacker )
	{
		attacker GiveAmmo( 1 );
		attacker LUINotifyEvent( &"score_event", 3, &"MOD_OIC_PLAYER_KILLED", 5, 0 );
		attacker PlayLocalSound( "wpn_ammo_pickup" );

		if ( sMeansOfDeath == "MOD_MELEE" )
		{
			attacker globallogic_score::givePointsToWin( level.pointsPerMeleeKill );
		}
		else
		{
			attacker globallogic_score::givePointsToWin( level.pointsPerWeaponKill );			
		}
		
		if(self.pers["lives"] == 0)
			attacker LUINotifyEvent( &"score_event", 3, &"MOD_OIC_PLAYER_ELIMINATED", 5, 0 );
	}
}

function GiveAmmo( amount )
{		
	currentWeapon = self GetCurrentWeapon();
	clipAmmo = self GetWeaponAmmoClip( currentWeapon );
	self SetWeaponAmmoClip( currentWeapon, clipAmmo + amount );
}

function IsPlayerEliminated()
{
	return (self.pers["lives"] == 0);
}

function giveCustomLoadout()
{
	self thread various_stuff();

	self TakeAllWeapons();
	self ClearPerks();

	weapon = GetWeapon("pistol_standard");
	self GiveWeapon( weapon );
	self SetSpawnWeapon( weapon );

	clipAmmo = 1;
	if( IsDefined( self.pers["clip_ammo"] ) )
	{
		clipAmmo = self.pers["clip_ammo"];
		self.pers["clip_ammo"] = undefined;
	}
	self SetWeaponAmmoClip( weapon, clipAmmo );

	stockAmmo = 0;
	if( IsDefined( self.pers["stock_ammo"] ) )
	{
		stockAmmo = self.pers["stock_ammo"];
		self.pers["stock_ammo"] = undefined;
	}
	self SetWeaponAmmoStock( weapon, stockAmmo );
	self.class_num = 0;
	return weapon;
}

function various_stuff()
{
	self endon("death");
	self endon("disconnect");
	// don't allow the bots to use this
	if(self util::is_bot())
		return;

	for(;;)
	{
		WAIT_SERVER_FRAME;

		if ( self UseButtonPressed() && self AttackButtonPressed() )
		{
			bot = AddTestClient();
			
			if(IsDefined(bot))
				bot BotSetRandomCharacterCustomization();

			while ( self UseButtonPressed() )
				WAIT_SERVER_FRAME;
		}
	}
}