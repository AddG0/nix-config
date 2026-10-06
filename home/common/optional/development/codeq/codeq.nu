# Nushell completion for codeq

module completions {

  def "nu-complete codeq commands" [] {
    [
      { value: "loc", description: "lines of code, comments, blanks per language (tokei)" }
      { value: "complexity", description: "cyclomatic complexity per function (lizard)" }
      { value: "dup", description: "copy-pasted blocks (pmd cpd)" }
      { value: "cycles", description: "call and import cycles (sqry)" }
      { value: "overview", description: "hubs, hotspots, unused public API (sqry)" }
      { value: "coupling", description: "Martin package metrics + graph, JVM (jdeps)" }
      { value: "design", description: "PMD design rules + CK class metrics, JVM" }
      { value: "bugs", description: "bug patterns in bytecode, JVM (spotbugs)" }
      { value: "coverage", description: "line/branch/method coverage, JVM or Go" }
      { value: "all", description: "every command that applies -> REPORT.md" }
      { value: "help", description: "list commands and what applies here" }
    ]
  }

  # Code-quality metrics across languages
  export extern "codeq" [
    command?: string@"nu-complete codeq commands"
    -o: path      # output directory (default ./.codeq)
    --tests       # include test sources
  ]

  # Line/branch/method coverage, JVM or Go
  export extern "codeq coverage" [
    --no-run      # summarise existing reports without running tests
  ]

  # Cyclomatic complexity per function
  export extern "codeq complexity" [
    ccn?: int     # warning threshold (default 10)
  ]

  # Copy-pasted blocks
  export extern "codeq dup" [
    tokens?: int  # minimum duplicate size in tokens (default 75)
  ]

  # Martin package metrics + graph, JVM
  export extern "codeq coupling" [
    prefix?: string  # root package prefix (default: auto-detected)
  ]
}

export use completions *
