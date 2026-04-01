from CTFd.plugins import register_plugin_assets_directory, register_plugin_script, register_user_page_menu_bar
from CTFd.plugins.challenges import CHALLENGE_CLASSES
from .models import BlockchainChallenge, BlockchainChallengeModel, UserDeployment  
from .routes import blockchain_bp

def load(app):
    # Registers the custom challenge type
    CHALLENGE_CLASSES["blockchain"] = BlockchainChallenge
    
    # Tells CTFd where the assests for the plugin should be hosted.
    register_plugin_assets_directory(
        app,
        base_path="/plugins/ctfd-blockchain-plugin/assets/",
    )

    # Injects ethers.js on all pages related to our plugin. This handles talking to wallets and nodes!
    register_plugin_script(
        "https://cdnjs.cloudflare.com/ajax/libs/ethers/6.7.1/ethers.umd.min.js"
    )

    # Register API blueprint
    app.register_blueprint(blockchain_bp)

    # Create the plugin DB tables
    app.db.create_all()

    # Add "Chain Scoreboard" link to the user navbar
    register_user_page_menu_bar(
        title="Chain Scoreboard",
        route="/api/v1/blockchain/scoreboard",
    )

    print("[blockchain-plugin] Loaded successfully.")