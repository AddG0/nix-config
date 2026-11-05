{
  optional,
  suites,
  ...
}: {
  development.home = with optional.home.development; [codeq core dev-cloud git gitlab languages lnav nvim-uri-handler polyrepo process-compose scripts] ++ suites.ide.home;
}
