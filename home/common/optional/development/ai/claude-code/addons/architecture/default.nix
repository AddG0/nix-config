# Architecture addon - agents, skills, and rules for system design, DDD, and ADRs
{pkgs, ...}: let
  skillsCollection = "${pkgs.claude-code-skills-collection}/share/claude-code/plugins/claude-code-skills-collection/skills";
in {
  agents = {
    "adr-architect" = ./agents/adr-architect.md;
    "system-architect" = ./agents/system-architect.md;
    "ddd-expert" = ./agents/ddd-expert.md;
  };

  skills = {
    "software-architecture" = "${pkgs.context-engineering-kit}/share/claude-code/plugins/ddd/skills/software-architecture";
    "decision-matrix" = "${skillsCollection}/decision-matrix";
    "forecast-premortem" = "${skillsCollection}/forecast-premortem";
    "postmortem" = "${skillsCollection}/postmortem";
    "security-threat-model" = "${skillsCollection}/security-threat-model";
  };

  rules."architecture" = ''
    Architecture conventions:
    - Document significant decisions as ADRs in docs/adr/ (MADR 3.0 format)
    - Use Mermaid for inline diagrams, C4 model for system-level views
    - Identify bounded contexts before designing components
    - Specify component interfaces (REST, gRPC, events) in YAML format
    - Always document trade-offs — what was chosen AND what was rejected and why
  '';
}
