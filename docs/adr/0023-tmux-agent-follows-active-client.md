# 23. tmux panes use the active client's SSH agent

Date: 2026-11-05

## Status

Accepted

## Context

A tmux pane can outlive the SSH connection whose forwarded agent socket it
inherited. New clients can attach with different agents, while existing panes
keep the old socket. A dead forwarded socket can still accept connections and
then stall signing.

This is a tmux lifecycle problem. Desktop applications and long-lived services
such as t3code do not belong to a tmux client, so routing them through the same
link would require guessing the user's presence or intent.

## Decision

Processes inside tmux use `~/.ssh/ssh_auth_sock`. tmux hooks aim that stable
link at the agent brought by the most recently active tmux client.

- Each client is recorded by its client name when it attaches.
- A client without an agent is recorded explicitly and refuses signing.
- The newest client's dead or stalled agent refuses signing rather than falling
  through to an older client's identity.
- Forwarded agents receive a bounded `ssh-add -l` health probe.
- Link updates are atomic and hook runs are serialized.
- Entries remain until tmux stops listing their client.

Processes outside tmux keep their normal agent discovery. Desktop state does
not participate in routing, and t3code is not wrapped with the tmux link.

## Consequences

- Existing panes survive SSH reconnects and follow the client currently using
  tmux.
- A sleeping or disconnected newest client fails visibly instead of signing
  with another client's keys.
- Client activity is still an approximation when several clients control the
  same tmux server simultaneously.
- With no attached client, the link can remain dead until another client
  attaches.
- Named tmux servers are independent views over one link and client map; using
  several concurrently is unsupported.

## Alternatives considered

### Route desktop applications and daemons through the same link

Rejected because those processes have no tmux origin. Lock state, idle state,
and tmux activity cannot reliably identify which agent a daemon request belongs
to.

### Fall back to an older usable agent

Rejected because availability does not establish identity. Falling back can
sign with keys the active client did not intend to use.

### Give every pane the raw socket from its creating connection

Rejected because panes and child processes outlive that connection. Rewriting
the tmux environment does not update already-running processes.
