"""
Flare FTSOv2 Anchor Price Service

Fetches finalized anchor prices from the Flare FTSOv2 smart contract.
Anchor prices are the on-chain median of all provider submissions,
updated once per voting epoch (~90 seconds).

Note: getFeedsById is marked payable on-chain by design. The fee is
currently 0 but is managed by FeeCalculator and may change. We call
with value=0 via call() — this is correct per Flare contract ABI.

Design constraints:
- No global state: all state is encapsulated in FlareAnchorService instances
- Fail fast on init: constructor raises on RPC failure, bad registry, zero address
- No silent degradation: fetch_prices() raises on error; callers decide on fallback
- ABI matches on-chain reality: getFeedsById is payable by design (not a mistake)
"""

import logging
from typing import Dict, List

from web3 import Web3

logger = logging.getLogger("ftso-monitor.anchor")

_REGISTRY_ABI = [
    {
        "inputs": [{"name": "_name", "type": "string"}],
        "name": "getContractAddressByName",
        "outputs": [{"name": "", "type": "address"}],
        "stateMutability": "view",
        "type": "function",
    }
]

# getFeedsById is payable by design — fee currently 0, managed by FeeCalculator.
# stateMutability intentionally matches on-chain ABI; do not change to "view".
_FTSO_ABI = [
    {
        "inputs": [],
        "name": "getSupportedFeedIds",
        "outputs": [{"name": "_feedIds", "type": "bytes21[]"}],
        "stateMutability": "view",
        "type": "function",
    },
    {
        "inputs": [{"name": "_feedIds", "type": "bytes21[]"}],
        "name": "getFeedsById",
        "outputs": [
            {"name": "_values", "type": "uint256[]"},
            {"name": "_decimals", "type": "int8[]"},
            {"name": "_timestamp", "type": "uint64"},
        ],
        "stateMutability": "payable",
        "type": "function",
    },
]

_ZERO_ADDRESS = "0x0000000000000000000000000000000000000000"


class FlareAnchorService:
    """
    Service for fetching finalized anchor prices from Flare FTSOv2.

    Lifecycle:
      - Construct once at startup via main()
      - Call fetch_prices() each poll cycle (runs synchronously; caller must
        offload to a thread executor to avoid blocking the async event loop)
      - Raises on initialisation failure — no silent degradation at startup

    fetch_prices() raises on RPC or contract error. The caller (poll_loop) is
    responsible for deciding fallback behaviour, which must be explicit and logged.
    """

    def __init__(self, rpc_url: str, registry_address: str, feed_names: List[str]) -> None:
        self._contract = self._resolve_contract(rpc_url, registry_address)
        # Filter configured feeds to only those supported on-chain.
        # getFeedsById reverts the entire call if any feed ID does not exist.
        self._feed_names, self._feed_ids = self._filter_supported_feeds(feed_names)

    @staticmethod
    def _encode_feed_id(name: str) -> bytes:
        """Encode feed name to 21-byte Flare feed ID: 0x01 + ASCII name, zero-padded."""
        return b'\x01' + name.encode('ascii').ljust(20, b'\x00')

    @staticmethod
    def _decode_feed_id(feed_id: bytes) -> str:
        """Decode a 21-byte Flare feed ID back to a feed name string."""
        return feed_id[1:].rstrip(b'\x00').decode('ascii', errors='ignore')

    def _resolve_contract(self, rpc_url: str, registry_address: str):
        """Resolve FtsoV2 contract address from on-chain registry. Raises on any failure."""
        w3 = Web3(Web3.HTTPProvider(rpc_url))
        if not w3.is_connected():
            raise ConnectionError(f"Cannot connect to Flare RPC at {rpc_url!r}")

        checksum_addr = Web3.to_checksum_address(registry_address)
        registry = w3.eth.contract(address=checksum_addr, abi=_REGISTRY_ABI)

        try:
            ftso_address = registry.functions.getContractAddressByName("FtsoV2").call()
        except Exception as exc:
            raise RuntimeError(f"ContractRegistry lookup failed: {exc}") from exc

        if ftso_address == _ZERO_ADDRESS:
            raise ValueError(
                "FtsoV2 returned zero address from ContractRegistry — "
                "verify FLARE_RPC_URL points to Flare mainnet"
            )

        logger.info("Flare FtsoV2 resolved at %s", ftso_address)
        return w3.eth.contract(address=ftso_address, abi=_FTSO_ABI)

    def _filter_supported_feeds(self, configured_names: List[str]):
        """
        Query getSupportedFeedIds() and intersect with our configured feed list.

        getFeedsById reverts the entire call if any feed ID is not registered
        on-chain. We must filter to only supported feeds before polling.
        Raises if the on-chain query itself fails.
        """
        try:
            on_chain_ids = self._contract.functions.getSupportedFeedIds().call()
        except Exception as exc:
            raise RuntimeError(f"getSupportedFeedIds failed: {exc}") from exc

        # Decode on-chain feed IDs to names for intersection
        on_chain_names = set()
        for feed_id in on_chain_ids:
            if isinstance(feed_id, bytes) and len(feed_id) == 21:
                name = self._decode_feed_id(feed_id)
                if name:
                    on_chain_names.add(name)

        supported = [n for n in configured_names if n in on_chain_names]
        skipped = [n for n in configured_names if n not in on_chain_names]

        if skipped:
            logger.warning(
                "Feeds not registered in FtsoV2 — will be skipped for anchor: %s",
                skipped,
            )
        logger.info(
            "Anchor feeds: %d configured, %d supported on-chain, %d skipped",
            len(configured_names), len(supported), len(skipped),
        )

        if not supported:
            raise ValueError(
                "No configured feeds are supported by FtsoV2 — "
                "check feed name encoding or RPC endpoint"
            )

        feed_ids = [self._encode_feed_id(name) for name in supported]
        return supported, feed_ids

    def fetch_prices(self) -> Dict[str, float]:
        """
        Fetch current anchor prices for all supported feeds.

        Returns only pairs with non-zero values — zero indicates stale/missing data.
        Raises on RPC or contract error — the caller (poll_loop) handles the fallback.

        This method is synchronous (blocking web3 HTTP call). Callers running an
        async event loop must offload via run_in_executor.
        """
        values, decimals, _ = self._contract.functions.getFeedsById(
            self._feed_ids
        ).call()

        prices: Dict[str, float] = {}
        for name, value, dec in zip(self._feed_names, values, decimals):
            if value > 0:
                token = name.split("/")[0]
                prices[token] = float(value) / (10 ** int(dec))
        return prices
