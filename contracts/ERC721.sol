//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.15;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./utils/BitMaps.sol";

import "hardhat/console.sol";

// Address(0) is an invalid input
error InvalidInputZeroAddress();
// Msg.sender is not approved to spend tokens or is not owner
error IsNotApprovedOrOwner();
// Token doesn't exist
error TokenDoesNotExist();
// Token already exists
error TokenAlreadyExists();
// Transfer to non ERC721Receiver implementer
error NonERC721Receiver();
// Max supply has been reached
error MaxSupplyReached();
// Not enough ETH to mint
error NotEnoughETHtoMint();
// mint is over
error MintIsOver();
// Can't Approve to caller
error FromCantBeTo();
// Can't call function twice
error CantCallTwice();
// Can't Withdraw
error WithdrawlFailed();
// Must Mint More then 0
error MintLessThan1();
// No Tokens have been minted
error MintHasNotStarted();
// caller has no tokens
error HoldingZeroTokens();

/// @author Ebrahim Elbagory
/// @title ERC721
contract ERC721 is
  IERC721,
  ERC165,
  Ownable,
  IERC721Enumerable,
  IERC721Metadata
{
  using Address for address;
  using Strings for uint256;
  using BitMaps for BitMaps.BitMap;

  BitMaps.BitMap private _batchHead;

  //dividen var
  mapping(address => uint256) credit;
  uint256 dividendPerToken;
  mapping(address => uint256) xDividendPerToken;

  string private _name;
  string private _symbol;
  string private _baseTokenURI;
  uint8 private immutable _maxMint;
  //price per nft
  uint256 private immutable _pricePerToken = 1e17;
  bool internal withdrawIsLocked;

  // Mapping from token ID to owner address
  mapping(uint256 => address) private _owners;
  uint256 internal _minted;

  // Mapping from token ID to approved address
  mapping(uint256 => address) private _tokenApprovals;

  // Mapping from owner to operator approvals
  mapping(address => mapping(address => bool)) private _operatorApprovals;

  event WithdrawAndLock(bool _withdrawAndLock);
  event withdrawlMade(address indexed withdrawer, uint256 amount);

  receive() external payable {
    if (withdrawIsLocked) updateDividendPerToken();
  }

  constructor(
    string memory name_,
    string memory symbol_,
    string memory baseTokenURI_,
    uint8 maxMint_
  ) {
    _name = name_;
    _symbol = symbol_;
    _baseTokenURI = baseTokenURI_;
    _maxMint = maxMint_;
  }

  function name() public view returns (string memory) {
    return _name;
  }

  function symbol() public view returns (string memory) {
    return _symbol;
  }

  function balanceOf(address owner)
    public
    view
    virtual
    override
    returns (uint256)
  {
    if (owner == address(0)) revert InvalidInputZeroAddress();
    uint256 count;
    for (uint256 i; i < _minted; ++i) {
      if (_exists(i)) {
        if (owner == ownerOf(i)) {
          ++count;
        }
      }
    }
    return count;
  }

  function withdrawAndLock() external onlyOwner {
    if (withdrawIsLocked) revert CantCallTwice();
    withdrawIsLocked = true;
    payable(owner()).transfer(address(this).balance);
    emit WithdrawAndLock(withdrawIsLocked);
  }

  function ownerOf(uint256 tokenId)
    public
    view
    virtual
    override
    returns (address)
  {
    (address owner, ) = _ownerAndBatchHeadOf(tokenId);
    return owner;
  }

  function _ownerAndBatchHeadOf(uint256 tokenId)
    internal
    view
    returns (address owner, uint256 tokenIdBatchHead)
  {
    if (!_exists(tokenId)) revert TokenDoesNotExist();
    tokenIdBatchHead = _getBatchHead(tokenId);
    owner = _owners[tokenIdBatchHead];
  }

  function maxMint() public view returns (uint8) {
    return _maxMint;
  }

  function pricePerToken() public pure returns (uint256) {
    return _pricePerToken;
  }

  function safeTransferFrom(
    address from,
    address to,
    uint256 tokenId
  ) public virtual override {
    safeTransferFrom(from, to, tokenId, "");
  }

  function mint(uint256 _numToMint) public payable {
    if (_numToMint > _maxMint) revert MaxSupplyReached();
    if (msg.value < (_pricePerToken * _numToMint)) revert NotEnoughETHtoMint();
    if (withdrawIsLocked) revert MintIsOver();

    _withdrawToCredit(msg.sender);
    _safeMint(msg.sender, _numToMint);
  }

  function safeTransferFrom(
    address from,
    address to,
    uint256 tokenId,
    bytes memory data
  ) public virtual override {
    if (!_isApprovedOrOwner(_msgSender(), tokenId))
      revert IsNotApprovedOrOwner();
    if (to == from) revert FromCantBeTo();
    _safeTransfer(from, to, tokenId, data);
  }

  function transferFrom(
    address from,
    address to,
    uint256 tokenId
  ) public virtual override {
    if (!_isApprovedOrOwner(_msgSender(), tokenId))
      revert IsNotApprovedOrOwner();
    _transfer(from, to, tokenId);
  }

  function approve(address operator, uint256 tokenId) public virtual override {
    address owner = ownerOf(tokenId);
    if (operator == _msgSender()) revert FromCantBeTo();

    if (!_isApprovedOrOwner(_msgSender(), tokenId) || msg.sender != owner)
      revert IsNotApprovedOrOwner();

    _approve(operator, tokenId);
  }

  function setApprovalForAll(address operator, bool approved)
    public
    virtual
    override
  {
    if (operator == _msgSender()) revert FromCantBeTo();

    _operatorApprovals[_msgSender()][operator] = approved;
    emit ApprovalForAll(_msgSender(), operator, approved);
  }

  function getApproved(uint256 tokenId)
    public
    view
    virtual
    override
    returns (address)
  {
    if (!_exists(tokenId)) revert TokenDoesNotExist();

    return _tokenApprovals[tokenId];
  }

  function _exists(uint256 tokenId) internal view virtual returns (bool) {
    return tokenId < _minted;
  }

  function _safeTransfer(
    address from,
    address to,
    uint256 tokenId,
    bytes memory data
  ) internal virtual {
    _transfer(from, to, tokenId);
    if (!_checkOnERC721Received(from, to, tokenId, 1, data))
      revert NonERC721Receiver();
  }

  function _transfer(
    address from,
    address to,
    uint256 tokenId
  ) internal virtual {
    (address owner, uint256 tokenIdBatchHead) = _ownerAndBatchHeadOf(tokenId);

    if (owner != from) revert IsNotApprovedOrOwner();
    if (to == address(0)) revert InvalidInputZeroAddress();

    _beforeTokenTransfer(from, to, tokenId, 1);

    // Clear approvals from the previous owner
    _approve(address(0), tokenId);

    uint256 nextTokenId = tokenId + 1;

    if (!_batchHead.get(nextTokenId) && nextTokenId < _minted) {
      _owners[nextTokenId] = from;
      _batchHead.set(nextTokenId);
    }

    _owners[tokenId] = to;
    if (tokenId != tokenIdBatchHead) {
      _batchHead.set(tokenId);
    }

    emit Transfer(from, to, tokenId);

    _afterTokenTransfer(from, to, tokenId, 1);
  }

  function isApprovedForAll(address owner, address operator)
    public
    view
    virtual
    override
    returns (bool)
  {
    return _operatorApprovals[owner][operator];
  }

  function _isApprovedOrOwner(address spender, uint256 tokenId)
    internal
    view
    virtual
    returns (bool)
  {
    if (!_exists(tokenId)) revert TokenDoesNotExist();
    address owner = ownerOf(tokenId);
    return (spender == owner ||
      getApproved(tokenId) == spender ||
      isApprovedForAll(owner, spender));
  }

  function _setApprovalForAll(
    address owner,
    address operator,
    bool approved
  ) internal virtual {
    if (owner == operator) revert FromCantBeTo();
    _operatorApprovals[owner][operator] = approved;
    emit ApprovalForAll(owner, operator, approved);
  }

  function _safeMint(address to, uint256 quantity) internal virtual {
    _safeMint(to, quantity, "");
  }

  function _safeMint(
    address to,
    uint256 quantity,
    bytes memory _data
  ) internal virtual {
    uint256 startTokenId = _minted;
    _mint(to, quantity);
    if (!_checkOnERC721Received(address(0), to, startTokenId, quantity, _data))
      revert NonERC721Receiver();
  }

  function _mint(address to, uint256 quantity) internal virtual {
    uint256 tokenIdBatchHead = _minted;

    if (quantity <= 0) revert MintLessThan1();
    if (to == address(0)) revert InvalidInputZeroAddress();

    _beforeTokenTransfer(address(0), to, tokenIdBatchHead, quantity);
    _minted += quantity;
    _owners[tokenIdBatchHead] = to;
    _batchHead.set(tokenIdBatchHead);
    _afterTokenTransfer(address(0), to, tokenIdBatchHead, quantity);

    // Emit events
    for (
      uint256 tokenId = tokenIdBatchHead;
      tokenId < tokenIdBatchHead + quantity;
      tokenId++
    ) {
      emit Transfer(address(0), to, tokenId);
    }
  }

  function _afterTokenTransfer(
    address from,
    address to,
    uint256 startTokenId,
    uint256 quantity
  ) internal virtual {}

  function _beforeTokenTransfer(
    address from,
    address to,
    uint256 startTokenId,
    uint256 quantity
  ) internal virtual {}

  function _approve(address to, uint256 tokenId) internal virtual {
    _tokenApprovals[tokenId] = to;
    emit Approval(ownerOf(tokenId), to, tokenId);
  }

  // ENUMERATION
  /**
   * @dev See {IERC721Enumerable-totalSupply}.
   */
  function totalSupply() public view virtual override returns (uint256) {
    return _minted;
  }

  /**
   * @dev See {IERC721Enumerable-tokenByIndex}.
   */
  function tokenByIndex(uint256 index)
    public
    view
    virtual
    returns (uint256 count)
  {
    if (index > totalSupply()) revert TokenDoesNotExist();

    for (uint256 i; i < _minted; i++) {
      if (_exists(i)) {
        if (count == index) return i;
        else count++;
      }
    }
  }

  /**
   * @dev See {IERC721Enumerable-tokenOfOwnerByIndex}.
   */
  function tokenOfOwnerByIndex(address owner, uint256 index)
    public
    view
    virtual
    returns (uint256 tokenId)
  {
    uint256 count;
    for (uint256 i; i < _minted; i++) {
      if (_exists(i) && owner == ownerOf(i)) {
        if (count == index) return i;
        else count++;
      }
    }

    revert("ERC721: owner index out of bounds");
  }

  function _getBatchHead(uint256 tokenId)
    internal
    view
    returns (uint256 tokenIdBatchHead)
  {
    tokenIdBatchHead = _batchHead.scanForward(tokenId);
  }

  //TOKEN URI

  function baseURI() public view returns (string memory) {
    return _baseURI();
  }

  function _baseURI() internal view virtual returns (string memory) {
    return _baseTokenURI;
  }

  function tokenURI(uint256 tokenId)
    public
    view
    virtual
    returns (string memory)
  {
    if (!_exists(tokenId)) revert TokenDoesNotExist();

    string memory baseURI_ = _baseURI();

    return
      bytes(baseURI_).length != 0
        ? string(abi.encodePacked(baseURI_, tokenId.toString()))
        : "";
  }

  //--------------------------------------------------------------

  function updateDividendPerToken() internal {
    if (totalSupply() == 0) revert MintHasNotStarted();
    dividendPerToken += msg.value / totalSupply();
  }

  function withdraw() external {
    uint256 holderBalance = balanceOf(_msgSender());
    if (holderBalance == 0) revert HoldingZeroTokens();

    uint256 amount = dividendEarned(msg.sender);
    credit[_msgSender()] = 0;
    xDividendPerToken[_msgSender()] = dividendPerToken;

    (bool success, ) = payable(_msgSender()).call{ value: amount }("");

    if (!success) revert WithdrawlFailed();
    emit withdrawlMade(msg.sender, amount);
  }

  function _withdrawToCredit(address to_) private {
    uint256 recipientBalance = balanceOf(to_);
    uint256 amount = (dividendPerToken - xDividendPerToken[to_]) *
      recipientBalance;
    credit[to_] += amount;
    xDividendPerToken[to_] = dividendPerToken;
  }

  function dividendEarned(address _user) public view returns (uint256) {
    uint256 holderBalance = balanceOf(_user);
    uint256 amount = ((dividendPerToken - xDividendPerToken[_user]) *
      holderBalance);
    amount += credit[_user];

    return amount;
  }

  /**
   * @dev Internal function to invoke {IERC721Receiver-onERC721Received} on a target address.
   * The call is not executed if the target address is not a contract.
   *
   * @param from address representing the previous owner of the given token ID
   * @param to target address that will receive the tokens
   * @param startTokenId uint256 the first ID of the tokens to be transferred
   * @param quantity uint256 amount of the tokens to be transfered.
   * @param _data bytes optional data to send along with the call
   * @return r bool whether the call correctly returned the expected magic value
   */
  function _checkOnERC721Received(
    address from,
    address to,
    uint256 startTokenId,
    uint256 quantity,
    bytes memory _data
  ) private returns (bool r) {
    if (to.isContract()) {
      r = true;
      for (
        uint256 tokenId = startTokenId;
        tokenId < startTokenId + quantity;
        tokenId++
      ) {
        try
          IERC721Receiver(to).onERC721Received(
            _msgSender(),
            from,
            tokenId,
            _data
          )
        returns (bytes4 retval) {
          r = r && retval == IERC721Receiver.onERC721Received.selector;
        } catch (bytes memory reason) {
          if (reason.length == 0) {
            revert("ERC721: transfer to non ERC721Receiver implementer");
          } else {
            assembly {
              revert(add(32, reason), mload(reason))
            }
          }
        }
      }
      return r;
    } else {
      return true;
    }
  }
}
