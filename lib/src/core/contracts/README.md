# Backend Contracts

Version-one input-contract parsers and strict JSON utilities are implemented here.
They preserve backend field/options/upload/evidence metadata immutably and reject
unsupported versions/types. Session snapshots live in features/session. Sanitized
backend-derived fixtures are under test/fixtures; native HTTP lives in core/network.
