"""
Optional asynchronous PostgreSQL storage for FTSO monitor price snapshots.

If PGHOST is set (either via env or AIXCL defaults), every poll cycle writes
provider + reference prices to `ftso_prices`. Otherwise the store is a no-op.

Schema (run once):
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

Connection: uses asyncpg + DATABASE_URL or individual PG* vars.
"""

import asyncio
import logging
import os
from typing import Dict, Optional

logger = logging.getLogger("ftso-monitor.db")

# Config
DATABASE_URL = os.getenv("DATABASE_URL")
PGHOST = os.getenv("PGHOST", os.getenv("POSTGRES_HOST", ""))
PGUSER = os.getenv("PGUSER", os.getenv("POSTGRES_USER", "admin"))
PGPASSWORD = os.getenv("PGPASSWORD", os.getenv("POSTGRES_PASSWORD", ""))
PGDATABASE = os.getenv("PGDATABASE", os.getenv("POSTGRES_DATABASE", "webui"))
PGPORT = int(os.getenv("PGPORT", os.getenv("POSTGRES_PORT", "5432")))

# Lazy singleton pool
try:
    import asyncpg  # type: ignore
    _POOL: Optional[object] = None
    _HAS_ASYNC = True
except ImportError:
    asyncpg = None  # type: ignore
    _POOL = None
    _HAS_ASYNC = False


def _make_dsn() -> str:
    if DATABASE_URL:
        return DATABASE_URL
    return f"postgresql://{PGUSER}:{PGPASSWORD}@{PGHOST}:{PGPORT}/{PGDATABASE}"


async def _get_pool():
    global _POOL
    if _POOL is not None:
        return _POOL
    dsn = _make_dsn()
    # Avoid leaking password into logs
    safe_dsn = dsn.replace(PGPASSWORD, "***") if PGPASSWORD else dsn
    logger.info("Connecting to PostgreSQL at %s", safe_dsn.split("@")[-1])
    _POOL = await asyncpg.create_pool(dsn=dsn, min_size=1, max_size=2)
    return _POOL


async def ensure_schema() -> bool:
    """Create tables. Returns True if DB is usable."""
    if not _HAS_ASYNC or not PGHOST:
        return False
    try:
        pool = await _get_pool()
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
                """
            )
        logger.info("PostgreSQL schema ensured")
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
        pool = await _get_pool()
        rows = []
        for pair in provider:
            rows.append((pair, "provider", float(provider[pair]), None, None))
            for src, prices in references.items():
                token = pair.split("/")[0]
                if token in prices:
                    dev = deviations.get(pair, {}).get(src)
                    band = in_band.get(pair, {}).get(src)
                    rows.append((
                        pair,
                        src,
                        float(prices[token]),
                        float(dev) if dev is not None else None,
                        bool(band) if band is not None else None,
                    ))
        async with pool.acquire() as conn:  # type: ignore
            await conn.copy_records_to_table(
                "ftso_prices",
                records=rows,
                columns=["pair", "source", "price", "deviation_pct", "in_band"],
            )
    except Exception as exc:
        logger.warning("PostgreSQL store_snapshot failed: %s", exc)


async def close() -> None:
    global _POOL
    if _POOL is not None:
        await _POOL.close()
        _POOL = None
