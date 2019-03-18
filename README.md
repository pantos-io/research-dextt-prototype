# DeXTT: Deterministic Cross-Blockchain Token Transfers
This repository hosts a reference implementation of Deterministic Cross-Blockchain Token Transfers (DeXTT), the protocol for deterministic cross-blockchain token transfers. This reference implementation exemplifies the protocol, and provides means for testing and evaluating it.

The following scientific publication describing the DeXTT protocol in detail is currently under peer review and will be linked here upon publishing:

> Michael Borkowski, Marten Sigwart, Philipp Frauenthaler, Taneli Hukkinen, Stefan Schulte: "DeXTT: Deterministic Cross-Blockchain Token Transfers" (2019; submitted for peer review).

In this document, we provide a brief description of the protocol in order to present its functionality and provide a reference for the provided solidity code.

# Introduction and Background
DeXTT has been developed within the [Token Atomic Swap Technology (TAST)](http://infosys.tuwien.ac.at/tast/) research project. The overarching goal of the TAST project is to foster cross-blockchain interoperability, in order to counter the current fragmentation of the research and development field of blockchains.

Such blockchain interoperability can entail various means, including cross-blockchain messaging, cross-blockchain smart contract invocation, or cross-blockchain asset transfers. As a first step towards such interoperability, we aim to develop a protocol for transferring tokens across blockchains.

Cross-blockchain token transfers, as provided by DeXTT, are in contrast to atomic swaps, where an asset exchange of two independent cryptographic assets (potentially on two different blockchains) is executed in an atomic way, i.e., without risk for any involved party. However, both assets remain independent and no information is exchanged between the blockchains. DeXTT, however, provides a way to synchronize token transfers across blockchains to maintain consistency of wallet balances.

## Preliminaries

DeXTT is needed as a special transfer protocol because direct blockchain-to-blockchain communication is not possible using practical means. We describe this in detail in the [cross-blockchain proof problem (TAST White Paper II)](http://dsg.tuwien.ac.at/staff/mborkowski/pub/tast/tast-white-paper-2.pdf), where we present the lemma of rooted blockchains.

This reference implementation of DeXTT is written in Solidity, the smart contract language of Ethereum, to demonstrate the DeXTT protocol. However, its concepts are not limited to Solidity or the Ethereum blockchain. We use the [Truffle Suite](https://truffleframework.com/) for the development, building, testing, and deployment of the smart contracts.

The DeXTT protocol specifies how the balances of a cross-blockchain currency are synchronized between all blockchains participating in the protocol (referred to as the the *blockchain ecosystem*), keeping the balances consistent after transfers. For this, we use techniques described in our previous white papers, such as [claim-first transactions (TAST White Paper II)](http://dsg.tuwien.ac.at/staff/mborkowski/pub/tast/tast-white-paper-2.pdf) or [deterministic witnesses (TAST White Paper III)](http://dsg.tuwien.ac.at/staff/mborkowski/pub/tast/tast-white-paper-3.pdf). We show how these techniques are used in DeXTT below.

We develop a token tradeable independently of a specific blockchain. Instead of having token balances per wallet on each blockchain, we use global wallet balances. In other words, instead of the notion of ``The token balance of wallet A on blockchain X is 10``, we only use the notion of ``The token balance of wallet A is 10`` and ensure the consistency of this information on all blockchains within the ecosystem. Note that this is a simplification of our [previous work (TAST White Paper III)](http://dsg.tuwien.ac.at/staff/mborkowski/pub/tast/tast-white-paper-3.pdf), where we used per-blockchain balances. However, the concept remains the same, and per-blockchain balances can easily be implemented with DeXTT as well.


# DeXTT Protocol Description

The DeXTT protocol entails a number of *transactions*, which we will later implement using Solidity functions. We now briefly describe how a regular DeXTT transaction is executed, using three types of transactions, **claim**, **contest**, and **finalize**. In this concept, we refer to *a party posting a transaction on a blockchain*. In our implementation, this is translated to a wallet signing a function call to a smart contract.

We rely on observers of transactions, called *witnesses*, for ensuring (eventual) consistency across blockchains. We will show how we provide a *witness reward* in what we call a *witness contest*. Several observers are competing in a contest for the witness reward. The selection of which of these contestants receives the reward is performed in a deterministic way, removing the necessity of synchronizing *this* decision across blockchains. This is the implementation of the *deterministic witnesses* concept.

In the following, we use PBT, an exemplary **p**an-**b**lockchain **t**oken, as the cross-blockchain asset being transferred. For simplicity, we assume that the witness reward for any transfer is 1 PBT, but other models, such as a percentage of the transferred PBT, are also feasible. The reward is taken from the transferred PBT, i.e., when transferring 100 PBT from **S** to **D**, 99 PBT are sent to **D**, and 1 PBT is assigned to the witness winning the witness contest (we describe below how this witness is selected).

## Regular DeXTT Transactions

We assume that the source **S** intends to send **x** PBT to the destination **D**. The protocol follows the following core steps:

1. Proof of Intent (signed by **S** and **D**)
2. **claim** transaction (posted by **D** on any blockchain in the ecosystem)
3. Witness contest using **contest** transactions (posted by multiple parties on all blockchains in the ecosystem)
4. Contest conclusion using **finalize** transactions (posted by **D** on all blockchains in the ecosystem)

### Step 1: Proof of Intent
The source **S** and the destination **D** must sign a so-called Proof of Intent (PoI). For this, **S** defines a validity period **t0..t1** during which this transfer is valid, which is used later in the protocol. **S** then signs the following data: **[S, D, x, t0..t1]**. We assume that the signature of this data using the private key of **S** is **sig_a**.

The destination counter-signs this data, yielding a complete PoI: **[S, D, x, t0..t1, sig_a, sig_b]**, where **sig_b** is used to denote the signature of all the previous values using the private key of **D**. This PoI can be used by any party to verify the intent to transfer of both involved parties.

At this point, the challenge is to ensure that the PoI is propagated across all blockchains, thus recording the transfer of PBT from **S** to **D**. We do not want to rely on a single party (e.g., **D**) to perform this transfer, and instead, provide a reward for observers (witnesses). We will later show how we select the recipient of this witness reward.

The negotiation of the PoI does not need to be secure, since none of the data involved is sensitive (in fact, all of this data will be later published on all blockchains). Therefore, the necessary communication can happen off-chain or on-chain, in any encrypted or unencrypted manner. For simplicity, in our reference implementation, we simply use the smart contract itself (i.e., we use on-chain communication between **S** and **D** to create the PoI).

### Step 2: The **claim** transaction
At this point, (at least) the destination **D** possesses the PoI. The DeXTT protocol defines that for any transfer, a witness contest must take place, and therefore, the PoI must be published for any observer to see. This is done by **D** using the **claim** transaction, on any blockchain within the ecosystem:

``claim(S, D, x, t0, t1, sig_a, sig_b)``

The aim of this transaction is simply to publish the PoI data to the ecosystem. This can be implemented using events (such as provided by Solidity).

### Step 3: Witness contest using **contest** transactions
Once the PoI is published, any observer can become a contestant (take part in the witness contest) by posting a **contest** transaction. For this, the contestant signs the PoI using its private key (here, this contestant signature is denoted as **sig_c**), and posts the **contest** transaction to all blockchains within the ecosystem:

``contest(S, D, x, t0, t1, sig_a, sig_b, sig_c)``

The signature **sig_c** will later play a role in the decision of the witness contest (note that since **sig_c** is derived from the contestant's private key, every contestant has a different **sig_c**). There are two effects of this transaction: First, the observer posting this transaction becomes a contestant (with the signature **sig_c** as a "ticket" for the contest), hoping for the witness reward (1 PBT in our implementation). Second---more or less as a byproduct---, the PoI is propagated, spreading the information about the DeXTT transfer. For the contestant, this is of limited relevance, but the overall DeXTT transfer, it is crucial.

### Step 4: Concluding the contest using **finalize** transactions
The witness runs until **t1** passes, i.e., until its validity period expires. Until that point, all observers post **contest** transactions, hoping for the witness reward.

Once **t1** passes, the winner of the witness contest must be decided. In the DeXTT protocol, we do not use a first-come-first-serve basis for this decision. Instead, we define that the contestant with the *lowest signature* **sig_c** *becomes the winning witness*, i.e., receives the witness reward.

This decision is performed within a transaction type called **finalize**, called by **D** on all blockchains in the ecosystem:

``finalize(sig_a)``

Only **sig_a** is required to identify the PoI. This transaction has two effects: First, the witness reward of 1 PBT is assigned to the winning witness. Second, the actual PBT transfer is executed, i.e., **x** PBT are deducted from the balance of **S**, **x-1** PBT are assigned to the balance of **D**, and 1 PBT is assigned to the winning witness.

Note that the winning witness is the same on all blockchains, regardless of the order in which the contestants posted their **contest** transactions. This means that all blockchains can deterministically reach the same decision on the witness receiver, and no direct cross-blockchain communication is required.

## Double Spending Prevention

Naturally, nothing keeps a malicious source **S** from signing two conflicting PoIs. For instance, **S** might have a balance of 100 PBT, and sign two PoIs, each constituting a transfer of 90 PBT, but with two different destinations, **D'** and **D''**. These two PoIs are conflicting because when executing the transfer in a regular way, the **finalize** transaction would result in a negative balance of **S**.

We therefore define that two conflicting PoIs (with overlapping validity periods) are illegal, and the mere existence of such a conflict means that **S** loses all PBT. We use the same mechanism as described above---a contest---to propagate the information of the co-existence of such conflicting PoIs to all blockchains. Again, we use witness rewards to ensure that the information is eventually propagated across all blockchains.

We call this special contest *veto contest*. Any observer of two conflicting PoIs can post the **veto** transaction to all blockchains:

``veto(S, D', D'', x', x'', t0', t1', t0'', t1'', sig_a', sig_a'', sig_b', sig_b'', sig_c)``

This transaction consists of all the information contained in the two conflicting PoIs, and is signed by the contestant, resulting in **sig_c**. We will see in our implementation that the number of required arguments is actually lower in the implementation, due to the fact that the blockchain already knows one of the two PoIs.

The effects of this transaction are as follows: First, the balance of **S** is set to zero. Second, any still-valid witness contest regarding one of the two conflicting PoIs is aborted. Third, a new contest, called the *veto contest*, is started. This contest is similar to a regular witness contest: Any observer posting a **veto** transaction becomes a contestant in the veto contest, and the observer with the lowest signature **sig_c** is the winner of this veto contest. The veto contest ends at a point in time specified as follows:

``veto_t1 = max(t1', t1'') + max(t1' - t0', t1'' - t0'')``

In other words, the veto contest runs until both PoIs are expired according to their **t1**, and the longer duration of the two validity periods has passed afterwards. Similar to a regular witness contest, the veto contest is concluded using a transaction type called **finalize-veto**:

``finalize-veto(sig_a', sig_a'')``

The **finalize-veto** transaction refers to the two conflicting PoIs by their signatures **sig_a'** and **sig_a''**, and assigns the veto witness reward (1 PBT in our example) to the winning veto witness.

## Possible Alternatives

The current protocol defines that the balance of **S** is set to zero in case of a conflicting PoI, since this can only occur if **S** deliberately attemts double spending. This burns all involved tokens, which is easy to implement, resistant to race conditions, and requires no additional synchronization across blockchains. As an alternative, one could also assign the tokens to the winning veto witness, instead of burning them. This would increase the incentive, but also require additional means to maintain consistency in case multiple PoI conflicts (i.e., more than two conflicting PoIs) exist.

# Solidity Implementation

The smart contracts contained in this repository represent a reference implementation of the DeXTT protocol. Above, we have described the concepts of the DeXTT protocol. In the implementation, certain simplifications are possible to reduce the complexity (and therefore deployment and invocation) cost of the DeXTT protocol.

## The ``Cryptography`` Library

In order to decouple certain cryptography-related functionality, we have created a library in ``Cryptography.sol``. This library provides functionality for creating and verifying signatures and hashes using the ``Keccak256`` hash function.

## The ``PBT`` Contract

The contract in ``PBT.sol`` is the core of our reference implementation. It contains a smart contract representing a token transferable according to the DeXTT protocol described in this document.

### Private Fields

The smart contract uses fields in the Ethereum storage to maintain its necessary state. The following fields are used:

* `balances` maps a wallet to its current, confirmed PBT balance.
* `senderLock` maps a wallet to the PoI currently "locking" this wallet, i.e., the PoI currently pending from the wallet address. If no PoI is currently pending for a wallet, this mapping contains zero (`bytes32(0)`). The PoI is referred to by its signature (**sig_a**).
* `alphaFrom`, `alphaTo`, `alphaValue`, `alphaT0`, `alphaT1` map a PoI signature (**sig_a**) to the PoI data (**S**, **D**, **x**, **t0**, and **t1**, respectively).
* `contestWinner` and `contestSignature` map a PoI (denoted by its **sig_a**) to its current contest winner, and the current winner's signature.
* `senderInvalid` is used to permanently disable a wallet. This is use to punish conflicting PoIs.
* `vetoT1` stores the end of the validity of a veto witness contest. The key of this mapping is the address of the conflicting PoIs' source **S**.
* `vetoWinner` and `vetoSignature`, similarly to `contestWinner` and `contestSignature`, store the current veto contest winner, and the current winner's signature.
* `vetoFinalized` marks whether a veto contest has been finished.

### Events

We heavily use Solidity events to facilitate creating clients using this smart contract. The following events are used:

* `Minted(addr, value)` is emitted when PBT are minted and `addr` is assigned `value` PBT.
* `TransferInitiated(from, to, value, t0, t1, alpha)` is emitted when a PoI has been signed by the source **S** (`from`), and is pending counter-signature by the destination **D** (`to`). `alpha` refers to the **sig_a** signature of the PoI.
* `ContestStarted(from, to, value, t0, t1, alpha, beta` is emitted when a PoI has been counter-signed and published, starting the witness contest. `beta` refers to the **sig_b** signature of the PoI.
* `TransferFinalized(from, to, value, t0, t1, witness)` is emitted when a witness contest is concluded. `witness` refers to the winning witness of this contest.

* `VetoStarted(from, to, value, t0, t1, alpha, beta)` is emitted when a veto contest has started.
* `VetoFinalized(from, witness)` is emitted when a veto contest is concluded. `witness` refers to the winning witness of this contest.

### Functions

* `totalSupply()`, `balanceOf(_owner)` are used to retrieve the total supply or a given wallet's balance.
* `mint(_owner, value)` and `unlock(sender)` are used in our testing environment to mint tokens and unlock wallets. They are not meant for regular use in the DeXTT protocol.
* `initiate(to, value, t0, t1, alpha)` represents the on-chain transfer of the (partial) PoI from the source (`msg.sender`) to the destination (`to`).
* `contest(from, to, value, t0, t1, alpha, beta)` is a function entailing the functionality of **claim**, **contest**, and **veto**. It is described in detail below.
* `finalize(from)` is a function entailing the functionality of **finalize** and **finalize-veto**. It is described in detail below.
* `verifyPoi(from, to, value, t0, t1, alpha, beta)` is used internally by `contest` to verify a PoI. This verification also includes the storing of the PoI details in the blockchain state (Ethereum storage). If the provided PoI is conflicting with a previously-stored PoI, the consequences as defined by the DeXTT protocol (removal of all PBT from the sender, starting of a veto contest) are executed.

### `contest` and `finalize` in Detail

Since the only aim of the **claim** transaction is to publish information about a PoI, its functionality is included together with the **contest** transaction in the ``contest`` function.

Furthermore, since the functionality of **contest** and **veto** are very similar, their functionality has been implemented in a single function, ``contest``. This also removes any problems arising from race conditions: A client does not have to  check whether a PoI is conflicting (further, such a check could not be executed atomically). Instead the `contest` function performs this check automatically. The `verifyPoI` function called internally performs the check whether the PoIs are conflicting, and sets the state fields (especially `senderInvalid`) accordingly.

Similarly, `finalize` entails the functionality of both **finalize** and **finalize-veto**, which also removes potential for race conditions.

# Closing Remarks

This initial reference implementation serves as an example on how DeXTT transactions can be implemented. Since research in this field is ongoing, further development is performed, and further versions of cross-blockchain transfer protocols are envisioned.

Therefore, the purpose of this work is to showcase a smart contract implementation of the DeXTT protocol, to publish the implementation used in the evaluation (which will be provided in the paper currently under review), and to foster discussion within the community.

# Acknowledgments

The TAST research project is conducted within [Pantos](https://pantos.io/).
