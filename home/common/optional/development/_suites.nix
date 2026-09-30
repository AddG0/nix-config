{
  optional,
  suites,
  ...
}: {
  development.home = with optional.home.development; [core git gitlab herdr languages lnav nvim-uri-handler polyrepo process-compose scripts] ++ suites.ide.home;
}
