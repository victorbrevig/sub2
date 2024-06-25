// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "solmate/src/tokens/ERC721.sol";
import "openzeppelin-contracts/contracts/utils/Strings.sol";
import "openzeppelin-contracts/contracts/utils/Base64.sol";
import {Querier} from "./Querier.sol";

contract Sub2NFT is ERC721 {
    uint256 public currentTokenId;

    Querier public immutable sub2Querier;

    mapping(address => bool) public hasMinted;

    error NonExistentTokenURI();
    error NotSubscribed();
    error AlreadyMinted();

    constructor(string memory _name, string memory _symbol, address _sub2Querier) ERC721(_name, _symbol) {
        sub2Querier = Querier(_sub2Querier);
    }

    function mintTo(address recipient) public payable returns (uint256) {
        if (
            !sub2Querier.isPayedSubscriber(
                recipient,
                0x8bCAC48d9cC2075917e1F1A831Df954214f7d6f9,
                5000000,
                0x7139F4601480d20d43Fa77780B67D295805aD31a,
                2592000
            )
        ) {
            revert NotSubscribed();
        }
        if (hasMinted[recipient]) {
            revert AlreadyMinted();
        }
        uint256 newItemId = ++currentTokenId;
        _safeMint(recipient, newItemId);
        hasMinted[recipient] = true;
        return newItemId;
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        if (ownerOf(tokenId) == address(0)) {
            revert NonExistentTokenURI();
        }

        string memory json = Base64.encode(
            bytes(
                string.concat(
                    '{"name": "Sub2 Subscribed #',
                    Strings.toString(tokenId),
                    '", "description": "Sub2 Subscribed NFT',
                    '", "image": "ipfs://QmNPC1yjuzLyVpaDGUo1vcmXpXeSwck5aUMYmbYdEvKHtw"}'
                )
            )
        );
        return string.concat("data:application/json;base64,", json);
    }
}
