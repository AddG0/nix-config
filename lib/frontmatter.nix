{lib}: let
  readInput = input:
    if lib.isPath input || lib.isDerivation input
    then builtins.readFile input
    else input;

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

  appendAttrList = attrs: key: value:
    attrs
    // {
      ${key} = (attrs.${key} or []) ++ [value];
    };

  parseDocument = input: let
    text = readInput input;
    lines = lib.splitString "\n" text;
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
      else {
        frontmatter = "";
        body = text;
      }
    else {
      frontmatter = "";
      body = text;
    };

  parse = text: let
    lines = lib.splitString "\n" text;
    step = state: line: let
      keyMatch = builtins.match ''([A-Za-z0-9_-]+):[[:space:]]*(.*)'' line;
      listMatch = builtins.match ''[[:space:]]*-[[:space:]]+(.*)'' line;
    in
      if keyMatch != null
      then let
        key = builtins.elemAt keyMatch 0;
        rawValue = builtins.elemAt keyMatch 1;
      in
        if rawValue == ""
        then {
          attrs = state.attrs // {${key} = state.attrs.${key} or [];};
          currentListKey = key;
        }
        else {
          attrs = state.attrs // {${key} = stripQuotes rawValue;};
          currentListKey = null;
        }
      else if listMatch != null && state.currentListKey != null
      then {
        attrs = appendAttrList state.attrs state.currentListKey (stripQuotes (builtins.elemAt listMatch 0));
        inherit (state) currentListKey;
      }
      else if line == ""
      then state
      else {
        inherit (state) attrs;
        currentListKey = null;
      };
  in
    (lib.foldl step {
        attrs = {};
        currentListKey = null;
      }
      lines).attrs;

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
  inherit fromFile toFile;
}
