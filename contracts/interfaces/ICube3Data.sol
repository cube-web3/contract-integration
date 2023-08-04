// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface ICube3Data {
    /*//////////////////////////////////////////////////////////////
            ENUMS
    //////////////////////////////////////////////////////////////*/

    /// @notice Defines the the state of the integration's authorization status.
    /// @dev    AuthorizationStatus refers to the integration's ability to access security modules via the router, not the function-level protections.
    /// @dev    Upon the completion of registration, an integration's authorizationStatus is set to ACTIVE, indicating that it is connected to the protocol.
    /// @dev    Only a CUBE3 admin has the power to modify these.
    /// @param INACTIVE The contract has not completed registration with the GateKeeper.
    /// @param ACTIVE The contract has been registered with the GateKeeper, and has access to the CUBE3 protocol's security modules.
    /// @param BYPASSED The CUBE3 Admin has disable the contract's protection functionality. Functions protected with the
    ///                 {Cube3Integration-cube3Protected} modifier will not revert, but not transactions will be routed to security modules.
    /// @param REVOKED The CUBE3 Admin has revoked the contract's protection functionality. All functions protected with the
    ///                {Cube3Integration-cube3Protected} modifier will revert if the function's protection status is enabled. This is a safeguard against malicious contracts.
    enum AuthorizationStatus {
        INACTIVE,
        ACTIVE,
        BYPASSED,
        REVOKED
    }

    /// @notice  Defines the state of the integration's registration status.
    /// @dev     RegistrationStatus refers to the integration's relationship with the CUBE3 protocol.
    /// @dev     An integration can only register with the protocol by receiving a registration signature from the CUBE3 service off-chain.
    /// @param   UNREGISTERED The integration technically does not exist as it has not been pre-registered with the protocol.
    /// @param   PENDING The integration has been pre-registered with the protocol, but has not completed registration.
    /// @param   REGISTERED The integration has completed registration with the protocol using the signature provided by the off-chain CUBE3 service.
    enum RegistrationStatus {
        UNREGISTERED,
        PENDING,
        REGISTERED
    }

    /*//////////////////////////////////////////////////////////////
            STRUCTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Defines the state of the integration's state in relation to the protocol.
    struct IntegrationState {
        RegistrationStatus registrationStatus;
        AuthorizationStatus authorizationStatus;
    }

    /// @notice Struct used to update an integration's authorization status.
    /// @param integrationOrProxy The address of the integration or its proxy contract.
    /// @param integrationOrImplementation The address of the integration or its implementation contract.
    /// @param authorizationStatus The new protection status of the integration.
    struct IntegrationProtection {
        address integrationOrProxy;
        address integrationOrImplementation;
        AuthorizationStatus authorizationStatus;
    }

    /// @notice Struct used to update an integration's registration status.
    /// @param integrationOrProxy The address of the integration or its proxy contract.
    /// @param integrationOrImplementation The address of the integration or its implementation contract.
    /// @param authorizationStatus The new registration status of the integration.
    struct IntegrationRegistration {
        address integrationOrProxy;
        address integrationOrImplementation;
        RegistrationStatus registrationStatus;
    }
}
