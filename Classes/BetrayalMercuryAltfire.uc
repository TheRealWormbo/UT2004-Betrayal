/******************************************************************************
BetrayalMercuryAltfire

Creation date: 2011-03-13 16:28
Last change: $Id$
Copyright © 2011, Wormbo
Website: http://www.koehler-homepage.de/Wormbo/
Feel free to reuse this code. Send me a note if you found it helpful or want
to report bugs/provide improvements.
Please ask for permission first, if you intend to make money off reused code.
******************************************************************************/

class BetrayalMercuryAltFire extends BetrayalMercuryFire;


//=============================================================================
// Imports
//=============================================================================

#exec audio import file=Sounds\MercBetrayalIgnite.wav


function DoFireEffect()
{
	local BetrayalGame Game;
	local Bot B;
	local BetrayalPRI PRI;

	Super.DoFireEffect();

	Game = BetrayalGame(Level.Game);
	PRI = BetrayalPRI(Instigator.PlayerReplicationInfo);
	if (Game != None && PRI != None) {
		if (Instigator.Controller != None && Instigator.Controller.ShotTarget != None)
			B = Bot(Instigator.Controller.ShotTarget.Controller);
		if (B != None && Game.OnSameTeam(Instigator, B.Pawn) && BetrayalSquadAI(B.Squad) != None && (PRI.CurrentTeam.TeamPot >= PRI.RogueValue || Game.GoalScore > 0 && PRI.CurrentTeam.TeamPot >= Min(PRI.RogueValue, Game.GoalScore - Max(PRI.Score, B.PlayerReplicationInfo.Score)))) {
			//`log(Instigator.Controller.ShotTarget.Controller.PlayerReplicationInfo.PlayerName$" betray shooter");
			BetrayalSquadAI(B.Squad).bBetrayTeam = true;
			BetrayalSquadAI(B.Squad).SetEnemy(B, Instigator);
		}
	}
}


//=============================================================================
// Default values
//=============================================================================

defaultproperties
{
	FireSound = Sound'MercBetrayalIgnite'
	TransientSoundVolume = 0.6
	ProjectileClass = class'BetrayalMercuryBetrayMissile'
}

