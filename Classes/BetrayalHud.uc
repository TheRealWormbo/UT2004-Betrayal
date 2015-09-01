/******************************************************************************
BetrayalHud

Creation date: 2010-05-19 12:43
Last change: $Id$
Copyright (c) 2010, Wormbo
******************************************************************************/

class BetrayalHud extends HudCDeathMatch;


//=============================================================================
// Imports
//=============================================================================

#exec texture import file=Textures\RoundedBox.tga     group=HUD alpha=1 lodset=LODSET_Interface
#exec texture import file=Textures\BetrayalIcons.tga  group=HUD alpha=1 lodset=LODSET_Interface
#exec texture import file=Textures\ConnectionIcon.dds group=HUD alpha=1 lodset=LODSET_Interface
#exec texture import file=Textures\ScoreBeacon.pcx    group=HUD alpha=1 lodset=LODSET_Interface alphatrick=1 mips=0


//=============================================================================
// Properties
//=============================================================================

var Material DaggerIcon;
var IntBox DaggerIconCoords;
var float DaggerWidth, DaggerHeight, DaggerSpacing, DaggerGroupOffset;
var color TeamTextColor[2];
var int NameFontSize;

var Texture BeaconTex;

var Material BGMaterial;
var color AreaBGColor, ItemBGColor;
var float AreaBGScale, ItemBGScale, ItemSpacing;
var float AreaPadding, ItemPadding;

var localized string PotString, RogueString, FreelanceString;

var() SpriteWidget  ConnectionIcon;
var() SpriteWidget  ConnectionBackground;
var() SpriteWidget  ConnectionBackgroundDisc;
var() SpriteWidget  ConnectionUnlagStatus;
var() SpriteWidget  ConnectionAlert;
var() NumericWidget ConnectionPing;
var() NumericWidget ConnectionLoss;

var() SpriteWidget  AltConnectionIcon;
var() SpriteWidget  AltConnectionBackground;
var() SpriteWidget  AltConnectionBackgroundDisc;
var() SpriteWidget  AltConnectionUnlagStatus;
var() SpriteWidget  AltConnectionAlert;
var() NumericWidget AltConnectionPing;
var() NumericWidget AltConnectionLoss;

var float ScoreboardConsoleMessagePosY;


//=============================================================================
// Variables
//=============================================================================

var BetrayalGRI BGRI;
var BetrayalTeam LocalTeam;
var BetrayalPRI LocalPRI;

struct TeammateHudInfo {
	var string TeammateName;
	var float TeammateNameStrWidth;
	var int NumSilverDaggers;
	var int NumGoldDaggers;
};


/** Reuse TAM/Freon settings menu command. */
exec function Menu3SPN()
{
	MyMenu();
}

/** Reuse UTComp's settings menu command. */
exec function MyMenu()
{
	if (Level.NetMode == NM_Standalone)
		Level.Pauser = PlayerOwner.PlayerReplicationInfo;

	PlayerOwner.ClientOpenMenu(class'BetrayalGame'.default.HUDSettingsMenu, False, string(class'BetrayalGame'), string(Level.NetMode == NM_Standalone));
}

exec function NextStats()
{
	if (bShowLocalStats && LocalStatsScreen != None)
		LocalStatsScreen.NextStats();
	else if (bShowScoreboard && Scoreboard != None)
		Scoreboard.NextStats();
}

function LinkActors()
{
	Super.LinkActors();

	BGRI = BetrayalGRI(Level.GRI);
	LocalPRI = BetrayalPRI(PawnOwnerPRI);
	if (LocalPRI != None)
		LocalTeam = LocalPRI.CurrentTeam;
}


function DrawSpectatingHud(Canvas C)
{
	Super.DrawSpectatingHud(C);

	if (UnrealPlayer(Owner).bDisplayWinner ||  UnrealPlayer(Owner).bDisplayLoser)
		return;

	DisplayConnectionStatus(C);

	if (PawnOwner != None)
		DrawTeamInfo(C);
}


function DrawHudPassA(Canvas C)
{
	Super.DrawHudPassA(C);
	DrawTeamInfo(C);
	DisplayConnectionStatus(C);
}


// disabled as enemy names are displayed above the beacons already
function DrawEnemyName(Canvas C);


function DisplayConnectionStatus(Canvas C)
{
	local float Ping, PingDeviation;

	if (Level.NetMode != NM_Client)
		return; // TODO: what about demo playback?

	// support that there might be adrenaline involved
	if (PlayerOwner.bAdrenalineEnabled)
	{
		ConnectionBackground     = default.AltConnectionBackground;
		ConnectionBackgroundDisc = default.AltConnectionBackgroundDisc;
		ConnectionAlert          = default.AltConnectionAlert;
		ConnectionUnlagStatus    = default.AltConnectionUnlagStatus;
		ConnectionIcon           = default.AltConnectionIcon;
		ConnectionPing           = default.AltConnectionPing;
		ConnectionLoss           = default.AltConnectionLoss;
	}
	else
	{
		ConnectionBackground     = default.ConnectionBackground;
		ConnectionBackgroundDisc = default.ConnectionBackgroundDisc;
		ConnectionAlert          = default.ConnectionAlert;
		ConnectionUnlagStatus    = default.ConnectionUnlagStatus;
		ConnectionIcon           = default.ConnectionIcon;
		ConnectionPing           = default.ConnectionPing;
		ConnectionLoss           = default.ConnectionLoss;
	}

	if (PawnOwnerPRI != None) {
		if (LocalPRI != None && LocalPRI.Owner == PlayerOwner) {
			Ping = LocalPRI.RealPing;
			PingDeviation = LocalPRI.RealPingDeviation;
		}
		else if (LocalPRI != None) {
			Ping = Square(LocalPRI.RepPing / 255.0);
			PingDeviation = LocalPRI.RepPingDeviation * 0.001;
		}
		else {
			Ping = PawnOwnerPRI.Ping * 0.004;
			// PingDeviation = 0.0;
		}
		ConnectionPing.Value = Round(Ping * 1000.0);
		ConnectionLoss.Value = PawnOwnerPRI.PacketLoss;
	}
	DrawSpriteWidget(C, ConnectionBackground);
	DrawSpriteWidget(C, ConnectionBackgroundDisc);
	if (bShowBadConnectionAlert) {
		DrawSpriteWidget(C, ConnectionAlert);
	}
	else if (PawnOwner != None && BGRI != None && LocalPRI != None && BGRI.MaxUnlagTime > 0.001 && LocalPRI.bUseUnlagging) {
		ConnectionUnlagStatus.Tints[0].G = 255 - Clamp(255 * (2 * (Ping + 2 * PingDeviation) - BGRI.MaxUnlagTime) / BGRI.MaxUnlagTime, 0, 255);
		ConnectionUnlagStatus.Tints[0].R = Min(510 * (Ping + 2 * PingDeviation) / BGRI.MaxUnlagTime, 255);
		ConnectionUnlagStatus.Tints[1] = ConnectionUnlagStatus.Tints[0];
		DrawSpriteWidget(C, ConnectionUnlagStatus);
	}
	DrawSpriteWidget(C, ConnectionIcon);

	ConnectionPing.Tints[0].G = 255 - Clamp(4 * (ConnectionPing.Value - 100), 0, 255);
	ConnectionPing.Tints[0].R = Min((ConnectionPing.Value - 10) * 51 / 18, 255);
	ConnectionPing.Tints[1] = ConnectionPing.Tints[0];
	DrawNumericWidget(C, ConnectionPing, DigitsBig);

	if (ConnectionLoss.Value == 0)
		ConnectionLoss.Tints[0] = WhiteColor;
	else
		ConnectionLoss.Tints[0] = RedColor;
	ConnectionLoss.Tints[1] = ConnectionLoss.Tints[0];
	DrawNumericWidget(C, ConnectionLoss, DigitsBig);
}


function Font GetScaledFontSizeIndex(Canvas C, int FontSize)
{
	local float ScaledClipX;

	ScaledClipX = C.ClipX * HudScale * HudCanvasScale;

	if (ScaledClipX >= 512)
		FontSize++;
	if (ScaledClipX >= 640)
		FontSize++;
	if (ScaledClipX >= 800)
		FontSize++;
	if (ScaledClipX >= 1024)
		FontSize++;
	if (ScaledClipX >= 1280)
		FontSize++;
	if (ScaledClipX >= 1600)
		FontSize++;

	return LoadFont(Clamp(8 - FontSize, 0, 8));
}


function DrawTeamInfo(Canvas C)
{
	local int i, j, NumTeammates, TempCount;
	local TeammateHudInfo Teammate;
	local array<TeammateHudInfo> HudTeammates;
	local float XL, YL, XPos, YPos, MaxTeammmateNameStrWidth, DaggersWidth, DaggersMaxWidth, TeammateHeight;

	if (bShowPoints) {
		C.Font = GetScaledFontSizeIndex(C, -1);
		C.StrLen("0000", DaggersMaxWidth, YL);
		TeammateHeight = FMax(YL, DaggerHeight * HudCanvasScale * ResScaleX * HudScale) + 2 * ItemPadding * HudCanvasScale * ResScaleY * HudScale;

		if (LocalTeam != None) {
			C.StrLen(PotString, MaxTeammmateNameStrWidth, YL);
		}
		else if (LocalPRI.bIsRogue) {
			C.StrLen(RogueString, MaxTeammmateNameStrWidth, YL);
		}
		else {
			C.StrLen(FreelanceString, MaxTeammmateNameStrWidth, YL);
			MaxTeammmateNameStrWidth *= 0.5;
			DaggersMaxWidth = FMax(DaggersMaxWidth, MaxTeammmateNameStrWidth);
		}

		if (LocalTeam != None) {
			// add current teammates
			for (i = 0; i < ArrayCount(LocalTeam.Teammates); i++) {
				if (LocalTeam.Teammates[i] != None && LocalTeam.Teammates[i] != LocalPRI) {
					Teammate.TeammateName = LocalTeam.Teammates[i].PlayerName;
					C.StrLen(Teammate.TeammateName, Teammate.TeammateNameStrWidth, YL);
					MaxTeammmateNameStrWidth = FMax(MaxTeammmateNameStrWidth, Teammate.TeammateNameStrWidth);

					TempCount = Clamp(LocalTeam.Teammates[i].BetrayalCount, 0, 100); // sanity clamp
					Teammate.NumSilverDaggers = TempCount % 5;
					Teammate.NumGoldDaggers   = TempCount / 5;
					HudTeammates[NumTeammates++] = Teammate;

					if (Teammate.NumGoldDaggers < 5) {
						DaggersWidth = DaggerWidth;
						if (Teammate.NumGoldDaggers > 0) {
							DaggersWidth += Teammate.NumGoldDaggers * DaggerSpacing;
						}
						if (Teammate.NumSilverDaggers > 0) {
							if (Teammate.NumGoldDaggers > 0)
								DaggersWidth += DaggerGroupOffset;
							DaggersWidth += Teammate.NumSilverDaggers * DaggerSpacing;
						}
						DaggersMaxWidth = FMax(DaggersMaxWidth, DaggersWidth * HudCanvasScale * ResScaleX * HudScale);
					}
					else { // I think this is about where awesome turns into ridiculous
						HudTeammates[NumTeammates - 1].NumSilverDaggers = LocalTeam.Teammates[i].BetrayalCount;
						C.TextSize(string(LocalTeam.Teammates[i].BetrayalCount), DaggersWidth, YL);
						DaggersWidth += DaggerWidth * HudCanvasScale * ResScaleX * HudScale;
						DaggersMaxWidth = FMax(DaggersMaxWidth, DaggersWidth);
					}
				}
			}
		}

		// add last betrayer, if any
		if (LocalPRI.Betrayer != None && LocalPRI.Betrayer.bIsRogue && LocalPRI.Betrayer.RemainingRogueTime >= 0) {
			Teammate.TeammateName = LocalPRI.Betrayer.PlayerName;
			C.StrLen(Teammate.TeammateName, Teammate.TeammateNameStrWidth, YL);
			MaxTeammmateNameStrWidth = FMax(MaxTeammmateNameStrWidth, Teammate.TeammateNameStrWidth);

			// not interested in betrayal count here
			HudTeammates[NumTeammates++] = Teammate;
		}
		MaxTeammmateNameStrWidth += 2 * ItemPadding * HudCanvasScale * ResScaleY * HudScale;
		DaggersMaxWidth += 2 * ItemPadding * HudCanvasScale * ResScaleY * HudScale;

		YPos = (1.0 - HudCanvasScale) * 0.5 * C.SizeY + AreaPadding * HudCanvasScale * ResScaleY * HudScale;
		C.DrawColor = AreaBGColor;
		DrawBox(C, BGMaterial,
			0.5 * C.ClipX - MaxTeammmateNameStrWidth - AreaPadding * HudCanvasScale * ResScaleY * HudScale,
			YPos - AreaPadding * HudCanvasScale * ResScaleY * HudScale,
			MaxTeammmateNameStrWidth + DaggersMaxWidth + 2 * AreaPadding * HudCanvasScale * ResScaleY * HudScale,
			(NumTeammates + 1) * TeammateHeight + AreaPadding * HudCanvasScale * ResScaleY * HudScale,
			AreaBGScale * HudCanvasScale * ResScaleY * HudScale,
			AreaBGScale * HudCanvasScale * ResScaleY * HudScale);

		for (i = 0; i < NumTeammates; i++) {
			C.DrawColor = ItemBGColor;
			DrawBox(C, BGMaterial,
				0.5 * C.ClipX - MaxTeammmateNameStrWidth,
				YPos,
				MaxTeammmateNameStrWidth,
				TeammateHeight,
				ItemBGScale * HudCanvasScale * ResScaleY * HudScale,
				ItemBGScale * HudCanvasScale * ResScaleY * HudScale);
			DrawBox(C, BGMaterial,
				0.5 * C.ClipX,
				YPos,
				DaggersMaxWidth,
				TeammateHeight,
				ItemBGScale * HudCanvasScale * ResScaleY * HudScale,
				ItemBGScale * HudCanvasScale * ResScaleY * HudScale);

			if (i == NumTeammates - 1 && LocalPRI.Betrayer != None && LocalPRI.Betrayer.bIsRogue && !LocalPRI.Betrayer.bOnlySpectator && LocalPRI.Betrayer.RemainingRogueTime >= 0) {
				// draw the rogue
				C.DrawColor = HudColorHighLight;
				C.StrLen(HudTeammates[i].TeammateName, XL, YL);
				C.SetPos(0.5 * C.ClipX - XL - ItemPadding * HudCanvasScale * ResScaleY * HudScale,
					YPos + 0.5 * (TeammateHeight - YL));
				C.DrawText(HudTeammates[i].TeammateName);

				// draw remaining rogue time
				C.StrLen(LocalPRI.Betrayer.RemainingRogueTime, XL, YL);
				C.SetPos(0.5 * (C.ClipX + DaggersMaxWidth - XL), YPos + 0.5 * (TeammateHeight - YL));
				C.DrawText(LocalPRI.Betrayer.RemainingRogueTime);
			}
			else {
				// draw the teammate
				C.DrawColor = WhiteColor;
				C.StrLen(HudTeammates[i].TeammateName, XL, YL);
				C.SetPos(0.5 * C.ClipX - XL - ItemPadding * HudCanvasScale * ResScaleY * HudScale,
					YPos + 0.5 * (TeammateHeight - YL));
				C.DrawText(HudTeammates[i].TeammateName);

				// draw daggers
				XPos = 0.5 * C.ClipX + ItemPadding * HudCanvasScale * ResScaleY * HudScale;

				if (HudTeammates[i].NumGoldDaggers < 5) {
					// gold daggers
					C.DrawColor = GoldColor;
					for (j = 0; j < HudTeammates[i].NumGoldDaggers; j++) {
						C.SetPos(XPos, YPos + 0.5 * (TeammateHeight - DaggerHeight * HudCanvasScale * ResScaleX * HudScale));
						C.DrawTile(DaggerIcon, DaggerWidth * HudCanvasScale * ResScaleX * HudScale, DaggerHeight * HudCanvasScale * ResScaleX * HudScale, DaggerIconCoords.X1, DaggerIconCoords.Y1, DaggerIconCoords.X2 - DaggerIconCoords.X1, DaggerIconCoords.Y2 - DaggerIconCoords.Y1);
						XPos += DaggerSpacing * HudCanvasScale * ResScaleX * HudScale;
					}
					if (HudTeammates[i].NumGoldDaggers > 0)
						XPos += DaggerGroupOffset * HudCanvasScale * ResScaleX * HudScale;

					// silver daggers
					C.DrawColor = WhiteColor;
					for (j = 0; j < HudTeammates[i].NumSilverDaggers; j++) {
						C.SetPos(XPos, YPos + 0.5 * (TeammateHeight - DaggerHeight * HudCanvasScale * ResScaleX * HudScale));
						C.DrawTile(DaggerIcon, DaggerWidth * HudCanvasScale * ResScaleX * HudScale, DaggerHeight * HudCanvasScale * ResScaleX * HudScale, DaggerIconCoords.X1, DaggerIconCoords.Y1, DaggerIconCoords.X2 - DaggerIconCoords.X1, DaggerIconCoords.Y2 - DaggerIconCoords.Y1);
						XPos += DaggerSpacing * HudCanvasScale * ResScaleX * HudScale;
					}
				}
				else {
					// one silver dagger
					C.DrawColor = WhiteColor;
					C.SetPos(XPos, YPos + 0.5 * (TeammateHeight - DaggerHeight * HudCanvasScale * ResScaleX * HudScale));
					C.DrawTile(DaggerIcon, DaggerWidth * HudCanvasScale * ResScaleX * HudScale, DaggerHeight * HudCanvasScale * ResScaleX * HudScale, DaggerIconCoords.X1, DaggerIconCoords.Y1, DaggerIconCoords.X2 - DaggerIconCoords.X1, DaggerIconCoords.Y2 - DaggerIconCoords.Y1);
					XPos += DaggerWidth * HudCanvasScale * ResScaleX * HudScale;

					// betrayal count as number
					C.StrLen(string(HudTeammates[i].NumSilverDaggers), XL, YL);
					C.SetPos(XPos, YPos + 0.5 * (TeammateHeight - YL));
					C.DrawText(string(HudTeammates[i].NumSilverDaggers));
				}
			}
			YPos += TeammateHeight + ItemSpacing * HudCanvasScale * ResScaleY * HudScale;
		}

		if (LocalTeam != None) {
			// draw pot
			C.DrawColor = HudColorTeam[1 - int(class'BetrayalPRI'.default.bSwapTeamColors)];
			C.StrLen(PotString, XL, YL);
			C.SetPos(0.5 * C.ClipX - XL - ItemPadding * HudCanvasScale * ResScaleY * HudScale, YPos + 0.5 * (TeammateHeight - YL));
			C.DrawText(PotString);

			C.StrLen(LocalTeam.TeamPot, XL, YL);
			C.SetPos(0.5 * (C.ClipX + DaggersMaxWidth - XL), YPos + 0.5 * (TeammateHeight - YL));
			C.DrawText(LocalTeam.TeamPot);
		}
		else if (LocalPRI.bIsRogue) {
			// draw remaining rogue time
			C.DrawColor = HudColorHighLight;
			C.StrLen(RogueString, XL, YL);
			C.SetPos(0.5 * C.ClipX - XL - ItemPadding * HudCanvasScale * ResScaleY * HudScale, YPos + 0.5 * (TeammateHeight - YL));
			C.DrawText(RogueString);

			C.StrLen(LocalPRI.RemainingRogueTime, XL, YL);
			C.SetPos(0.5 * (C.ClipX + DaggersMaxWidth - XL), YPos + 0.5 * (TeammateHeight - YL));
			C.DrawText(LocalPRI.RemainingRogueTime);
		}
		else {
			// freelancing
			C.DrawColor = GoldColor;
			C.StrLen(FreelanceString, XL, YL);
			C.SetPos(0.5 * (C.ClipX - XL), YPos + 0.5 * (TeammateHeight - YL));
			C.DrawText(FreelanceString);
		}
	}
}

function DisplayMessages(Canvas C)
{
	if (bShowScoreBoard || bShowLocalStats)
		ConsoleMessagePosY = ScoreboardConsoleMessagePosY;
	else
		ConsoleMessagePosY = default.ConsoleMessagePosY;

	Super.DisplayMessages(C);
}

function DrawCustomBeacon(Canvas C, Pawn P, float ScreenLocX, float ScreenLocY)
{
	//local Texture BeaconTex;
	local float XL, YL, Scale, PosY;
	local BetrayalPRI PRI;
	local bool bSameTeam, bDrawName;
	local string Value;
	local vector CamLoc;
	local rotator CamRot;

	//BeaconTex = PlayerOwner.TeamBeaconTexture;
	PRI = BetrayalPRI(P.PlayerReplicationInfo);
	if (BeaconTex == None || PRI == None || P.bNoTeamBeacon || PlayerOwner.bHideSpectatorBeacons && PlayerOwner.IsSpectating() || P == PlayerOwner.ViewTarget)
		return;

	C.GetCameraLocation(CamLoc, CamRot);
	if (VSize(P.Location - CamLoc) > PlayerOwner.TeamBeaconMaxDist || (P.Location - CamLoc) dot vector(CamRot) < 0)
		return; // either out of range or behind camera (why is it called at all in that case?)

	if (Level.TimeSeconds - PRI.LastPostRenderTraceTime > 0.2) {
		PRI.LastPostRenderTraceTime = Level.TimeSeconds + 0.1 * FRand();
		PRI.bPostRenderTraceSucceeded = FastTrace(P.Location, CamLoc) || FastTrace(P.Location + P.CollisionHeight * vect(0,0,1), CamLoc);
	}
	if (!PRI.bPostRenderTraceSucceeded)
		return;

	bSameTeam = LocalTeam != None && PRI.CurrentTeam == LocalTeam;

	C.Style = 9; // STY_AlphaZ
	C.Font = GetFontSizeIndex(C, -1);
	Scale = FMin(PlayerOwner.TeamBeaconPlayerInfoMaxDist / VSize(CamLoc - P.Location), 1.0);
	C.FontScaleX = 1.0;
	C.FontScaleY = 1.0;
	bDrawName = Scale >= 0.75;

	if (LocalPRI.bOnlySpectator)
		Scale *= 0.3;

	Scale *= HudScale;

	// draw beacon
	if (PRI.bIsRogue && (LocalPRI.Betrayer == PRI || LocalPRI.bOnlySpectator)) {
		// local player was betrayed by that player
		C.DrawColor = GoldColor * 0.7;
	}
	else if (LocalPRI.bIsRogue && PRI.Betrayer == LocalPRI) {
		// local player betrayed that player
		C.DrawColor = HudColorTeam[int(class'BetrayalPRI'.default.bSwapTeamColors)] * 0.75;
	}
	else if (bSameTeam) {
		// on local player's team
		C.DrawColor = HudColorTeam[1 - int(class'BetrayalPRI'.default.bSwapTeamColors)] * 0.75;
	}
	else {
		// normal enemy
		C.DrawColor = GrayColor * 0.7;
		if (!LocalPRI.bOnlySpectator && bNoEnemyNames)
			bDrawName = false;
	}
	if (xPawn(P) == None || !xPawn(P).bInvis)
		C.DrawColor.A = 255;
	else
		C.DrawColor.A = 100;
	C.StrLen("00", XL, YL);
	C.SetPos(ScreenLocX - 0.7 * Scale * XL, ScreenLocY - 1.4 * Scale * YL);
	C.DrawTile(BeaconTex, 1.4 * Scale * XL, 1.4 * Scale * YL, 0, 0, BeaconTex.USize, BeaconTex.VSize);
	PosY = ScreenLocY - 1.5 * Scale * YL;

	if (!LocalPRI.bOnlySpectator) {
		// draw score value
		if (PRI.bIsRogue && LocalPRI.Betrayer == PRI) {
			C.DrawColor = TeamTextColor[int(class'BetrayalPRI'.default.bSwapTeamColors)];
		}
		else
			C.DrawColor = HudColorHighLight;
		if (xPawn(P) == None || !xPawn(P).bInvis)
			C.DrawColor.A = 255;
		else
			C.DrawColor.A = 100;
		Value = string(PRI.ScoreValueFor(LocalPRI));
		C.FontScaleX = Scale;
		C.FontScaleY = Scale;
		C.StrLen(Value, XL, YL);
		C.SetPos(ScreenLocX - 0.5 * XL, ScreenLocY - 1.3 * YL);
		C.DrawTextClipped(Value, true);
		C.FontScaleX = 1.0;
		C.FontScaleY = 1.0;
	}
	if (bDrawName) {
		// draw player name
		if (PRI.bIsRogue && (LocalPRI.Betrayer == PRI || LocalPRI.bOnlySpectator)) {
			// local player was betrayed by that player
			C.DrawColor = GoldColor;
		}
		else if (LocalPRI.bIsRogue && PRI.Betrayer == LocalPRI) {
			// local player betrayed that player
			C.DrawColor = TeamTextColor[int(class'BetrayalPRI'.default.bSwapTeamColors)];
		}
		else if (bSameTeam) {
			// on local player's team
			C.DrawColor = TeamTextColor[1 - int(class'BetrayalPRI'.default.bSwapTeamColors)];
		}
		else {
			// normal enemy
			C.DrawColor = GrayColor;
		}
		if (xPawn(P) != None && xPawn(P).bInvis)
			C.DrawColor.A /= 3;
		if (LocalPRI.bOnlySpectator)
			C.Font = GetFontSizeIndex(C, -5);
		else
			C.Font = GetFontSizeIndex(C, -3);
		C.FontScaleX = HudScale;
		C.FontScaleY = HudScale;
		C.StrLen(PRI.PlayerName, XL, YL);
		C.SetPos(ScreenLocX - 0.5 * XL, PosY - YL);
		C.DrawTextClipped(PRI.PlayerName, true);
		C.FontScaleX = 1.0;
		C.FontScaleY = 1.0;
	}
}


/**
Make some room for the teammate list
*/
simulated function GetScreenCoords(float PosX, float PosY, out float ScreenX, out float ScreenY, out HudLocalizedMessage Message, Canvas C)
{
	Super.GetScreenCoords(PosX, 0.1 + 0.9 * PosY, ScreenX, ScreenY, Message, C);
}

/**
More flexible version of Canvas.DrawTileStretched().
*/
static function DrawBox(Canvas C, Material M, float PosX, float PosY, float XL, float YL, float ScaleX, float ScaleY)
{
	local float UL, VL;
	local float BorderUL, BorderVL;
	local float BorderXL, BorderYL;

	UL = M.MaterialUSize();
	VL = M.MaterialVSize();
	BorderUL = int((UL-0.5) / 2);
	BorderVL = int((VL-0.5) / 2);
	BorderXL = BorderUL * ScaleX;
	BorderYL = BorderVL * ScaleY;

	// left side
	C.SetPos(PosX, PosY);
	C.DrawTile(M,
		BorderXL, BorderYL,
		0,        0,
		BorderUL, BorderVL);
	C.SetPos(PosX, PosY + BorderYL);
	C.DrawTile(M,
		BorderXL, YL - 2 * BorderYL,
		0,        BorderVL,
		BorderUL, VL - 2 * BorderVL);
	C.SetPos(PosX, PosY + YL - BorderYL);
	C.DrawTile(M,
		BorderXL, BorderYL,
		0,        VL - BorderVL,
		BorderUL, BorderVL);

	// middle
	C.SetPos(PosX + BorderXL, PosY);
	C.DrawTile(M,
		XL - 2 * BorderXL, BorderYL,
		BorderUL,          0,
		UL - 2 * BorderUL, BorderVL);
	C.SetPos(PosX + BorderXL, PosY + BorderYL);
	C.DrawTile(M,
		XL - 2 * BorderXL, YL - 2 * BorderYL,
		BorderUL,          BorderVL,
		UL - 2 * BorderUL, VL - 2 * BorderVL);
	C.SetPos(PosX + BorderXL, PosY + YL - BorderYL);
	C.DrawTile(M,
		XL - 2 * BorderXL, BorderYL,
		BorderUL,          VL - BorderVL,
		UL - 2 * BorderUL, BorderVL);

	// right side
	C.SetPos(PosX + XL - BorderXL, PosY);
	C.DrawTile(M,
		BorderXL,      BorderYL,
		UL - BorderUL, 0,
		BorderUL,      BorderVL);
	C.SetPos(PosX + XL - BorderXL, PosY + BorderYL);
	C.DrawTile(M,
		BorderXL,      YL - 2 * BorderYL,
		UL - BorderUL, BorderVL,
		BorderUL,      VL - 2 * BorderVL);
	C.SetPos(PosX + XL - BorderXL, PosY + YL - BorderYL);
	C.DrawTile(M,
		BorderXL,      BorderYL,
		UL - BorderUL, VL - BorderVL,
		BorderUL,      BorderVL);
}


//=============================================================================
// Default values
//=============================================================================

defaultproperties
{
	DaggerIcon        = Texture'BetrayalIcons'
	DaggerIconCoords  = (X1=0,Y1=35,X2=15,Y2=62)
	DaggerWidth       = 10
	DaggerHeight      = 17.5
	DaggerSpacing     = 3.75
	DaggerGroupOffset = 1.875

	TeamTextColor[0] = (R=255,G=16,B=16,A=255)
	TeamTextColor[1] = (R=32,G=64,B=255,A=255)

	BeaconTex = Texture'ScoreBeacon'

	PotString       = "Pot"
	RogueString     = "Rogue"
	FreelanceString = "Freelance"

	BGMaterial  = Texture'RoundedBox'
	AreaBGColor = (R=32,G=32,B=32,A=128)
	AreaBGScale = 0.25
	AreaPadding = 4.0

	ItemBGColor = (R=0,G=0,B=0,A=128)
	ItemBGScale = 0.125
	ItemPadding = 2.0
	ItemSpacing = 1.0

	ScoreboardConsoleMessagePosY = 0.99

	FontArrayNames(8)="UT2003Fonts.FontMono"

	ConnectionIcon            = (WidgetTexture=Texture'ConnectionIcon',RenderStyle=STY_Alpha,PosX=1.0,PosY=0.0,OffsetX=5,OffsetY=20,DrawPivot=DP_UpperRight,TextureCoords=(X1=0,Y1=0,X2=128,Y2=128),TextureScale=0.21,ScaleMode=SM_Right,Scale=1.000000,Tints[0]=(R=255,G=255,B=255,A=255),Tints[1]=(R=255,G=255,B=255,A=255))
	ConnectionBackground      = (WidgetTexture=Texture'HudContent.Generic.HUD',RenderStyle=STY_Alpha,PosX=1.0,PosY=0.0,OffsetX=0,OffsetY=10,DrawPivot=DP_UpperRight,TextureCoords=(X1=168,Y1=211,X2=334,Y2=255),TextureScale=0.53,ScaleMode=SM_Right,Scale=1.000000,Tints[0]=(R=0,G=0,B=0,A=150),Tints[1]=(R=0,G=0,B=0,A=150))
	ConnectionBackgroundDisc  = (WidgetTexture=Texture'HudContent.Generic.HUD',RenderStyle=STY_Alpha,PosX=1.0,PosY=0.0,OffsetX=0,OffsetY=5,DrawPivot=DP_UpperRight,TextureCoords=(X1=119,Y1=258,X2=173,Y2=313),TextureScale=0.53,ScaleMode=SM_Right,Scale=1.000000,Tints[0]=(R=255,G=255,B=255,A=255),Tints[1]=(R=255,G=255,B=255,A=255))
	ConnectionUnlagStatus     = (WidgetTexture=Material'HudContent.Generic.GlowCircle',RenderStyle=STY_Alpha,PosX=1.0,PosY=0.0,OffsetX=4,OffsetY=2,DrawPivot=DP_UpperRight,TextureCoords=(X1=0,Y1=0,X2=64,Y2=64),TextureScale=0.5,ScaleMode=SM_Right,Scale=1.000000,Tints[0]=(R=0,G=0,B=0,A=255),Tints[1]=(R=0,G=0,B=0,A=255))
	ConnectionAlert           = (WidgetTexture=Material'HudContent.Generic.fb_Pulse001',RenderStyle=STY_Alpha,PosX=1.0,PosY=0.0,OffsetX=6,OffsetY=1,DrawPivot=DP_UpperRight,TextureCoords=(X1=0,Y1=0,X2=64,Y2=64),TextureScale=0.53,ScaleMode=SM_Right,Scale=1.000000,Tints[0]=(R=255,G=192,B=0,A=255),Tints[1]=(R=255,G=192,B=0,A=255))
	ConnectionPing            = (RenderStyle=STY_Alpha,PosX=1.0,PosY=0.0,OffsetX=-74,OffsetY=32,DrawPivot=DP_MiddleRight,TextureScale=0.4,Tints[0]=(A=255),Tints[1]=(A=255))
	ConnectionLoss            = (RenderStyle=STY_Alpha,PosX=1.0,PosY=0.0,OffsetX=-100,OffsetY=78,DrawPivot=DP_MiddleRight,TextureScale=0.3,Tints[0]=(A=255),Tints[1]=(A=255))

	AltConnectionIcon            = (WidgetTexture=Texture'ConnectionIcon',RenderStyle=STY_Alpha,PosX=1.0,PosY=0.0,OffsetX=5,OffsetY=156,DrawPivot=DP_UpperRight,TextureCoords=(X1=0,Y1=0,X2=128,Y2=128),TextureScale=0.21,ScaleMode=SM_Right,Scale=1.000000,Tints[0]=(R=255,G=255,B=255,A=255),Tints[1]=(R=255,G=255,B=255,A=255))
	AltConnectionBackground      = (WidgetTexture=Texture'HudContent.Generic.HUD',RenderStyle=STY_Alpha,PosX=1.0,PosY=0.0,OffsetX=0,OffsetY=64,DrawPivot=DP_UpperRight,TextureCoords=(X1=168,Y1=211,X2=334,Y2=255),TextureScale=0.53,ScaleMode=SM_Right,Scale=1.000000,Tints[0]=(R=0,G=0,B=0,A=150),Tints[1]=(R=0,G=0,B=0,A=150))
	AltConnectionBackgroundDisc  = (WidgetTexture=Texture'HudContent.Generic.HUD',RenderStyle=STY_Alpha,PosX=1.0,PosY=0.0,OffsetX=0,OffsetY=59,DrawPivot=DP_UpperRight,TextureCoords=(X1=119,Y1=258,X2=173,Y2=313),TextureScale=0.53,ScaleMode=SM_Right,Scale=1.000000,Tints[0]=(R=255,G=255,B=255,A=255),Tints[1]=(R=255,G=255,B=255,A=255))
	AltConnectionUnlagStatus     = (WidgetTexture=Material'HudContent.Generic.GlowCircle',RenderStyle=STY_Alpha,PosX=1.0,PosY=0.0,OffsetX=4,OffsetY=59,DrawPivot=DP_UpperRight,TextureCoords=(X1=0,Y1=0,X2=64,Y2=64),TextureScale=0.5,ScaleMode=SM_Right,Scale=1.000000,Tints[0]=(R=0,G=0,B=0,A=255),Tints[1]=(R=0,G=0,B=0,A=255))
	AltConnectionAlert           = (WidgetTexture=Material'HudContent.Generic.fb_Pulse001',RenderStyle=STY_Alpha,PosX=1.0,PosY=0.0,OffsetX=6,OffsetY=55,DrawPivot=DP_UpperRight,TextureCoords=(X1=0,Y1=0,X2=64,Y2=64),TextureScale=0.53,ScaleMode=SM_Right,Scale=1.000000,Tints[0]=(R=255,G=192,B=0,A=255),Tints[1]=(R=255,G=192,B=0,A=255))
	AltConnectionPing            = (RenderStyle=STY_Alpha,PosX=1.0,PosY=0.0,OffsetX=-74,OffsetY=103,DrawPivot=DP_MiddleRight,TextureScale=0.4,Tints[0]=(A=255),Tints[1]=(A=255))
	AltConnectionLoss            = (RenderStyle=STY_Alpha,PosX=1.0,PosY=0.0,OffsetX=-100,OffsetY=173,DrawPivot=DP_MiddleRight,TextureScale=0.3,Tints[0]=(A=255),Tints[1]=(A=255))
}

