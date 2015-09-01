/******************************************************************************
BetrayalClientSettingsMenu

Creation date: 2011-03-09 19:29
Last change: $Id$
Copyright © 2011, Wormbo
Website: http://www.koehler-homepage.de/Wormbo/
Feel free to reuse this code. Send me a note if you found it helpful or want
to report bugs/provide improvements.
Please ask for permission first, if you intend to make money off reused code.
******************************************************************************/

class BetrayalClientSettingsMenu extends UT2K4CustomHUDMenu;


var automated moCheckBox SwapTeamColors;
var automated moCheckBox WantUnlagging;
var automated moSlider   PingSmoothing;
var automated moCheckBox NoConsoleDeathMessages;
var bool bPauseGame;


function HandleParameters(string GameClassName, string PauseGame)
{
	bPauseGame = bool(PauseGame);

	Super.HandleParameters(GameClassName, PauseGame);

	if (bPauseGame)
		PlayerOwner().SetPause(True);
}

event Closed(GUIComponent Sender, bool bCancelled)
{
	Super.Closed(Sender, bCancelled);

	if (bPauseGame)
		PlayerOwner().SetPause(False);
}

function bool InitializeGameClass(string GameClassName)
{
	return true;
}

function LoadSettings()
{
	SwapTeamColors.Checked(class'BetrayalPRI'.default.bSwapTeamColors);
	WantUnlagging.Checked(class'BetrayalPRI'.default.bWantUnlagging);
	PingSmoothing.SetValue(class'BetrayalPRI'.default.PingSmoothing);
	NoConsoleDeathMessages.Checked(class'BetrayalDeathMessage'.default.bNoConsoleDeathMessages);
}


function SaveSettings()
{
	local BetrayalPawn P;

	class'BetrayalPRI'.default.bSwapTeamColors = SwapTeamColors.IsChecked();
	class'BetrayalPRI'.default.bWantUnlagging = WantUnlagging.IsChecked();
	class'BetrayalPRI'.default.PingSmoothing = Clamp(Round(PingSmoothing.GetValue()), 0, 255);
	class'BetrayalPRI'.static.StaticSaveConfig();

	class'BetrayalDeathMessage'.default.bNoConsoleDeathMessages = NoConsoleDeathMessages.IsChecked();
	class'BetrayalDeathMessage'.static.StaticSaveConfig();

	// update colors immediately
	foreach PlayerOwner().DynamicActors(class'BetrayalPawn', P) {
		if (BetrayalPRI(P.PlayerReplicationInfo) != None)
			P.SetTeamSkin(BetrayalPRI(P.PlayerReplicationInfo).Rec);
	}
	PlayerOwner().Mutate("WantUnlagging"@int(class'BetrayalPRI'.default.bWantUnlagging));
}


//=============================================================================
// Default values
//=============================================================================

defaultproperties
{
	WindowName = "Betrayal Client Options"
	WinTop     = 0.3
	WinLeft    = 0.3
	WinWidth   = 0.4
	WinHeight  = 0.35

	bAllowedAsLast = True // FFS!

	Begin Object Class=moCheckBox Name=chkSwapTeamColors
		Caption                = "Swap Team Colors"
		CaptionWidth           = 0.10
		ComponentJustification = TXTA_Center
		WinTop                 = 0.35
		WinLeft                = 0.325
		WinWidth               = 0.35
		TabOrder               = 4
		Hint = "Whether you want to reverse team colors so you and your teammates are red and opponents blue."
	End Object
	SwapTeamColors=chkSwapTeamColors

	Begin Object Class=moCheckBox Name=chkWantUnlagging
		Caption                = "Use Shot Unlagging"
		CaptionWidth           = 0.10
		ComponentJustification = TXTA_Center
		WinTop                 = 0.4
		WinLeft                = 0.325
		WinWidth               = 0.35
		TabOrder               = 4
		Hint = "Whether you want to take advantage of server-side ping compensation for hit detection."
	End Object
	WantUnlagging=chkWantUnlagging

	Begin Object Class=moSlider Name=sldPingSmoothing
		Caption                = "Ping Smoothing"
		CaptionWidth           = 0.10
		ComponentJustification = TXTA_Center
		WinTop                 = 0.45
		WinLeft                = 0.325
		WinWidth               = 0.35
		TabOrder               = 5
		MinValue               = 1
		MaxValue               = 100
		bIntSlider             = True
		Hint = "Select the number of recent ping values to consider for smoothing your calculated ping. (default: 20)"
	End Object
	PingSmoothing=sldPingSmoothing

	Begin Object Class=moCheckBox Name=chkNoConsoleDeathMessages
		Caption                = "No Console Death Messages"
		CaptionWidth           = 0.10
		ComponentJustification = TXTA_Center
		WinTop                 = 0.5
		WinLeft                = 0.325
		WinWidth               = 0.35
		TabOrder               = 4
		Hint = "Turn off death messages in Betrayal. (Does not affect other game types.)"
	End Object
	NoConsoleDeathMessages=chkNoConsoleDeathMessages

	Begin Object Class=GUIButton Name=CancelButton
		Caption                = "Cancel"
		WinTop                 = 0.57
		WinLeft                = 0.44
		WinWidth               = 0.1
		WinHeight              = 0.04
		TabOrder               = 7
		OnClick                = InternalOnClick
		Hint = "Click to close this menu, discarding changes."
	End Object
	b_Cancel=CancelButton

	Begin Object Class=GUIButton Name=OkButton
		Caption                = "OK"
		WinTop                 = 0.57
		WinLeft                = 0.55
		WinWidth               = 0.1
		WinHeight              = 0.04
		TabOrder               = 8
		OnClick                = InternalOnClick
		Hint = "Click to close this menu, saving changes."
	End Object
	b_OK=OkButton
}

