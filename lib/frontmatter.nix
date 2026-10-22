{lib}: let
  readInput = input:
    if lib.isPath input || lib.isDerivation input
    then builtins.readFile input
    else if lib.isString input && lib.hasPrefix "/" input
    then
      if builtins.pathExists input
      then builtins.readFile input
      else throw "frontmatter.readInput: path does not exist: ${input}"
    else if lib.isString input
    then input
    else throw "frontmatter.readInput: expected path, derivation, or string; got ${builtins.typeOf input}";

  takeUntil = pred: list:
    if list == []
    then {
      found = false;
      before = [];
      after = [];
    }
    else if pred (builtins.head list)
    then {
      found = true;
      before = [];
      after = builtins.tail list;
    }
    else let
      next = takeUntil pred (builtins.tail list);
    in {
      inherit (next) found after;
      before = [(builtins.head list)] ++ next.before;
    };

  unescapeDoubleQuoted = fail: inner:
    lib.concatMapStrings (part:
      if lib.isList part
      then
        {
          "\\" = "\\";
          "\"" = "\"";
          "/" = "/";
          n = "\n";
          t = "\t";
        }
        .${
          lib.head part
        }
        or (fail "unsupported escape `\\${lib.head part}` in a double-quoted scalar")
      else part)
    (builtins.split "\\\\(.)" inner);

  # One scalar as YAML reads it on its line: quotes undone, a trailing ` #` comment dropped. Returns {quoted | flow | plain}.
  readScalar = fail: raw: let
    text = lib.strings.trim raw;
    single = builtins.match "'(([^']|'')*)'([[:space:]]+#.*)?" text;
    double = builtins.match "\"(([^\"\\\\]|\\\\.)*)\"([[:space:]]+#.*)?" text;
    flow = builtins.match "(\\[('([^']|'')*'|\"([^\"\\\\]|\\\\.)*\"|[^]'\"])*])([[:space:]]+#.*)?" text;
    plain =
      if lib.hasPrefix "#" text
      then ""
      else lib.strings.trim (lib.head (builtins.split "[[:space:]]#" text));
  in
    if lib.hasPrefix "'" text
    then
      if single == null
      then fail "unterminated single quote, or text after the closing quote"
      else {quoted = lib.replaceStrings ["''"] ["'"] (lib.head single);}
    else if lib.hasPrefix "\"" text
    then
      if double == null
      then fail "unterminated double quote, or text after the closing quote"
      else {quoted = unescapeDoubleQuoted fail (lib.head double);}
    else if lib.hasPrefix "[" text
    then
      if flow != null
      then {flow = lib.head flow;}
      # Claude Code's documented `argument-hint: [pr-number] [priority]` form, which it reads as a string.
      else if builtins.match "(\\[[^]'\"]*][[:space:]]*)+(#.*)?" text != null
      then {inherit plain;}
      else fail "unterminated flow list, or text after its closing `]`"
    else if builtins.match "[{&!%@`].*|[?:-]([[:space:]].*)?" plain != null
    then fail "`${plain}` needs YAML this parser does not read (a flow map, anchor, tag, directive or block indicator)"
    else {inherit plain;};

  # Splits on commas outside quotes; an item opening a quote must close it.
  splitFlowItems = text: let
    item = builtins.match "[[:space:]]*('([^']|'')*'|\"([^\"\\\\]|\\\\.)*\"|[^,'\"[:space:]][^,]*)?[[:space:]]*(,(.*))?" text;
  in
    if item == null
    then throw "frontmatter: unmatched quote or text after a quoted item in flow list '${text}'"
    else let
      first =
        if builtins.elemAt item 0 == null
        then ""
        else lib.strings.trim (builtins.elemAt item 0);
      rest = builtins.elemAt item 4;
    in
      [first] ++ lib.optionals (builtins.elemAt item 3 != null) (splitFlowItems rest);

  scalarString = scalar: scalar.quoted or scalar.flow or scalar.plain;

  # YAML's plain-scalar types for the values a frontmatter author writes; a quoted value stays a string.
  typedPlain = plain:
    if plain == "true"
    then true
    else if plain == "false"
    then false
    else if plain == "null" || plain == "~"
    then null
    else if builtins.match "-?[0-9]+" plain != null
    then lib.toInt plain
    else plain;

  flowItems = fail: flow: let
    inner = lib.strings.trim (lib.removeSuffix "]" (lib.removePrefix "[" flow));
  in
    if inner == ""
    then []
    else map (item: typedScalar fail (readScalar fail item)) (splitFlowItems inner);

  typedScalar = fail: scalar:
    scalar.quoted
    or (
      if scalar ? flow
      then flowItems fail scalar.flow
      else typedPlain scalar.plain
    );

  normalizeStringList = value:
    if value == null || value == ""
    then []
    else if lib.isList value
    then value
    else let
      trimmed = lib.strings.trim value;
      unwrapped =
        if lib.hasPrefix "[" trimmed && lib.hasSuffix "]" trimmed
        then lib.removeSuffix "]" (lib.removePrefix "[" trimmed)
        else trimmed;
      fail = reason: throw "frontmatter.normalizeStringList: ${reason} in '${value}'";
    in
      if lib.strings.trim unwrapped == ""
      then []
      else map (item: scalarString (readScalar fail item)) (splitFlowItems unwrapped);

  # `desc` names the origin in errors; inline text has none, which is how it
  # avoids readInput's path heuristic.
  splitDocument = desc: text: let
    lines = lib.splitString "\n" (lib.replaceStrings ["\r\n"] ["\n"] text);
    inputDesc =
      if desc == ""
      then ""
      else " in ${desc}";
  in
    if lines != [] && builtins.head lines == "---"
    then let
      split = takeUntil (line: line == "---") (builtins.tail lines);
    in
      if split.found
      then {
        inherit desc;
        frontmatter = lib.concatStringsSep "\n" split.before;
        body = lib.concatStringsSep "\n" split.after;
      }
      else throw "frontmatter.parseDocument: opened with '---' but no closing '---' fence found${inputDesc}"
    else {
      inherit desc;
      frontmatter = "";
      body = lib.concatStringsSep "\n" lines;
    };

  describeInput = input:
    if lib.isPath input || lib.isDerivation input
    then toString input
    else if lib.isString input && lib.hasPrefix "/" input
    then input
    else "";

  parseDocument = input: splitDocument (describeInput input) (readInput input);

  flushBlockScalar = state:
    if state.blockScalar == null
    then state
    else let
      bs = state.blockScalar;
      strip = l:
        if l == "" || bs.indent == 0
        then l
        else if lib.stringLength l <= bs.indent
        then ""
        else builtins.substring bs.indent (lib.stringLength l - bs.indent) l;
      stripped = map strip bs.lines;
      reversed = lib.reverseList stripped;
      trimmedRev =
        (lib.foldl (acc: l:
            if acc.done || l != ""
            then {
              done = true;
              out = acc.out ++ [l];
            }
            else acc) {
            done = false;
            out = [];
          }
          reversed).out;
      trimmed = lib.reverseList trimmedRev;
      joined =
        if bs.style == "|"
        then lib.concatStringsSep "\n" trimmed
        else
          (lib.foldl (acc: l:
              if l == ""
              then {
                result = acc.result + "\n";
                lastNonEmpty = false;
              }
              else if acc.result == ""
              then {
                result = l;
                lastNonEmpty = true;
              }
              else if acc.lastNonEmpty
              then {
                result = acc.result + " " + l;
                lastNonEmpty = true;
              }
              else {
                result = acc.result + l;
                lastNonEmpty = true;
              })
            {
              result = "";
              lastNonEmpty = false;
            }
            trimmed).result;
    in
      state
      // {
        attrs = state.attrs // {${bs.key} = joined;};
        pending = null;
        blockScalar = null;
      };

  # Reads top-level keys holding a scalar, a block scalar, or one level of list items or `key: scalar` pairs; throws, naming the line, on anything deeper.
  parseWith = typed: desc: text: let
    lines = lib.splitString "\n" text;
    keyPattern = "([A-Za-z0-9_-]+):([[:space:]]+(.*))?";
    step = state: entry: let
      inherit (entry) line;
      where =
        if desc == ""
        then "line ${toString entry.number} of inline frontmatter"
        else "${desc}:${toString entry.number}";
      fail = reason: throw "frontmatter: ${where}: ${reason}";
      convert = scalar:
        if typed
        then typedScalar fail scalar
        else scalarString scalar;
      indentMatch = builtins.match ''([[:space:]]*)(.*)'' line;
      indent = lib.stringLength (builtins.elemAt indentMatch 0);
      content = builtins.elemAt indentMatch 1;
      keyMatch = builtins.match keyPattern content;
      valueOf = match:
        if builtins.elemAt match 2 == null
        then ""
        else builtins.elemAt match 2;
      listMatch = builtins.match ''-([[:space:]]+(.*))?'' content;
      setPending = key: value:
        state
        // {
          attrs = state.attrs // {${key} = value;};
          pending = key;
          nestedIndent = null;
        };
      setScalar = key: value:
        state
        // {
          attrs = state.attrs // {${key} = value;};
          pending = null;
        };
      enterBlock = key: style:
        state
        // {
          pending = key;
          blockScalar = {
            inherit key style;
            indent = null;
            lines = [];
          };
        };
      setNested = value:
        state
        // {
          attrs = state.attrs // {${state.pending} = value;};
          nestedIndent = indent;
        };
      existing = state.attrs.${state.pending};
      blockStyle = scalar: lib.elem (scalar.plain or null) [">" "|"];
    in
      if state.blockScalar != null
      then
        if content == ""
        then
          state
          // {
            blockScalar = state.blockScalar // {lines = state.blockScalar.lines ++ [""];};
          }
        else if indent == 0 || (state.blockScalar.indent != null && indent < state.blockScalar.indent)
        then step (flushBlockScalar state) entry
        else if state.blockScalar.indent == null
        then
          state
          // {
            blockScalar =
              state.blockScalar
              // {
                inherit indent;
                lines = state.blockScalar.lines ++ [line];
              };
          }
        else
          state
          // {
            blockScalar = state.blockScalar // {lines = state.blockScalar.lines ++ [line];};
          }
      else if content == "" || lib.hasPrefix "#" content
      then state
      else if indent == 0
      then
        if keyMatch == null
        then fail "expected `key: value` at the top level, got `${content}`"
        else let
          key = builtins.elemAt keyMatch 0;
          scalar = readScalar fail (valueOf keyMatch);
        in
          if scalar.plain or null == ""
          then setPending key null
          else if blockStyle scalar
          then enterBlock key scalar.plain
          else if builtins.match ''[>|][-+0-9].*'' (scalar.plain or "") != null
          then fail "YAML chomping/indent indicators in '${key}: ${scalar.plain}' are not supported; use plain '>' or '|', or inline the value"
          else setScalar key (convert scalar)
      else if state.pending == null
      then fail "an indented line continues nothing: only a `key:` with no value on its line opens a list or map, and a multi-line plain scalar is not read"
      else if state.nestedIndent != null && indent != state.nestedIndent
      then fail "`${state.pending}` nests deeper than one level or is indented unevenly; only one level of list items or `key: value` pairs is read"
      else if listMatch != null
      then let
        item = builtins.elemAt listMatch 1;
        scalar = readScalar fail item;
      in
        if item == null || lib.strings.trim item == ""
        then fail "an empty list item under `${state.pending}`"
        else if builtins.match keyPattern item != null
        then fail "a list of maps under `${state.pending}` is not read"
        else if lib.isAttrs existing
        then fail "`${state.pending}` mixes list items with `key: value` pairs"
        else if blockStyle scalar
        then fail "a block scalar inside the list under `${state.pending}` is not read"
        else
          setNested ((
              if lib.isList existing
              then existing
              else []
            )
            ++ [(convert scalar)])
      else if keyMatch != null
      then let
        nestedKey = builtins.elemAt keyMatch 0;
        scalar = readScalar fail (valueOf keyMatch);
      in
        if lib.isList existing
        then fail "`${state.pending}` mixes list items with `key: value` pairs"
        else if scalar.plain or null == "" || blockStyle scalar
        then fail "`${state.pending}.${nestedKey}` opens a nested map, list or block scalar; only one level of nesting is read"
        else
          setNested ((
              if lib.isAttrs existing
              then existing
              else {}
            )
            // {${nestedKey} = convert scalar;})
      else fail "expected `- item` or `key: value` under `${state.pending}`, got `${content}`";

    finalState =
      lib.foldl step {
        attrs = {};
        pending = null;
        nestedIndent = null;
        blockScalar = null;
      }
      (lib.imap0 (index: line: {
          inherit line;
          # Frontmatter opens on the file's second line, after the `---` fence.
          number = index + 2;
        })
        lines);
  in
    (flushBlockScalar finalState).attrs;

  parse = parseWith false;

  dropWhile = pred: list:
    if list == []
    then []
    else if pred (builtins.head list)
    then dropWhile pred (builtins.tail list)
    else list;

  stripFrontmatter = text: let
    lines = lib.splitString "\n" text;
  in
    if lines != [] && builtins.head lines == "---"
    then let
      remainder = dropWhile (line: line != "---") (builtins.tail lines);
    in
      if remainder == []
      then text
      else lib.concatStringsSep "\n" (builtins.tail remainder)
    else text;

  yamlQuote = value: "'${lib.replaceStrings ["'"] ["''"] (toString value)}'";

  renderScalar = value:
    if builtins.isBool value
    then
      (
        if value
        then "true"
        else "false"
      )
    else if builtins.isInt value || builtins.isFloat value
    then toString value
    else yamlQuote value;

  indent = level: lib.concatStrings (builtins.genList (_: "  ") level);

  # A bare `*` key would parse as a YAML alias.
  renderKey = name:
    if builtins.match "[A-Za-z0-9_][A-Za-z0-9_./-]*" name != null
    then name
    else yamlQuote name;

  # The first field shares the dash's line, so a nested value stays nested.
  renderListItem = level: value:
    if lib.isAttrs value
    then let
      lines = renderAttrs (level + 1) value;
    in
      if lines == []
      then ["${indent level}- {}"]
      else ["${indent level}- ${lib.removePrefix (indent (level + 1)) (lib.head lines)}"] ++ lib.tail lines
    else if lib.isList value
    then ["${indent level}- ${renderScalar (lib.concatStringsSep ", " (map toString value))}"]
    else ["${indent level}- ${renderScalar value}"];

  renderField = level: name: value:
    if value == null
    then []
    else if lib.isList value
    then
      if value == []
      then []
      else ["${indent level}${renderKey name}:"] ++ lib.concatMap (item: renderListItem (level + 1) item) value
    else if lib.isAttrs value
    then
      if value == {}
      then []
      else ["${indent level}${renderKey name}:"] ++ renderAttrs (level + 1) value
    else ["${indent level}${renderKey name}: ${renderScalar value}"];

  renderAttrs = level: attrs:
    lib.concatMap (name: renderField level name attrs.${name}) (builtins.attrNames attrs);

  fromFile = input: let
    document = parseDocument input;
  in {
    inherit (document) body;
    attrs = parse document.desc document.frontmatter;
    typedAttrs = parseWith true document.desc document.frontmatter;
  };

  # `fromFile` reads a leading "/" as a path and throws, so a body opening with
  # a slash command needs this.
  fromText = text: let
    document = splitDocument "" text;
  in {
    inherit (document) body;
    attrs = parse "" document.frontmatter;
    typedAttrs = parseWith true "" document.frontmatter;
  };

  toFile = {
    attrs ? {},
    body ? "",
  }: let
    cleanBody = stripFrontmatter body;
    frontmatterLines = renderAttrs 0 attrs;
  in
    if frontmatterLines == []
    then cleanBody
    else lib.concatStringsSep "\n" (["---"] ++ frontmatterLines ++ ["---" "" cleanBody]);
in {
  inherit fromFile fromText normalizeStringList toFile;
}
