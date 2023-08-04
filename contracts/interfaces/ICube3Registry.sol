// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

/// @title CUBE3 Signing Authority Registry.
/// @author CUBE3.ai
/// @notice This contract serves as a registry for storing and managing the signing authorities
///         assigned to specific Cube3 customer integrations.
/// @dev A "signing authority" is the EOA address belonging to the private key from the keypair that
///      generates the signature of the secure payload supplied by the Risk API. See {Cube3Integration}.
/// @dev All Signing Authority Keypairs are managed by the CUBE3 KMS on behalf of integrations.
/// @dev All active signing authorities are tied to the current value of {_invalidationNonce}.
/// @dev Incrememnting {_invalidationNonce} will invalidate all registered signing authories - given that
///      the contract has 2^256 storage slots, we simply discard the reference to the existing
///      items in storage (by incrementing the nonce) instead of zeroing-out each slot.
/// @dev Invalidating the active nonce requires an admin to supply a temporary signer override address, and
///      sets the contract into recovery mode, which means the "global" temporary signing authority is returned
///      as the signing authority for all integrations until recovery mode is deactivated.
/// @dev Contract is upgradeable via the Universal Upgradeable Proxy Standard (UUPS).
/// @dev Includes a `__storageGap` to prevent storage collisions following upgrades.

interface ICube3Registry {
    /*//////////////////////////////////////////////////////////////
            EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when a new signing authority is set.
    /// @param integration The integration contract's address.
    /// @param signer The signing authority's account address.
    /// @param activeNonce The currently active invalidation nonce for the signing authority set
    event SigningAuthorityUpdated(address indexed integration, address indexed signer, uint256 activeNonce);

    /// @notice Emitted when a signing authority is revoked.
    /// @param integration The integration contract's address.
    /// @param revokedSigner The signing authority's account address.
    /// @param activeNonce The active _invalidationNonce for the set.
    event SigningAuthorityRevoked(address indexed integration, address indexed revokedSigner, uint256 activeNonce);

    /// @notice Emitted when the invalidation nonce is incremented.
    /// @dev Effectively represents an entire set of signing authorities that have been revoked.
    /// @param invalidationNonce The `_invalidationNonce` that was invalidated.
    event SigningAuthorityNonceSetInvalidated(uint256 invalidationNonce);

    /// @notice Emitted when the `_invalidationNonce` is incremented and a temporary recovery signing authority is set
    /// @param tempSignerOverride The override account that will serve as the signing authority for all integrations
    /// @param newInvalidationNonce The invalidation nonce whose set the temporary signing authority belongs to
    event TemporaryRecoverySigningAuthorityAssigned(address indexed tempSignerOverride, uint256 newInvalidationNonce);

    /// @notice Emitted when the Cube3 admin enters/exits recovery mode.
    /// @dev Setting mode to active occurs when the invalidation nonce is incremented.
    /// @dev See {Cube3RegistryLogic-invalidateSigningAuthorityNonceSet} for details.
    /// @param isActive The current Recovery Mode status, where True is active.
    event RecoveryModeStatusUpdated(bool isActive);

    /*//////////////////////////////////////////////////////////////
            FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Sets, or updates, the signing authority address for an integration contract.
    /// @dev Can only be called by a key manager.
    /// @dev Each integration has a unique signing authority stored in the `integrationToSigningAuthority` map.
    /// @dev The signing authority is intrinsicly linked to the current `_invalidationNonce`, if the nonce
    ///      is incremented, the signing authority is no longer valid.
    /// @param integrationContract The contract address of the integration.
    /// @param clientSigningAuthority The public address generated for the integration's private-public key-pair.
    function setClientSigningAuthority(address integrationContract, address clientSigningAuthority) external;

    /// @notice Sets multiple integration contracts and their corresponding signing authorities for the active
    ///         `_invalidationNonce`.
    /// @dev No array-length check, therefore subject to out-of-gas error, up to the key manager to use their
    ///      discretion when calling.
    /// @param integrations The addresses of the integration contracts.
    /// @param signingAuthorities The addresses of the signingAuthorities, where each index corresponds to
    ///        the ingtegration contract in the `integrations` array at the same index.
    function batchSetSigningAuthority(address[] calldata integrations, address[] calldata signingAuthorities) external;

    /// @notice Revokes a signing authority for the provided contract address.
    /// @dev Can only be called by a key manager.
    /// @dev Removes the signing authority from the `integrationToSigningAuthority` map.
    /// @param integration The integration contract's address.
    function revokeSigningAuthorityForIntegration(address integration) external;

    /// @notice Revokes multiple signing authorities in the same transaction.
    /// @dev If used in an emergency, gas price should be set high to front-run mempool TXs that
    /// 	 contain soon-to-be-revoked signing authorities.
    /// @dev Is subject to experiencing out-of-gas error if the `integrationsRevoked` array is too long.
    /// @param integrationsToRevoke The list of integration addresses to revoke.
    function batchRevokeSigningAuthoritiesForIntegrations(address[] calldata integrationsToRevoke) external;

    /// @notice Retrieves the signing authority's address for the supplied integration.
    /// @dev Each integration contract has a unique signature authority managed by Cube3's KMS.
    /// @dev Function will return address(0) for a non-existent authority, so it's up to the caller
    ///      to handle it accordingly.
    /// @dev If the registry is in recovery mode, ie a nonce set has been invalidated, the temporary
    ///      signing authority override is returned.
    /// @dev The calling contract relies on the returned address to validate whether the integration has
    ///      been registered.  When `isRecoveryMode` is true, this check is invalid as the temporary
    ///      override signer is returned by default.
    /// @param integration The ingtegration contract's address.
    /// @return The signing authority (account address) of the authority's private-public keypair.
    function getSignatureAuthorityForIntegration(address integration) external view returns (address);

    /// @notice Invalidates every signing authority belonging to the current `_invalidationNonce` set.
    /// @dev Sets `isRecoveryModeActive` to true, which enables the use of the `tempRecoverySigningAuthority`.
    /// @dev Invalidates the global `_invalidationNonce` which nullifies all active signing authorities.
    /// @dev Only callable by the Cube3 admin - the `tempSignerOverride will not expire, see
    ///      {Cube3RegistryLogic-exitRecoveryMode} for details.
    /// @dev Resets the `_signingAuthorityCount` to 0.
    /// @param tempSignerOverride Address of the temporary signing authority override that will be used to sign
    ///                           all payloads until recoveryMode is disabled.
    function invalidateSigningAuthorityNonceSet(address tempSignerOverride) external;

    /// @notice Exits recovery mode and disables the temporary signing authority.
    /// @dev Sets the `tempRecoverySigningAuthority` back to the Zero address.
    /// @dev Only callable by the Cube3 admin or Key Manager role.
    /// @dev Recovery mode is typically only activated in emergency situations, such as breach of the Cube3 KMS, ie.
    ///      when an entire signatury authority set needs to be invalidated.
    /// @dev Resets the _tempRecoverySigningAuthority to the Zero Address.
    function exitRecoveryMode() external;

    /// @notice Returns the current active invalidation nonce.
    /// @dev The active _invalidationNonce controls signing authority set
    ///      assosciated with the nonce.
    function invalidationNonce() external returns (uint256);

    /// @notice Returns whether the registry is in recovery mode.
    function isRecoveryModeActive() external returns (bool);

    /// @notice Utility function to access an integration's signing authority from a given nonce set.
    /// @param integration The integration contract the signing authority belongs to.
    /// @param nonce The invalidation nonce representing the set the authority belongs.
    /// @return The invalidated signing authority and whether the authority is active, ie part of a the current (valid) nonce set.
    function getSignatureAuthorityFromNonceSet(
        address integration,
        uint256 nonce
    ) external view returns (address, bool);
}
