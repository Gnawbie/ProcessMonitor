# Security Policy

## Reporting a vulnerability

If you find a security issue in ProcessMonitor, please **do not** open a public issue.

Instead, use GitHub's private vulnerability reporting:
👉 [Report a vulnerability](https://github.com/Gnawbie/ProcessMonitor/security/advisories/new)

I'll acknowledge the report within a few days and work on a fix. Once resolved, the vulnerability and fix will be publicly disclosed.

## What counts as a security issue

- The monitor script executing unintended code
- Log files capturing or exposing sensitive data they shouldn't
- The PID file or settings file being writable in a way that allows privilege escalation
- Any way a malicious process name or exit code could cause unintended behaviour

## What doesn't count

- The monitor requires PowerShell execution policy to be set — this is by design and expected
- The log folder being readable by other local users — logs contain process names and exit codes only, no personal data
- General Windows security issues unrelated to this tool

## Supported versions

Only the latest version on `master` is actively maintained.
