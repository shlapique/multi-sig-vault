# MultiSig Wallet

This project provides a secure upgradeable MultiSig wallet implementation with
UUPS proxy pattern. The system allows:

- Creation of configurable MultiSig wallets with arbitrary owners and
  thresholds

- Secure transaction management requiring multiple confirmations ($2/3$)

- Upgradeable logic while preserving wallet state

# Protocol

## Proxy Contract

![](./img/diag-proxy.svg)

## MultiSig Logic (UUPS)

![](./img/diag-ms.svg)

# Refs
https://pkqs90.github.io/posts/gnosis-safe-walkthrough/
https://docs.openzeppelin.com/contracts/5.x/api/access#Ownable
https://docs.openzeppelin.com/contracts/5.x/api/proxy
https://docs.openzeppelin.com/contracts/5.x/api/proxy#ERC1967Utils
https://docs.openzeppelin.com/upgrades-plugins/proxies#proxy-forwarding
