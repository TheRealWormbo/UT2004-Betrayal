/******************************************************************************
BetrayalScoreboard

Creation date: 2011-03-10 00:14
Last change: $Id$
Copyright © 2011, Wormbo
Website: http://www.koehler-homepage.de/Wormbo/
Feel free to reuse this code. Send me a note if you found it helpful or want
to report bugs/provide improvements.
Please ask for permission first, if you intend to make money off reused code.
******************************************************************************/

class BetrayalScoreboard extends ScoreBoardDeathMatch;


//=============================================================================
// Properties
//=============================================================================

var float HeaderAreaTop;
var float PlayersAreaLeft, PlayersAreaTop, PlayersAreaWidth, PlayersAreaMaxHeight;
var float RankPos, NamePos, NameMaxWidth, ScorePos, StatPos, NetPos;
var float SpectatorsAreaLeft, SpectatorsAreaBottom, SpectatorsAreaWidth, SpectatorsAreaMinSpacing;

var Material DaggerIcon;
var IntBox DaggerIconCoords;
var float DaggerScale, DaggerSpacing, DaggerGroupOffset;

var Material ReadyIcon;
var IntBox ReadyIconCoords;
var Material NotReadyIcon;
var IntBox NotReadyIconCoords;

var Material BGMaterial;
var color AreaBGColor, ItemBGColor, HeaderTextColor, RogueBGColor, TeamBGColor[2], ItemTextColor, LocalItemTextColor;
var float AreaBGScale, ItemBGScale, ItemSpacing;
var float AreaPadding, ItemPadding;

const STAT_TYPE_MAX = 4;
var localized string StatCaption[STAT_TYPE_MAX];


//=============================================================================
// Variables
//=============================================================================

/** Only valid during UpdateScoreboard(). */
var transient Canvas Canvas;

var string Title, VictoryCondition;
var Font PlayerFont, SpectatorFont, InfoFont;
var float ResScale;
var PlayerReplicationInfo LocalPRI;
var BetrayalPRI LocalBPRI;
var BetrayalGRI BGRI;

var byte StatType;

var transient int NumPlayers, NumDrawnPlayers, FirstSpectator, NumSpectators, NumDrawnSpectators;
var transient int LocalPlayerRank, LocalPlayerIndex, LocalSpectatorIndex, LocalSpectatorNum;
var transient float PlayersLeft, PlayersTop, PlayersWidth, PlayersHeight, PlayersRowHeight, PlayersRowSpacing;
var transient float SpectatorsLeft, SpectatorsTop, SpectatorsWidth, SpectatorsHeight, SpectatorsRowHeight, SpectatorsRowSpacing;
var transient float LargeTextYL;


function NextStats()
{
	if (++StatType >= STAT_TYPE_MAX)
		StatType = 0;
}

function bool GetStatPercent(BetrayalPRI PRI, out int Percent, out int ValueA, out int ValueB)
{
	switch (StatType) {
	case 0:
		ValueA = PRI.Hits;
		ValueB = PRI.Shots;
		Percent = 100 * ValueA / ValueB;
		return ValueB > 0;
	case 1:
		ValueA = PRI.RepKills;
		ValueB = PRI.Deaths;
		Percent = 100 * ValueA / (ValueA + ValueB);
		return ValueA + ValueB > 0;
	case 2:
		ValueA = PRI.PaybackCount;
		ValueB = PRI.BetrayalCount;
		Percent = 100 * ValueA / ValueB;
		return ValueB > 0;
	case 3:
		ValueA = PRI.RetributionCount;
		ValueB = PRI.BetrayedCount;
		Percent = 100 * ValueA / ValueB;
		return ValueB > 0;
	}
}

function bool InOrder(PlayerReplicationInfo P1, PlayerReplicationInfo P2)
{
	// spectators go to the end of the list in alphabetical order
	if (P1.bOnlySpectator)
		return P2.bOnlySpectator && Caps(P1.PlayerName) <= Caps(P2.PlayerName);
	else if (P2.bOnlySpectator)
		return true;

	// active players are sorted by score, kills and deaths
	return P1.Score > P2.Score || P1.Score == P2.Score && (P1.Kills > P2.Kills || P1.Kills == P2.Kills && P1.Deaths <= P2.Deaths);
}

static function Font GetFontSizeOffset(Font aFont, int offset)
{
	local int i;

	for (i = 0; i < 9; i++) {
		if (default.HudClass.static.LoadFontStatic(i) == aFont)
			return default.HudClass.static.LoadFontStatic(Clamp(i + offset, 0, 8));
	}
	return aFont;
}

function UpdateScoreBoard(Canvas C)
{
	local int DrawStage;
	local Hud LocalHud;

	if (PlayerController(Owner) != None) {
		LocalHud = PlayerController(Owner).MyHud;
		if (LocalHud != None)
			LocalPRI = LocalHud.PawnOwnerPRI;
		if (LocalPRI == None)
			LocalPRI = PlayerController(Owner).PlayerReplicationInfo;

		// draw crosshair, because can still see enough through the scores
		if (LocalHud != None && LocalHud.PlayerOwner != None && LocalHud.PawnOwner != None && LocalHud.PawnOwnerPRI != None && !LocalHud.PlayerOwner.IsSpectating() && !LocalHud.PlayerOwner.bBehindView && !LocalHud.PawnOwner.bHideRegularHUD)
			LocalHud.DrawCrosshair(C);
	}
	LocalBPRI = BetrayalPRI(LocalPRI);
	BGRI = BetrayalGRI(Level.GRI);

	Canvas = C;

	// initial style
	Canvas.Reset();
	Canvas.Style = 5;
	ResScale     = (Canvas.ClipX + Canvas.ClipY) / 1800;

	LayoutScoreboard();

	DrawHeader();
	DrawMatchID(Canvas, 0);

	// DrawStages: 0 = BG, 1 = big font, 2 = small/spectator font, 3 = other stuff
	for (DrawStage = 0; DrawStage < 4; DrawStage++) {
		DrawPlayers(DrawStage);
		if (NumSpectators > 0)
			DrawSpectators(DrawStage);
	}

	Canvas = None;
}

function String GetDefaultScoreInfoString()
{
	local String ScoreInfoString;

	if (GRI == None)
		return "";
	if (GRI.MaxLives != 0)
		ScoreInfoString = MaxLives@GRI.MaxLives@spacer;
	if (GRI.GoalScore != 0)
		ScoreInfoString @= class'ScoreBoardTeamDeathMatch'.default.FragLimit@GRI.GoalScore@spacer;
	if ( GRI.TimeLimit != 0 )
		ScoreInfoString @= TimeLimit@FormatTime(GRI.RemainingTime);
	else
		ScoreInfoString @= FooterText@FormatTime(GRI.ElapsedTime);

	return ScoreInfoString;
}


function DrawHeader()
{
	local float XL, YL, YPos;
	local string ScoreInfoString, RestartString;
	local int FontReduction;

	if (Title == "")
		Title = GetTitleString();

	YPos = HeaderAreaTop * Canvas.ClipY;
	Canvas.DrawColor = HUDClass.default.GoldColor;
	Canvas.Font = GetFontSizeOffset(PlayerFont, -4);
	Canvas.StrLen(Title, XL, YL);
	while ((XL > Canvas.ClipX * 0.95 || YL > Canvas.ClipY * 0.7 * PlayersAreaTop) && FontReduction < 3) {
		FontReduction++;
		Canvas.Font = GetFontSizeOffset(Canvas.Font, 1);
		Canvas.StrLen(Title, XL, YL);
	}
	if (XL > Canvas.ClipX * 0.95 || YL > Canvas.ClipY * 0.7 * PlayersAreaTop) {
		Canvas.FontScaleX = FMin(Canvas.ClipX * 0.95 / XL, Canvas.ClipY * 0.7 * PlayersAreaTop / YL);
		Canvas.FontScaleY = Canvas.FontScaleX;
		Canvas.StrLen(Title, XL, YL);
	}
	Canvas.SetPos(0.5 * (Canvas.ClipX - XL), YPos);
	Canvas.DrawText(Title, true);
	YPos += YL;
	Canvas.FontScaleX = 1.0;
	Canvas.FontScaleY = 1.0;

	ScoreInfoString = GetDefaultScoreInfoString();
	if (UnrealPlayer(Owner).bDisplayLoser)
		ScoreInfoString = class'HUDBase'.default.YouveLostTheMatch;
	else if (UnrealPlayer(Owner).bDisplayWinner)
		ScoreInfoString = class'HUDBase'.default.YouveWonTheMatch;
	else if (PlayerController(Owner).IsDead())
		RestartString = GetRestartString();

	FontReduction = 0;
	Canvas.Font = GetSmallFontFor(Canvas.ClipX, 0);
	Canvas.StrLen(ScoreInfoString, XL, YL);
	while ((XL > Canvas.ClipX * 0.95 || YL > Canvas.ClipY * 0.3 * PlayersAreaTop) && FontReduction < 5) {
		FontReduction++;
		Canvas.Font = GetSmallFontFor(Canvas.ClipX, FontReduction);
		Canvas.StrLen(ScoreInfoString, XL, YL);
	}
	Canvas.SetPos(0.5 * (Canvas.ClipX - XL), YPos);
	Canvas.DrawText(ScoreInfoString, true);
}


function LayoutScoreboard()
{
	local int i, FontReduction;
	local float NumFitting, XL, YL;

	// figure out how many players and spectators there are
	LocalPlayerIndex    = -1;
	LocalPlayerRank     =  0;
	NumPlayers          =  0;
	FirstSpectator      = -1;
	LocalSpectatorIndex = -1;
	NumSpectators       =  0;

	// players are sorted first...
	if (GRI.PRIArray.Length > 0 && !GRI.PRIArray[0].bOnlySpectator) {
		do {
			if (GRI.PRIArray[i].PlayerID != 0) {
				NumPlayers++;
				if (GRI.PRIArray[i] == LocalPRI) {
					LocalPlayerIndex = i;
					LocalPlayerRank = NumPlayers;
				}
			}
		} until (++i == GRI.PRIArray.Length || GRI.PRIArray[i].bOnlySpectator);
	}
	// ...then spectators, if any
	if (i < GRI.PRIArray.Length) {
		FirstSpectator = i;
		do {
			if (GRI.PRIArray[i].PlayerID != 0) {
				NumSpectators++;
				if (GRI.PRIArray[i] == LocalPRI) {
					LocalSpectatorIndex = i;
					LocalSpectatorNum   = NumSpectators;
				}
			}
		} until (++i == GRI.PRIArray.Length);
	}

	// determine players area dimensions
	PlayersLeft   = Canvas.ClipX * PlayersAreaLeft + AreaPadding * ResScale;
	PlayersTop    = Canvas.ClipY * PlayersAreaTop + AreaPadding * ResScale;
	PlayersWidth  = Canvas.ClipX * PlayersAreaWidth - 2 * AreaPadding * ResScale;
	PlayersHeight = Canvas.ClipY * PlayersAreaMaxHeight - 2 * AreaPadding * ResScale;

	// determine player font size
	FontReduction = 0;
	Canvas.Font = HudClass.static.GetMediumFontFor(Canvas);
	Canvas.StrLen("X", XL, YL);
	for (i = 0; i < 5 && (NumPlayers + 1) * (YL + (2 * ItemPadding + ItemSpacing) * ResScale) > PlayersHeight; i++) {
		Canvas.Font = GetSmallerFontFor(Canvas, ++FontReduction);
		Canvas.StrLen("X", XL, YL);
	}
	LargeTextYL       = YL;
	PlayerFont        = Canvas.Font;
	InfoFont          = GetSmallFontFor(Canvas.ClipX, FontReduction);
	PlayersRowHeight  = YL + 2 * ItemPadding * ResScale;
	PlayersRowSpacing = ItemSpacing * ResScale;

	// determine actual player area height and number of drawn players
	NumFitting = PlayersHeight / (PlayersRowHeight + PlayersRowSpacing) - 1;
	if (NumFitting >= NumPlayers) {
		NumDrawnPlayers = NumPlayers;
		NumFitting      = NumDrawnPlayers;
	}
	else if (LocalPlayerRank > 0 && LocalPlayerRank < NumPlayers && LocalPlayerRank > NumFitting - 0.5) {
		NumDrawnPlayers = NumFitting - 1.0; // rounded down
		NumFitting      = NumDrawnPlayers + 1;
	}
	else {
		NumDrawnPlayers = NumFitting - 0.5; // rounded down
		NumFitting      = NumDrawnPlayers + 0.5;
	}
	PlayersHeight = PlayersRowHeight * (NumFitting + 1) + PlayersRowSpacing * NumFitting;
	// header counts as row without extra spacing

	if (NumSpectators > 0) {
		// determine spectators area dimensions
		SpectatorsLeft   = Canvas.ClipX * SpectatorsAreaLeft + AreaPadding * ResScale;
		SpectatorsTop    = PlayersTop + PlayersHeight + 2 * AreaPadding * ResScale + Canvas.ClipY * SpectatorsAreaMinSpacing;
		SpectatorsWidth  = Canvas.ClipX * SpectatorsAreaWidth - 2 * AreaPadding * ResScale;
		SpectatorsHeight = Canvas.ClipY * SpectatorsAreaBottom - SpectatorsTop - 2 * AreaPadding * ResScale;

		// determine spectator font size
		FontReduction = 0;
		Canvas.Font = GetSmallFontFor(Canvas.ClipX, 0);
		Canvas.StrLen("X", XL, YL);
		for (i = 0; i < 4 && (NumSpectators + 1) * (YL + (2 * ItemPadding + ItemSpacing) * ResScale) > SpectatorsHeight; i++) {
			Canvas.Font = GetSmallFontFor(Canvas.ClipX, ++FontReduction);
			Canvas.StrLen("X", XL, YL);
		}
		SpectatorFont = Canvas.Font;
		SpectatorsRowHeight  = YL + 2 * ItemPadding * ResScale;
		SpectatorsRowSpacing = ItemSpacing * ResScale;

		// determine actual spectator area height and number of drawn spectators
		NumFitting = SpectatorsHeight / (SpectatorsRowHeight + SpectatorsRowSpacing) - 1;
		if (NumFitting >= NumSpectators) {
			NumDrawnSpectators = NumSpectators;
			NumFitting         = NumDrawnSpectators;
		}
		else {
			NumDrawnSpectators = NumFitting - 0.5; // rounded down
			NumFitting         = NumDrawnSpectators + 0.5;
		}
		SpectatorsHeight = SpectatorsRowHeight * (NumFitting + 1) + SpectatorsRowSpacing * NumFitting;
		SpectatorsTop    = Canvas.ClipY * SpectatorsAreaBottom - SpectatorsHeight - 2 * AreaPadding * ResScale;
	}
}


function DrawPlayers(byte DrawStage)
{
	local int i, PrevIndex, Rank;
	local float PosY;

	if (DrawStage == 0) {
		Canvas.DrawColor = AreaBGColor;
		class'BetrayalHud'.static.DrawBox(
			Canvas,
			BGMaterial,
			PlayersLeft - AreaPadding * ResScale,
			PlayersTop - AreaPadding * ResScale,
			PlayersWidth + 2 * AreaPadding * ResScale,
			PlayersHeight + 2 * AreaPadding * ResScale,
			AreaBGScale * ResScale,
			AreaBGScale * ResScale);
	}

	PosY = PlayersTop;
	DrawPlayerHeader(NumPlayers > 0, PlayersLeft, PosY, PlayersWidth, PlayersRowHeight, DrawStage);
	if (NumPlayers > 0) {
		// draw the players
		PrevIndex = -1;
		for (i = 0; i < GRI.PRIArray.Length && !GRI.PRIArray[i].bOnlySpectator && Rank < NumDrawnPlayers; i++) {
			if (GRI.PRIArray[i].PlayerID != 0) {
				Rank++;
				if (LocalPlayerRank <= NumDrawnPlayers || Rank < NumDrawnPlayers) {
					PosY += PlayersRowHeight + PlayersRowSpacing;
					DrawPlayer(GRI.PRIArray[i], Rank * int(PrevIndex < 0 || GRI.PRIArray[i].Score != GRI.PRIArray[PrevIndex].Score), PlayersLeft, PosY, PlayersWidth, PlayersRowHeight, DrawStage);
				}
				PrevIndex = i;
			}
		}
		if (NumDrawnPlayers < NumPlayers) {
			PosY += 0.5 * (PlayersRowHeight + PlayersRowSpacing);
			DrawEllipsis(PlayersLeft, PosY, PlayersWidth, 0.5 * PlayersRowHeight, DrawStage);
		}
		if (LocalPlayerRank > NumDrawnPlayers) {
			PosY += PlayersRowHeight + PlayersRowSpacing;
			DrawPlayer(GRI.PRIArray[LocalPlayerIndex], LocalPlayerRank, PlayersLeft, PosY, PlayersWidth, PlayersRowHeight, DrawStage);
			if (LocalPlayerRank < NumPlayers) {
				PosY += 0.5 * (PlayersRowHeight + PlayersRowSpacing);
				DrawEllipsis(PlayersLeft, PosY, PlayersWidth, 0.5 * PlayersRowHeight, DrawStage);
			}
		}
	}
}

function DrawPlayerHeader(bool bAnyPlayers, float X, float Y, float XL, float YL, byte DrawStage)
{
	local float TextXL, TextYL, SmallTextXL, SmallTextYL;
	local string NextStatCaption;

	if (!bAnyPlayers) {
		if (DrawStage == 0) {
			Canvas.DrawColor = ItemBGColor;
			class'BetrayalHud'.static.DrawBox(Canvas, BGMaterial, X, Y, XL, YL, ItemBGScale * ResScale, ItemBGScale * ResScale);
		}
		else if (DrawStage == 1) {
			Canvas.Font = PlayerFont;
			Canvas.DrawColor = HeaderTextColor;
			Canvas.StrLen(class'StartupMessage'.default.Stage[0], TextXL, TextYL);
			Canvas.SetPos(X + 0.5 * (XL - TextXL), Y + 0.5 * (YL - TextYL));
			Canvas.DrawTextClipped(class'StartupMessage'.default.Stage[0]);
		}
	}
	else if (DrawStage == 1 || DrawStage == 2) {
		Canvas.Font = InfoFont;
		NextStatCaption = class'GameInfo'.static.GetKeyBindName("NextStats", PlayerController(Owner));
		if (NextStatCaption != "")
			NextStatCaption = "[" $ NextStatCaption $ "]";
		Canvas.StrLen(NextStatCaption, SmallTextXL, SmallTextYL);

		Canvas.Font = PlayerFont;
		if (DrawStage == 1) {
			Canvas.DrawColor = HeaderTextColor;
			Canvas.StrLen(PlayerText, TextXL, TextYL);
			Canvas.SetPos(X + NamePos * XL, Y + 0.5 * (YL - TextYL));
			Canvas.DrawTextClipped(PlayerText);

			Canvas.FontScaleX = 0.75;
			Canvas.FontScaleY = 0.75;

			if (GRI.bMatchHasBegun) {
				Canvas.StrLen(PointsText, TextXL, TextYL);
				Canvas.SetPos(X + ScorePos * XL - 0.5 * TextXL, Y + 0.5 * (YL - TextYL));
				Canvas.DrawTextClipped(PointsText);

				Canvas.StrLen(StatCaption[StatType], TextXL, TextYL);
				Canvas.SetPos(X + StatPos * XL - 0.5 * (TextXL + SmallTextXL), Y + 0.5 * (YL - TextYL));
				Canvas.DrawTextClipped(StatCaption[StatType]);
			}
			else if (BGRI.bPlayersMustBeReady) {
				Canvas.StrLen(ReadyText, TextXL, TextYL);
				Canvas.SetPos(X + ScorePos * XL - 0.5 * TextXL, Y + 0.5 * (YL - TextYL));
				Canvas.DrawTextClipped(ReadyText);
			}
			if (Level.NetMode != NM_Standalone) {
				Canvas.StrLen(NetText, TextXL, TextYL);
				Canvas.SetPos(X + NetPos * XL - 0.5 * TextXL, Y + 0.5 * (YL - TextYL));
				Canvas.DrawTextClipped(NetText);
			}

			Canvas.FontScaleX = 1;
			Canvas.FontScaleY = 1;
		}
		else if (GRI.bMatchHasBegun) {
			Canvas.FontScaleX = 0.75;
			Canvas.FontScaleY = 0.75;
			Canvas.StrLen(StatCaption[StatType], TextXL, TextYL);
			Canvas.FontScaleX = 1;
			Canvas.FontScaleY = 1;

			Canvas.DrawColor = ItemTextColor;
			Canvas.Font = InfoFont;
			Canvas.SetPos(X + StatPos * XL + 0.5 * (TextXL - SmallTextXL), Y + 0.5 * (YL - SmallTextYL));
			Canvas.DrawTextClipped(NextStatCaption);
		}
	}
}

function DrawPlayer(PlayerReplicationInfo PRI, int Rank, float X, float Y, float XL, float YL, byte DrawStage)
{
	local float TextXL, IconXL, IconYL, NameTextYL, TextYL, PosX, PosY, TextScale;
	local BetrayalPRI BPRI;
	local string StatPercentString, PingString;
	local int NumSilverDaggers, NumGoldDaggers, NumRedDaggers, i, StatPercent, StatA, StatB;

	BPRI = BetrayalPRI(PRI);
	if (DrawStage == 1 || DrawStage == 3) {
		// figure out name/dagger scaling
		Canvas.Font = PlayerFont;
		Canvas.StrLen(PRI.PlayerName, TextXL, NameTextYL);

		if (BPRI != None) {
			NumSilverDaggers = BPRI.BetrayalCount % 5;
			NumGoldDaggers   = BPRI.BetrayalCount / 5 % 5;
			NumRedDaggers    = BPRI.BetrayalCount / 25;
		}
		if (BPRI.BetrayalCount > 0) {
			IconXL = (NumSilverDaggers + NumGoldDaggers + NumRedDaggers) * DaggerSpacing * ResScale + NameTextYL * DaggerScale * (DaggerIconCoords.X2 - DaggerIconCoords.X1) / (DaggerIconCoords.Y2 - DaggerIconCoords.Y1);
			if (NumSilverDaggers * NumGoldDaggers > 0 || NumSilverDaggers * NumRedDaggers > 0 || NumGoldDaggers * NumRedDaggers > 0)
				IconXL += DaggerGroupOffset * ResScale; // at least two groups used
			if (NumSilverDaggers * NumGoldDaggers * NumRedDaggers > 0)
				IconXL += DaggerGroupOffset * ResScale; // all three groups used
		}
		if (TextXL + IconXL > XL * NameMaxWidth)
			TextScale = XL * NameMaxWidth / (TextXL + IconXL);
		else
			TextScale = 1.0;

		Canvas.FontScaleX = TextScale;
		Canvas.FontScaleY = TextScale;
		Canvas.StrLen(PRI.PlayerName, TextXL, NameTextYL);
	}
	switch (DrawStage) {
	case 0: // background
		Canvas.DrawColor = ItemBGColor;
		if (BPRI != None && LocalBPRI != None) {
			if (BPRI.bIsRogue && (BPRI == LocalPRI || BPRI == LocalBPRI.Betrayer || LocalBPRI.bOnlySpectator))
				Canvas.DrawColor = RogueBGColor;
			else if (BPRI.CurrentTeam != None && LocalBPRI.CurrentTeam == BPRI.CurrentTeam)
				Canvas.DrawColor = TeamBGColor[1 - int(class'BetrayalPRI'.default.bSwapTeamColors)];
			else if (LocalBPRI.bIsRogue && BPRI.Betrayer == LocalPRI)
				Canvas.DrawColor = TeamBGColor[int(class'BetrayalPRI'.default.bSwapTeamColors)];
		}
		// rank stays outside the box
		class'BetrayalHud'.static.DrawBox(Canvas, BGMaterial, X + NamePos * XL - ItemPadding * ResScale, Y, (1 - NamePos) * XL + ItemPadding * ResScale, YL, ItemBGScale * ResScale, ItemBGScale * ResScale);
		return;

	case 1: // large font
		if (PRI == LocalPRI || PRI.Owner == Owner)
			Canvas.DrawColor = LocalItemTextColor;
		else
			Canvas.DrawColor = ItemTextColor;

		Canvas.SetPos(X + NamePos * XL, Y + 0.5 * (YL + LargeTextYL) - NameTextYL);
		Canvas.DrawTextClipped(PRI.PlayerName);

		if (GRI.bMatchHasBegun) {
			Canvas.FontScaleX = 1;
			Canvas.FontScaleY = 1;
			Canvas.StrLen(string(int(PRI.Score)), TextXL, TextYL);
			Canvas.SetPos(X + ScorePos * XL - 0.5 * TextXL, Y + 0.5 * (YL - TextYL));
			Canvas.DrawTextClipped(string(int(PRI.Score)));

			Canvas.FontScaleX = 0.75;
			Canvas.FontScaleY = 0.75;

			if (Rank > 0) {
				// only draw rank if actually worse than player above
				Canvas.StrLen(string(Rank), TextXL, TextYL);
				Canvas.SetPos(X + 0.5 * (NamePos * XL - TextXL) - ItemPadding * ResScale, Y + 0.5 * (YL + LargeTextYL) - TextYL);
				Canvas.DrawTextClipped(string(Rank));
			}

			if (BPRI != None) {
				if (GetStatPercent(BPRI, StatPercent, StatA, StatB))
					StatPercentString = StatPercent $ "%";
				else
					StatPercentString = "--%";

				Canvas.StrLen(StatPercentString, TextXL, TextYL);
				Canvas.SetPos(X + StatPos * XL - TextXL, Y + 0.5 * (YL + LargeTextYL) - TextYL);
				Canvas.DrawTextClipped(StatPercentString);
			}
		}
		if (PRI.bAdmin) {
			Canvas.StrLen(AdminText, TextXL, TextYL);
			Canvas.SetPos(X + NetPos * XL - 0.5 * TextXL, Y + 0.5 * (YL + LargeTextYL) - TextYL);
			Canvas.DrawTextClipped(AdminText);
		}

		Canvas.FontScaleX = 1;
		Canvas.FontScaleY = 1;
		return;

	case 2: // small font
		Canvas.FontScaleX = 1;
		Canvas.FontScaleY = 1;
		Canvas.Font = InfoFont;
		Canvas.StrLen("X", TextXL, TextYL);

		if (BPRI != None && GRI.bMatchHasBegun) {
			GetStatPercent(BPRI, StatPercent, StatA, StatB);
			Canvas.SetPos(X + StatPos * XL, Y + 0.5 * (YL + LargeTextYL) - TextYL);
			Canvas.DrawTextClipped(" " $ StatA $ "/" $ StatB);
		}

		if (!PRI.bAdmin && !PRI.bBot && Level.NetMode != NM_Standalone) {
			if (BPRI != None) {
				PingString = string(int(Square(BPRI.RepPing / 255.0) * 1000));
				if (BPRI.RepPingDeviation > 0)
					PingString $= Chr(4) $ "+" $ BPRI.RepPingDeviation;
			}
			else
				PingString = string(PRI.Ping * 4);
			PingString $= "ms";
			Canvas.StrLen(PingString, TextXL, TextYL);
			Canvas.SetPos(X + NetPos * XL - TextXL, Y + 0.5 * (YL + LargeTextYL) - TextYL);
			Canvas.DrawTextClipped(PingString, True);
			Canvas.SetPos(X + NetPos * XL, Y + 0.5 * (YL + LargeTextYL) - TextYL);
			Canvas.DrawTextClipped("/" $ PRI.PacketLoss);
		}
		return;

	case 3: // daggers
		if (!GRI.bMatchHasBegun) {
			if (BGRI.bPlayersMustBeReady && !PRI.bBot) {
				if (PRI.bReadyToPlay) {
					IconXL = NameTextYL * (ReadyIconCoords.X2 - ReadyIconCoords.X1) / (ReadyIconCoords.Y2 - ReadyIconCoords.Y1);
					IconYL = NameTextYL;

					Canvas.DrawColor = HudClass.default.GreenColor;
					Canvas.SetPos(X + ScorePos * XL - 0.5 * IconXL, Y + 0.5 * (YL - NameTextYL));
					Canvas.DrawTile(ReadyIcon,
						IconXL, IconYL,
						ReadyIconCoords.X1, ReadyIconCoords.Y1,
						ReadyIconCoords.X2 - ReadyIconCoords.X1, ReadyIconCoords.Y2 - ReadyIconCoords.Y1);
				}
				else {
					IconXL = NameTextYL * (NotReadyIconCoords.X2 - NotReadyIconCoords.X1) / (NotReadyIconCoords.Y2 - NotReadyIconCoords.Y1);
					IconYL = NameTextYL;

					Canvas.DrawColor = HudClass.default.RedColor;
					Canvas.SetPos(X + ScorePos * XL - 0.5 * IconXL, Y + 0.5 * (YL - NameTextYL));
					Canvas.DrawTile(NotReadyIcon,
						IconXL, IconYL,
						NotReadyIconCoords.X1, NotReadyIconCoords.Y1,
						NotReadyIconCoords.X2 - NotReadyIconCoords.X1, NotReadyIconCoords.Y2 - NotReadyIconCoords.Y1);
				}
			}
		}
		else if (BPRI != None) {
			PosX = X + NamePos * XL + TextXL;
			PosY = Y + 0.5 * (YL + LargeTextYL) - 0.5 * (1 + DaggerScale) * NameTextYL;
			IconXL = DaggerScale * NameTextYL * (DaggerIconCoords.X2 - DaggerIconCoords.X1) / (DaggerIconCoords.Y2 - DaggerIconCoords.Y1);
			IconYL = DaggerScale * NameTextYL;

			// red daggers
			Canvas.DrawColor = HudClass.default.RedColor;
			for (i = 0; i < NumRedDaggers; i++) {
				Canvas.SetPos(PosX, PosY);
				Canvas.DrawTile(DaggerIcon,
					IconXL, IconYL,
					DaggerIconCoords.X1, DaggerIconCoords.Y1,
					DaggerIconCoords.X2 - DaggerIconCoords.X1, DaggerIconCoords.Y2 - DaggerIconCoords.Y1);
				PosX += TextScale * DaggerSpacing * ResScale;
			}
			if (NumRedDaggers > 0)
				PosX += TextScale * DaggerGroupOffset * ResScale;

			// gold daggers
			Canvas.DrawColor = HudClass.default.GoldColor;
			for (i = 0; i < NumGoldDaggers; i++) {
				Canvas.SetPos(PosX, PosY);
				Canvas.DrawTile(DaggerIcon,
					IconXL, IconYL,
					DaggerIconCoords.X1, DaggerIconCoords.Y1,
					DaggerIconCoords.X2 - DaggerIconCoords.X1, DaggerIconCoords.Y2 - DaggerIconCoords.Y1);
				PosX += TextScale * DaggerSpacing * ResScale;
			}
			if (NumGoldDaggers > 0)
				PosX += TextScale * DaggerGroupOffset * ResScale;

			// silver daggers
			Canvas.DrawColor = HudClass.default.WhiteColor;
			for (i = 0; i < NumSilverDaggers; i++) {
				Canvas.SetPos(PosX, PosY);
				Canvas.DrawTile(DaggerIcon,
					IconXL, IconYL,
					DaggerIconCoords.X1, DaggerIconCoords.Y1,
					DaggerIconCoords.X2 - DaggerIconCoords.X1, DaggerIconCoords.Y2 - DaggerIconCoords.Y1);
				PosX += TextScale * DaggerSpacing * ResScale;
			}
		}
		Canvas.FontScaleX = 1;
		Canvas.FontScaleY = 1;
		return;
	}
}

function DrawEllipsis(float X, float Y, float XL, float YL, byte DrawStage)
{
	local float TextXL, TextYL;

	if (DrawStage != 1)
		return;

	Canvas.DrawColor = ItemTextColor;
	Canvas.Font = PlayerFont;
	Canvas.StrLen("...", TextXL, TextYL);
	Canvas.SetPos(X + 0.5 * (XL - TextXL), Y + YL - 0.25 * TextYL);
	Canvas.DrawTextClipped("...");
}


function DrawSpectators(byte DrawStage)
{
	local int i, Num;
	local float PosY;

	PosY = SpectatorsTop;
	if (DrawStage == 0) {
		Canvas.DrawColor = AreaBGColor;
		class'BetrayalHud'.static.DrawBox(
			Canvas,
			BGMaterial,
			SpectatorsLeft - AreaPadding * ResScale,
			SpectatorsTop - AreaPadding * ResScale,
			SpectatorsWidth + 2 * AreaPadding * ResScale,
			SpectatorsHeight + 2 * AreaPadding * ResScale,
			AreaBGScale * ResScale,
			AreaBGScale * ResScale);
	}
	else if (DrawStage == 2) {
		DrawSpectatorHeader(SpectatorsLeft, PosY, SpectatorsWidth, SpectatorsRowHeight);
	}

	// draw the Spectators
	for (i = FirstSpectator; i < GRI.PRIArray.Length && Num < NumDrawnSpectators; i++) {
		if (GRI.PRIArray[i].PlayerID != 0) {
			Num++;
			if (LocalSpectatorNum <= NumDrawnSpectators || Num < NumDrawnSpectators) {
				PosY += SpectatorsRowHeight + SpectatorsRowSpacing;
				DrawSpectator(GRI.PRIArray[i], SpectatorsLeft, PosY, SpectatorsWidth, SpectatorsRowHeight, DrawStage);
			}
		}
	}
	if (LocalSpectatorNum > NumDrawnSpectators) {
		PosY += SpectatorsRowHeight + SpectatorsRowSpacing;
		DrawSpectator(GRI.PRIArray[LocalSpectatorIndex], SpectatorsLeft, PosY, SpectatorsWidth, SpectatorsRowHeight, DrawStage);
	}
	if (NumDrawnSpectators < NumSpectators) {
		PosY += 0.5 * (SpectatorsRowHeight + SpectatorsRowSpacing);
		DrawEllipsis(SpectatorsLeft, PosY, SpectatorsWidth, 0.5 * SpectatorsRowHeight, DrawStage);
	}
}

function DrawSpectatorHeader(float X, float Y, float XL, float YL)
{
	local float TextXL, TextYL;

	Canvas.DrawColor = HeaderTextColor;
	Canvas.Font = SpectatorFont;
	Canvas.StrLen(class'UT2K4Tab_MidGameVoiceChat'.default.sb_Specs.Caption, TextXL, TextYL);
	Canvas.SetPos(X + 0.5 * (XL - TextXL), Y + 0.5 * (YL - TextYL));
	Canvas.DrawTextClipped(class'UT2K4Tab_MidGameVoiceChat'.default.sb_Specs.Caption);
}

function DrawSpectator(PlayerReplicationInfo PRI, float X, float Y, float XL, float YL, byte DrawStage)
{
	local string SpectatorName;
	local float TextXL, TextYL;

	switch (DrawStage) {
	case 0:
		Canvas.DrawColor = ItemBGColor;
		class'BetrayalHud'.static.DrawBox(Canvas, BGMaterial, X, Y, XL, YL, ItemBGScale * ResScale, ItemBGScale * ResScale);
		return;

	case 2:
		SpectatorName = PRI.PlayerName;
		if (PRI.bAdmin)
			SpectatorName @= "(" $ AdminText $ ")";
		if (PRI == LocalPRI || PRI.Owner == Owner)
			Canvas.DrawColor = LocalItemTextColor;
		else
			Canvas.DrawColor = ItemTextColor;
		Canvas.Font = SpectatorFont;
		Canvas.StrLen(SpectatorName, TextXL, TextYL);

		if (TextXL > XL - 2 * ItemPadding * ResScale) {
			Canvas.FontScaleX = (XL - 2 * ItemPadding * ResScale) / TextXL;
			Canvas.FontScaleY = Canvas.FontScaleX;
			Canvas.StrLen(PRI.PlayerName, TextXL, TextYL); // recalculate because scaling isn't exact
		}
		Canvas.SetPos(X + 0.5 * (XL - TextXL), Y + 0.5 * (YL - TextYL));
		Canvas.DrawTextClipped(SpectatorName);

		Canvas.FontScaleX = 1;
		Canvas.FontScaleY = 1;
		return;
	}
}


/**
Returns the current level's title. If the mapper didn't set a title, processes
the map package name to create one. (Borrowed from JB2004 scoreboard.)
*/
static function string GetLevelTitle(LevelInfo Level)
{
	local int iChar;
	local int iCharSeparator;
	local string TextTitle;

	if (Level.Title != Level.Default.Title)
		return Level.Title;

	TextTitle = string(Level);
	TextTitle = Left(TextTitle, InStr(TextTitle, "."));

	iCharSeparator = InStr(TextTitle, "-");
	if (iCharSeparator >= 0)
		TextTitle = Mid(TextTitle, iCharSeparator + 1);

	for (iChar = 0; iChar < Len(TextTitle); iChar++) {
		if (Caps(Mid(TextTitle, iChar, 1)) < "A" || Caps(Mid(TextTitle, iChar, 1)) > "Z")
			break;
	}
	TextTitle = Left(TextTitle, iChar);

	for (iChar = Len(TextTitle) - 1; iChar > 0; iChar--) {
		if (Mid(TextTitle, iChar, 1) >= "A" && Mid(TextTitle, iChar, 1) <= "Z")
			TextTitle = Left(TextTitle, iChar) @ Mid(TextTitle, iChar);
	}
	return TextTitle;
}


//=============================================================================
// Default values
//=============================================================================

defaultproperties
{
	HUDClass = class'BetrayalHud'
	bDisplayMessages = True

	StatCaption[0] = "ACCURACY"
	StatCaption[1] = "EFFICIENCY"
	StatCaption[2] = "PAYBACK"
	StatCaption[3] = "RETRIBUTION"

	HeaderAreaTop           = 0.01
	PlayersAreaLeft         = 0.05
	PlayersAreaTop          = 0.13
	PlayersAreaWidth        = 0.9
	PlayersAreaMaxHeight    = 0.72

	RankPos      = 0.045
	NamePos      = 0.05
	NameMaxWidth = 0.4
	ScorePos     = 0.55
	StatPos      = 0.75
	NetPos       = 0.96

	SpectatorsAreaLeft       = 0.75
	SpectatorsAreaBottom     = 0.99
	SpectatorsAreaWidth      = 0.2
	SpectatorsAreaMinSpacing = 0.01

	DaggerIcon        = Texture'BetrayalIcons'
	DaggerIconCoords  = (X1=0,Y1=35,X2=15,Y2=62)
	DaggerScale       = 0.9
	DaggerSpacing     = 5
	DaggerGroupOffset = 2

	ReadyIcon          = Texture'BetrayalIcons'
	ReadyIconCoords    = (X1=2,Y1=1,X2=28,Y2=31)
	NotReadyIcon       = Texture'BetrayalIcons'
	NotReadyIconCoords = (X1=34,Y1=1,X2=60,Y2=31)

	BGMaterial  = Texture'RoundedBox'
	AreaBGColor = (R=32,G=32,B=32,A=128)
	AreaBGScale = 0.25
	AreaPadding = 4.0

	ItemBGColor = (R=0,G=0,B=0,A=128)
	ItemBGScale = 0.125
	ItemPadding = 2.0
	ItemSpacing = 1.0

	HeaderTextColor    = (R=255,G=255,B=255,A=255)
	RogueBGColor       = (R=64,G=48,B=0,A=160)
	TeamBGColor[0]     = (R=80,G=0,B=0,A=160)
	TeamBGColor[1]     = (R=0,G=16,B=80,A=160)
	ItemTextColor      = (R=192,G=192,B=192,A=255)
	LocalItemTextColor = (R=255,G=255,B=128,A=255)
}

