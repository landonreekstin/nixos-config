# ~/nixos-config/modules/nixos/desktop/custom-sddm-theme.nix
{ config, lib, ... }:

let
  cfg = config.customConfig.desktop.displayManager.sddm.customTheme;
in
{
  options.sddm-astronaut.customThemeContent = lib.mkOption {
    type = with lib.types; nullOr str;
    internal = true;
    default = null;
    description = "Generated string content for the custom SDDM Astronaut theme.";
  };

  config = lib.mkIf cfg.enable {
    # We construct the entire .conf file as a multi-line string here,
    # ensuring all keys are under the single, correct `[General]` section.
    # We also include all keys from the example for maximum compatibility.
    sddm-astronaut.customThemeContent = ''
      [General]
      #################### General ####################
      ScreenWidth="1920"
      ScreenHeight="1080"
      ScreenPadding=""
      Font="${cfg.font}"
      FontSize="${toString cfg.fontSize}"
      KeyboardSize="0.4"
      RoundCorners="${toString cfg.roundCorners}"
      Locale=""
      HourFormat="HH:mm"
      DateFormat="dddd d"
      HeaderText=""

      #################### Background ####################
      BackgroundPlaceholder="Backgrounds/${builtins.baseNameOf cfg.wallpaper-placeholder}"
      Background="Backgrounds/${builtins.baseNameOf cfg.wallpaper}"
      BackgroundSpeed="1.0"
      PauseBackground=""
      DimBackground="0.0"
      CropBackground="true"
      BackgroundHorizontalAlignment="center"
      BackgroundVerticalAlignment="center"

      #################### Colors ####################
      HeaderTextColor="${cfg.colors.headerText}"
      DateTextColor="${cfg.colors.dateText}"
      TimeTextColor="${cfg.colors.timeText}"
      FormBackgroundColor="${cfg.colors.formBackground}"
      BackgroundColor="${cfg.colors.formBackground}"
      DimBackgroundColor="${cfg.colors.dimBackground}"
      LoginFieldBackgroundColor="#d8d8ff"
      PasswordFieldBackgroundColor="#d8d8ff"
      LoginFieldTextColor="#d8d8ff"
      PasswordFieldTextColor="#d8d8ff"
      UserIconColor="#d8d8ff"
      PasswordIconColor="#d8d8ff"
      PlaceholderTextColor="${cfg.colors.placeholderText}"
      WarningColor="#d8d8ff"
      LoginButtonTextColor="${cfg.colors.loginButtonText}"
      LoginButtonBackgroundColor="${cfg.colors.loginButtonBackground}"
      SystemButtonsIconsColor="${cfg.colors.systemButtonsIcons}"
      SessionButtonTextColor="#d8d8ff"
      VirtualKeyboardButtonTextColor="#d8d8ff"
      DropdownTextColor="#6c6caa"
      DropdownSelectedBackgroundColor="#f8f8ff"
      DropdownBackgroundColor="#d8d8ff"
      HighlightTextColor="#484855"
      HighlightBackgroundColor="${cfg.colors.highlightBackground}"
      HighlightBorderColor="transparent"
      HoverUserIconColor="#6c6caa"
      HoverPasswordIconColor="#6c6caa"
      HoverSystemButtonsIconsColor="#6c6caa"
      HoverSessionButtonTextColor="#6c6caa"
      HoverVirtualKeyboardButtonTextColor="#6c6caa"

      #################### Form ####################
      PartialBlur="true"
      FullBlur=""
      BlurMax="8"
      Blur="${toString cfg.blur}"
      HaveFormBackground="true"
      FormPosition="right"

      #################### Virtual Keyboard ####################
      VirtualKeyboardPosition="right"

      #################### Interface Behavior ####################
      HideVirtualKeyboard="false"
      HideSystemButtons="false"
      HideLoginButton="false"
      ForceLastUser="true"
      PasswordFocus="true"
      HideCompletePassword="true"
      AllowEmptyPassword="false"
      AllowUppercaseLettersInUsernames="false"
      BypassSystemButtonsChecks="false"
      RightToLeftLayout="false"

      #################### Translation ####################
      TranslatePlaceholderUsername=""
      TranslatePlaceholderPassword=""
      TranslateLogin=""
      TranslateLoginFailedWarning=""
      TranslateCapslockWarning=""
      TranslateSuspend=""
      TranslateHibernate=""
      TranslateReboot=""
      TranslateShutdown=""
      TranslateSessionSelection=""
      TranslateVirtualKeyboardButtonOn=""
      TranslateVirtualKeyboardButtonOff=""
    '';
  };
}