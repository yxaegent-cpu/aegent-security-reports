// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

interface IAegentSaleProceedsVault {
    function marketRegistry() external view returns (address);

    function usdt() external view returns (address);

    function usdc() external view returns (address);

    function beneficiary() external view returns (address);
}
