{config, ...}: {
  sops.secrets = {
    "msmtp-password" = {
      owner = config.users.users.${config.hostSpec.primaryUsername}.name;
      inherit (config.users.users.${config.hostSpec.primaryUsername}) group;
    };
  };

  programs.msmtp = {
    enable = true;
    setSendmail = true; # set the system sendmail to msmtp's

    accounts = {
      "default" = {
        host = "${config.hostSpec.email.msmtp-host}";
        port = 587;
        auth = true;
        tls = true;
        tls_starttls = true;
        from = "${config.hostSpec.email.notifier}";
        user = "${config.hostSpec.email.notifier}";
        passwordeval = "cat ${config.sops.secrets."msmtp-password".path}";
        logfile = "~/.msmtp.log";
      };
    };
  };
}
