# Rebase Token

A single-chain rebase token built with Foundry. Users deposit ETH into a vault and receive tokens whose `balanceOf` grows every second. Each user's interest rate is fixed when they deposit, and the global rate can only go down, so early depositors earn more.

This is a learning project and is **not audited**. Do not use it with real funds.

## How it works

- **Deposit:** a user sends ETH to the `Vault` and receives the same amount of rebase tokens.
- **Growing balance:** `balanceOf` returns the stored balance plus interest earned since the user's last update. It is a view function, so nothing is minted when it is read.
- **Interest is minted on interaction:** accrued interest is minted into the user's stored balance just before a mint, burn or transfer, and the timer restarts.
- **Redeem:** the user burns tokens and gets ETH back from the vault.

```
balanceOf = storedBalance * (1e18 + userRate * secondsSinceLastUpdate) / 1e18
```

## Interest rate model

- There is one global rate, set by the owner. It can only **decrease**.
- When a user deposits, they get a snapshot of the current global rate. That becomes their own rate.
- Early depositors keep a higher rate than later ones.
- When tokens are transferred to an address with no balance, the recipient takes the sender's rate.

## Contracts

| Contract | Purpose |
| --- | --- |
| `src/RebaseToken.sol` | ERC20 with per-user interest, owner-controlled rate, and a mint/burn role |
| `src/Vault.sol` | Accepts ETH, mints tokens on deposit, burns tokens and returns ETH on redeem |
| `src/interfaces/IRebaseToken.sol` | Interface the vault uses to call the token |

Built on OpenZeppelin v5 (`ERC20`, `Ownable`, `AccessControl`).

## Project structure

```
src/
  RebaseToken.sol
  Vault.sol
  interfaces/IRebaseToken.sol
test/
  RebaseToken.t.sol
  Fuzz/
    Handler.sol
    RebaseTokenInvariant.t.sol
```

## Getting started

Requires [Foundry](https://book.getfoundry.sh/getting-started/installation).

```bash
git clone --recurse-submodules https://github.com/opeyemi0101/foundry-rebase-token.git
cd foundry-rebase-token
forge build
forge test -vvv
```

## Tests

- **Unit and fuzz tests** (`test/RebaseToken.t.sol`): interest grows linearly, principal balance stays fixed, deposit and redeem, partial redeem, rate can only decrease, early depositor keeps the higher rate, access control for mint, burn and rate changes, transfers and `transferFrom`.
- **Invariant tests** (`test/Fuzz/`): a handler runs random deposits, redeems, transfers, time jumps and rate changes. After each call, the tests check that the interest rate never increases and that `balanceOf` is never below the principal balance.

Run a single test:

```bash
forge test --match-test testInterestCanOnlyDecrease -vvv
```

## Known limitations

- The interest is created by the token, not earned from a real yield source. The vault must hold extra ETH to pay it out, otherwise large redemptions revert.
- A new deposit from an existing user overwrites their rate with the current global rate.
- Single chain only. Cross-chain support with Chainlink CCIP is planned.

## Roadmap

- [x] Rebase token and vault
- [x] Unit, fuzz and invariant tests
- [ ] Cross-chain transfers with Chainlink CCIP

## Author

Opeyemi Jimoh — [GitHub](https://github.com/opeyemi0101)

## License

MIT
