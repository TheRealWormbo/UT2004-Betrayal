/******************************************************************************
BetrayalUnlaggedCollision

Creation date: 2011-03-09 23:35
Last change: $Id$
Copyright © 2011, Wormbo
Website: http://www.koehler-homepage.de/Wormbo/
Feel free to reuse this code. Send me a note if you found it helpful or want
to report bugs/provide improvements.
Please ask for permission first, if you intend to make money off reused code.
******************************************************************************/

class BetrayalUnlaggedCollision extends Actor notplaceable;


//=============================================================================
// Structs
//=============================================================================

struct TUnlagData {
	var float TimeSeconds;
	var vector Location;
	var float CollisionRadius, CollisionHeight;
	var bool bJustTeleported;
};


//=============================================================================
// Variables
//=============================================================================

var bool bUnlagged;

var private array<TUnlagData> UnlagData;

var BetrayalGame Game;
var BetrayalUnlaggedCollision PrevCollision, NextCollision;


/**
Associate with the owner pawn.
*/
function PostBeginPlay()
{
	Game = BetrayalGame(Level.Game);
	if (Game == None || BetrayalPawn(Owner) == None) {
		Destroy();
		return;
	}

	NextCollision = Game.FirstCollision;
	Game.FirstCollision = Self;
	if (NextCollision != None)
		NextCollision.PrevCollision = Self;
}

function Destroyed()
{
	if (PrevCollision != None && PrevCollision.NextCollision == Self) {
		PrevCollision.NextCollision = NextCollision;
	}
	if (NextCollision != None && NextCollision.PrevCollision == Self) {
		NextCollision.PrevCollision = PrevCollision;
	}
	if (Game != None && Game.FirstCollision == Self) {
		Game.FirstCollision = NextCollision;
	}
}

/**
Delegate damage to unlagged pawn.
*/
function TakeDamage(int Damage, Pawn EventInstigator, vector HitLocation, vector Momentum, class<DamageType> DamageType)
{
	if (bUnlagged && Owner != None) {
		Owner.SetLocation(Location);
		Owner.TakeDamage(Damage, EventInstigator, HitLocation + (Owner.Location - Location), Momentum, DamageType);
	}
}


/**
Remember the last ticks' locations for serverside ping compensation.
*/
function UpdateUnlagLocation()
{
	local int i;

	if (Owner == None || Pawn(Owner) != None && Pawn(Owner).Health <= 0) {
		Destroy();
		return;
	}
	Assert(!bUnlagged);

	// is there any outdated unlag data?
	if (UnlagData.Length > 1 && UnlagData[1].TimeSeconds + Game.MaxUnlagTime < Level.TimeSeconds) {
		// determine amount of outdated unlag data
		do {} until (++i == UnlagData.Length-1 || UnlagData[i+1].TimeSeconds + Game.MaxUnlagTime >= Level.TimeSeconds);

		// remove outdated unlag data
		UnlagData.Remove(0, i);
	}

	i = UnlagData.Length;
	UnlagData.Length = i + 1;
	UnlagData[i].TimeSeconds = Level.TimeSeconds;
	UnlagData[i].Location = Owner.Location;
	UnlagData[i].CollisionHeight = Owner.CollisionHeight;
	UnlagData[i].CollisionRadius = Owner.CollisionRadius;
	UnlagData[i].bJustTeleported = (VSize(Owner.Location - UnlagData[i].Location) / (Level.TimeSeconds - UnlagData[i].TimeSeconds) > 10000.0);
}


/**
Spawn and enable the unlagged collision cylinder.
*/
function EnableUnlag(float PingTime, vector ShotStart, vector ShotDir)
{
	local int Low, High, Middle;
	local vector UnlaggedLocation, CurrentLocation;
	local float UnlagTime, Alpha;
	local float CurrentRadius, CurrentHeight;
	local float UnlaggedRadius, UnlaggedHeight;

	if (Level.NetMode == NM_Standalone || Owner == None || !bUnlagged && !Owner.bCollideActors || Pawn(Owner) != None && Pawn(Owner).Health <= 0 || UnlagData.Length == 0) {
		return;
	}

	if (bUnlagged) {
		CurrentLocation = Location;
		CurrentRadius   = CollisionRadius;
		CurrentHeight   = CollisionHeight;
	}
	else {
		CurrentLocation = Owner.Location;
		CurrentRadius   = Owner.CollisionRadius;
		CurrentHeight   = Owner.CollisionHeight;
	}

	UnlagTime = Level.TimeSeconds - FClamp(PingTime, 0, Game.MaxUnlagTime);
	High = UnlagData.Length;
	while (Low < High) {
		Middle = (High + Low) / 2;
		if (UnlagData[Middle].TimeSeconds < UnlagTime)
			Low = Middle + 1;
		else
			High = Middle;
	}
	if (Low == 0) {
		// past end of data, just use oldest entry
		UnlaggedLocation = UnlagData[0].Location;
		UnlaggedRadius   = UnlagData[0].CollisionRadius;
		UnlaggedHeight   = UnlagData[0].CollisionHeight;
		//log(Owner@"max. unlagging");
	}
	else if (!UnlagData[Low].bJustTeleported) {
		// unlag time between entries Low and Low-1
		Alpha = (UnlagData[Low].TimeSeconds - UnlagTime) / (UnlagData[Low].TimeSeconds - UnlagData[Low-1].TimeSeconds);

		UnlaggedLocation = Alpha * UnlagData[Low].Location + (1 - Alpha) * UnlagData[Low-1].Location;
		UnlaggedRadius   = Lerp(Alpha, UnlagData[Low-1].CollisionRadius, UnlagData[Low].CollisionRadius);
		UnlaggedHeight   = Lerp(Alpha, UnlagData[Low-1].CollisionHeight, UnlagData[Low].CollisionHeight);
		//log(Owner@"unlagging to"@UnlagTime*100@Alpha*100@Low@"between"@UnlagData[Low-1].TimeSeconds*100@"and"@UnlagData[Low].TimeSeconds*100);
	}
	else {
		// teleported between entries, use the one closer to the unlag time
		if (UnlagData[Low].TimeSeconds - UnlagTime > UnlagTime - UnlagData[Low-1].TimeSeconds) {
			// newer entry is closer
			UnlaggedLocation = UnlagData[Low].Location;
			UnlaggedRadius   = UnlagData[Low].CollisionRadius;
			UnlaggedHeight   = UnlagData[Low].CollisionHeight;
		}
		else {
			// older entry is closer
			UnlaggedLocation = UnlagData[Low-1].Location;
			UnlaggedRadius   = UnlagData[Low-1].CollisionRadius;
			UnlaggedHeight   = UnlagData[Low-1].CollisionHeight;
		}
	}
	// only actually enable unlagging if relevant (pawn or unlagged collision in line of shot)
	//if (ShotDir dot (UnlaggedLocation - ShotStart) > 0 && VSize(ShotDir cross (UnlaggedLocation - ShotStart)) < UnlaggedRadius + UnlaggedHeight || ShotDir dot (Owner.Location - ShotStart) > 0 && VSize(ShotDir cross (CurrentLocation - ShotStart)) < CurrentRadius + CurrentHeight) {
		//log("...really!");
		SetLocation(UnlaggedLocation);
		SetCollisionSize(UnlaggedRadius, UnlaggedHeight);
		if (!bUnlagged) {
			SetCollision(Owner.bCollideActors, Owner.bBlockActors, Owner.bBlockPlayers);
			Owner.SetCollision(false, false, false);
		}
		bUnlagged = True;
	//}
}


/**
Disable the unlagged collision cylinder for the UnlaggedPawn.
*/
function DisableUnlag()
{
	if (!bUnlagged || Level.NetMode == NM_Standalone || Owner == None || Owner.bCollideActors)
		return;

	Owner.SetCollision(bCollideActors, bBlockActors, bBlockPlayers);
	SetCollision(false, false, false);
	bUnlagged = False;
}


//=============================================================================
// Default properties
//=============================================================================

defaultproperties
{
	bHidden         = True
	RemoteRole      = ROLE_None
	bCollideWorld   = False
	bCollideActors  = False
	bBlockActors    = False
	bProjTarget     = True
}

