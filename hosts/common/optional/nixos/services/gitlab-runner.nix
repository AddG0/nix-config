{
  services.gitlab-runner = {
    enable = true;
    runners = {
      "gitlab-runner" = {
        name = "gitlab-runner";
        token = "gitlab-runner";
      };
    };
  };
}