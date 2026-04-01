CTFd._internal.challenge.data = undefined;
CTFd._internal.challenge.preRender = function() {};
CTFd._internal.challenge.postRender = function() {};

// CTFd calls this when the player clicks Submit.
// The submission is the player's wallet address, passed to attempt() on the backend.
CTFd._internal.challenge.submit = function(preview) {
    var challenge_id = parseInt(CTFd.lib.$("#challenge-id").val());
    var submission   = CTFd.lib.$("#challenge-input").val();
    var body         = { challenge_id: challenge_id, submission: submission };
    var params       = {};
    if (preview) { params["preview"] = true; }
    return CTFd.api.post_challenge_attempt(params, body).then(function(response) {
        return response;
    });
};

// Inject blockchain UI for our plugin into the challenge modal that CTFd uses
(function () {
    "use strict";

    const UI_HTML = `
<div id="blockchain-challenge-container" style="margin-bottom:16px;">

    <div id="bc-network-bar" class="bc-status-bar bc-status-disconnected mb-3">
        <span id="bc-network-label">Wallet not connected</span>
    </div>

    <ul class="nav nav-tabs" id="bc-tabs">
        <li class="nav-item"><a class="nav-link active" data-bs-toggle="tab" href="#bc-tab-exploit">Exploit</a></li>
        <li class="nav-item"><a class="nav-link" data-bs-toggle="tab" href="#bc-tab-source">Source Code</a></li>
        <li class="nav-item"><a class="nav-link" data-bs-toggle="tab" href="#bc-tab-account">Account</a></li>
    </ul>

    <div class="tab-content mt-3 mb-3">

        <div class="tab-pane fade show active" id="bc-tab-exploit">
            <div class="bc-step-card">
                <h6>Step 1 - Connect Wallet</h6>
                <p class="text-muted small">MetaMask or any EIP-1193 provider.</p>
                <button id="bc-connect-btn" class="btn btn-outline-primary btn-sm">Connect Wallet</button>
                <code id="bc-wallet-address" class="d-block mt-2 text-muted small"></code>
            </div>
            <div class="bc-step-card">
                <h6>Step 2 - Deploy Your Instance</h6>
                <p class="text-muted small">
                    Calls <code>proxy.generate_contract(vuln_id)</code>.
                    First deployment is free. A second costs <code>price_for_slot</code> wei.
                </p>
                <p id="bc-price-hint" class="text-warning small" style="display:none"></p>
                <button id="bc-deploy-btn" class="btn btn-outline-warning btn-sm" disabled>Deploy Contract</button>
                <div id="bc-deploy-status" class="mt-2 small"></div>
                <div id="bc-contract-address-wrap" style="display:none" class="mt-2">
                    <span class="text-muted small">Your instance: </span>
                    <code id="bc-contract-address" class="small"></code>
                    <a id="bc-explorer-link" href="#" target="_blank" class="small ml-2">View on Explorer ↗</a>
                </div>
            </div>
            <div class="bc-step-card">
                <h6>Step 3 - Exploit &amp; Verify</h6>
                <p class="text-muted small">
                    Exploit your instance. The contract calls
                    <code>proxy.increment_score(vuln_id, player)</code> on completion.
                    Your wallet address will be filled in automatically - just click Submit.
                </p>
                <button id="bc-verify-btn" class="btn btn-outline-success btn-sm" disabled>
                    Check On-Chain Status
                </button>
                <div id="bc-verify-status" class="mt-2 small"></div>
            </div>
        </div>

        <div class="tab-pane fade" id="bc-tab-source">
            <p class="text-muted small">Study the contract - the vulnerability is intentional.</p>
            <pre id="bc-source-block"
                 style="max-height:420px;overflow-y:auto;background:#1e1e2e;
                        color:#cdd6f4;border-radius:6px;padding:16px;
                        font-size:12px;white-space:pre-wrap;word-break:break-word;">Loading…</pre>
        </div>

        <div class="tab-pane fade" id="bc-tab-account">
            <p class="text-muted small">Live data from <code>proxy.user_stats(address)</code>. Connect wallet to load.</p>
            <table class="table table-sm">
                <tbody>
                    <tr><td class="text-muted">On-chain score</td><td><strong id="bc-score">-</strong></td></tr>
                    <tr><td class="text-muted">Deployment slot</td><td><span id="bc-slot-status">-</span></td></tr>
                </tbody>
            </table>
        </div>

    </div>

    <style>
    .bc-status-bar { display:flex; align-items:center; gap:8px; padding:6px 12px; border-radius:4px; font-size:13px; font-weight:500; }
    .bc-status-disconnected { background:#2d1b1b; color:#f38ba8; }
    .bc-status-connected    { background:#1b2d1b; color:#a6e3a1; }
    .bc-status-wrong-chain  { background:#2d2b1b; color:#f9e2af; }
    .bc-step-card { border:1px solid rgba(255,255,255,0.08); border-radius:6px; padding:16px; margin-bottom:12px; background:rgba(255,255,255,0.02); }
    .bc-step-card h6 { margin-bottom:6px; font-weight:600; }
    </style>
</div>`;

    // Inject UI and re-inject every time the modal reopens otherwise it breaks without a refresh :D
    function inject() {
        const input = document.getElementById("challenge-input");
        if (!input) return false;

        // Already injected into this exact modal instance - skip
        if (document.getElementById("blockchain-challenge-container")) return true;

        const modalBody = input.closest(".modal-body") || input.closest(".card-body") || input.parentElement;
        if (!modalBody) return false;

        modalBody.insertAdjacentHTML("afterbegin", UI_HTML);
        input.placeholder = "0x... (auto-filled on wallet connect)";

        // Reset all state so a fresh open starts clean
        deployedAddress = null;
        walletAddress   = null;
        signer          = null;
        provider        = null;

        init();
        return true;
    }

    // Watch for modal open/close and re-inject every time.
    // CTFd tears down and rebuilds the modal body on each open.
    const _observer = new MutationObserver(() => {
        // challenge-input appearing means a modal just opened
        if (document.getElementById("challenge-input") &&
            !document.getElementById("blockchain-challenge-container")) {
            inject();
        }
    });
    _observer.observe(document.body, { childList: true, subtree: true });

    // Also try immediately in case the script loads after the modal is already open
    inject();

    // All state
    let VULN_ID = null, PROXY_ADDRESS = null, CHAIN_ID = null, PRICE_WEI = BigInt(0), CONTRACT_ABI = [], CHALLENGE_ID = null;
    let provider = null, signer = null, walletAddress = null, deployedAddress = null;

    const PROXY_ABI = [
        // generate_contract is no longer payable - payment goes through reset() instead
        { inputs:[{name:"id",type:"uint256"}], name:"generate_contract", outputs:[{name:"",type:"address"}], stateMutability:"nonpayable", type:"function" },
        // reset() clears the active slot bit - must be called before re-deploying
        { inputs:[], name:"reset", outputs:[{name:"",type:"bool"}], stateMutability:"payable", type:"function" },
        { inputs:[{name:"",type:"address"}],   name:"user_stats",        outputs:[{name:"",type:"uint256"}], stateMutability:"view", type:"function" },
        { inputs:[{name:"",type:"address"}],   name:"current_contract",  outputs:[{name:"",type:"address"}], stateMutability:"view", type:"function" },
        { inputs:[],                           name:"price_for_slot",    outputs:[{name:"",type:"uint128"}], stateMutability:"view", type:"function" },
    ];
    const ACTIVE_SLOT_BIT = BigInt("2147483648");
    const EXPLORERS = { 1:"https://etherscan.io", 11155111:"https://sepolia.etherscan.io" };

    // Init - runs after UI is injected
    async function init() {
        // Get challenge id from the hidden CTFd input
        CHALLENGE_ID = document.getElementById("challenge-id")?.value;
        if (!CHALLENGE_ID) return;

        await loadChallengeInfo();
        await loadExistingDeployment();
        bindButtons();
    }

 // Load challenge info
    async function loadChallengeInfo() {
        try {
            const res  = await fetch(`/api/v1/blockchain/challenge/${CHALLENGE_ID}/info`);
            const data = await res.json();
            if (!data.success) return;
            VULN_ID       = data.vuln_id;
            PROXY_ADDRESS = data.proxy_address;
            CHAIN_ID      = data.chain_id;
            PRICE_WEI     = BigInt(data.price_for_slot);
            CONTRACT_ABI  = data.abi;
            const pre = document.getElementById("bc-source-block");
            if (pre) pre.textContent = data.source_code || "// Source not available.";
            if (PRICE_WEI > 0n) {
                const hint = document.getElementById("bc-price-hint");
                if (hint) { hint.textContent = `Re-deploy costs ${PRICE_WEI} wei`; hint.style.display = "block"; }
            }
        } catch (e) { console.error("[bc]", e); }
    }

    // In the case that the user already has a deployment
    async function loadExistingDeployment() {
        try {
            const res  = await fetch(`/api/v1/blockchain/challenge/${CHALLENGE_ID}/deployment`);
            const data = await res.json();
            if (data.success && data.contract_address) {
                deployedAddress = data.contract_address;
                showDeployedAddress(deployedAddress);
                document.getElementById("bc-verify-btn").disabled = false;
                if (data.solved) setVerifyStatus("success", "Already solved!");
            }
        } catch (e) { console.error("[bc]", e); }
    }

    function bindButtons() {
        document.getElementById("bc-connect-btn")?.addEventListener("click", connectWallet);
        document.getElementById("bc-deploy-btn")?.addEventListener("click",  deployInstance);
        document.getElementById("bc-verify-btn")?.addEventListener("click",  verifyExploit);
    }

    // Connect wallet 
    async function connectWallet() {
        if (!window.ethereum) { alert("No wallet detected. Install MetaMask."); return; }
        try {
            provider      = new ethers.BrowserProvider(window.ethereum);
            await provider.send("eth_requestAccounts", []);
            signer        = await provider.getSigner();
            walletAddress = await signer.getAddress();
            const net     = await provider.getNetwork();
            if (Number(net.chainId) !== CHAIN_ID) {
                setNetworkBar("wrong", `Wrong network - need chain ID ${CHAIN_ID}`);
                try {
                    await window.ethereum.request({ method:"wallet_switchEthereumChain", params:[{ chainId:"0x"+CHAIN_ID.toString(16) }] });
                    await connectWallet();
                } catch { alert(`Switch wallet to chain ID ${CHAIN_ID}`); }
                return;
            }
            setNetworkBar("connected", `${shortAddr(walletAddress)} · Chain ${CHAIN_ID}`);
            document.getElementById("bc-wallet-address").textContent = walletAddress;

            // Auto-fill CTFd submit field with wallet address
            const input = document.getElementById("challenge-input");
            if (input) input.value = walletAddress;

            document.getElementById("bc-deploy-btn").disabled = false;
            if (deployedAddress) document.getElementById("bc-verify-btn").disabled = false;
            await refreshAccountStatus();
        } catch (e) { setNetworkBar("disconnected", "Connection rejected."); }
    }

    // Account status
    async function refreshAccountStatus() {
        if (!walletAddress || !PROXY_ADDRESS) return;
        try {
            const proxy    = new ethers.Contract(PROXY_ADDRESS, PROXY_ABI, provider);
            const rawStats = await proxy.user_stats(walletAddress);
            const hasSlot  = (rawStats & ACTIVE_SLOT_BIT) !== 0n;
            document.getElementById("bc-score").textContent      = (rawStats & BigInt("2147483647")).toString();
            document.getElementById("bc-slot-status").textContent = hasSlot
                ? "Active deployment exists (re-deploying costs " + PRICE_WEI + " wei)"
                : "Free slot available";
            const btn = document.getElementById("bc-deploy-btn");
            if (hasSlot && btn) {
                const livePrice = BigInt(await proxy.price_for_slot());
                btn.textContent = `Reset + Re-deploy (reset costs ${livePrice} wei)`;
                btn.classList.replace("btn-outline-warning","btn-outline-danger");
            }
            const cc = await proxy.current_contract(walletAddress);
            if (cc && cc !== ethers.ZeroAddress && !deployedAddress) {
                deployedAddress = cc;
                showDeployedAddress(cc);
                document.getElementById("bc-verify-btn").disabled = false;
            }
        } catch (e) { console.warn("[bc] refreshAccountStatus:", e); }
    }

    // Deploy
    async function deployInstance() {
        if (!signer) { alert("Connect wallet first."); return; }
        setDeployStatus("info", "Checking slot…");
        document.getElementById("bc-deploy-btn").disabled = true;
        try {
            const proxy    = new ethers.Contract(PROXY_ADDRESS, PROXY_ABI, signer);
            const rawStats = await proxy.user_stats(walletAddress);
            const hasSlot  = (rawStats & ACTIVE_SLOT_BIT) !== 0n;

            if (hasSlot) {
                // Must call reset() before re-deploying
                const livePrice = BigInt(await proxy.price_for_slot());
                if (!confirm(`You have an active contract. Resetting costs ${livePrice} wei and abandons it. Continue?`)) {
                    document.getElementById("bc-deploy-btn").disabled = false;
                    setDeployStatus("", ""); return;
                }
                setDeployStatus("info", "Sending reset() transaction…");
                const resetTx = await proxy.reset({ value: livePrice });
                setDeployStatus("info", `Reset tx ${shortAddr(resetTx.hash)} - waiting…`);
                await resetTx.wait();
                setDeployStatus("info", "Slot reset! Deploying new instance…");
            }

            // generate_contract is now non-payable
            setDeployStatus("info", "Sending generate_contract() transaction…");
            const tx = await proxy.generate_contract(VULN_ID);
            setDeployStatus("info", `Tx ${shortAddr(tx.hash)} - waiting…`);
            await tx.wait();

            const instanceAddr = await proxy.current_contract(walletAddress);
            if (!instanceAddr || instanceAddr === ethers.ZeroAddress) throw new Error("current_contract returned zero address");
            deployedAddress = instanceAddr;
            showDeployedAddress(deployedAddress);

            await fetch(`/api/v1/blockchain/challenge/${CHALLENGE_ID}/deployment`, {
                method:"POST", headers:{"Content-Type":"application/json","CSRF-Token":getCsrf()},
                body: JSON.stringify({ contract_address: deployedAddress, paid_wei: "0" }),
            });
            setDeployStatus("success", "Deployed! Exploit it, then click Submit.");
            document.getElementById("bc-verify-btn").disabled = false;
            await refreshAccountStatus();
        } catch (e) {
            setDeployStatus("danger", `Failed: ${e.reason ?? e.message ?? e}`);
            document.getElementById("bc-deploy-btn").disabled = false;
        }
    }

    // Verify
    async function verifyExploit() {
        if (!walletAddress) { alert("Connect wallet first."); return; }
        setVerifyStatus("info", "Querying chain…");
        document.getElementById("bc-verify-btn").disabled = true;
        try {
            const res  = await fetch(`/api/v1/blockchain/challenge/${CHALLENGE_ID}/verify`, {
                method:"POST", headers:{"Content-Type":"application/json","CSRF-Token":getCsrf()},
                body: JSON.stringify({ player_address: walletAddress }),
            });
            const data = await res.json();
            if (data.success) {
                setVerifyStatus("success", `✓ ${data.message} - click Submit below to record your score.`);
                await refreshAccountStatus();
            } else {
                setVerifyStatus("warning", data.message);
                document.getElementById("bc-verify-btn").disabled = false;
            }
        } catch (e) {
            setVerifyStatus("danger", `Error: ${e.message ?? e}`);
            document.getElementById("bc-verify-btn").disabled = false;
        }
    }


    // Helpers
    function setNetworkBar(state, text) {
        const bar = document.getElementById("bc-network-bar");
        if (bar) bar.className = `bc-status-bar bc-status-${state==="connected"?"connected":state==="wrong"?"wrong-chain":"disconnected"}`;
        const lbl = document.getElementById("bc-network-label");
        if (lbl) lbl.textContent = text;
    }
    function setDeployStatus(level, msg) {
        const el = document.getElementById("bc-deploy-status");
        if (el) el.innerHTML = level ? `<span class="text-${level}">${msg}</span>` : "";
    }
    function setVerifyStatus(level, msg) {
        const el = document.getElementById("bc-verify-status");
        if (el) el.innerHTML = level ? `<span class="text-${level}">${msg}</span>` : "";
    }
    function showDeployedAddress(addr) {
        const wrap = document.getElementById("bc-contract-address-wrap");
        const code = document.getElementById("bc-contract-address");
        const link = document.getElementById("bc-explorer-link");
        if (wrap) wrap.style.display = "block";
        if (code) code.textContent   = addr;
        const base = EXPLORERS[CHAIN_ID];
        if (link) { link.href = base ? `${base}/address/${addr}` : "#"; link.style.display = base ? "inline" : "none"; }
    }
    function shortAddr(addr) { return addr ? addr.slice(0,6)+"…"+addr.slice(-4) : ""; }
    function getCsrf() { return (window.CTFd?.config?.csrfNonce) || document.querySelector('meta[name="csrf-token"]')?.content || ""; }

})();