# AI Integration

## Integration Scope
Provides operator UI for Hermes host workflows; relies on remote canonical state.

## Operational Notes
- Use OpenAI-compatible endpoint abstractions when possible.
- Keep secrets in environment/config, not in repository source.
- Validate model endpoint health before enabling automated workflows.

## Risks
SSH auth/path misconfiguration can cause false-negative host readiness signals.
