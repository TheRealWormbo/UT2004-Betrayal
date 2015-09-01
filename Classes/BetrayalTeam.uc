/******************************************************************************
BetrayalTeam

Creation date: 2010-01-31 15:24
Last change: $Id$
Copyright (c) 2010, Wormbo
******************************************************************************/

class BetrayalTeam extends ReplicationInfo;


const MAX_TEAMMATES = 3;
var BetrayalPRI Teammates[MAX_TEAMMATES];

//Value of the shared pot
var int TeamPot;

replication
{
	reliable if (bNetDirty)
		TeamPot, Teammates;
}


function bool AddTeammate(BetrayalPRI NewTeammate, int MaxTeamSize)
{
	local int i, NumTeammates;
	local Bot B;

	if (TeamPot > NewTeammate.RogueValue / 2) {
		// don't add to teams that already have significant pots
		return false;
	}

	//Count current team size
	for (i = 0; i < MAX_TEAMMATES; i++) {
		if (Teammates[i] != None) {
			NumTeammates++;
		}
	}

	MaxTeamSize = Min(MaxTeamSize, MAX_TEAMMATES);
	if (NumTeammates >= MaxTeamSize) {
		return false;
	}

	for (i = 0; i < MAX_TEAMMATES; i++) {
		if (Teammates[i] == NewTeammate) {
			// already added
			return true;
		}

		if (Teammates[i] == None || Teammates[i].bDeleteMe) {
			NewTeammate.CurrentTeam = self;
			Teammates[i] = NewTeammate;
			//NewTeamMate.TeamChanged();

			B = Bot(NewTeamMate.Owner);
			if (B != None && BetrayalSquadAI(B.Squad) != None)
				BetrayalSquadAI(B.Squad).SetNewTeam(Self);

			// save to reuse i here
			for (i = 0; i < MAX_TEAMMATES; i++) {
				// prevent bot from instantly attacking new teammates
				if (Teammates[i] != None) {
					B = Bot(Teammates[i].Owner);
					if (B != None && BetrayalSquadAI(B.Squad) != None)
						BetrayalSquadAI(B.Squad).NotifyNewTeammate(NewTeammate);
				}
			}
			return true;
		}
	}

	return false;
}

function bool MemberWasBetrayedBy(BetrayalPRI PRI)
{
	local int i;

	if (PRI.BetrayedTeam == Self)
		return true; // actually betrayed this team

	for (i = 0; i < MAX_TEAMMATES; i++) {
		if (Teammates[i] != None && PRI.Betrayed == Teammates[i])
			return true; // betrayed a new member of this team
	}
	return false;
}

function int LoseTeammate(BetrayalPRI OldTeammate)
{
	local int i, NumTeammates;
	local Bot B;

	OldTeammate.CurrentTeam = None;
	//OldTeammate.TeamChanged();
	B = Bot(OldTeammate.Owner);
	if (B != None && BetrayalSquadAI(B.Squad) != None)
		BetrayalSquadAI(B.Squad).SetNewTeam(None);

	NetUpdateTime = Level.TimeSeconds - 1;
	for (i = 0; i < MAX_TEAMMATES; i++) {
		if (Teammates[i] == None || Teammates[i] == OldTeammate || Teammates[i].bDeleteMe) {
			Teammates[i] = None;
		}
		else {
			NumTeammates++;
		}
	}

	//Returns number of teammates left after removing a player
	return NumTeammates;
}

/**
Discard temporary teams on reset.
*/
function Reset()
{
	local int i;

	for (i = 0; i < MAX_TEAMMATES; i++) {
		if (Teammates[i] != None)
			LoseTeammate(Teammates[i]);
	}

	if (BetrayalGame(Level.Game) != None)
		BetrayalGame(Level.Game).RemoveTeam(Self);
	Destroy();
}


//=============================================================================
// Default values
//=============================================================================

defaultproperties
{
	NetUpdateFrequency = 2
}
