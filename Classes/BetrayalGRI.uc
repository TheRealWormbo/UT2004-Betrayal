/******************************************************************************
BetrayalGRI

Creation date: 2010-05-19 12:47
Last change: $Id$
Copyright (c) 2010, Wormbo
******************************************************************************/

class BetrayalGRI extends GameReplicationInfo;


//=============================================================================
// Variables
//=============================================================================

var() editconst float MaxUnlagTime;
var() editconst bool bPlayersMustBeReady;
var() editconst bool bBrighterPlayerSkins;
var() editconst bool bImprovedSlopeDodging;


//=============================================================================
// Replication
//=============================================================================

replication
{
	reliable if (bNetInitial)
		MaxUnlagTime, bPlayersMustBeReady, bBrighterPlayerSkins, bImprovedSlopeDodging;
}


/**
Duplicated form MutInstagib to improve the chances of pickup bases being removed.
*/
simulated function BeginPlay()
{
	local xPickupBase P;
	local Pickup L;

	foreach AllActors(class'xPickupBase', P) {
		P.bHidden = true;
		if (P.myEmitter != None)
			P.myEmitter.Destroy();
	}
	foreach AllActors(class'Pickup', L)
		if (L.IsA('WeaponLocker'))
			L.GotoState('Disabled');

	Super.BeginPlay();
}


/**
Notify server whether this particular client wants unlagging.
*/
simulated function PostNetBeginPlay()
{
	local PlayerController PC;

	Super.PostNetBeginPlay();

	PC = Level.GetLocalPlayerController();
	if (PC != None)
	{
		PC.Mutate("WantUnlagging"@int(class'BetrayalPRI'.default.bWantUnlagging));

		// replace booster combo with pint-sized combo, because the former is entirely useless in Betrayal
		if (xPlayer(PC) != None)
		{
			xPlayer(PC).ComboNameList[2] = "BonusPack.ComboMiniMe";
			xPlayer(PC).ComboList[2] = class<Combo>(DynamicLoadObject(xPlayer(PC).ComboNameList[2], class'Class'));
		}
	}
}


/**
Prevent incrementing clientside elapsed time before match start and after match end.
*/
simulated function Timer()
{
	Super.Timer();

	if (Level.NetMode == NM_Client && bStopCountDown)
		ElapsedTime--;
}


//=============================================================================
// Default values
//=============================================================================

defaultproperties
{
}

