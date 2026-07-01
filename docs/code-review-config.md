# Code review config

Per-project knobs for the portable review skills: the whole-repo `full-code-review`
(`~/.claude/skills/full-code-review`) and the PR-scoped `adversarial-pr-review`
(`~/.claude/skills/adversarial-pr-review`). Both load their repo-specific tailoring from this file.

## Project identity & stack

- **What it is:** HomeLab — Ansible/lab automation for standing up an RKE2 (Rancher Kubernetes
  Engine 2) homelab cluster, plus assorted lab setup helpers.
- **Primary contents:** an Ansible project under `rke2-homelab-ansible/` (playbooks, roles, group_vars,
  inventory, Jinja2 config templates) and a set of top-level bootstrap/setup shell scripts
  (`setup-*.sh`, `COMPLETE-SETUP.sh`, `apply-fixes.sh`) that scaffold roles and drive the deploy.
  A `dns_update/` playbook handles resolver updates.
- **Stack / scale:** Ansible (~32 YAML files), Bash (~11 `.sh` helpers), Jinja2 (~8 `.j2` templates).
  No application code, no Python package, no compiled artifacts.
- **Targets:** Debian/apt-based Linux nodes reached over SSH; deploys RKE2 masters/workers with
  Cilium, Longhorn/storage, Traefik ingress, cert-manager, and test apps.

## Applicability

- **Lint/CI baseline:** `.pre-commit-config.yaml` runs `ansible-lint` (profile `min`,
  see `rke2-homelab-ansible/.ansible-lint`) and `yamllint` (`rke2-homelab-ansible/.yamllint`)
  on the Ansible tree. There is **no** `.github/workflows` CI and there are **no** unit tests.
- **Reviews should focus on** what those linters do NOT catch: task logic and idempotency,
  wrong/misused module arguments, privilege-escalation and secrets handling, host-exposure choices,
  destructive operations, and shell-script correctness for the setup helpers.
- Treat anything ansible-lint / yamllint / shellcheck already flags as out of scope (see below).

## PR review (`adversarial-pr-review` skill)

Knobs for the PR-scoped, adversarial proposer→challenger review (`~/.claude/skills/adversarial-pr-review`). Reviews a single PR's diff and posts one consolidated comment; complements the whole-repo `full-code-review`.

- **Confidence threshold:** 80.
- **Challengers per finding:** 1 (use `--thorough` for a 3-challenger median on high-stakes PRs).
- **Lenses that apply:**
  - `bug:` — task logic, idempotency, wrong/misused module args (e.g. `command`/`shell` where a
    module exists, missing `changed_when`/`creates`), template correctness; **and** shell-script
    correctness for the `setup-*.sh` / `COMPLETE-SETUP.sh` / `apply-fixes.sh` helpers.
  - `claude-md:` — repo-convention compliance (Ansible coding standards, FQCN module names,
    role/task layout, no embedded secrets in vars, YAML sorted by operational intent).
  - `sec/data:` — `become`/privilege escalation, secrets in vars or templates, host exposure
    (ingress/listen addresses, firewall/sysctl, exposed ports), destructive plays.
  - `history:` — git-blame / prior-PR-comment regressions; reverting a fix or re-introducing a
    previously corrected non-idempotent or destructive step.
  - `test:` — **PARTIAL.** No unit-test suite exists and none is expected. Only flag when a change
    should have been accompanied by (or breaks) `ansible-lint` / `ansible-playbook --syntax-check`
    coverage, or removes an existing guard/check. Do not demand new test frameworks.
- **Priority paths for diff context:**
  - `rke2-homelab-ansible/playbooks/*.yml` (01-prepare-nodes, 02-install-rke2, 03-install-addons)
  - `rke2-homelab-ansible/roles/*/tasks/*.yml`
  - `rke2-homelab-ansible/roles/*/templates/*.j2` and other `*.j2` config templates
  - `rke2-homelab-ansible/group_vars/*.yml`, `rke2-homelab-ansible/inventory/hosts.yml`
  - top-level `setup-*.sh`, `COMPLETE-SETUP.sh`, `apply-fixes.sh` helper scripts
  - `dns_update/*.yml`, `dns_update/*.j2`
- **Post on no findings:** false.
- **Out of scope for challengers (score low):** anything ansible-lint / yamllint / shellcheck already
  catches (FQCN nits, trailing whitespace, line length, unquoted-in-YAML style, `SC****` shell lints);
  pre-existing issues not introduced by the diff; lines the PR did not modify.
- **What "real, in-scope" looks like here:**
  - A non-idempotent task — e.g. a `command`/`shell` step with no `creates`/`changed_when` that
    re-runs and mutates state on every play.
  - A hardcoded secret (token, kubeconfig, cluster join token, password) committed in `group_vars`,
    a task, or a `.j2` template instead of being sourced from Vault / a protected var.
  - A destructive play without a guard — e.g. `swapoff`, disk/partition wipe, `rm -rf`, or a node
    reset that runs unconditionally instead of behind a `when:` / confirmation.
  - An unquoted or unguarded variable in a helper script — e.g. `rm -rf $DIR` or `cd $x` without
    quoting or a `set -euo pipefail` guard, where an empty/unset var causes damage.
