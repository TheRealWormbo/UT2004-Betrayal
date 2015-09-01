/******************************************************************************
NavPointRatingInfo

Creation date: 2011-08-01 07:16
Last change: $Id$
Copyright © 2011, Wormbo
Website: http://www.koehler-homepage.de/Wormbo/
Feel free to reuse this code. Send me a note if you found it helpful or want
to report bugs/provide improvements.
Please ask for permission first, if you intend to make money off reused code.
******************************************************************************/

class NavPointRatingInfo extends Inventory;


var bool bNoAssociatedStartSpot;
var PlayerStart ClosestStartSpot;


function PlayerStart GetClosestPlayerStart()
{
	local NavigationPoint thisNP;
	local float Dist, BestDist;

	if (bNoAssociatedStartSpot || ClosestStartSpot != None)
		return ClosestStartSpot;

	if (PlayerStart(Owner) != None) {
		ClosestStartSpot = PlayerStart(Owner);
		return ClosestStartSpot;
	}

	if (PathNode(Owner) != None && HoverPathNode(Owner) == None && FlyingPathNode(Owner) == None || JumpDest(Owner) != None && GameObjective(Owner) == None || AssaultPath(Owner) != None || LiftExit(Owner) != None || AIMarker(Owner) != None || InventorySpot(Owner) != None && (InventorySpot(Owner).markedItem == None || InventorySpot(Owner).markedItem.IsInState('Disabled'))) {
		for (thisNP = Level.NavigationPointList; thisNP != None; thisNP = thisNP.NextNavigationPoint) {
			if (PlayerStart(thisNP) != None) {
				Dist = VSize(Owner.Location - thisNP.Location);
				if (BestDist == 0.0 || BestDist > Dist) {
					ClosestStartSpot = PlayerStart(thisNP);
					BestDist = Dist;
				}
			}
		}
	}
	if (ClosestStartSpot == None)
		bNoAssociatedStartSpot = True;

	return ClosestStartSpot;
}


//=============================================================================
// Default values
//=============================================================================

defaultproperties
{
	RemoteRole = ROLE_None
	bTravel = False
	CollisionRadius = 25.0
	CollisionHeight = 44.0
	bCollideWorld = True
	bCollideActors = True
	bOnlyAffectPawns = True
}

