# Smart Contract Integration

Connecting your smart contracts to the CUBE3 protocol


## Integration Overview

The following section describe the steps for creating an integration:
- Add the CUBE3 contracts to your codebase
- Import and inherit from Cube3Integration.sol or Cube3IntegrationUpgradeable.sol
- Add the cube3Protected modifier to the functions you wish to add RASP functionality for
[Optional] Apply the Cube3Protected Security Admin account to your chosen access control pattern
- Supporting ERC165
- Deploy your contract/s
- Register your integration on-chain with the Cube3Router
- [Optional] Update the Security Admin account
- Register for the CUBE3 service, apply for your registrar token, and register your integration on-chain
- [Optional] Enable/Disable the protection status of your protected functions

## Step 1: Install the CUBE3 contracts using your package manager of choice

`Cube3Protected.sol` leverages [OpenZeppelin's](https://www.openzeppelin.com/) ERC165 and Context implementations, so these will need to be installed along with the CUBE3 contracts.

### Hardhat  (NPM or Yarn)
  
  ```bash
npm install --save-dev @cube-web3/cube3-integration @openzeppelin/contracts @openzeppelin/openzeppelin-contracts-upgradeable
```

### Foundry (Forge)

```bash
forge install cube-web3/cube3-integration @openzeppelin/openzeppelin-contracts @openzeppelin/openzeppelin-contracts-upgradeable 
```

Next, you'll need to update your `foundry.toml` and `remappings.txt` files.

Update your foundry.toml remappings - the entry should look something like. Make sure to include the `auto_detect_remappings` line:

```
remappings = [
    "forge-std/=lib/forge-std/src/",
    "ds-test/=lib/forge-std/lib/ds-test/src/",
    "@openzeppelin/contracts=lib/openzeppelin-contracts/contracts/",
    "@openzeppelin/contracts-upgradeable=lib/openzeppelin-contracts/contracts/",
    "cube3/=lib/cube3-integration/contracts/"
]

auto_detect_remappings = false
```


This will prevent the protocol repo's remappings from interfering with your own. Bear in mind the that you'll need to add any additional packages to your foundry.toml' s remappings property.

Then update your `remappings.txt `file.

```shell
forge remappings > remappings.txt
```

## Step 2: Import and inherit a CUBE3 base contract

Follow section 2.1 if your integration is a standalone contract, or 2.2 if you're using a proxy pattern.

### Step 2.1: Standalone integration

Below is an example of inheriting the Cube3Integration.sol contract into a standalone contract. Cube3Integration.sol inherits from SecurityAdmin2Step.sol, which sets the default Security Admin as the deployer.

```solidity
import {Cube3Integration} from "cube3/Cube3Integration.sol";

contract MyIntegration is Cube3Integration {
    ...
    constructor(...args) Cube3Integration() {
        ...
    }
}
```

### Step 2.2: Upgradeable/proxy integration

Below is an example of inheriting the `Cube3IntegrationUpgradeable.sol` contract into an upgradeable contract. Because initializers are not linearized by the compiler like constructors, we want to avoid initializing the same contract twice. As such, we follow OpenZeppelin's standards for Multiple Inheritance utilizing the `_init` and `_init_unchained` pattern. Upgradeable integrations will call `__Cube3IntegrationUpgradeable_init(...args) `inside their own initialize functions.
Unlike the standalone implementation of `Cube3Integration.sol` that inherits `SecurityAdmin2Step.sol`, which sets the default Security Admin as the deployer, the upgradeable version requires the Security Admin to be set explicitly. This provides flexibility for proxy patterns, such as the minimal forwarder proxy, that utilize a factory contract, whereby the deployer would be the factory contract if it was set implicitly. The integration **MUST** initialize Cube3IntegrationUpgradeable in its initialize function to set the protocol contract addresses and the security admin. 
Eg:

```solidity
import {Cube3IntegrationUpgradeable} from "cube3/upgradeable/Cube3IntegrationUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract MyIntegrationUpgradeable is UUPSUpgradeable, Cube3IntegrationUpgradeable {

   function initialize(
      ...args,
      address securityAdmin,
   ) external initializer {

      // Do something with the ...args
      
       __UUPSUpgradeable_init();
       __Cube3IntegrationUpgradeable_init(securityAdmin);
   }

    // upgradeability will be covered in a later section
    function _authorizeUpgrade(address newImplementation) internal virtual override onlySecurityAdmin {
        _preAuthorizeNewImplementation(newImplementation);
    }

}
```


---

`Cube3Integration.sol` inherits from `SecurityAdmin2Step.sol`, whereas `Cube3IntegrationUpgradeable.sol` inherits from `SecurityAdmin2StepUpgradeable.sol`. This access control pattern is based on OpenZeppelin's  where the new admin account needs to call a function to accept the transfer of the Security Admin account.

This step is marked as [Optional] because the contract can still be managed without altering your contract's access control patterns.  The implication is simply that the `_securityAdmin` account is assigned to contract's deployer and can be left as is, or transferred to a separate address. This can be done using the external `{transferSecurityAdministration}` made available by the selected base contract.

```solidity
/// @notice Explain to an end user what this does
/// @dev Starts the security admin transfer.
/// @dev Can only be called by the current _securityAdmin.
/// @dev Overridden functions MUST include {onlySecurityAdmin} modifier to maintain security functionalitys.
/// @dev No need for Zero address validation as the Zero address cannot call {acceptSecurityAdministration}
///      and _pendingSecurityAdmin can be overwritten.
/// @param newAdmin The address of the account waiting to accept the {_securityAdmin} role.
function transferSecurityAdministration(address newAdmin) public virtual onlySecurityAdmin {
    _pendingSecurityAdmin = newAdmin;
    emit SecurityAdminTransferStarted(securityAdmin(), newAdmin);
}
​
/// @dev Encapsulates the transfer and event emission for easy reuse.
/// @dev Can be used by inheritor to integrate with desired access control patterns.
function _transferSecurityAdministration(address newAdmin) internal {
    _beforeSecurityAdminTransfer(newAdmin);
    address oldAdmin = _securityAdmin;
    _securityAdmin = newAdmin;
    emit SecurityAdministrationTransferred(oldAdmin, newAdmin);
}
​
/// @dev Hook that is called before the security admin is set to a new address.
function _beforeSecurityAdminTransfer(address newAdmin) internal virtual {}
```
​
The inclusion of SecurityAdmin2Step is intentionally different from OpenZeppelin's Ownable2Step to avoid any potential conflicts should you choose to use that access control pattern.  The _securityAdmin is set to the deployer's address in the `Cube3Integration.sol` contract's constructor, or set explicitly in `{Cube3IntegrationUpgradeable-initialize}`.  This account has elevated permissions, allowing it to enable/disable the protection status of functions decorated with the cube3Protected modifier.

```
// SecurityAdmin2Step.sol || SecurityAdmin2StepUpgradeable.sol
​
// the current security admin for the derived contract
address private _securityAdmin;
​
// the pending security admin for the derived contract, once accepting the role will be transferred to the _securityAdmin
address private _pendingSecurityAdmin;
```

Presented below is an example integration using OpenZeppelin's Ownable access pattern. In this scenario, the owner and _securityAdmin accounts are aligned to be the same EOA. 
Please note: this is not a recommendation or suggestion of best practices, it is simply a demonstration of how to override the internal functions provided. In this example, it should also be noted that while the ownership would be transferred to the newAdmin address, whereas the EOA would still need to call acceptSecurityAdministration. It's up to you to determine how the Security Admin account is managed.

```solidity
contract ExampleIntegrationOwnable is Cube3Integration, Ownable {
    constructor() Cube3Integration() {}
​
    function transferSecurityAdministration(address newAdmin) public override
    onlySecurityAdmin {
        _transferOwnership(newAdmin);
        _transferSecurityAdministration(newAdmin);
    }
}
```
Another example use/s OpenZeppelin's AccessControl. This example is more nuanced, and assigns the example contract's deployer the EXAMPLE_ADMIN_ROLE, this role would then be used to execute functions that require elevated privileges in the example contract.  Should the contract's deployer want the _securityAdmin and EXAMPLE_ADMIN_ROLE to be the same account, the role can be granted and revoked in the _beforeSecurityAdminTransfer hook.

```solidity
contract ExampleIntegrationAccessControl is Cube3Integration, AccessControl {
    bytes32 constant EXAMPLE_ADMIN_ROLE = keccak256(abi.encode("EXAMPLE_ADMIN_ROLE"));
​
    // deployer is security admin by default
    constructor(address Cube3RouterProxy) Cube3Integration() {
        _grantRole(EXAMPLE_ADMIN_ROLE, msg.sender);
    }
​
​
    function transferSecurityAdministration(address newAdmin) public override 
    onlySecurityAdmin onlyRole(EXAMPLE_ADMIN_ROLE) {
        _grantRole(EXAMPLE_ADMIN_ROLE, newAdmin);
        _revokeRole(EXAMPLE_ADMIN_ROLE, msg.sender);
        _transferSecurityAdministration(newAdmin);
    }
​
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(AccessControl, Cube3Integration) returns (bool) {
        // is the same as  return AccessControl.supportsInterface(interfaceId) || Cube3Protected.supportsInterface(interfaceId);
        // due to linearization, it will first call Cube3Protected's implementation due to the linearization order. Because Cube3Protected also uses the super
        // keyword, it will then call AccessControl's implementation.
        return super.supportsInterface(interfaceId);
    }
}
```

An important note for the above implementation is that both OpenZeppelin's AccessControl and Cube3Integration implement ERC165 and, as such, the {supportsInterface} function needs to be overridden. 

### Step 5: Supporting ERC165

This step is optional and only relevant if your contract implements the ERC165 interface. If your contract does not implement ERC165, you can skip this step.
If your contract does implement ERC165, or inherits from another contract that implements it, you'll need to override the supportsInterface function and override each contract that implements ERC165.

The following example shows how to override supportsInterface, which is present in both the Cube3Integration and OpenZeppelin AccessControl contracts.

```solidity
function supportsInterface(
  bytes4 interfaceId
) public view virtual override(AccessControl, Cube3Integration) returns (bool) {
  return super.supportsInterface(interfaceId);
}
```

Using super.supportsInterface(interfaceId) is the same as AccessControl.supportsInterface(interfaceId) || Cube3Integration.supportsInterface(interfaceId) dues to linearization. It will first call Cube3Integration's implementation due to the linearization order. Because Cube3Integration also uses the super keyword, it will then call AccessControl's implementation.
Step 6: Deploy your contracts
Deploy your contracts to your network of choice, using your preferred tooling, eg. Hardhat, Foundry etc.
If utilizing a proxy, and deploying via hardhat, it's likely you're using the Hardhat Upgrades PLugin. For security purposes the immutable variable _self is set in the Cube3IntegrationUpgradeable constructor during the integration's implementation contract's deployment.
// Cube3IntegrationUpgradeable.sol
constructor() {
  _self = address(this);
}
This creates a reference to the integration's own implementation address that's stored in the contract's bytecode, so is not subject to being bypassed via a delegate call that would read from the caller's state.
As such, we need to tell the plugin to allow the constructor using the unsafeAllow option when deploying the proxy.
{
  ...opts,
  initializer: 'initialize',
  unsafeAllow: ['constructor', 'state-variable-immutable'],
}
Which will show a warning like the following:
Warning: Potentially unsafe deployment of test/foundry/dummy/DummyIntegrationTransparent.sol:DummyIntegrationTransparent
​
You are using the `unsafeAllow.state-variable-immutable` flag.
​
Warning: Potentially unsafe deployment of test/foundry/dummy/DummyIntegrationTransparent.sol:DummyIntegrationTransparent
​
You are using the `unsafeAllow.constructor` flag.