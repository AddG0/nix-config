# Lets the seat user open Attack Shark mice over hidraw, which their WebHID web driver needs.
{
  services.udev.extraRules = ''
    SUBSYSTEM=="hidraw", ATTRS{idVendor}=="373e", TAG+="uaccess", MODE="0660"
  '';
}
