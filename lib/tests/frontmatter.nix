# lib.custom.frontmatter: the YAML subset it reads, and the rest it refuses instead of misreading.
{
  lib,
  coverage,
  ...
}: let
  inherit (lib.custom) frontmatter;

  document = frontmatterLines: "---\n${lib.concatStringsSep "\n" frontmatterLines}\n---\n\nBody.";
  attrsOf = lines: (frontmatter.fromText (document lines)).attrs;
  typedOf = lines: (frontmatter.fromText (document lines)).typedAttrs;
  forced = value: builtins.deepSeq value value;

  refuses = lines: msg: {
    expr = forced (attrsOf lines);
    expectedError = {
      type = "ThrownError";
      inherit msg;
    };
  };
in
  coverage.addCoverage frontmatter {
    fromText = {
      testCrlfLineEndingsKeepTheFrontmatter = {
        expr = let
          parsed = frontmatter.fromText "---\r\nname: a\r\ndescription: d\r\n---\r\n\r\nBody.\r\n";
        in {inherit (parsed) attrs body;};
        expected = {
          attrs = {
            name = "a";
            description = "d";
          };
          body = "\nBody.\n";
        };
      };
      testATrailingCommentOnAPlainScalarIsDropped = {
        expr = [(attrsOf ["name: a # note"]).name (typedOf ["count: 3 # note"]).count (attrsOf ["colour: a#b"]).colour];
        expected = ["a" 3 "a#b"];
      };
      testATrailingCommentAfterAQuotedScalarIsDropped = {
        expr = (attrsOf ["name: 'a # b' # note"]).name;
        expected = "a # b";
      };
      testACommentLineIsSkipped = {
        expr = attrsOf ["# a comment" "name: a" "tools:" "  # between items" "  - Read"];
        expected = {
          name = "a";
          tools = ["Read"];
        };
      };
      testADoubledSingleQuoteUnescapes = {
        expr = [(attrsOf ["name: 'it''s'"]).name (typedOf ["name: 'it''s'"]).name (typedOf ["tools: ['it''s', b]"]).tools];
        expected = ["it's" "it's" ["it's" "b"]];
      };
      testADoubleQuotedEscapeUnescapes = {
        expr = (attrsOf ["name: \"say \\\"hi\\\"\\tnow\""]).name;
        expected = "say \"hi\"\tnow";
      };
      testOneLevelOfNestingStillParses = {
        expr = typedOf ["metadata:" "  owner: addg" "  count: 2" "tools:" "  - Read" "  - 'Bash(git *)'" "note: |" "  line one" "  line two"];
        expected = {
          metadata = {
            owner = "addg";
            count = 2;
          };
          tools = ["Read" "Bash(git *)"];
          note = "line one\nline two";
        };
      };
      testSpaceSeparatedBracketPlaceholdersReadAsAString = {
        expr = [(attrsOf ["argument-hint: [path] [--new]"]).argument-hint (typedOf ["argument-hint: [pr-number] [priority] # note"]).argument-hint];
        expected = ["[path] [--new]" "[pr-number] [priority]"];
      };
      testANestedMapUnderANestedKeyThrows = refuses ["hooks:" "  Stop:" "    - matcher: x"] "line 3 of inline frontmatter: `hooks\\.Stop` opens a nested map, list or block scalar; only one level of nesting is read";
      testAListOfMapsThrows = refuses ["tools:" "  - name: a" "    kind: b"] "a list of maps under `tools` is not read";
      testAContinuationLineUnderAScalarThrows = refuses ["description: first" "  second"] "an indented line continues nothing";
      testATopLevelLineThatIsNotAKeyThrows = refuses ["- stray"] "expected `key: value` at the top level, got `- stray`";
      testAListAndAMapUnderOneKeyThrows = refuses ["tools:" "  - Read" "  name: a"] "`tools` mixes list items with `key: value` pairs";
      testAFlowMapThrows = refuses ["metadata: {owner: addg}"] "`\\{owner: addg\\}` needs YAML this parser does not read";
      testTextAfterAFlowListThrows = refuses ["tools: [a] b"] "unterminated flow list, or text after its closing `\\]`";
      testAnUnterminatedFlowListThrows = refuses ["tools: [a, b"] "unterminated flow list, or text after its closing `\\]`";
      testAnUnterminatedQuoteThrows = refuses ["name: 'open"] "unterminated single quote, or text after the closing quote";
    };

    normalizeStringList = {
      testAFrontmatterStringListUnescapesItsItems = {
        expr = frontmatter.normalizeStringList "['it''s', \"a,b\", c]";
        expected = ["it's" "a,b" "c"];
      };
    };

    fromFile = {
      testAPathIsReadAndParsed = {
        expr = (frontmatter.fromFile ./fixtures/ai/plain-skill/SKILL.md).attrs ? name;
        expected = true;
      };
      testAMissingAbsolutePathThrows = {
        expr = frontmatter.fromFile "/nonexistent/SKILL.md";
        expectedError = {
          type = "ThrownError";
          msg = "path does not exist: /nonexistent/SKILL\\.md";
        };
      };
    };

    toFile = {
      testRenderedAttrsReadBackUnchanged = {
        expr =
          (frontmatter.fromText (frontmatter.toFile {
            attrs = {
              name = "a";
              tools = ["Read" "Bash(git *)"];
            };
            body = "Body.";
          })).typedAttrs;
        expected = {
          name = "a";
          tools = ["Read" "Bash(git *)"];
        };
      };
      testNoAttrsRendersTheBodyAlone = {
        expr = frontmatter.toFile {body = "Body.";};
        expected = "Body.";
      };
    };
  }
