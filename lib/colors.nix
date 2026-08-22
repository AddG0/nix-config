{lib}: let
  digits = "0123456789abcdef";
  digitToInt =
    lib.listToAttrs
    (lib.imap0 (i: c: lib.nameValuePair c i) (lib.stringToCharacters digits));
  intToDigit = n: builtins.substring n 1 digits;

  strip = s: lib.removePrefix "#" (lib.toLower s);
  byteAt = s: i:
    digitToInt.${builtins.substring i 1 s} * 16 + digitToInt.${builtins.substring (i + 1) 1 s};
  toByte = n: intToDigit (n / 16) + intToDigit (lib.mod n 16);

  mixColors = a: b: num: den: let
    x = strip a;
    y = strip b;
    chan = i: (byteAt x i * (den - num) + byteAt y i * num) / den;
  in
    "#" + toByte (chan 0) + toByte (chan 2) + toByte (chan 4);
in {
  # Linear mix of two hex colours, num/den of the way from a to b.
  mix = mixColors;

  # base16 assigns base03 to comments and base04 to status bars, but schemes are
  # free to pick tones unreadable against their own base00.
  muted = c: {
    text = mixColors c.base04 c.base05 2 3;
    ui = mixColors c.base04 c.base05 1 3;
  };
}
