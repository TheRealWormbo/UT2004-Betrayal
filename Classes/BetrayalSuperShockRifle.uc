/******************************************************************************
BetrayalSuperShockRifle

Creation date: 2010-05-19 12:22
Last change: $Id$
Copyright (c) 2010, Wormbo
******************************************************************************/

class BetrayalSuperShockRifle extends SuperShockRifle hidedropdown;


simulated function PostBeginPlay()
{
	// sanity check: are we actually running Betrayal?
	if (Level.GRI != None && BetrayalGRI(Level.GRI) == None)
		FireModeClass[1] = FireModeClass[0];
	Super.PostBeginPlay();
}


/**
Use altfire to betray team mates.
*/
function byte BestMode()
{
	local Bot B;
	local BetrayalGame Game;

	Game = BetrayalGame(Level.Game);
	B = Bot(Instigator.Controller);
	if (B != None && Game != None && Game.OnSameTeam(Instigator, B.Enemy))
		return 1;

	return 0;
}


//=============================================================================
// Default values
//=============================================================================

defaultproperties
{
	FireModeClass(0) = BetrayalSuperShockBeamFire
	FireModeClass(1) = BetrayalSuperShockBeamAltFire
	AttachmentClass  = BetrayalShockAttachment

	ItemName = "Betrayal Instagib Rifle"
	PickupClass = class'BetrayalSuperShockRiflePickup'
}

