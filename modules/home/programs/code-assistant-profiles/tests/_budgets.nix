# Context budgets.
{
  budgets,
  emptySpec,
  evalTargets,
  lib,
  manyLines,
  needleProblems,
  noNeedleProblems,
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
in {
  "test an over-budget profile is reported once per breached limit" = {
    expr = lib.length (budgetOf budget overBudget);
    expected = 1;
  };
  "test the report names the rule to cut" = {
    expr = lib.hasInfix "long 7L" (lib.head (budgetOf budget overBudget));
    expected = true;
  };
  "test path-scoped rules are outside the budget" = {
    expr = budgetOf budget scopedOnly;
    expected = [];
  };
  "test codex and opencode count a path-scoped rule toward the budget" = {
    expr = (budgets.measureInlined (typed scopedOnly)).lines;
    expected = 7;
  };
  "test a path-scoped rule over budget is reported for codex and opencode" = {
    expr = lib.length (budgets.inlinedBudgetMessages "profile 'p'" budget (typed scopedOnly));
    expected = 1;
  };
  "test the inlined check stays silent when no rule is path-scoped" = {
    expr = budgets.inlinedBudgetMessages "profile 'p'" budget (typed overBudget);
    expected = [];
  };
  "test an over-budget path-scoped rule warns when codex or opencode renders the profile" = {
    expr = lib.any (lib.hasInfix "as codex/opencode inline it") scopedOverBudget.warnings;
    expected = true;
  };
  "test a null budget disables the check" = {
    expr = budgetOf noBudget overBudget;
    expected = [];
  };
  "test instructions count toward the budget" = {
    expr = (budgets.measureAlwaysOn (typed (withInstructions (spec "a\nb\nc")))).lines;
    expected = 3;
  };
  "test a breached total and a breached per-entry cap are reported separately" = {
    expr = lib.length (budgets.selectionMessages "profile 'p'" budget.description (typed selectionCases));
    expected = 2;
  };
  "test the total report counts every skill and agent" = {
    expr = lib.hasInfix "3 skills and agents carry 139 characters" (lib.head (budgets.selectionMessages "profile 'p'" budget.description (typed selectionCases)));
    expected = true;
  };
  "test the truncation report names only the oversized entries" = {
    expr = lib.hasInfix "2 descriptions exceed" (lib.elemAt (budgets.selectionMessages "profile 'p'" budget.description (typed selectionCases)) 1);
    expected = true;
  };
  "test the truncation report skips a lean description" = {
    expr = needleProblems (lib.elemAt (budgets.selectionMessages "profile 'p'" budget.description (typed selectionCases)) 1) {
      contains = ["chatty"];
      lacks = ["lean"];
    };
    expected = noNeedleProblems;
  };
  "test whenToUse counts toward an entry's length" = {
    expr = map (e: e.length) (budgets.selectionEntries (typed {
      skills.pair = {
        description = "Twenty characters ok";
        whenToUse = "and another twenty-eight here";
      };
    }));
    expected = [49];
  };
  "test a null description budget disables both checks" = {
    expr =
      budgets.selectionMessages "profile 'p'" {
        total = null;
        characters = null;
      }
      (typed selectionCases);
    expected = [];
  };
  "test the total budget derives from the context window" = {
    expr = (budgets.resolveBudgets (derivedBudget 200000)).description.total;
    expected = 8000;
  };
  "test a bigger window buys a bigger listing" = {
    expr = (budgets.resolveBudgets (derivedBudget 1000000)).description.total;
    expected = 40000;
  };
  "test an explicit total wins over the derivation" = {
    expr = (budgets.resolveBudgets (budget // {contextWindow = 1000000;})).description.total;
    expected = 100;
  };
  "test a null context window drops the derived budget" = {
    expr = (budgets.resolveBudgets (derivedBudget null)).description.total;
    expected = null;
  };
}
