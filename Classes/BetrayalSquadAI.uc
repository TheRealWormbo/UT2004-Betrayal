/******************************************************************************
BetrayalSquadAI

Creation date: 2011-03-08 21:03
Last change: $Id$
Copyright © 2011, Wormbo
Website: http://www.koehler-homepage.de/Wormbo/
Feel free to reuse this code. Send me a note if you found it helpful or want
to report bugs/provide improvements.
Please ask for permission first, if you intend to make money off reused code.
******************************************************************************/

class BetrayalSquadAI extends DMSquad;


//=============================================================================
// Variables
//=============================================================================

var bool bBetrayTeam;
var BetrayalPRI PRI;
var BetrayalTeam CurrentTeam;


function AddBot(Bot B)
{
	Super.AddBot(B);
	PRI = BetrayalPRI(B.PlayerReplicationInfo);
}

function bool SetEnemy(Bot B, Pawn NewEnemy)
{
	return ValidEnemy(NewEnemy) && Super.SetEnemy(B, NewEnemy);
}

function bool FriendlyToward(Pawn Other)
{
	return !bBetrayTeam && (Level.Game.TimeLimit == 0 || DeathMatch(Level.Game) == None || DeathMatch(Level.Game).RemainingTime > 15) && CurrentTeam != None && BetrayalPRI(Other.PlayerReplicationInfo) != None && BetrayalPRI(Other.PlayerReplicationInfo).CurrentTeam == CurrentTeam;
}

function SetNewTeam(BetrayalTeam NewTeam)
{
	local int i;

	CurrentTeam = NewTeam;
	bBetrayTeam = False;

	if (CurrentTeam != None) {
		for (i = 0; i < ArrayCount(Enemies); i++) {
			if (Enemies[i] != None && BetrayalPRI(Enemies[i].PlayerReplicationInfo) != None && BetrayalPRI(Enemies[i].PlayerReplicationInfo).CurrentTeam == CurrentTeam)
				RemoveEnemy(Enemies[i]);
		}
	}
}

function NotifyNewTeammate(BetrayalPRI PRI)
{
	if (!bBetrayTeam && PRI.Pawn != None)
		RemoveEnemy(PRI.Pawn);
}

function float ModifyThreat(float current, Pawn NewThreat, bool bThreatVisible, Bot B)
{
	local BetrayalPRI ThreatPRI;

	ThreatPRI = BetrayalPRI(NewThreat.PlayerReplicationInfo);
	if (ThreatPRI != None) {
		current += 0.5 * (ThreatPRI.ScoreValueFor(PRI) - 1);
		if (bThreatVisible && ThreatPRI.bIsRogue && PRI.Betrayer == ThreatPRI)
			current += 2; // kill the traitor!
		if (bThreatVisible && PRI.bIsRogue && ThreatPRI.Betrayer == PRI)
			current += 1; // he probably won't like me
	}
	return current;
}

function bool MustKeepEnemy(Pawn E)
{
	local BetrayalPRI EnemyPRI;

	EnemyPRI = BetrayalPRI(E.PlayerReplicationInfo);
	return EnemyPRI != None && EnemyPRI.bIsRogue && PRI.Betrayer == EnemyPRI;
}


//=============================================================================
// Default values
//=============================================================================

defaultproperties
{
}

