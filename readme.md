---
title: 38. NFT exchange
tags:
  - solidity
  - application
  -wtfacademy
  - ERC721
  - NFT Swap
---

# WTF Minimalist introduction to Solidity: 38. NFT exchange

I'm recently re-learning solidity, consolidating the details, and writing a "WTF Solidity Minimalist Introduction" for novices (programming experts can find another tutorial), updating 1-3 lectures every week.

Twitter: [@0xAA_Science](https://twitter.com/0xAA_Science)

discord: [WTF Academy](https://discord.gg/5akcruXrsk)

All codes and tutorials are open source on github: [github.com/AmazingAng/WTFSolidity](https://github.com/AmazingAng/WTFSolidity)

-----

`Opensea` is the largest `NFT` trading platform on Ethereum, with a total transaction volume of `$30 billion`. `Opensea` takes a `2.5%` commission on transactions, so it has made at least `$750 million` from user transactions. In addition, its operation is not decentralized and it is not prepared to issue coins to compensate users. `NFT` players have been suffering from `Opensea` for a long time. Today we use smart contracts to build a zero-fee decentralized `NFT` exchange: `NFTSwap`.

## Design logic

- Seller: The party selling `NFT` can place orders `list`, cancel orders `revoke`, and modify the price `update`.
- Buyer: The party who purchases `NFT` can purchase `purchase`.
- Order: `NFT` on-chain order issued by the seller. There is at most one order for the same `tokenId` in a series, which contains the pending order price `price` and the holder `owner` information. When an order is completed or canceled, the information is cleared.

## `NFTSwap` Contract

### event
The contract contains `4` events, corresponding to the four actions of placing orders `list`, canceling orders `revoke`, modifying the price `update`, and buying `purchase`:
``` solidity
    event List(address indexed seller, address indexed nftAddr, uint256 indexed tokenId, uint256 price);
    event Purchase(address indexed buyer, address indexed nftAddr, uint256 indexed tokenId, uint256 price);
    event Revoke(address indexed seller, address indexed nftAddr, uint256 indexed tokenId);    
    event Update(address indexed seller, address indexed nftAddr, uint256 indexed tokenId, uint256 newPrice);
```

### Order
The `NFT` order is abstracted into the `Order` structure, which contains the pending order price `price` and the holder `owner` information. The `nftList` mapping records the `NFT` series (contract address) and `tokenId` information corresponding to the order.
```solidity
    //Define order structure
    struct Order{
        address owner;
        uint256 price;
    }
    // NFT Order mapping
    mapping(address => mapping(uint256 => Order)) public nftList;
```

### Fallback function
In `NFTSwap`, users use `ETH` to purchase `NFT`. Therefore, the contract needs to implement the `fallback()` function to receive `ETH`.

```solidity
    fallback() external payable{}
```

### onERC721Received

The secure transfer function of `ERC721` will check whether the receiving contract implements the `onERC721Received()` function and returns the correct selector `selector`. After the user places an order, he needs to send the `NFT` to the `NFTSwap` contract. Therefore, `NFTSwap` inherits the `IERC721Receiver` interface and implements the `onERC721Received()` function:

```solidity
contract NFTSwap is IERC721Receiver{

    // Implement onERC721Received of {IERC721Receiver}, which can receive ERC721 tokens
    function onERC721Received(
        address operator,
        address from,
        uint tokenId,
        bytes calldata data
    ) external override returns (bytes4){
        return IERC721Receiver.onERC721Received.selector;
    }
```

### trade

The contract implements `4` transaction-related functions:

- Pending order `list()`: The seller creates `NFT` and creates an order, and releases the `List` event. The parameters are the `NFT` contract address `_nftAddr`, the `_tokenId` corresponding to `NFT`, and the pending order price `_price` (**Note: the unit is `wei`**). After success, the `NFT` will be transferred from the seller to the `NFTSwap` contract.

```solidity
    //Pending order: The seller lists NFT, the contract address is _nftAddr, the tokenId is _tokenId, and the price_price is Ethereum (unit is wei)
    function list(address _nftAddr, uint256 _tokenId, uint256 _price) public{
        IERC721 _nft = IERC721(_nftAddr); // Declare IERC721 interface contract variables
        require(_nft.getApproved(_tokenId) == address(this), "Need Approval"); // The contract is authorized
        require(_price > 0); // price is greater than 0

        Order storage _order = nftList[_nftAddr][_tokenId]; //Set NF holder and price
        _order.owner = msg.sender;
        _order.price = _price;
        // Transfer NFT to contract
        _nft.safeTransferFrom(msg.sender, address(this), _tokenId);

        // Release List event
        emit List(msg.sender, _nftAddr, _tokenId, _price);
    }
```

- Order cancellation `revoke()`: The seller withdraws the pending order and releases the `Revoke` event. The parameters are `NFT` contract address `_nftAddr` and `_tokenId` corresponding to `NFT`. Upon success, the `NFT` will be transferred back to the seller from the `NFTSwap` contract.
```solidity
    // Cancel order: The seller cancels the pending order
    function revoke(address _nftAddr, uint256 _tokenId) public {
        Order storage _order = nftList[_nftAddr][_tokenId]; // Get Order        
        require(_order.owner == msg.sender, "Not Owner"); // Must be initiated by the owner
        // Declare IERC721 interface contract variables
        IERC721 _nft = IERC721(_nftAddr);
        require(_nft.ownerOf(_tokenId) == address(this), "Invalid Order"); // NFT is in the contract
        
        // Transfer the NFT to the seller
        _nft.safeTransferFrom(address(this), msg.sender, _tokenId);
        delete nftList[_nftAddr][_tokenId]; // Delete order
      
        // Release the Revoke event
        emit Revoke(msg.sender, _nftAddr, _tokenId);
    }
```
- Modify price `update()`: The seller modifies the `NFT` order price and releases the `Update` event. The parameters are the `NFT` contract address `_nftAddr`, the `_tokenId` corresponding to `NFT`, and the updated pending order price `_newPrice` (**Note: the unit is `wei`**).
```solidity
    //Adjust price: The seller adjusts the price of the pending order
    function update(address _nftAddr, uint256 _tokenId, uint256 _newPrice) public {
        require(_newPrice > 0, "Invalid Price"); // NFT price is greater than 0
        Order storage _order = nftList[_nftAddr][_tokenId]; // Get Order        
        require(_order.owner == msg.sender, "Not Owner"); // Must be initiated by the owner
        // Declare IERC721 interface contract variables
        IERC721 _nft = IERC721(_nftAddr);
        require(_nft.ownerOf(_tokenId) == address(this), "Invalid Order"); // NFT is in the contract
        
        //Adjust NFT price
        _order.price = _newPrice;
      
        // Release Update event
        emit Update(msg.sender, _nftAddr, _tokenId, _newPrice);
    }
```

- Purchase `purchase`: The buyer pays `ETH` to purchase the `NFT` of the pending order and releases the `Purchase` event. The parameters are `NFT` contract address `_nftAddr` and `_tokenId` corresponding to `NFT`. Upon success, `ETH` will be transferred to the seller and `NFT` will be transferred to the buyer from the `NFTSwap` contract.
```solidity
    // Purchase: The buyer purchases NFT, the contract is _nftAddr, the tokenId is _tokenId, and ETH must be included when calling the function
    function purchase(address _nftAddr, uint256 _tokenId) payable public {
        Order storage _order = nftList[_nftAddr][_tokenId]; // Get Order        
        require(_order.price > 0, "Invalid Price"); // NFT price is greater than 0
        require(msg.value >= _order.price, "Increase price"); // The purchase price is greater than the list price
        // Declare IERC721 interface contract variables
        IERC721 _nft = IERC721(_nftAddr);
        require(_nft.ownerOf(_tokenId) == address(this), "Invalid Order"); // NFT is in the contract

        // Transfer the NFT to the buyer
        _nft.safeTransferFrom(address(this), msg.sender, _tokenId);
        // Transfer ETH to the seller, and refund the excess ETH to the buyer
        payable(_order.owner).transfer(_order.price);
        payable(msg.sender).transfer(msg.value-_order.price);

        delete nftList[_nftAddr][_tokenId]; // Delete order

        // Release the Purchase event
        emit Purchase(msg.sender, _nftAddr, _tokenId, _order.price);
    }
```

## `Remix` implementation

### 1. Deploy NFT contract
Refer to the [ERC721](https://github.com/AmazingAng/WTFSolidity/tree/main/34_ERC721) tutorial to learn about NFT and deploy the `WTFApe` NFT contract.

![Deploy NFT contract](./img/38-1.png)

Give yourself the first NFT mint. The mint given here is for you to be able to list the NFT, modify the price and other operations in the future.

The `mint(address to, uint tokenId)` method has 2 parameters:

`to`: Mint NFT to the specified address, which is usually your own wallet address.

`tokenId`: The `WTFApe` contract defines a total amount of 10,000 NFTs. In the figure, the first and second NFTs mint, `tokenId` is `0` and `1` respectively.

![mint NFT](./img/38-2.png)

In the `WTFApe` contract, use `ownerOf` to confirm that you have obtained the NFT with `tokenId` as 0.

The `ownerOf(uint tokenId)` method has 1 parameter:

`tokenId`: `tokenId` is the id of the NFT, in this case it is the `0`Id of the above mint.

![Confirm that you have obtained the NFT](./img/38-3.png)

According to the above method, mint NFTs with TokenId `0` and `1` to yourself. If `tokenId` is `0`, we will perform the update purchase operation. If `tokenId` is `1`, we will perform the delisting operation. operate.

### 2. Deploy `NFTSwap` contract
Deploy the `NFTSwap` contract.

![Deploy `NFTSwap` contract](./img/38-4.png)

### 3. Authorize the `NFT` to be listed to the `NFTSwap` contract
Call the `approve()` authorization function in the `WTFApe` contract to authorize the NFT with a `tokenId` of 0 that you hold to the `NFTSwap` contract address.

The `approve(address to, uint tokenId)` method has 2 parameters:

`to`: Authorize the tokenId to the `to` address. In this case, it will be authorized to the `NFTSwap` contract address.

`tokenId`: `tokenId` is the id of the NFT, in this case it is the `0`Id of the above mint.

![](./img/38-5.png)

According to the above method, the NFT with `tokenId` as `1` is also authorized to the `NFTSwap` contract address.

### 4. List `NFT`
Call the `list()` function of the `NFTSwap` contract to list the NFT with `tokenId` 0 that you hold on `NFTSwap`, and set the price to 1 `wei`.

The `list(address _nftAddr, uint256 _tokenId, uint256 _price)` method has 3 parameters:

`_nftAddr`: `_nftAddr` is the NFT contract address, in this case it is the `WTFApe` contract address.

`_tokenId`: `_tokenId` is the id of the NFT, in this case it is the `0`Id of the above mint.

`_price`: `_price` is the price of NFT, in this case it is 1 `wei`.

![](./img/38-6.png)

According to the above method, list the NFT with `tokenId` as 1 that you hold on `NFTSwap`, and set the price to 1 `wei`.

### 5. View listed NFTs

Call the `nftList()` function of the `NFTSwap` contract to view the listed NFTs.

`nftList`: is a mapping of NFT Order, with the following structure:

`nftList[_nftAddr][_tokenId]`: Input `_nftAddr` and `_tokenId`, and return an NFT order.

![](./img/38-7.png)

### 6. Update `NFT` price

Call the `update()` function of the `NFTSwap` contract to update the NFT price with `tokenId` as 0 to 77 `wei`

The `update(address _nftAddr, uint256 _tokenId, uint256 _newPrice)` method has 3 parameters:

`_nftAddr`: `_nftAddr` is the NFT contract address, in this case it is the `WTFApe` contract address.

`_tokenId`: `_tokenId` is the id of the NFT, in this case it is the `0`Id of the above mint.

`_newPrice`: `_newPrice` is the new price of NFT, in this case it is 77 `wei`.

After executing `update`, call `nftList` to view the updated price

![](./img/38-8.png)


### 5. Remove NFT from the shelves

Call the `revoke()` function of the `NFTSwap` contract to delist the NFT.

In the above article, we listed 2 NFTs, with `tokenId` being `0` and `1` respectively. In this method, we remove the NFT with `tokenId` as `1`.

The `revoke(address _nftAddr, uint256 _tokenId)` method has 2 parameters:

`_nftAddr`: `_nftAddr` is the NFT contract address, in this case it is the `WTFApe` contract address.

`_tokenId`: `_tokenId` is the id of the NFT, in this case it is the `1`Id of the above mint.

![](./img/38-9.png)

Calling the `nftList()` function of the `NFTSwap` contract, you can see that `NFT` has been removed from the shelves. Listing again requires re-authorization.

![](./img/38-10.png)

**Note that after delisting the NFT, you need to start from step 3 again and re-authorize and list the NFT before you can purchase it**

### 6. Purchase `NFT`

Switch accounts and call the `purchase()` function of the `NFTSwap` contract to purchase NFT. When purchasing, you need to enter the `NFT` contract address, `tokenId`, and enter the `ETH` for payment.

We have removed the NFT with `tokenId` as `1`, and there are still NFT with `tokenId` as `0`, so we can purchase the NFT with `tokenId` as `0`.

The `purchase(address _nftAddr, uint256 _tokenId, uint256 _wei)` method has 3 parameters:

`_nftAddr`: `_nftAddr` is the NFT contract address, in this case it is the `WTFApe` contract address.

`_tokenId`: `_tokenId` is the id of the NFT, in this case it is the `0`Id of the above mint.

`_wei`: `_wei` is the amount of `ETH` paid, in this case it is 77 `wei`.

![](./img/38-11.png)

### 7. Verify `NFT` holder change

After the purchase is successful, call the `ownerOf()` function of the `WTFApe` contract. You can see that the holder of the `NFT` changes and the purchase is successful!

![](./img/38-12.png)

## Summarize
In this lecture, we have established a decentralized `NFT` exchange with zero handling fees. Although `OpenSea` has made a great contribution to the development of `NFT`, its shortcomings are also very obvious: high handling fees, no coins to reward users, and the transaction mechanism is easily phished, resulting in the loss of user assets. Currently, new `NFT` trading platforms such as `Looksrare` and `dydx` are challenging the position of `OpenSea`, and `Uniswap` is also studying new `NFT` exchanges. I believe that in the near future, we will use a better NFT exchange.