#using scripts\shared\clientfield_shared;
#using scripts\codescripts\struct;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

function main()
{
	clientfield::register( "clientuimodel", "hudItems.players_lives", VERSION_SHIP, 4, "int", undefined, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
}

function onPrecacheGameType()
{
}

function onStartGameType()
{
}