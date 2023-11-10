// SPDX-License-Identifier: MIT
pragma solidity ^0.8.1;

// Address library
library Address {
    // Use extcodesize to determine whether an address is a contract address
    function isContract(address account) internal view returns (bool) {
        uint size;
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
    }
}