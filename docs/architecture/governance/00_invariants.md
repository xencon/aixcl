# AIXCL Platform Invariants

This document defines the **non-negotiable invariants** of the AIXCL platform.

These invariants exist to:
- Preserve architectural intent
- Protect the core runtime from accidental erosion
- Enable safe collaboration by humans and AI assistants
- Provide a stable foundation as the platform evolves

Breaking an invariant requires an **explicit architectural decision** by the project maintainer.

---

## 1. What AIXCL Is

AIXCL is an **opinionated AI development platform and distribution**.

It is:
- A curated composition of upstream open-source projects
- Focused on providing a cohesive local and single-node AI development experience

It is **not**:
- A general-purpose LLM framework
- A pluggable inference abstraction layer
- A sandbox for experimenting with arbitrary AI runtimes

Do **not** attempt to generalize or abstract the runtime core.

---

## 2. Fixed Core Runtime (Strict)

The following components **always** form the AIXCL runtime core:

- **Ollama** - LLM inference engine (Docker-managed service)
- **Council** - Multi-model orchestration (Docker-managed service)
- **Continue** - AI-powered code assistance (VS Code plugin, not Docker-managed)

These components are:
- Always enabled
- Always present in every profile
- Never optional

> **Note:** Continue is a client-side VS Code plugin that connects to Council via the OpenAI-compatible API. It is not managed by Docker Compose and therefore does not appear in the `RUNTIME_CORE_SERVICES` array or profile service mappings. The Docker-managed runtime core services are Ollama and Council.

Any change that removes, replaces, or conditionally disables these components is considered **architecturally breaking**.

---

## 3. Runtime vs Operational Services Boundary (Strict)

AIXCL services are divided into two categories:

### Runtime Core
- Required for AIXCL to function as a product
- Defines “what AIXCL is”

### Operational Services
- Support, observe, or operate the runtime
- Do **not** define the product itself

**Invariants:**
- Runtime core must be runnable **without** any operational services
- Operational services may depend on runtime core
- Runtime core must **never** depend on operational services (monitoring, logging, UI, automation)

**Runtime persistence:** The runtime may use persistence (e.g. for conversation storage) implemented via a shared database. That does not violate the boundary: the prohibition is on depending on operational *capabilities* (observability, UI, automation), not on using the same persistence technology or instance when persistence is a documented runtime requirement.

---

## 4. Profiles (Strict Guarantees, Flexible Composition)

Profiles define **which operational services are enabled**.

**Invariants:**
- Profiles may add services
- Profiles may not remove or disable runtime core
- All profiles must include the full runtime core

---

## 5. Upstream Projects and Ownership

AIXCL does **not** own the internal implementation of upstream projects.

AIXCL is responsible for:
- Selection
- Configuration
- Composition
- Lifecycle coordination

AIXCL is **not** responsible for:
- Feature development inside upstream projects
- Internal architectural changes upstream

Integration logic must assume upstream change and minimize blast radius.

---

## 6. CLI Responsibility Boundary

The AIXCL CLI is a **control plane**, not a decision engine.

**Invariants:**
- CLI executes declared intent
- CLI does not encode architectural policy
- CLI does not contain service-specific business logic
- CLI must not infer behavior beyond explicit configuration

---

## 7. Evolution and Enforcement

These invariants are:
- **Strict for the runtime core**
- **Guiding for operational services**, with the intent to become stricter over time

---

## 8. AI Assistant Guidance (Normative)

AI assistants interacting with this repository must:

- Preserve all invariants in this document
- Treat runtime core components as non-refactorable unless explicitly instructed
- Avoid introducing new dependencies from runtime → operations
- Prefer declarative configuration over imperative logic
