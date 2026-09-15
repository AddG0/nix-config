# A remote pointing at an ssh alias (`git@gitlab-work:owner/repo`, resolved by
# ~/.ssh/config) carries a host only ssh knows, so no provider is detected and the
# repository identity matches no change-request link — pasting one in chat leaves
# an ordinary link with no way to link it to the thread. `ssh -G` answers with the
# hostname ssh itself would dial. Drop once t3code resolves aliases.
#
# Two sites read the host: RepositoryIdentityResolver for change-request links,
# GitVcsDriver.listRemotes for the provider registry, which otherwise settles on
# the `unknown` provider and fails every MR lookup.
#
# Patched in `unwrapped`: see README.md.
_: _final: prev: let
  inherit (prev.lib) escapeShellArg;

  hostCanonicalizerAnchor = "const resolveRepositoryIdentityFromCacheKey = Effect.fn(";
  hostCanonicalizerPatch = builtins.concatStringsSep "\n" [
    "/** `ssh -G` prints one lowercased `key value` line per resolved option. */"
    "const SSH_RESOLVED_HOSTNAME = /^hostname (\\S+)$/mu;"
    "const SCP_STYLE_REMOTE = /^([a-zA-Z0-9._-]+@)([^:/\\s]+)(:[^/\\s]+(?:\\/[^/\\s]+)+)$/u;"
    ""
    "/**"
    " * The hostname behind a remote's ssh alias, or the remote untouched. Git resolves the alias"
    " * at transport time and leaves it in `.git/config`, so every identity derived from the"
    " * remote inherits a host no provider recognises."
    " */"
    "const canonicalizeRemoteHost = Effect.fn(\"RepositoryIdentityResolver.canonicalizeRemoteHost\")("
    "  function* ("
    "    remoteUrl: string,"
    "  ): Effect.fn.Return<string, never, ProcessRunner.ProcessRunner> {"
    "    const trimmed = remoteUrl.trim();"
    "    const scp = SCP_STYLE_REMOTE.exec(trimmed);"
    "    let url: URL | null = null;"
    "    if (scp === null) {"
    "      try {"
    "        const parsed = new URL(trimmed);"
    "        if (parsed.protocol === \"ssh:\") url = parsed;"
    "      } catch {"
    "        return remoteUrl;"
    "      }"
    "    }"
    "    const alias = scp?.[2] ?? url?.hostname;"
    "    if (alias === undefined || alias.length === 0) return remoteUrl;"
    ""
    "    const processRunner = yield* ProcessRunner.ProcessRunner;"
    "    const result = yield* processRunner"
    "      .run({ command: \"ssh\", args: [\"-G\", alias], timeoutBehavior: \"timedOutResult\" })"
    "      .pipe(Effect.option);"
    "    // No ssh, no answer, or an alias that resolves to itself: the remote stands as written."
    "    if (result._tag === \"None\" || result.value.code !== 0) return remoteUrl;"
    "    const hostname = SSH_RESOLVED_HOSTNAME.exec(result.value.stdout)?.[1];"
    "    if (hostname === undefined || hostname.toLowerCase() === alias.toLowerCase()) {"
    "      return remoteUrl;"
    "    }"
    "    if (scp !== null) return `\${scp[1]}\${hostname}\${scp[3]}`;"
    "    if (url === null) return remoteUrl;"
    "    url.hostname = hostname;"
    "    return url.toString();"
    "  },"
    ");"
    ""
    hostCanonicalizerAnchor
  ];

  identityRemoteAnchor = builtins.concatStringsSep "\n" [
    "  const remote = pickPrimaryRemote(parseRemoteFetchUrls(remoteResult.value.stdout));"
    "  return remote ? buildRepositoryIdentity({ ...remote, rootPath: cacheKey }) : null;"
  ];
  identityRemotePatch = builtins.concatStringsSep "\n" [
    "  const remote = pickPrimaryRemote(parseRemoteFetchUrls(remoteResult.value.stdout));"
    "  if (remote === null) return null;"
    "  const remoteUrl = yield* canonicalizeRemoteHost(remote.remoteUrl);"
    "  return buildRepositoryIdentity({ ...remote, remoteUrl, rootPath: cacheKey });"
  ];

  driverImportAnchor = "import * as NodeCrypto from \"node:crypto\";";
  driverImportPatch = builtins.concatStringsSep "\n" [
    "import * as NodeChildProcess from \"node:child_process\";"
    driverImportAnchor
  ];

  driverHelperAnchor = "export interface ExecuteGitInput {";
  driverHelperPatch = builtins.concatStringsSep "\n" [
    "/** `ssh -G` prints one lowercased `key value` line per resolved option. */"
    "const SSH_RESOLVED_HOSTNAME = /^hostname (\\S+)$/mu;"
    "const SCP_STYLE_REMOTE = /^([a-zA-Z0-9._-]+@)([^:/\\s]+)(:[^/\\s]+(?:\\/[^/\\s]+)+)$/u;"
    "const sshAliasHosts = new Map<string, string>();"
    ""
    "/** The hostname behind a remote's ssh alias, or the remote untouched. */"
    "function canonicalizeRemoteAliasHost(remoteUrl: string): string {"
    "  const trimmed = remoteUrl.trim();"
    "  const scp = SCP_STYLE_REMOTE.exec(trimmed);"
    "  let url: URL | null = null;"
    "  if (scp === null) {"
    "    try {"
    "      const parsed = new URL(trimmed);"
    "      if (parsed.protocol === \"ssh:\") url = parsed;"
    "    } catch {"
    "      return remoteUrl;"
    "    }"
    "  }"
    "  const alias = scp?.[2] ?? url?.hostname;"
    "  if (alias === undefined || alias.length === 0) return remoteUrl;"
    ""
    "  let hostname = sshAliasHosts.get(alias);"
    "  if (hostname === undefined) {"
    "    try {"
    "      const output = NodeChildProcess.execFileSync(\"ssh\", [\"-G\", alias], {"
    "        encoding: \"utf8\","
    "        timeout: 2000,"
    "        // `ssh -G` warns about the missing tty on stderr."
    "        stdio: [\"ignore\", \"pipe\", \"ignore\"],"
    "      });"
    "      hostname = SSH_RESOLVED_HOSTNAME.exec(output)?.[1] ?? alias;"
    "    } catch {"
    "      // No ssh, or an unresolvable alias: the remote stands as written."
    "      hostname = alias;"
    "    }"
    "    sshAliasHosts.set(alias, hostname);"
    "  }"
    "  if (hostname.toLowerCase() === alias.toLowerCase()) return remoteUrl;"
    ""
    "  if (scp !== null) return `\${scp[1]}\${hostname}\${scp[3]}`;"
    "  if (url === null) return remoteUrl;"
    "  url.hostname = hostname;"
    "  return url.toString();"
    "}"
    ""
    driverHelperAnchor
  ];

  driverRemoteAnchor = builtins.concatStringsSep "\n" [
    "            url: remote.url,"
    "            pushUrl: remote.pushUrl ? Option.some(remote.pushUrl) : Option.none(),"
  ];
  driverRemotePatch = builtins.concatStringsSep "\n" [
    "            url: canonicalizeRemoteAliasHost(remote.url),"
    "            pushUrl: remote.pushUrl"
    "              ? Option.some(canonicalizeRemoteAliasHost(remote.pushUrl))"
    "              : Option.none(),"
  ];
in {
  t3code = prev.t3code.override {
    t3code-unwrapped = prev.t3code.unwrapped.overrideAttrs (old: {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace apps/server/src/project/RepositoryIdentityResolver.ts \
            --replace-fail ${escapeShellArg hostCanonicalizerAnchor} ${escapeShellArg hostCanonicalizerPatch} \
            --replace-fail ${escapeShellArg identityRemoteAnchor} ${escapeShellArg identityRemotePatch}
          substituteInPlace apps/server/src/vcs/GitVcsDriver.ts \
            --replace-fail ${escapeShellArg driverImportAnchor} ${escapeShellArg driverImportPatch} \
            --replace-fail ${escapeShellArg driverHelperAnchor} ${escapeShellArg driverHelperPatch} \
            --replace-fail ${escapeShellArg driverRemoteAnchor} ${escapeShellArg driverRemotePatch}
        '';
    });
    # Pinned to avoid a Rust rebuild for an identical binary.
    t3code-resource-monitor = prev.t3code.resourceMonitor;
  };
}
