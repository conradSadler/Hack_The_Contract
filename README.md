## The Blockchain CTFd Declaration of Independence

We hold these truths to be self-evident, that all men are created equal, that they are endowed by their Creator with certain unalienable Rights, that among these are Life, Liberty and the pursuit of Happiness... as well as knowing how to run this super awesome CTFd plugin!

**Step 1** Clone the master CTFd repo: https://github.com/CTFd/CTFd/tree/master, right now we are simply a colony

**Step 2** Replace the `docker-compose.yml` in the CTFd repo with ours as if that file were wearing a redcoat 🇺🇸

**Step 3** Place our `ctfd-blockchain-plugin` inside the plugins folder, overhauling several pieces of the CTFd architecture as if we were establishing a new form of government 🦅

**Step 4** Run `docker compose down && docker compose up` to see the birth of our nation at `http://127.0.0.1:8000`

And for the support of this CTFd plugin, with a firm reliance on the protection of divine Providence, we mutually pledge to each other our Lives, our Fortunes and our sacred Honor.

Here marks the end of the Declaration of Independence. I hope you enjoyed it. Below is some more boring documentation, might as well be tea in the Boston harbor.

૮₍˶Ó﹏Ò ⑅₎ა 

### Creating a Challenge
When you first log in to CTFd, it should ask you to set up the instance and create an admin account. I suggest just making that account `admin:admin` (🏸) so you don't forget it (OH NO DEFAULT CREDENTIALS RUNNNN  \\(˚☐˚”)/)

So you made it past the login screen? Good job clanker. Now we should make a challenge. To do this, click on the fancy `Admin Panel` button and then click on `Challenges`. You might be smarter than me, so you probably found it already, but in case you are blind like me, click on the plus sign to create a new challenge. Then under `Challenge Types` select `blockchain`. Here is what your screen should look like right now:
<img width="1132" height="1039" alt="image" src="https://github.com/user-attachments/assets/c15d7868-db34-41aa-adc8-8a5bf2f5fcd7" />
Most of the fields are self-explanatory, but there are a few that are goofy:
- **Value:** This is only for the CTFd scoring purposes; you can make it the vuln_id if you want, or you can make it 0, it doesn't really matter.
- **Proxy Contract Address** This is the address that your proxy deployed to.
- **Chain ID** This is the ID of the chain everything is deployed on, I've been setting my Anvil to have ID 1337 bc it's l33t, but it should work with any chain ID you want.
- **RPC URL** If you are using a localhost chain, the RPC needs to be `httIn order to use MetaMask with an Anvil chain, we gotta do some fun things. First, find wherever you have hardcoded your password (mine's in a clear-text markdown file, dw), and log in. Next, navigate to Manage networks and + Add a custom network to fill in your Anvil chain info. Assuming you nailed that step, go to your accounts and hit Add Wallet followed by Import an account. Then use one of the Anvil private keys for the account (NOT a private key you used for contract deployment). BAM, you should be ready to hack.p://host.docker.internal:8545` so your Docker can correctly talk to the chain!

- Assuming we survived the above, when you hit the bright blue `Create` button, it will ask you for a flag value; just leave it blank.

- Once you have the challenge created, click on `CTFd` and then `Challenges` to see your hopefully beautiful child!

- Clicking on said child will reveal the awesome modal that should work once all your contracts are deployed to the chain with the correct vuln_id. 

### For Information on deploying a local ethereum node using Foundry:

Using Foundry Anvil allows for quick setup on home sweet home (127.0.0.1

[Link Text]https://www.getfoundry.sh/introduction/getting-started

### Using MetaMask for Smarties

The only step left now is connecting that sweet $Bling-Bling$ that is your MetaMask wallet.

In order to use MetaMask with an Anvil chain, we gotta do some fun things. First, find wherever you have hardcoded your password (mine's in a clear-text markdown file, dw), and log in. Next, navigate to `Manage networks` and `+ Add a custom network` to fill in your Anvil chain info. Assuming you nailed that step, go to your accounts and hit `Add Wallet` followed by `Import an account`. Then use one of the Anvil private keys for the account (NOT a private key you used for contract deployment). BAM, you should be ready to hack.

### Tech Support
Operating hours are 9AM-10PM most days. Outside of business hours, please fill out a ticket: https://forms.gle/omdWBZ2CKqH3psvM8
