// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";


contract StrangersNFT is ERC721Enumerable, ERC721Burnable, Ownable, ReentrancyGuard {

    // Résolution d'un conflit 
    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC721Enumerable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    //Pour increment l'id des NFTs
    using Counters for Counters.Counter;

    //Pour concaténer l'URL d'un NFT
    using Strings for uint256;

    //Pour vérifier les adresses dans la whitelist
    bytes32 public merkleRoot;

    //Id du prochain NFT à minté
    Counters.Counter private _nftIdCounter;

    //Le nombre de NFTs dans la collection
    uint public constant MAX_SUPPLY = (?);
    //Le nombre maximum de NFTs qu'une adresse peut mint
    uint public max_mint_allowed = (?);
    //Prix d'un NFT pendant la presale
    uint public pricePresale = (?) ether;
    //Prix d'un NFT pendant la sale
    uint public priceSale = (?) ether;

    //URI des NFTs quand ils sont reveal
    string public baseURI;
    //URI des NFTs quand ils ne sont pas reveal
    string public notRevealedURI;
    //L'extension du fichier ayant les métadonnées des NFTs
    string public baseExtension = ".json";

    //Les NFTs sont-ils révélés ?
    bool public revealed = false;

    //Le contrat est-il en pause ?
    bool public paused = false;

    //Les différentes étapes de la vente de la collection
    enum Steps {
        Before,
        Presale,
        Sale,
        SoldOut,
        Reveal
    }

    Steps public sellingStep;
    
    //Owner du smart contract
    address private _owner;

    //Garder une trace du nombre de tokens par adresse
    mapping(address => uint) nftsPerWallet;

    //Constructeur de la collection
    constructor(string memory _theBaseURI, string memory _notRevealedURI, bytes32 _merkleRoot) ERC721("Strangers NFT", "Strangers") {
        _nftIdCounter.increment();
        transferOwnership(msg.sender);
        sellingStep = Steps.Before;
        baseURI = _theBaseURI;
        notRevealedURI = _notRevealedURI;
        merkleRoot = _merkleRoot;
    }

    //Editer la racine de Merkle
    function changeMerkleRoot(bytes32 _newMerkleRoot) external onlyOwner {
        merkleRoot = _newMerkleRoot;
    }

    //Définir la pause du contrat
    function setPaused(bool _paused) external onlyOwner {
        paused = _paused;
    }

    //Pour modifier le nombre de NFT qu'une adresse peut minté
    function changeMaxMintAllowed(uint _maxMintAllowed) external onlyOwner {
        max_mint_allowed = _maxMintAllowed;
    }

    //Modifier le prix d'un NFT pour la presale
    function changePricePresale(uint _pricePresale) external onlyOwner {
        pricePresale = _pricePresale;
    }

    //Modifier le prix d'un NFT pour la sale
    function changePriceSale(uint _priceSale) external onlyOwner {
        priceSale = _priceSale;
    }

    //Modifier l'URI
    function setBaseUri(string memory _newBaseURI) external onlyOwner {
        baseURI = _newBaseURI;
    }

    //Modifier l'URI notReveal
    function setNotRevealURI(string memory _notRevealedURI) external onlyOwner {
        notRevealedURI = _notRevealedURI;
    }

    //Pour mettre la variable reveal à true
    function reveal() external onlyOwner{
        revealed = true;
    }

    //Retourne l'URI des NFTs quand ils sont révélés
    function _baseURI() internal view virtual override returns (string memory) {
        return baseURI;
    }

    //Pour changer l'extension du fichiers des métadonnées
    function setBaseExtension(string memory _baseExtension) external onlyOwner {
        baseExtension = _baseExtension;
    }


    //Pour changer l'étape de vente en Presale
    function setUpPresale() external onlyOwner {
        sellingStep = Steps.Presale;
    }


    //Pour changer l'étape de vente en sale
    function setUpSale() external onlyOwner {
        require(sellingStep == Steps.Presale, "First the presale, then the sale.");
        sellingStep = Steps.Sale;
    }

    //Pour minté un NFT si l'utilisateur est dans la whitelist
    function presaleMint(address _account, bytes32[] calldata _proof) external payable nonReentrant {
        //Vérifie si on est en presale ?
        require(sellingStep == Steps.Presale, "Presale has not started yet.");
        //Vérifie si l'utilisateur à déjà minté un NFT
        require(nftsPerWallet[_account] < 1, "You can only get 1 NFT on the Presale");
        //Vérifie si l'utilisateur est dans la whitelist
        require(isWhiteListed(_account, _proof), "Not on the whitelist");
        //On récupère le prix d'un NFT en presale
        uint price = pricePresale;
        //On vérifie si l'utilisateur à envoyé assez d'ethers
        require(msg.value >= price, "Not enought funds.");
        //On incrémente le nombre de NFTs que l'utilisateur à minté
        nftsPerWallet[_account]++;
        //On mint le NFT de l'utilisateur
        _safeMint(_account, _nftIdCounter.current());
        //On incrémente l'Id du prochain NFT à mint
        _nftIdCounter.increment();
    }

    //Pour minté les NFTs
    function saleMint(uint256 _ammount) external payable nonReentrant {
        //On réccupère le nombre de NFT vendus
        uint numberNftSold = totalSupply();
        //On récupère le prix d'un NFT en sale
        uint price = priceSale;
        //Si tout les NFTs sont achetés
        require(sellingStep != Steps.SoldOut, "Sorry, no NFTs left.");
        //Si la sale n'a pas encore commencé
        require(sellingStep == Steps.Sale, "Sorry, sale has not started yet.");
        //Vérifie si l'utilisateur à assez d'ethers pour acheter
        require(msg.value >= price * _ammount, "Not enought funds.");
        //L'utilisateur ne peut mint que un certain montant de NFTs
        require(_ammount <= max_mint_allowed, "You can't mint more than (?) tokens");
        //Si l'utilisateur essaye de minté un token non existant
        require(numberNftSold + _ammount <= MAX_SUPPLY, "Sale is almost done and we don't have enought NFTs left.");
        //On incrémente le montant de NFTs minté par l'utilisateur
        nftsPerWallet[msg.sender] += _ammount;
        //Si l'utilisateur à minté le dernier NFTs disponible
        if(numberNftSold + _ammount == MAX_SUPPLY) {
            sellingStep = Steps.SoldOut;   
        }
        //Minting all the account NFTs
        for(uint i = 1 ; i <= _ammount ; i++) {
            _safeMint(msg.sender, numberNftSold + i);
        }
    }

    //Pour burn un NFT
    function burn(uint _nftId) public virtual override onlyOwner {
        _burn(_nftId);
    }

    //Retourne true or false si le compte est sur la whitelist ou non
    function isWhiteListed(address account, bytes32[] calldata proof) internal view returns(bool) {
        return _verify(_leaf(account), proof);
    }

    
    //Retourne le hash du compte
    function _leaf(address account) internal pure returns(bytes32) {
        return keccak256(abi.encodePacked(account));
    }

    //Retourne true si on peut prouver que la leaf fait partie de l'arbre de Merkle
    function _verify(bytes32 leaf, bytes32[] memory proof) internal view returns(bool) {
        return MerkleProof.verify(proof, merkleRoot, leaf);
    }

    
    //Pour avoir l'URI complète d'un NFT spécifique avec son ID
    function tokenURI(uint _nftId) public view override(ERC721) returns (string memory) {
        require(_exists(_nftId), "This NFT doesn't exist.");
        if(revealed == false) {
            return notRevealedURI;
        }
        
        string memory currentBaseURI = _baseURI();
        return 
            bytes(currentBaseURI).length > 0 
            ? string(abi.encodePacked(currentBaseURI, _nftId.toString(), baseExtension))
            : "";
    }

    //Pour retirer l'argent
    function withdraw() public payable onlyOwner {    
        (bool success, ) = payable(owner()).call{value: address(this).balance}("");
        require(success);
    }
}
