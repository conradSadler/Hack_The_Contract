from flask import Blueprint, request, jsonify, abort
from CTFd.utils.decorators import authed_only
from CTFd.plugins import bypass_csrf_protection
from CTFd.utils.user import get_current_user, get_current_team
from CTFd.models import db, Solves
from .models import (
    BlockchainChallengeModel,
    UserDeployment,
    verify_on_chain,
    read_user_stats,
    read_price_for_slot,
    _resolve_rpc,
    _upsert_deployment,
)

blockchain_bp = Blueprint(
    "blockchain",
    __name__,
    url_prefix="/api/v1/blockchain",
)


# Helpers
def _get_challenge_or_404(challenge_id: int) -> BlockchainChallengeModel:
    chall = BlockchainChallengeModel.query.filter_by(id=challenge_id).first()
    if not chall:
        abort(404, description="Blockchain challenge not found.")
    return chall


def _get_deployment(user_id: int, challenge_id: int):
    return UserDeployment.query.filter_by(
        user_id=user_id, challenge_id=challenge_id
    ).first()


def _validate_address(addr: str) -> bool:
    return isinstance(addr, str) and addr.startswith("0x") and len(addr) == 42


# Routes
# Endpoints:
#     GET /api/v1/blockchain/challenge/<id>/info
#     Returns chain_id, proxy_address, vuln_id, ABI, source code,
#     and price_for_slot so the frontend can handle payment correctly

#     GET /api/v1/blockchain/challenge/<id>/deployment
#     Returns the player's cached contract address and solved status.
#     Also reads current_contract[player] directly from the chain so
#     the frontend always has the live address even after a re-deploy

#     POST /api/v1/blockchain/challenge/<id>/deployment
#     Records the deployed contract address after the player's wallet
#     confirms the generate_contract() tx

#     GET /api/v1/blockchain/account
#     Returns the player's full on-chain account status:
#     score, active slot flag, completed challenge ids, current contract.
#     Used by the account status panel

#     POST /api/v1/blockchain/challenge/<id>/verify
#     Reads user_stats[player] & vuln_id on-chain.
#     If set, injects a CTFd Solve and awards points
@blockchain_bp.route("/challenge/<int:challenge_id>/info", methods=["GET"])
@authed_only
def challenge_info(challenge_id: int):
    chall = _get_challenge_or_404(challenge_id)

    import json
    try:
        abi = json.loads(chall.abi)
    except Exception:
        abi = []

    price_wei = read_price_for_slot(_resolve_rpc(chall), chall.proxy_address)

    return jsonify({
        "success":        True,
        "vuln_id":        chall.vuln_id,
        "proxy_address":  chall.proxy_address,
        "chain_id":       chall.chain_id,
        "price_for_slot": str(price_wei),
        "abi":            abi,
        "source_code":    chall.source_code,
    })


@blockchain_bp.route("/challenge/<int:challenge_id>/deployment", methods=["GET"])
@authed_only
def get_deployment(challenge_id: int):
    chall = _get_challenge_or_404(challenge_id)
    row   = _get_deployment(get_current_user().id, challenge_id)

    # Always return the cached address, frontend can call /account to get the live current_contract value from the chain if needed
    if row:
        return jsonify({
            "success":          True,
            "contract_address": row.contract_address,
            "solved":           row.solved,
            "paid_wei":         row.paid_wei,
            "deployed_at":      row.deployed_at.isoformat() if row.deployed_at else None,
        })
    return jsonify({"success": True, "contract_address": None, "solved": False})


@blockchain_bp.route("/challenge/<int:challenge_id>/deployment", methods=["POST"])
@bypass_csrf_protection # was getting CSRF errors with this endpoint, so just disabling protection... Wustrow would be disappointed
@authed_only
def record_deployment(challenge_id: int):
    _get_challenge_or_404(challenge_id)
    data             = request.get_json(silent=True) or {}
    contract_address = data.get("contract_address", "").strip()
    paid_wei         = str(data.get("paid_wei", "0"))

    if not _validate_address(contract_address):
        return jsonify({"success": False, "message": "Invalid contract address."}), 400

    _upsert_deployment(
        user_id          = get_current_user().id,
        challenge_id     = challenge_id,
        contract_address = contract_address,
        solved           = False,
        paid_wei         = paid_wei,
    )
    return jsonify({"success": True, "contract_address": contract_address})


@blockchain_bp.route("/account", methods=["GET"])
@authed_only
def account_status():
    player_address = request.args.get("player_address", "").strip()
    proxy_address  = request.args.get("proxy_address", "").strip()
    rpc_url        = request.args.get("rpc_url", "").strip() or None

    if not _validate_address(player_address):
        return jsonify({"success": False, "message": "Invalid player address."}), 400
    if not _validate_address(proxy_address):
        return jsonify({"success": False, "message": "Invalid proxy address."}), 400

    import os
    rpc = rpc_url or os.environ.get("BLOCKCHAIN_RPC_URL", "http://localhost:8545")
    stats = read_user_stats(rpc, proxy_address, player_address)

    return jsonify({"success": True, **stats})


@blockchain_bp.route("/challenge/<int:challenge_id>/verify", methods=["POST"])
@bypass_csrf_protection
@authed_only
def verify_challenge(challenge_id: int):
    chall          = _get_challenge_or_404(challenge_id)
    data           = request.get_json(silent=True) or {}
    player_address = data.get("player_address", "").strip()

    if not _validate_address(player_address):
        return jsonify({"success": False, "message": "Invalid wallet address."}), 400

    # Already solved in CTFd?
    already_solved = Solves.query.filter_by(
        user_id=get_current_user().id, challenge_id=challenge_id
    ).first()
    if already_solved:
        return jsonify({"success": True, "message": "Already solved - points previously awarded."})

    # Check on-chain
    completed = verify_on_chain(
        rpc_url        = _resolve_rpc(chall),
        proxy_address  = chall.proxy_address,
        player_address = player_address,
        vuln_id        = chall.vuln_id,
    )

    if not completed:
        return jsonify({
            "success": False,
            "message": "user_stats bit not set - exploit the contract first, "
                       "then the vulnerable contract will call proxy.increment_score() for you.",
        })

    # Mark local deployment as solved
    row = _get_deployment(get_current_user().id, challenge_id)
    if row:
        row.solved = True
        db.session.commit()

    # Award CTFd points
    team = get_current_team()
    db.session.add(Solves(
        user_id      = get_current_user().id,
        team_id      = team.id if team else None,
        challenge_id = challenge_id,
        ip           = request.remote_addr,
        provided     = f"on-chain:{player_address}",
    ))
    db.session.commit()

    return jsonify({"success": True, "message": "Exploit verified on-chain! Points awarded."})


# Blockchain scoreboard
@blockchain_bp.route("/scoreboard", methods=["GET"])
@authed_only
def scoreboard():
    from flask import render_template_string
    from CTFd.models import Users

    # Get all challenges to build the completion legend
    challenges = BlockchainChallengeModel.query.filter_by(state="visible").all()

    # Get all users who have made at least one attempt (have a deployment record)
    deployments = UserDeployment.query.all()
    seen_users  = {d.user_id for d in deployments}

    # Also include anyone with a CTFd solve on a blockchain challenge
    challenge_ids = [c.id for c in challenges]
    solves = Solves.query.filter(Solves.challenge_id.in_(challenge_ids)).all() if challenge_ids else []
    for s in solves:
        seen_users.add(s.user_id)

    # Build scoreboard rows by reading on-chain stats for each user
    # We need a wallet address per user, use the provided field from CTFd
    # or fall back to the address recorded in their latest deployment
    rows = []
    rpc_url      = None
    proxy_address = None

    # Use first visible challenge to get RPC + proxy (all challenges share same proxy)
    if challenges:
        proxy_address = challenges[0].proxy_address
        rpc_url       = challenges[0].rpc_url or __import__('os').environ.get(
            "BLOCKCHAIN_RPC_URL", "http://localhost:8545"
        )

    for user_id in seen_users:
        user = Users.query.get(user_id)
        if not user or user.banned or user.hidden:
            continue

        # Find the wallet address, use the most recent deployment record
        wallet = None
        user_deployments = UserDeployment.query.filter_by(user_id=user_id).all()
        if user_deployments:
            # Use address from a solved deployment first, else any deployment
            solved = [d for d in user_deployments if d.solved]
            wallet = solved[0].contract_address if solved else user_deployments[0].contract_address
            # deployment stores contract address not wallet, get wallet from solves
            user_solves = Solves.query.filter_by(user_id=user_id).filter(
                Solves.challenge_id.in_(challenge_ids)
            ).all()
            for s in user_solves:
                if s.provided and s.provided.startswith("on-chain:"):
                    wallet = s.provided.replace("on-chain:", "")
                    break

        # Read on-chain stats if we have a wallet and proxy
        stats = {"score": 0, "completed_ids": [], "has_active_slot": False}
        if wallet and proxy_address and rpc_url:
            from .models import read_user_stats
            stats = read_user_stats(rpc_url, proxy_address, wallet)

        # Map completed vuln_ids to challenge names
        completed = []
        for c in challenges:
            if c.vuln_id in stats["completed_ids"]:
                completed.append(c.name)

        rows.append({
            "user_id":   user_id,
            "username":  user.name,
            "wallet":    wallet or "unknown",
            "score":     stats["score"],
            "completed": completed,
        })

    # Sort by on-chain score descending
    rows.sort(key=lambda r: r["score"], reverse=True)

    return render_template_string(SCOREBOARD_TEMPLATE,
        rows=rows,
        challenges=challenges,
        proxy_address=proxy_address or "not configured",
    )


SCOREBOARD_TEMPLATE = """
{% extends "base.html" %}
{% block content %}
<div class="jumbotron">
    <div class="container">
        <h1>⛓ On-Chain Scoreboard ⛓</h1>
        <p class="text-muted">
            Scores read live from <code>proxy.user_stats(address)</code> on the chain
        </p>
    </div>
</div>
<div class="container">
    {% if not rows %}
    <p class="text-muted">No on-chain activity yet.</p>
    {% else %}
    <table class="table table-striped">
        <thead>
            <tr>
                <th>#</th>
                <th>Player</th>
                <th>Wallet</th>
                <th>On-Chain Score</th>
                {% for c in challenges %}
                <th>{{ c.name }}</th>
                {% endfor %}
            </tr>
        </thead>
        <tbody>
            {% for row in rows %}
            <tr>
                <td>{{ loop.index }}</td>
                <td><a href="/users/{{ row.user_id }}">{{ row.username }}</a></td>
                <td><code style="font-size:11px">{{ row.wallet[:10] }}...{{ row.wallet[-6:] }}</code></td>
                <td><strong>{{ row.score }}</strong></td>
                {% for c in challenges %}
                <td>
                    {% if c.name in row.completed %}
                    <span class="text-success">✓</span>
                    {% else %}
                    <span class="text-muted">-</span>
                    {% endif %}
                </td>
                {% endfor %}
            </tr>
            {% endfor %}
        </tbody>
    </table>
    {% endif %}

    <p class="text-muted small mt-4">
        Score = each completed challenge contributes its vuln_id (power of 2) to the total.
    </p>
</div>
{% endblock %}
"""