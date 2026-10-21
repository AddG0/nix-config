# Context budgets.
{
  budgets,
  emptySpec,
  evalTargets,
  expect,
  expectText,
  lib,
  manyLines,
  rule,
  scopedRule,
  spec,
  typed,
  withInstructions,
  ...
}: let
  budget = {
    alwaysOn = {
      lines = 5;
      characters = 200;
    };
    description = {
      total = 100;
      characters = 40;
    };
    contextWindow = null;
    enforce = "warn";
  };

  noBudget = {
    alwaysOn = {
      lines = null;
      characters = null;
    };
    description = {
      total = null;
      characters = null;
    };
    contextWindow = null;
    enforce = "warn";
  };

  budgetOf = b: sharedConfig: budgets.budgetMessages "profile 'p'" b (typed sharedConfig);

  derivedBudget = window: {
    alwaysOn = {
      lines = null;
      characters = null;
    };
    description = {
      total = null;
      characters = null;
    };
    contextWindow = window;
    enforce = "warn";
  };

  wordy = builtins.concatStringsSep "" (builtins.genList (_: "x") 60);

  selectionCases = {
    skills.chatty = {
      description = wordy;
      whenToUse = null;
    };
    skills.lean = {
      description = "Short and specific.";
      whenToUse = null;
    };
    agents.chatty.description = wordy;
  };

  overBudget = {
    instructions = emptySpec;
    rules.long = rule "one\ntwo\nthree\nfour\nfive\nsix\nseven";
  };

  scopedOnly = {
    instructions = emptySpec;
    rules.long = scopedRule ["**/*.ts"] "one\ntwo\nthree\nfour\nfive\nsix\nseven";
  };

  scopedOverBudget = evalTargets {
    rules.long = {
      paths = ["**/*.ts"];
      content.text = manyLines;
    };
  };
in ''
  ${expect "an over-budget profile is reported once per breached limit" (lib.length (budgetOf budget overBudget)) 1}
  ${expect "the report names the rule to cut" (lib.hasInfix "long 7L" (lib.head (budgetOf budget overBudget))) true}
  ${expect "path-scoped rules are outside the budget" (budgetOf budget scopedOnly) []}
  ${expect "codex and opencode count a path-scoped rule toward the budget" (budgets.measureInlined (typed scopedOnly)).lines 7}
  ${expect "a path-scoped rule over budget is reported for codex and opencode" (lib.length (budgets.inlinedBudgetMessages "profile 'p'" budget (typed scopedOnly))) 1}
  ${expect "the inlined check stays silent when no rule is path-scoped" (budgets.inlinedBudgetMessages "profile 'p'" budget (typed overBudget)) []}
  ${expect "an over-budget path-scoped rule warns when codex or opencode renders the profile" (lib.any (lib.hasInfix "as codex/opencode inline it") scopedOverBudget.warnings) true}
  ${expect "a null budget disables the check" (budgetOf noBudget overBudget) []}
  ${expect "instructions count toward the budget" (budgets.measureAlwaysOn (typed (withInstructions (spec "a\nb\nc")))).lines 3}
  ${expect "a breached total and a breached per-entry cap are reported separately" (lib.length (budgets.selectionMessages "profile 'p'" budget.description (typed selectionCases))) 2}
  ${expect "the total report counts every skill and agent" (lib.hasInfix "3 skills and agents carry 139 characters" (lib.head (budgets.selectionMessages "profile 'p'" budget.description (typed selectionCases)))) true}
  ${expect "the truncation report names only the oversized entries" (lib.hasInfix "2 descriptions exceed" (lib.elemAt (budgets.selectionMessages "profile 'p'" budget.description (typed selectionCases)) 1)) true}
  ${expectText "the truncation report skips a lean description" (lib.elemAt (budgets.selectionMessages "profile 'p'" budget.description (typed selectionCases)) 1) {
    contains = ["chatty"];
    lacks = ["lean"];
  }}
  ${expect "whenToUse counts toward an entry's length" (map (e: e.length) (budgets.selectionEntries (typed {
    skills.pair = {
      description = "Twenty characters ok";
      whenToUse = "and another twenty-eight here";
    };
  }))) [49]}
  ${expect "a null description budget disables both checks" (budgets.selectionMessages "profile 'p'" {
      total = null;
      characters = null;
    }
    (typed selectionCases)) []}
  ${expect "the total budget derives from the context window" (budgets.resolveBudgets (derivedBudget 200000)).description.total 8000}
  ${expect "a bigger window buys a bigger listing" (budgets.resolveBudgets (derivedBudget 1000000)).description.total 40000}
  ${expect "an explicit total wins over the derivation" (budgets.resolveBudgets (budget // {contextWindow = 1000000;})).description.total 100}
  ${expect "a null context window drops the derived budget" (budgets.resolveBudgets (derivedBudget null)).description.total null}

''
