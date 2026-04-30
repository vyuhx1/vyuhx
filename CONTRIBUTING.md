# Contributing to VyuhX

Thank you for your interest in contributing. VyuhX is a Salesforce CG Cloud + Agentforce + Data Cloud project — contributions should follow Salesforce platform conventions.

---

## Before You Start

- Read [TECHNICAL_DESIGN.md](./TECHNICAL_DESIGN.md) to understand the architecture
- Make sure you have a Salesforce scratch org or sandbox with CG Cloud and Agentforce enabled
- Salesforce CLI (`sf` v2+) must be installed and authenticated

---

## What You Can Contribute

- Bug fixes in Apex actions, LWC components, or flows
- New Agentforce actions following the existing `Request / Result / @InvocableMethod` pattern
- LWC improvements to the expansion dashboard or visit card components
- Additional Lightning Type renderers
- Test class coverage (Apex unit tests)
- Documentation improvements

---

## Development Setup

```bash
# Clone the repo
git clone https://github.com/your-org/vyuhx.git
cd vyuhx

# Authenticate to your org
sf org login web --alias vyuhx-dev

# Deploy source
sf project deploy start --source-dir force-app --target-org vyuhx-dev
```

---

## Contribution Guidelines

### Apex

- Follow the `without sharing` pattern for all Agentforce action classes
- All agent actions must use the `Request` / `Result` inner class pattern with `@InvocableVariable`
- Query logic must live in a service implementation class, not directly inside the action
- Never hardcode API keys, org IDs, or credentials — use Custom Metadata
- All SOQL inputs from external sources must use bind variables (`:variable`), not string concatenation

### LWC

- Agentforce renderer components must declare `<target>lightning__AgentforceOutput</target>` in `js-meta.xml`
- Maps URLs must be built client-side from `latitude` / `longitude` fields — no server roundtrip
- Use `NavigationMixin` for all record navigation links
- Keep manager-facing and surveyor-facing card variants separate (`visitCard` vs `myVisitCard`)

### Flows

- AutoLaunched flows that update Visit records must use `SystemModeWithoutSharing`
- Add a decision node guard before any field that could be null-overwritten on a second call

### General

- One feature or fix per pull request
- Keep PRs focused — do not mix unrelated changes
- Test your changes in a scratch org before submitting

---

## Pull Request Process

1. Fork the repository and create a branch: `git checkout -b feature/your-feature-name`
2. Make your changes
3. Deploy and test in a scratch org
4. Submit a pull request with a clear description of what changed and why
5. Link any related issues in the PR description

---

## Reporting Issues

Use the GitHub Issue templates:
- **Bug Report** — for defects in Apex, LWC, flows, or metadata
- **Feature Request** — for new Agentforce actions, dashboard enhancements, or capability ideas

---

## Code of Conduct

Be respectful and constructive. This is a collaborative project — all contributors are expected to maintain a professional and inclusive environment.
