// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

interface IAegentRegistryBound {
    function marketRegistry() external view returns (address);

    function endpointKind() external pure returns (bytes32);
}
