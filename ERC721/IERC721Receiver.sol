// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// ERC721 receiver interface: The contract must implement this interface to receive ERC721 through secure transfer
interface IERC721Receiver {
    function onERC721Received(
        address operator,
        address from,
        uint tokenId,
        bytes calldata data
    ) external returns (bytes4);
}