// SPDX-License-Identifier: MIT
// by 0xAA
pragma solidity ^0.8.4;

import "./IERC165.sol";
import "./IERC721.sol";
import "./IERC721Receiver.sol";
import "./IERC721Metadata.sol";
import "./Address.sol";
import "./String.sol";

contract ERC721 is IERC721, IERC721Metadata{
    using Address for address; // Use the Address library and use isContract to determine whether the address is a contract
    using Strings for uint256; // Using the String library,

    //Token name
    string public override name;
    // Token code
    string public override symbol;
    // holder mapping from tokenId to owner address
    mapping(uint => address) private _owners;
    // Position mapping from address to position quantity
    mapping(address => uint) private _balances;
    //Authorization mapping from tokenID to authorized address
    mapping(uint => address) private _tokenApprovals;
    // owner address. Bulk authorization mapping to operator address
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    /**
     * Constructor, initialize `name` and `symbol`.
     */
    constructor(string memory name_, string memory symbol_) {
        name = name_;
        symbol = symbol_;
    }

    // Implement the IERC165 interface supportsInterface
    function supportsInterface(bytes4 interfaceId)
        external
        pure
        override
        returns (bool)
    {
        return
            interfaceId == type(IERC721).interfaceId ||
            interfaceId == type(IERC165).interfaceId ||
            interfaceId == type(IERC721Metadata).interfaceId;
    }

    // Implement the balanceOf of IERC721 and use the _balances variable to query the balance of the owner address.
    function balanceOf(address owner) external view override returns (uint) {
        require(owner != address(0), "owner = zero address");
        return _balances[owner];
    }

    // Implement the ownerOf of IERC721 and use the _owners variable to query the owner of tokenId.
    function ownerOf(uint tokenId) public view override returns (address owner) {
        owner = _owners[tokenId];
        require(owner != address(0), "token doesn't exist");
    }

    // Implement isApprovedForAll of IERC721, and use the _operatorApprovals variable to query whether the owner address has authorized the batch of NFTs held to the operator address.
    function isApprovedForAll(address owner, address operator)
        external
        view
        override
        returns (bool)
    {
        return _operatorApprovals[owner][operator];
    }

    // Implement IERC721's setApprovalForAll and authorize all tokens held to the operator address. Call the _setApprovalForAll function.
    function setApprovalForAll(address operator, bool approved) external override {
        _operatorApprovals[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }

    // Implement getApproved of IERC721 and use the _tokenApprovals variable to query the authorization address of tokenId.
    function getApproved(uint tokenId) external view override returns (address) {
        require(_owners[tokenId] != address(0), "token doesn't exist");
        return _tokenApprovals[tokenId];
    }
     
    // Authorization function. By adjusting _tokenApprovals, authorize the to address to operate tokenId and release the Approval event at the same time.
    function _approve(
        address owner,
        address to,
        uint tokenId
    ) private {
        _tokenApprovals[tokenId] = to;
        emit Approval(owner, to, tokenId);
    }

    // Implement IERC721 approve and authorize tokenId to the to address. Condition: to is not the owner, and msg.sender is the owner or authorized address. Call the _approve function.
    function approve(address to, uint tokenId) external override {
        address owner = _owners[tokenId];
        require(
            msg.sender == owner || _operatorApprovals[owner][msg.sender],
            "not owner nor approved for all"
        );
        _approve(owner, to, tokenId);
    }

    // Check whether the spender address can use tokenId (needs to be the owner or authorized address)
    function _isApprovedOrOwner(
        address owner,
        address spender,
        uint tokenId
    ) private view returns (bool) {
        return (spender == owner ||
            _tokenApprovals[tokenId] == spender ||
            _operatorApprovals[owner][spender]);
    }

    /*
     * Transfer function. Transfer the tokenId from from to to by adjusting the _balances and _owner variables, and release the Transfer event at the same time.
     * condition:
     * 1. tokenId is owned by from
     * 2. to is not the 0 address
     */
    function _transfer(
        address owner,
        address from,
        address to,
        uint tokenId
    ) private {
        require(from == owner, "not owner");
        require(to != address(0), "transfer to the zero address");

        _approve(owner, address(0), tokenId);

        _balances[from] -= 1;
        _balances[to] += 1;
        _owners[tokenId] = to;

        emit Transfer(from, to, tokenId);
    }
    
    // Implement transferFrom of IERC721, which is not a secure transfer and is not recommended. Call the _transfer function
    function transferFrom(
        address from,
        address to,
        uint tokenId
    ) external override {
        address owner = ownerOf(tokenId);
        require(
            _isApprovedOrOwner(owner, msg.sender, tokenId),
            "not owner nor approved"
        );
        _transfer(owner, from, to, tokenId);
    }

    /**
     * Secure transfer, securely transfer tokenId tokens from from to to, will check whether the contract recipient understands the ERC721 protocol to prevent tokens from being permanently locked. The _transfer function and _checkOnERC721Received function were called. condition:
     * from cannot be 0 address.
     * to cannot be the 0 address.
     * tokenId token must exist and be owned by from.
     * If to is a smart contract, it must support IERC721Receiver-onERC721Received.
     */
    function _safeTransfer(
        address owner,
        address from,
        address to,
        uint tokenId,
        bytes memory _data
    ) private {
        _transfer(owner, from, to, tokenId);
        require(_checkOnERC721Received(from, to, tokenId, _data), "not ERC721Receiver");
    }

    /**
     * Implement IERC721's safeTransferFrom, safe transfer, and call the _safeTransfer function.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint tokenId,
        bytes memory _data
    ) public override {
        address owner = ownerOf(tokenId);
        require(
            _isApprovedOrOwner(owner, msg.sender, tokenId),
            "not owner nor approved"
        );
        _safeTransfer(owner, from, to, tokenId, _data);
    }

    // safeTransferFrom overloaded function
    function safeTransferFrom(
        address from,
        address to,
        uint tokenId
    ) external override {
        safeTransferFrom(from, to, tokenId, "");
    }

    /** 
     * Casting function. Cast the tokenId and transfer it to to by adjusting the _balances and _owners variables, and release the Transfer event at the same time. Casting function. Cast the tokenId and transfer it to to by adjusting the _balances and _owners variables, and release the Transfer event at the same time.
     * This mint function can be called by everyone. Actual use requires developers to rewrite it and add some conditions.
     * condition:
     * 1. tokenId does not exist yet.
     * 2. to is not the 0 address.
     */
    function _mint(address to, uint tokenId) internal virtual {
        require(to != address(0), "mint to zero address");
        require(_owners[tokenId] == address(0), "token already minted");

        _balances[to] += 1;
        _owners[tokenId] = to;

        emit Transfer(address(0), to, tokenId);
    }

    // Destroy function, destroy tokenId by adjusting _balances and _owners variables, and release the Transfer event at the same time. Condition: tokenId exists.
    function _burn(uint tokenId) internal virtual {
        address owner = ownerOf(tokenId);
        require(msg.sender == owner, "not owner of token");

        _approve(owner, address(0), tokenId);

        _balances[owner] -= 1;
        delete _owners[tokenId];

        emit Transfer(owner, address(0), tokenId);
    }

    // _checkOnERC721Received: Function, used to call IERC721Receiver-onERC721Received when to is a contract, to prevent the tokenId from being accidentally transferred into the black hole.
    function _checkOnERC721Received(
        address from,
        address to,
        uint tokenId,
        bytes memory _data
    ) private returns (bool) {
        if (to.isContract()) {
            return
                IERC721Receiver(to).onERC721Received(
                    msg.sender,
                    from,
                    tokenId,
                    _data
                ) == IERC721Receiver.onERC721Received.selector;
        } else {
            return true;
        }
    }

    /**
     * Implement the tokenURI function of IERC721Metadata to query metadata.
     */
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_owners[tokenId] != address(0), "Token Not Exist");

        string memory baseURI = _baseURI();
        return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, tokenId.toString())) : "";
    }

    /**
     * Calculate the BaseURI of {tokenURI}. tokenURI is to splice baseURI and tokenId together and needs to be developed and rewritten.
     * The baseURI of BAYC is ipfs://QmeSjSinHpPnmXmspMjwiXyN6zS4E9zccariGR3jxcaWtq/
     */
    function _baseURI() internal view virtual returns (string memory) {
        return "";
    }
}