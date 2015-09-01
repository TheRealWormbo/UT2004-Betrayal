/******************************************************************************
BetrayalSuperShockBeamFire

Creation date: 2011-03-08 23:29
Last change: $Id$
Copyright © 2011, Wormbo
Website: http://www.koehler-homepage.de/Wormbo/
Feel free to reuse this code. Send me a note if you found it helpful or want
to report bugs/provide improvements.
Please ask for permission first, if you intend to make money off reused code.
******************************************************************************/

class BetrayalSuperShockBeamFire extends SuperShockBeamFire;


//=============================================================================
// Properties
//=============================================================================

var bool bSameTeamShot;
var int HitCount;
var bool bWasHeadShot;


function bool AllowMultiHit()
{
	return BetrayalGame(Level.Game) != None && BetrayalGame(Level.Game).bBeamMultiHit;
}


function DoTrace(vector Start, rotator Dir)
{
	local BetrayalPRI PRI;

	HitCount = 0;
	bWasHeadShot = False;
	if (BetrayalGame(Level.Game) != None)
		BetrayalGame(Level.Game).EnableUnlag(Instigator, Start, vector(Dir));
	Super.DoTrace(Start, Dir);

	PRI = BetrayalPRI(Instigator.PlayerReplicationInfo);
	if (PRI != None) {
		PRI.Shots++;
		if (bWasHeadShot)
			PRI.HeadCount++;
		if (HitCount > 0)
			PRI.Hits++;
		if (HitCount > 1) {
			PRI.MultiHits++;
			if (PlayerController(Instigator.Controller) != None)
				PlayerController(Instigator.Controller).ReceiveLocalizedMessage(class'BetrayalSpecialKillMessage', HitCount);
		}
		else if (bWasHeadShot && Instigator.Controller != None) {
			if (PlayerController(Instigator.Controller) != None)
				PlayerController(Instigator.Controller).ReceiveLocalizedMessage(class'SpecialKillMessage');
			if (PRI.HeadCount == 15 && UnrealPlayer(Instigator.Controller) != None)
				UnrealPlayer(Instigator.Controller).ClientDelayedAnnouncementNamed('HeadHunter', 15);
		}
		if (HitCount > PRI.BestMultiHit)
			PRI.BestMultiHit = HitCount;
	}
	if (BetrayalGame(Level.Game) != None) {
		BetrayalGame(Level.Game).DisableUnlag();

		if (bWasHeadShot || HitCount > 1)
			BetrayalGame(Level.Game).ScoreSpecialKill(Instigator.Controller);
	}
}


function TracePart(vector Start, vector End, vector X, rotator Dir, Pawn Ignored)
{
	local vector HitLocation, HitNormal;
	local Actor Other;
	local BetrayalGame Game;
	local BetrayalPRI PRI;
	local Bot B;
	local PlayerController HeadshotVictim;

	Other = Ignored.Trace(HitLocation, HitNormal, End, Start, true);
	PRI = BetrayalPRI(Instigator.PlayerReplicationInfo);
	if (BetrayalUnlaggedCollision(Other) != None)
		Other = Other.Owner;
	Game = BetrayalGame(Level.Game);
	if (Other != None && Other != Ignored) {
		if (!Other.bWorldGeometry) {
			if (Game == None || Pawn(Other) != None && Level.TimeSeconds - Pawn(Other).SpawnTime > Game.SpawnProtectionTime && Game.OnSameTeam(Instigator, Pawn(Other)) == bSameTeamShot) {
				if (Game != None && Pawn(Other) != None && bSameTeamShot) {
					Game.ShotTeammate(PRI, BetrayalPRI(Pawn(Other).PlayerReplicationInfo), Instigator, Pawn(Other));
				}
				if (Pawn(Other) != None && Pawn(Other).Health > 0) {
					HitCount++;
					if (Game != None && Game.bSpecialKillRewards && Pawn(Other).IsHeadShot(HitLocation, X, 1.0)) {
						bWasHeadShot = True;
						HeadshotVictim = PlayerController(Pawn(Other).Controller);
					}
				}
				Other.TakeDamage(DamageMax, Instigator, HitLocation, Momentum * X, DamageType);

				if (HeadshotVictim != None)
					HeadshotVictim.ReceiveLocalizedMessage(class'BetrayalSpecialKillMessage', 0, Instigator.PlayerReplicationInfo);
			}
			HitNormal = Vect(0,0,0);
			if (Pawn(Other) != None && HitLocation != Start && AllowMultiHit())
				TracePart(HitLocation, End, X, Dir, Pawn(Other));
		}
	}
	else {
		HitLocation = End;
		HitNormal = Vect(0,0,0);
	}
	if (Pawn(Other) == None && bSameTeamShot && Game != None) {
		if (Instigator.Controller != None && Instigator.Controller.ShotTarget != None)
			B = Bot(Instigator.Controller.ShotTarget.Controller);
		if (B != None && Game.OnSameTeam(Instigator, B.Pawn) && BetrayalSquadAI(B.Squad) != None && (PRI.CurrentTeam.TeamPot >= PRI.RogueValue || Game.GoalScore > 0 && PRI.CurrentTeam.TeamPot >= Min(PRI.RogueValue, Game.GoalScore - Max(PRI.Score, B.PlayerReplicationInfo.Score)))) {
			//`log(Instigator.Controller.ShotTarget.Controller.PlayerReplicationInfo.PlayerName$" betray shooter");
			BetrayalSquadAI(B.Squad).bBetrayTeam = true;
			BetrayalSquadAI(B.Squad).SetEnemy(B, Instigator);
		}
	}
	SpawnBeamEffect(Start, Dir, HitLocation, HitNormal, 0);
}


function SpawnBeamEffect(vector Start, rotator Dir, vector HitLocation, vector HitNormal, int ReflectNum)
{
	local ShockBeamEffect Beam;

	Beam = Weapon.Spawn(BeamEffectClass,,, Start, Dir);
	if (ReflectNum != 0)
		Beam.Instigator = None; // prevents client side repositioning of beam start
	Beam.AimAt(HitLocation, HitNormal);
}


//=============================================================================
// Default values
//=============================================================================

defaultproperties
{
	//BeamEffectclass = class'BetrayalShockBeamEffect'
}

