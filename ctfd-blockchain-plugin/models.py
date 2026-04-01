from CTFd.models import db, Challenges
from CTFd.plugins.challenges import BaseChallenge
from CTFd.utils.user import get_current_user
from flask import request
import requests
import os

# Function selector IDs (keccak256(signature)[:4])
USER_STATS_SELECTOR       = "e96842ec"
CURRENT_CONTRACT_SELECTOR = "892643c4"
PRICE_FOR_SLOT_SELECTOR   = "66dbbb7f"

# Bit 31 of user_stats: marks that the user has an active (unsolved) deployment
ACTIVE_SLOT_BIT = 2147483648 
SCORE_MASK      = 2147483647  

# Database model
# Extends the base Challenges table with blockchain-specific fields that we need
# vuln_id must be a power of 2 matching proxy.vuln_gen[vuln_id]:
#         1  = Reentrancy Easy
#         2  = Reentrancy Hard
#         4  = TBD
#         8  = TBD
class BlockchainChallengeModel(Challenges):
    __tablename__ = "blockchain_challenges"
    __mapper_args__ = {"polymorphic_identity": "blockchain"}

    id = db.Column(
        db.Integer,
        db.ForeignKey("challenges.id", ondelete="CASCADE"),
        primary_key=True,
    )

    vuln_id       = db.Column(db.Integer, nullable=False, default=1)
    proxy_address = db.Column(db.String(42), nullable=False, default="")
    chain_id      = db.Column(db.Integer, nullable=False, default=1337)
    rpc_url       = db.Column(db.String(256), nullable=True)
    source_code   = db.Column(db.Text, nullable=True, default="")
    abi           = db.Column(db.Text, nullable=True, default="[]")


# Local cache of stats from the chain, so when a user refreshes the site we don't have to make calls to the chain again.
class UserDeployment(db.Model):
    __tablename__ = "blockchain_deployments"

    id               = db.Column(db.Integer, primary_key=True, autoincrement=True)
    user_id          = db.Column(db.Integer, db.ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    challenge_id     = db.Column(db.Integer, db.ForeignKey("challenges.id", ondelete="CASCADE"), nullable=False)
    contract_address = db.Column(db.String(42), nullable=True)
    deployed_at      = db.Column(db.DateTime, default=db.func.now())
    solved           = db.Column(db.Boolean, default=False)
    paid_wei         = db.Column(db.String(32), default="0")

    __table_args__ = (
        db.UniqueConstraint("user_id", "challenge_id", name="uq_user_challenge"),
    )

# Custom CTFd challenge type: 'blockchain'
# Verification: reads proxy.user_stats(player) and checks the vuln_id bit.
# No flag strings, though we can't get rid of the field. Leaving it blank works for now
class BlockchainChallenge(BaseChallenge):
    id    = "blockchain"
    name  = "Blockchain"

    templates = {
        "create": "/plugins/ctfd-blockchain-plugin/assets/create.html",
        "update": "/plugins/ctfd-blockchain-plugin/assets/update.html",
        "view":   "/plugins/ctfd-blockchain-plugin/assets/view.html",
    }
    scripts = {
        "create": "/plugins/ctfd-blockchain-plugin/assets/create.js",
        "update": "/plugins/ctfd-blockchain-plugin/assets/update.js",
        "view":   "/plugins/ctfd-blockchain-plugin/assets/view.js",
    }

    @classmethod
    def create(cls, request):
        data = request.form or request.get_json()
        challenge = BlockchainChallengeModel(
            name          = data["name"],
            description   = data.get("description", ""),
            value         = int(data.get("value", 100)),
            category      = data.get("category", "Blockchain"),
            type          = "blockchain",
            state         = data.get("state", "visible"),
            vuln_id       = int(data.get("vuln_id", 1)),
            proxy_address = data.get("proxy_address", ""),
            chain_id      = int(data.get("chain_id", 1337)),
            rpc_url       = data.get("rpc_url", ""),
            source_code   = data.get("source_code", ""),
            abi           = data.get("abi", "[]"),
        )
        db.session.add(challenge)
        db.session.commit()
        return challenge

    @classmethod
    def read(cls, challenge):
        chall = BlockchainChallengeModel.query.filter_by(id=challenge.id).first()
        return {
            "id":            chall.id,
            "name":          chall.name,
            "value":         chall.value,
            "description":   chall.description,
            "category":      chall.category,
            "state":         chall.state,
            "type":          "blockchain",
            "vuln_id":       chall.vuln_id,
            "proxy_address": chall.proxy_address,
            "chain_id":      chall.chain_id,
            "rpc_url":       chall.rpc_url,
            "source_code":   chall.source_code,
            "abi":           chall.abi,
            "type_data": {
                "id":        cls.id,
                "name":      cls.name,
                "templates": cls.templates,
                "scripts":   cls.scripts,
            },
        }

    @classmethod
    def update(cls, challenge, request):
        data  = request.form or request.get_json()
        chall = BlockchainChallengeModel.query.filter_by(id=challenge.id).first()
        chall.name          = data.get("name",          chall.name)
        chall.description   = data.get("description",   chall.description)
        chall.value         = int(data.get("value",     chall.value))
        chall.category      = data.get("category",      chall.category)
        chall.state         = data.get("state",         chall.state)
        chall.vuln_id       = int(data.get("vuln_id",   chall.vuln_id))
        chall.proxy_address = data.get("proxy_address", chall.proxy_address)
        chall.chain_id      = int(data.get("chain_id",  chall.chain_id))
        chall.rpc_url       = data.get("rpc_url",       chall.rpc_url)
        chall.source_code   = data.get("source_code",   chall.source_code)
        chall.abi           = data.get("abi",           chall.abi)
        db.session.commit()
        return chall

    @classmethod
    def delete(cls, challenge):
        chall = BlockchainChallengeModel.query.filter_by(id=challenge.id).first()
        db.session.delete(chall)
        db.session.commit()

    # This is the CTF code for checking the flag value, I had changed the logic here a little to check the stats on chain
    # Players then submit their wallet address as the flag to get credit in CTFd. Technically the chain scoreboard does not need
    # a user to "submit" the challenge to function, but it integrates nicely. Plus, actually being able to submit is fun on CTFd
    @classmethod
    def attempt(cls, challenge, request):
        chall          = BlockchainChallengeModel.query.filter_by(id=challenge.id).first()
        data           = request.form or request.get_json()
        player_address = data.get("submission", "").strip()

        if not player_address.startswith("0x") or len(player_address) != 42:
            return False, "Submit your Ethereum wallet address (0x...)"

        completed = verify_on_chain(
            rpc_url        = _resolve_rpc(chall),
            proxy_address  = chall.proxy_address,
            player_address = player_address,
            vuln_id        = chall.vuln_id,
        )

        if completed:
            user = get_current_user()
            _upsert_deployment(user.id, chall.id, contract_address=player_address, solved=True)
            return True, "Exploit verified on-chain! Points awarded."
        return False, "Contract not yet exploited - keep trying!"

    @classmethod
    def solve(cls, user, team, challenge, request):
        from CTFd.models import Solves
        db.session.add(Solves(
            user_id      = user.id,
            team_id      = team.id if team else None,
            challenge_id = challenge.id,
            ip           = request.remote_addr,
            provided     = "on-chain-verified",
        ))
        db.session.commit()

    @classmethod
    def fail(cls, user, team, challenge, request):
        from CTFd.models import Fails
        data = request.form or request.get_json()
        db.session.add(Fails(
            user_id      = user.id,
            team_id      = team.id if team else None,
            challenge_id = challenge.id,
            ip           = request.remote_addr,
            provided     = data.get("submission", ""),
        ))
        db.session.commit()

# Raw JSON RPC right now, as web3 was scary
def _eth_call(rpc_url: str, to: str, data: str) -> str:
    payload = {
        "jsonrpc": "2.0",
        "method":  "eth_call",
        "params":  [{"to": to, "data": data}, "latest"],
        "id":      1,
    }
    resp = requests.post(rpc_url, json=payload, timeout=10)
    resp.raise_for_status()
    body = resp.json()
    if "error" in body:
        raise ValueError(f"JSON-RPC error: {body['error']}")
    return body.get("result", "0x")

# Reads proxy.user_stats(player) and checks whether the vuln_id bit is set.
# A challenge is complete when: (user_stats[player] & vuln_id) != 0
def verify_on_chain(rpc_url: str, proxy_address: str, player_address: str, vuln_id: int) -> bool:
    addr_padded = player_address[2:].lower().zfill(64)
    call_data   = "0x" + USER_STATS_SELECTOR + addr_padded
    try:
        result = _eth_call(rpc_url, proxy_address, call_data)
        return (int(result, 16) & vuln_id) != 0
    except Exception as e:
        print(f"[blockchain-plugin] verify_on_chain error: {e}")
        return False

# Returns decoded user_stats for the account status panel
def read_user_stats(rpc_url: str, proxy_address: str, player_address: str) -> dict:
    addr_padded = player_address[2:].lower().zfill(64)
    try:
        raw_stats = int(
            _eth_call(rpc_url, proxy_address, "0x" + USER_STATS_SELECTOR + addr_padded),
            16,
        )
        raw_cc = _eth_call(
            rpc_url, proxy_address, "0x" + CURRENT_CONTRACT_SELECTOR + addr_padded
        )
        current_contract = "0x" + raw_cc[-40:]

        completed_ids = [1 << bit for bit in range(31) if raw_stats & (1 << bit)]

        return {
            "raw":              raw_stats,
            "has_active_slot":  bool(raw_stats & ACTIVE_SLOT_BIT),
            "score":            raw_stats & SCORE_MASK,
            "completed_ids":    completed_ids,
            "current_contract": current_contract,
        }
    except Exception as e:
        print(f"[blockchain-plugin] read_user_stats error: {e}")
        return {"raw": 0, "has_active_slot": False, "score": 0,
                "completed_ids": [], "current_contract": None}

# Read proxy.price_for_slot()
def read_price_for_slot(rpc_url: str, proxy_address: str) -> int:
    try:
        return int(_eth_call(rpc_url, proxy_address, "0x" + PRICE_FOR_SLOT_SELECTOR), 16)
    except Exception as e:
        print(f"[blockchain-plugin] read_price_for_slot error: {e}")
        return 0

# Internal help functions
def _resolve_rpc(chall: BlockchainChallengeModel) -> str:
    url = chall.rpc_url or os.environ.get("BLOCKCHAIN_RPC_URL", "http://host.docker.internal:8545")
    # Ensure the URL always has a scheme, requests refuses bare host:port strings
    if url and not url.startswith("http://") and not url.startswith("https://"):
        url = "http://" + url
    return url

def _upsert_deployment(user_id: int, challenge_id: int,
                       contract_address=None, solved: bool = False,
                       paid_wei: str = "0"):
    row = UserDeployment.query.filter_by(
        user_id=user_id, challenge_id=challenge_id
    ).first()
    if row:
        if contract_address is not None:
            row.contract_address = contract_address
        row.solved     = solved
        row.paid_wei   = paid_wei
        row.deployed_at = db.func.now()
    else:
        row = UserDeployment(
            user_id=user_id, challenge_id=challenge_id,
            contract_address=contract_address, solved=solved, paid_wei=paid_wei,
        )
        db.session.add(row)
    db.session.commit()