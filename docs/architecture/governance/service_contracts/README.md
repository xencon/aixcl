# AIXCL Service Contracts

Service contracts describe **what a service is allowed to do** and its **dependency rules**.

Purpose:
- Preserve boundaries
- Reduce blast radius
- Enable agentic safe modification
- Make service intent explicit

---

## Contract Scope

- Name
- Category (runtime | bld)
- Purpose
- Depends On
- Exposes
- Must Not Depend On
- Notes

---

## Enforcement

- Runtime: strict
- Ops: guiding
- Violations require explicit maintainer approval
