// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * @dev ERC165 standard interface, see details
 * https://eips.ethereum.org/EIPS/eip-165[EIP].
 *
 * Contracts can declare supported interfaces for other contracts to check
 *
 */
interface IERC165 {
    /**
     * @dev If the contract implements the queried `interfaceId`, it returns true
     * For detailed rules, please see: https://eips.ethereum.org/EIPS/eip-165#how-interfaces-are-identified[EIP section]
     *
     */
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}