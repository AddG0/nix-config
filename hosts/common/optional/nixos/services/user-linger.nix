# Lets the primary user's services run on a host nobody stays logged into —
# without this a user unit only lives between first login and last logout.
#
# All-or-nothing per user: the manager reaches default.target at boot, so every
# user unit wanting that target starts there too.
{config, ...}: {
  users.users.${config.hostSpec.primaryUsername}.linger = true;
}
