/******************************************************************************
MutMercuryIGBetrayal

Creation date: 2011-03-13 14:30
Last change: $Id$
Copyright © 2011, Wormbo
Website: http://www.koehler-homepage.de/Wormbo/
Feel free to reuse this code. Send me a note if you found it helpful or want
to report bugs/provide improvements.
Please ask for permission first, if you intend to make money off reused code.
******************************************************************************/

class MutMercuryIGBetrayal extends Mutator;


//=============================================================================
// Configuration
//=============================================================================

var config float RocketJumpBoost;


//=============================================================================
// Localization
//=============================================================================

var localized string RocketJumpBoostText;
var localized string RocketJumpBoostHelpText;


/**
Only works in Betrayal mode.
*/
function bool MutatorIsAllowed()
{
	return !Level.IsDemoBuild() && BetrayalGame(Level.Game) != None;
}


/**
Replace the default Betrayal weapon.
*/
function PostBeginPlay()
{
	local BetrayalMutator BM;

	BM = BetrayalMutator(Level.Game.BaseMutator);
	if (BM != None) {
		BM.WeaponName        = class'BetrayalMercuryLauncher'.Name;
		BM.WeaponString      = string(class'BetrayalMercuryLauncher');
		BM.DefaultWeaponName = string(class'BetrayalMercuryLauncher');
	}

	if (BetrayalGame(Level.Game) != None)
		BetrayalGame(Level.Game).bUnlaggingDisabled = True; // not supported
}


/**
Configures the Mercury Missile Launcher's settings.
*/
function bool AlwaysKeep(Actor Other)
{
	if (BetrayalMercuryLauncher(Other) != None)
		BetrayalMercuryLauncher(Other).RocketJumpBoost = RocketJumpBoost;

	return NextMutator != None && NextMutator.AlwaysKeep(Other);
}


/**
Adds  Mercury Missile config details to the server details.
*/
function GetServerDetails(out GameInfo.ServerResponseLine ServerState)
{
	local int i;

	Super.GetServerDetails(ServerState);

	i = ServerState.ServerInfo.Length;
	ServerState.ServerInfo[i++] = KeyValuePair("Mercury Jump Boost", RocketJumpBoost);
}


static final function GameInfo.KeyValuePair KeyValuePair(string Key, coerce string Value)
{
	local GameInfo.KeyValuePair Pair;

	Pair.Key = Key;
	Pair.Value = Value;

	return Pair;
}


/**
Adds configurable properties to the web admin interface.
*/
static function FillPlayInfo(PlayInfo PlayInfo)
{
	Super.FillPlayInfo(PlayInfo);

	PlayInfo.AddSetting(default.RulesGroup, "RocketJumpBoost", default.RocketJumpBoostText, 0, 0, "Text", "5;0.0:20.0");
}


/**
Returns the description text for a configurable property.
*/
static event string GetDescriptionText(string PropName)
{
	if (PropName == "RocketJumpBoost")
		return default.RocketJumpBoostHelpText;

	return Super.GetDescriptionText(PropName);
}


//=============================================================================
// Default values
//=============================================================================

defaultproperties
{
	FriendlyName = "Betrayal Mercury Missiles"
	Description  = "Replaces the Instagib Rifle in Betrayal with the Instagib Mercury Missile Launcher."
	bAddToServerPackages = True

	RocketJumpBoost = 3.0

	RocketJumpBoostText     = "Rocket jump boost"
	RocketJumpBoostHelpText     = "Higher values make rocket jumps with mercury missiles more efficient. (default: 3.0)"
}

