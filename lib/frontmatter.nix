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

  stripQuotes = value:
    if lib.hasPrefix "\"" value && lib.hasSuffix "\"" value
    then lib.removeSuffix "\"" (lib.removePrefix "\"" value)
    else if lib.hasPrefix "'" value && lib.hasSuffix "'" value
    then lib.removeSuffix "'" (lib.removePrefix "'" value)
    else value;

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
    in
      map (item: stripQuotes (lib.strings.trim item)) (lib.splitString "," unwrapped);

  parseDocument = input: let
    text = readInput input;
    lines = lib.splitString "\n" text;
    inputDesc =
      if lib.isPath input || lib.isDerivation input
      then " in ${toString input}"
      else if lib.isString input && lib.hasPrefix "/" input
      then " in ${input}"
      else "";
  in
    if lines != [] && builtins.head lines == "---"
    then let
      split = takeUntil (line: line == "---") (builtins.tail lines);
    in
      if split.found
      then {
        frontmatter = lib.concatStringsSep "\n" split.before;
        body = lib.concatStringsSep "\n" split.after;
      }
      else throw "frontmatter.parseDocument: opened with '---' but no closing '---' fence found${inputDesc}"
    else {
      frontmatter = "";
      body = text;
    };

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

  parse = text: let
    lines = lib.splitString "\n" text;
    step = state: line: let
      indentMatch = builtins.match ''([[:space:]]*)(.*)'' line;
      indent =
        if indentMatch == null
        then 0
        else lib.stringLength (builtins.elemAt indentMatch 0);
      content =
        if indentMatch == null
        then line
        else builtins.elemAt indentMatch 1;
      keyMatch = builtins.match ''([A-Za-z0-9_-]+):[[:space:]]*(.*)'' content;
      listMatch = builtins.match ''-[[:space:]]+(.*)'' content;
      setPending = key: value:
        state
        // {
          attrs = state.attrs // {${key} = value;};
          pending = key;
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
      appendNested = list:
        state
        // {
          attrs = state.attrs // {${state.pending} = list;};
        };
    in
      if state.blockScalar != null
      then
        if content == ""
        then
          state
          // {
            blockScalar = state.blockScalar // {lines = state.blockScalar.lines ++ [""];};
          }
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
        else if indent < state.blockScalar.indent
        then step (flushBlockScalar state) line
        else
          state
          // {
            blockScalar = state.blockScalar // {lines = state.blockScalar.lines ++ [line];};
          }
      else if content == ""
      then state
      else if indent == 0
      then
        if keyMatch != null
        then let
          key = builtins.elemAt keyMatch 0;
          rawValue = builtins.elemAt keyMatch 1;
          trimmedValue = lib.strings.trim rawValue;
        in
          if rawValue == ""
          then setPending key null
          else if trimmedValue == ">" || trimmedValue == "|"
          then enterBlock key trimmedValue
          else if builtins.match ''[>|][-+0-9].*'' trimmedValue != null
          then throw "frontmatter.parse: YAML chomping/indent indicators in '${key}: ${trimmedValue}' are not supported; use plain '>' or '|', or inline the value"
          else setScalar key (stripQuotes rawValue)
        else state // {pending = null;}
      else if state.pending == null
      then state
      else if listMatch != null
      then let
        existing = state.attrs.${state.pending};
        existingList =
          if lib.isList existing
          then existing
          else [];
      in
        appendNested (existingList ++ [(stripQuotes (builtins.elemAt listMatch 0))])
      else if keyMatch != null
      then let
        nestedKey = builtins.elemAt keyMatch 0;
        rawValue = builtins.elemAt keyMatch 1;
        existing = state.attrs.${state.pending};
        existingMap =
          if lib.isAttrs existing
          then existing
          else {};
      in
        appendNested (existingMap // {${nestedKey} = stripQuotes rawValue;})
      else state;

    finalState =
      lib.foldl step {
        attrs = {};
        pending = null;
        blockScalar = null;
      }
      lines;
  in
    (flushBlockScalar finalState).attrs;

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

  renderListItem = level: value:
    if lib.isAttrs value
    then let
      names = builtins.attrNames value;
      first = builtins.head names;
      rest = builtins.tail names;
    in
      ["${indent level}- ${first}: ${renderValueInline value.${first}}"]
      ++ lib.concatMap (name: renderField (level + 1) name value.${name}) rest
    else if lib.isList value
    then ["${indent level}- ${renderScalar (lib.concatStringsSep ", " (map toString value))}"]
    else ["${indent level}- ${renderScalar value}"];

  renderValueInline = value:
    if lib.isAttrs value || lib.isList value
    then yamlQuote (builtins.toJSON value)
    else renderScalar value;

  renderField = level: name: value:
    if value == null
    then []
    else if lib.isList value
    then
      if value == []
      then []
      else ["${indent level}${name}:"] ++ lib.concatMap (item: renderListItem (level + 1) item) value
    else if lib.isAttrs value
    then
      if value == {}
      then []
      else ["${indent level}${name}:"] ++ renderAttrs (level + 1) value
    else ["${indent level}${name}: ${renderScalar value}"];

  renderAttrs = level: attrs:
    lib.concatMap (name: renderField level name attrs.${name}) (builtins.attrNames attrs);

  fromFile = input: let
    document = parseDocument input;
  in {
    inherit (document) body;
    attrs = parse document.frontmatter;
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
  inherit fromFile normalizeStringList toFile;
}
