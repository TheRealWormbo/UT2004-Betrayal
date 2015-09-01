/******************************************************************************
BetrayalMutator

Creation date: 2010-01-31 15:45
Last change: $Id$
Copyright (c) 2010, Wormbo
******************************************************************************/

class BetrayalMutator extends MutZoomInstaGib hidedropdown cacheexempt;


/**
No team bosting and translocator settings.
*/
function PostBeginPlay();

/**
Only useful for Betrayal game mode.
*/
function bool MutatorIsAllowed()
{
	return BetrayalGame(Level.Game) != None;
}


/**
Not configurable.
*/
static function FillPlayInfo(PlayInfo PlayInfo);


function bool AlwaysKeep(Actor Other)
{
	return Super(Mutator).AlwaysKeep(Other);
}

function bool IsRelevant(Actor Other, out byte bSuperRelevant)
{
	if (Controller(Other) != None && MessagingSpectator(Other) == None) {
		Controller(Other).PawnClass = class'BetrayalPawn';
		Controller(Other).PreviousPawnClass = class'BetrayalPawn';
		Controller(Other).PlayerReplicationInfoClass = class'BetrayalPRI';
		Controller(Other).bAdrenalineEnabled = false;

		if (Bot(Other) != None)
			Bot(Other).ComboNames[2] = "BonusPack.ComboMiniMe";
		else if (xPlayer(Other) != None)
			xPlayer(Other).ComboNameList[2] = "BonusPack.ComboMiniMe";
	}

	return Super.IsRelevant(Other, bSuperRelevant);
}

function string RecommendCombo(string ComboName)
{
	if (FRand() > 0.5)
		return "XGame.ComboInvis";
	return ComboName;
}


function ModifyPlayer(Pawn Other)
{
	if (BetrayalPawn(Other) != None && Level.NetMode != NM_Standalone && BetrayalGRI(Level.GRI).MaxUnlagTime > 0.001) {
		if (BetrayalPawn(Other).UnlaggedCollision == None)
			BetrayalPawn(Other).UnlaggedCollision = Spawn(class'BetrayalUnlaggedCollision', Other);
	}

	Super.ModifyPlayer(Other);
}


function PlayerChangedClass(Controller aPlayer)
{
	Super.PlayerChangedClass(aPlayer);
	if (class<BetrayalPawn>(aPlayer.PawnClass) == None)
		aPlayer.PawnClass = class'BetrayalPawn';
}


function Mutate(string MutateString, PlayerController Sender)
{
	local string Cmd, Param;

	Super.Mutate(MutateString, Sender);

	if (Sender != None && Divide(MutateString, " ", Cmd, Param) && Cmd ~= "WantUnlagging") {
		if (BetrayalPRI(Sender.PlayerReplicationInfo) != None) {
			BetrayalPRI(Sender.PlayerReplicationInfo).bUseUnlagging = bool(Param);
		}
	}
}

//=============================================================================
// Default values
//=============================================================================

defaultproperties
{
	bAddToServerPackages = True
	WeaponName   = "BetrayalSuperShockRifle"
	WeaponString = "BetrayalV1.BetrayalSuperShockRifle"
	DefaultWeaponName = "BetrayalV1.BetrayalSuperShockRifle"
}
