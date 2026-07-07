# SwiftStash

Read @AGENTS.md — it contains the full agent guide:

- **Why this instead of `@AppStorage`** — seven practical limitations, with no persisted-data migration for compatible values (read this first; it's the reason the package exists)
- API decision table (which wrapper/initializer for which type) and use-case mapping
- The fourteen pitfalls that silently bite (keychain service config, dotted keys vs. observation, accessibility defaults, …)
- **Adoption playbook** for migrating an existing app from `@AppStorage` / raw `UserDefaults` / keychain code
- Build & test commands and repo conventions for contributing

`README.md` is the human-facing overview; DocC lives in `Sources/SwiftStash/SwiftStash.docc/`.
