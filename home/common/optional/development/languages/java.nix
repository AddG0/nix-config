{pkgs, ...}: {
  home.packages = with pkgs; [
    jdk
    maven
    gradle
  ];

  home.sessionVariables = {
    JAVA_HOME = "${pkgs.jdk}";
  };
}
