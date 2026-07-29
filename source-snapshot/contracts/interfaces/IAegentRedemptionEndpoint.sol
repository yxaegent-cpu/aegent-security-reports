// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IAegentRegistryBound} from "./IAegentRegistryBound.sol";

interface IAegentRedemptionEndpoint is IAegentRegistryBound {
    function isOperational() external view returns (bool);
}
