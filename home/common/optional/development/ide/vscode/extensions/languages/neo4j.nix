{pkgs, ...}: {
  extensions = [
    # Official Neo4j extension - Cypher syntax, linting, autocompletion, database connection
    pkgs.vscode-marketplace.neo4j-extensions.neo4j-for-vscode
  ];
}
