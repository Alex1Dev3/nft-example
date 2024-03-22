// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Token is ERC721Enumerable, Ownable {
    string public baseTokenURI;

    uint256 public constant maxSupply = 1000; // maximum allowed number of tokens
    uint256 public constant batchMintAmount = 6; // number of tokens in batch minting

    address public validator;
    uint256 public price; // price for single minting
    uint256 public batchPrice; // price for batch minting

    mapping(address => bool) enoughBatchMint; // for batch minting: one address - one batch mint

    event BatchMint(address indexed sender, uint256[] tokenIds); // event about batch minting for backend

    error NotEnoughCoins();
    error MaxAllocatableSupplyExceeded();
    error WrongSignature();
    error AlreadyBatchMint();

    constructor(
        address _validator,
        uint256 _price,
        uint256 _batchPrice,
        string memory _baseTokenURI
    ) ERC721("TEST", "TST") Ownable(_msgSender())
    {
        validator = _validator;
        price = _price;
        batchPrice = _batchPrice;
        baseTokenURI = _baseTokenURI;
    }

    function setBaseURI(string memory _baseTokenURI)
    external onlyOwner
    {
        baseTokenURI = _baseTokenURI;
    }

    function setValidator(address _validator)
    external onlyOwner
    {
        validator = _validator;
    }

    // single minting by user
    function mint()
    external payable
    {
        if (msg.value < price) {
            revert NotEnoughCoins();
        }
        if (totalSupply() + 1 > maxSupply) {
            revert MaxAllocatableSupplyExceeded();
        }

        _mint(_msgSender(), totalSupply() + 1);
    }

    // single minting via validator
    function signedMint(bytes calldata _signature)
    external
    {
        if (totalSupply() + 1 > maxSupply) {
            revert MaxAllocatableSupplyExceeded();
        }

        bytes32 hash = getHash(_msgSender(), totalSupply()); // using current amount of tokens (totalSupply) as nonce
        if (_recoverSigner(hash, _signature) != validator) { // verification of signature signer and validator
            revert WrongSignature();
        }

        _mint(_msgSender(), totalSupply() + 1);
    }

    // batch minting by user
    function mintBatch()
    external payable
    {
        if (msg.value < batchPrice) {
            revert NotEnoughCoins();
        }
        if (totalSupply() + batchMintAmount > maxSupply) {
            revert MaxAllocatableSupplyExceeded();
        }
        if (enoughBatchMint[_msgSender()]) {
            revert AlreadyBatchMint();
        }

        uint256[] memory tokenIds = new uint256[](batchMintAmount);

        for (uint256 i = 0; i < batchMintAmount; i++) {
            tokenIds[i] = totalSupply() + 1;
            _mint(_msgSender(), totalSupply() + 1);
        }

        enoughBatchMint[_msgSender()] = true;

        emit BatchMint(_msgSender(), tokenIds);
    }

    // generating hash for signature
    function getHash(
        address _address,
        uint256 _nonce // used to make signature unique
    )
    public pure
    returns (bytes32)
    {
        return keccak256(abi.encodePacked(_address, _nonce));
    }

    // getting the hash signer address from signature
    function _recoverSigner(
        bytes32 _hash,
        bytes memory _signature
    )
    internal pure
    returns (address)
    {
        bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(_hash);
        return ECDSA.recover(ethSignedMessageHash, _signature);
    }

    function _baseURI()
    internal view override
    returns (string memory)
    {
        return baseTokenURI;
    }
}