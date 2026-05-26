"""
Optional asynchronous PostgreSQL storage for FTSO monitor price snapshots.

Creates a dedicated `ftso` database automatically on startup, then writes
every poll cycle to `ftso_prices`. Degrades gracefully to no-op if
PostgreSQL is unreachable or misconfigured.

Schema (auto-created):
    CREATE TABLE IF NOT EXISTS ftso_prices (
        ts TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        pair TEXT NOT NULL,
        source TEXT NOT NULL,         -- 'provider', 'coingecko', 'binance', 'anchor'
        price DOUBLE PRECISION,
        deviation_pct DOUBLE PRECISION,
        in_band BOOLEAN,
        PRIMARY KEY (ts, pair, source)
    );
    CREATE INDEX idx_ftso_prices_ts ON ftso_prices(ts);
    CREATE INDEX idx_ftso_prices_pair ON ftso_prices(pair, ts DESC);

    CREATE TABLE IF NOT EXISTS ftso_sources (
        ts TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        pair TEXT NOT NULL,
        exchange TEXT NOT NULL,
        symbol TEXT,
        raw_price DOUBLE PRECISION,
        weight DOUBLE PRECISION,
        staleness_ms DOUBLE PRECISION,
        voting_round BIGINT,
        PRIMARY KEY (ts, pair, exchange)
    );
    CREATE INDEX idx_ftso_sources_ts ON ftso_sources(ts);
    CREATE INDEX idx_ftso_sources_pair ON ftso_sources(pair, ts DESC);

Connection: uses asyncpg + DATABASE_URL or individual PG* vars.
"""

import asyncio
import logging
import os
from typing import Dict, List, Optional

logger = logging.getLogger("ftso-monitor.db")

# Config
DATABASE_URL = os.getenv("DATABASE_URL")
PGHOST = os.getenv("PGHOST", os.getenv("POSTGRES_HOST", ""))
PGUSER = os.getenv("PGUSER", os.getenv("POSTGRES_USER", "admin"))
PGPASSWORD = os.getenv("PGPASSWORD", os.getenv("POSTGRES_PASSWORD", ""))
PGPORT = int(os.getenv("PGPORT", os.getenv("POSTGRES_PORT", "5432")))
# Dedicated FTSO database name (default 'ftso').
# If you want to share the 'webui' database instead, set FTSO_DATABASE=webui.
FTSO_DATABASE = os.getenv("FTSO_DATABASE", "ftso")

# If PGPASSWORD is not in env, read from Docker secret mounted by compose.
# AIXCL Vault mounts as 'postgres-password' (dash); try dash first, then underscore fallback.
if not PGPASSWORD:
    for _secret_path in (
        os.getenv("PGPASSWORD_FILE", ""),
        "/run/secrets/postgres-password",
        "/run/secrets/postgres_password",
    ):
        if not _secret_path:
            continue
        try:
            with open(_secret_path, "r") as f:
                PGPASSWORD = f.read().strip()
            if PGPASSWORD:
                logger.debug("Read PostgreSQL password from %s", _secret_path)
                break
        except Exception:
            continue

# Lazy singleton pool
try:
    import asyncpg  # type: ignore
    _POOL: Optional[object] = None
    _HAS_ASYNC = True
except ImportError:
    asyncpg = None  # type: ignore
    _POOL = None
    _HAS_ASYNC = False


def _make_dsn(database: str) -> str:
    if DATABASE_URL:
        return DATABASE_URL
    return f"postgresql://{PGUSER}:{PGPASSWORD}@{PGHOST}:{PGPORT}/{database}"


def _safe_log_dsn(dsn: str) -> str:
    """Return DSN with password redacted for logging."""
    return dsn.replace(PGPASSWORD, "***") if PGPASSWORD else dsn


async def _get_pool(database: str = FTSO_DATABASE):
    global _POOL
    if _POOL is not None:
        return _POOL
    dsn = _make_dsn(database)
    logger.info("Connecting to PostgreSQL at %s", _safe_log_dsn(dsn).split("@")[-1])
    _POOL = await asyncpg.create_pool(dsn=dsn, min_size=1, max_size=2)
    return _POOL


async def _ensure_database() -> bool:
    """Create the dedicated FTSO database if it does not exist.

    Connects to the 'postgres' maintenance database using bootstrap credentials,
    checks for existence, and creates it. This is safe to run repeatedly.
    """
    if not _HAS_ASYNC or not PGHOST:
        return False
    if not PGUSER or not PGPASSWORD:
        logger.warning("Missing PostgreSQL credentials -- cannot create database")
        return False

    try:
        dsn = _make_dsn("postgres")
        conn = await asyncpg.connect(dsn=dsn)
        try:
            # Check if database already exists
            row = await conn.fetchrow(
                "SELECT 1 FROM pg_database WHERE datname = $1", FTSO_DATABASE
            )
            if row:
                logger.debug("Database '%s' already exists", FTSO_DATABASE)
                return True

            logger.info("Creating dedicated FTSO database '%s'", FTSO_DATABASE)
            # asyncpg's connection.execute does not support CREATE DATABASE
            # because it's a transaction-bound statement. Use a raw connection.
            await conn.execute(f'CREATE DATABASE "{FTSO_DATABASE}"')
            logger.info("Database '%s' created", FTSO_DATABASE)
            return True
        finally:
            await conn.close()
    except Exception as exc:
        logger.error("Failed to create database '%s': %s", FTSO_DATABASE, exc)
        return False


async def ensure_schema() -> bool:
    """Create tables in the dedicated FTSO database. Returns True if usable."""
    if not _HAS_ASYNC or not PGHOST:
        return False

    # Step 1: ensure the database itself exists
    if not await _ensure_database():
        return False

    # Step 2: connect to the dedicated database and create schema
    try:
        pool = await _get_pool(FTSO_DATABASE)
        async with pool.acquire() as conn:  # type: ignore
            await conn.execute(
                """
                CREATE TABLE IF NOT EXISTS ftso_prices (
                    ts TIMESTAMPTZ NOT NULL DEFAULT NOW(),
                    pair TEXT NOT NULL,
                    source TEXT NOT NULL,
                    price DOUBLE PRECISION,
                    deviation_pct DOUBLE PRECISION,
                    in_band BOOLEAN,
                    PRIMARY KEY (ts, pair, source)
                );
                CREATE INDEX IF NOT EXISTS idx_ftso_prices_ts ON ftso_prices(ts);
                CREATE INDEX IF NOT EXISTS idx_ftso_prices_pair ON ftso_prices(pair, ts DESC);

                CREATE TABLE IF NOT EXISTS ftso_sources (
                    id BIGSERIAL PRIMARY KEY,
                    ts TIMESTAMPTZ NOT NULL DEFAULT NOW(),
                    pair TEXT NOT NULL,
                    exchange TEXT NOT NULL,
                    symbol TEXT,
                    raw_price DOUBLE PRECISION,
                    weight DOUBLE PRECISION,
                    staleness_ms DOUBLE PRECISION,
                    voting_round BIGINT
                );
                CREATE INDEX IF NOT EXISTS idx_ftso_sources_ts ON ftso_sources(ts);
                CREATE INDEX IF NOT EXISTS idx_ftso_sources_pair ON ftso_sources(pair, ts DESC);
                """
            )
        logger.info("PostgreSQL schema ensured in database '%s'", FTSO_DATABASE)
        return True
    except Exception as exc:
        logger.warning("PostgreSQL schema init failed: %s", exc)
        return False


async def store_snapshot(
    provider: Dict[str, float],
    references: Dict[str, Dict[str, float]],
    deviations: Dict[str, Dict[str, float]],
    in_band: Dict[str, Dict[str, bool]],
) -> None:
    """Write one poll cycle to PostgreSQL."""
    if not _HAS_ASYNC or not PGHOST:
        return
    try:
        pool = await _get_pool(FTSO_DATABASE)
        rows = []
        for pair, price in provider.items():
            if price is None:
                continue
            rows.append((pair, "provider", float(price), None, None))
            for src, prices in references.items():
                token = pair.split("/")[0]
                if token not in prices or prices[token] is None:
                    continue
                dev = deviations.get(pair, {}).get(src)
                band = in_band.get(pair, {}).get(src)
                rows.append((
                    pair,
                    src,
                    float(prices[token]),
                    float(dev) if dev is not None else None,
                    bool(band) if band is not None else None,
                ))
        if not rows:
            return
        async with pool.acquire() as conn:  # type: ignore
            await conn.copy_records_to_table(
                "ftso_prices",
                records=rows,
                columns=["pair", "source", "price", "deviation_pct", "in_band"],
            )
    except Exception as exc:
        logger.warning("PostgreSQL store_snapshot failed: %s", exc)


async def store_source_details(
    details: Dict[str, List[Dict]],
    voting_round: int,
) -> None:
    """Write per-source transparency data to ftso_sources."""
    if not _HAS_ASYNC or not PGHOST:
        return
    try:
        pool = await _get_pool(FTSO_DATABASE)
        rows = []
        for pair, sources in details.items():
            for src in sources:
                rows.append((
                    pair,
                    src.get("exchange", ""),
                    src.get("symbol", ""),
                    float(src["rawPrice"]) if src.get("rawPrice") is not None else None,
                    float(src["weight"]) if src.get("weight") is not None else None,
                    float(src["stalenessMs"]) if src.get("stalenessMs") is not None else None,
                    int(voting_round) if voting_round is not None else None,
                ))
        if not rows:
            return
        async with pool.acquire() as conn:  # type: ignore
            await conn.copy_records_to_table(
                "ftso_sources",
                records=rows,
                columns=["pair", "exchange", "symbol", "raw_price", "weight", "staleness_ms", "voting_round"],
            )
    except Exception as exc:
        logger.warning("PostgreSQL store_source_details failed: %s", exc)


async def close() -> None:
    global _POOL
    if _POOL is not None:
        await _POOL.close()
        _POOL = None
