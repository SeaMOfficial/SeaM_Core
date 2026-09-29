# SeaM_Core v1.0.0

SeaM's modular FiveM framework core with a Svelte-powered pirate interface for notifications, progress actions, and interaction prompts.

## Interface

- Notifications use ink-black dispatch cards with parchment text and aged-brass detailing.
- Progress actions use the same SeaM design and continue to show `X` when cancellation is allowed.
- Interaction prompts only appear when they contain real text. Empty prompt calls are discarded, preventing a standalone `E` from becoming stuck at the bottom of the screen.
- The idle NUI is transparent, hidden, and has no mounted interface elements.
- The production Svelte UI is contained in `html/index.html`; no external browser assets are needed.

## Rebuilding the UI

The compiled UI is included. To rebuild after editing `ui/src`:

```bash
cd ui
npm install
npm run build
```

## Existing client exports

```lua
exports.SeaM_Core:Notify(message, kind, duration, title)
exports.SeaM_Core:ClearNotifications()
exports.SeaM_Core:ShowTextUI(text, owner, key)
exports.SeaM_Core:HideTextUI(owner)
exports.SeaM_Core:IsProgressActive()
```

Existing point registrations, notification events, and progress events remain compatible.

## Notes for resource authors

- Hooks registered from another resource (through `GetCoreObject().Hooks.register` or `exports.SeaM_Core:registerHook`) receive a copy of the context. They can veto by returning `false, reason`, but edits they make to the context never reach the core.
- FiveM has no server-side `SetEntityHealth`. From a server script, use `TriggerClientEvent('SeaM_Core:admin:heal', target)` or `TriggerClientEvent('SeaM_Core:admin:kill', target)` instead.
