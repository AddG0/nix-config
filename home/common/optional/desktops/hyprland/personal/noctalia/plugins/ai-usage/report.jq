# Builds the AI Usage report from Prometheus instant-query responses ($usage, $resets, $status,
# $overUsed, $overLimit, $available, $modelUsage, $modelResets), per provider and account.

def results($r): $r.data.result // [];
def num: .value[1] | tonumber;
def key($m): [$m.provider, $m.account, ($m.limit // ""), ($m.model // "")] | join("|");
def byKey($r): reduce results($r)[] as $x ({}; .[key($x.metric)] = ($x | num));
def byAccount($r): reduce results($r)[] as $x ({}; .[$x.metric.provider + "|" + $x.metric.account] = ($x | num));
def providerName: {claude: "Claude", codex: "Codex"}[.] // ((.[0:1] | ascii_upcase) + .[1:]);
def providerOrder: {claude: 0, codex: 1}[.] // 9;
# Window length of a limit label like "30m", "5h", "7d", "2w"; null for others ("overage").
def windowSeconds:
  capture("^(?<n>[0-9]+)(?<u>[mhdw])$")? // null
  | if . == null then null else (.n | tonumber) * {m: 60, h: 3600, d: 86400, w: 604800}[.u] end;

byKey($resets) as $resetAt
| byKey($modelResets) as $modelResetAt
| (reduce (results($status)[] | select(num == 1)) as $s ({}; .[key($s.metric)] = $s.metric.status)) as $statusOf
| byAccount($overUsed) as $overUsedOf
| byAccount($overLimit) as $overLimitOf
| byAccount($available) as $availableOf
| [results($usage)[] | .metric as $m | ($m.limit | windowSeconds) as $seconds | select($seconds != null) | {
    provider: $m.provider,
    account: $m.account,
    label: $m.limit,
    seconds: $seconds,
    percent: (num * 100),
    resetAt: $resetAt[key($m)],
    status: $statusOf[key($m)]
  }] as $limits
| [results($modelUsage)[] | .metric as $m | {
    provider: $m.provider,
    account: $m.account,
    model: $m.model,
    label: $m.limit,
    percent: (num * 100),
    resetAt: $modelResetAt[key($m)]
  }] as $models
| ($limits | group_by(.provider) | map(.[0].provider as $p | {
    id: $p,
    name: ($p | providerName),
    accounts: (group_by(.account) | map(.[0].account as $a | ($p + "|" + $a) as $pa | {
      account: $a,
      available: (($availableOf[$pa] // 1) == 1),
      limits: (sort_by(.seconds) | map({label, seconds, percent, resetAt, status})),
      overage: (if $overUsedOf[$pa] == null then null else {
        used: $overUsedOf[$pa],
        limit: ($overLimitOf[$pa] // 0),
        status: $statusOf[$pa + "|overage|"]
      } end),
      models: [$models[] | select(.provider == $p and .account == $a) | {model, label, percent, resetAt}]
    }))
  }) | sort_by(.id | providerOrder)) as $providers
| {fetchedAt: now, providers: $providers}
