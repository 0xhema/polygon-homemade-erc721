//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.15;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "hardhat/console.sol";

// Address(0) is an invalid input
error InvalidInputZeroAddress();
// Msg.sender is not approved to spend tokens or is not owner
error IsNotApprovedOrOwner();
// Token doesn't exist
error TokenDoesNotExist();
// Token doesn't exist
error TokenAlreadyExists();
// Transfer to non ERC721Receiver implementer
error NonERC721Receiver();

interface DividendPayingTokenInterface {
  /// @notice View the amount of dividend in wei that an address can withdraw.
  /// @param _owner The address of a token holder.
  /// @return The amount of dividend in wei that `_owner` can withdraw.
  function dividendOf(address _owner) external view returns (uint256);

  /// @notice Distributes ether to token holders as dividends.
  /// @dev SHOULD distribute the paid ether to token holders as dividends.
  ///  SHOULD NOT directly transfer ether to token holders in this function.
  ///  MUST emit a `DividendsDistributed` event when the amount of distributed ether is greater than 0.
  function distributeDividends() external payable;

  /// @notice Withdraws the ether distributed to the sender.
  /// @dev SHOULD transfer `dividendOf(msg.sender)` wei to `msg.sender`, and `dividendOf(msg.sender)` SHOULD be 0 after the transfer.
  ///  MUST emit a `DividendWithdrawn` event if the amount of ether transferred is greater than 0.
  function withdrawDividend() external;

  /// @dev This event MUST emit when ether is distributed to token holders.
  /// @param from The address which sends ether to this contract.
  /// @param weiAmount The amount of distributed ether in wei.
  event DividendsDistributed(address indexed from, uint256 weiAmount);

  /// @dev This event MUST emit when an address withdraws their dividend.
  /// @param to The address which withdraws ether from this contract.
  /// @param weiAmount The amount of withdrawn ether in wei.
  event DividendWithdrawn(address indexed to, uint256 weiAmount);
}

/// @author Ebrahim Elbagory
/// @title ERC721
contract ERC721 is IERC721, ERC165, Ownable {
  using Address for address;
  using Strings for uint256;
  using SafeMathUint for uint256;
  using SafeMathInt for int256;
  using SafeMath for uint256;

  string private _name;
  string private _symbol;
  string private _baseTokenURI;
  uint8 private immutable _maxMint;
  //price per nft
  uint256 private immutable _pricePerToken = 1e16;
  // Mapping from token ID to owner address
  mapping(uint256 => address) private _owners;

  // Mapping owner address to token count
  mapping(address => uint256) private _balances;

  // Mapping from token ID to approved address
  mapping(uint256 => address) private _tokenApprovals;

  // Mapping from owner to operator approvals
  mapping(address => mapping(address => bool)) private _operatorApprovals;

  // Mapping from owner to list of owned token IDs (IERC721-Enumerable)
  mapping(address => mapping(uint256 => uint256)) private _ownedTokens;

  // Mapping from token ID to index of the owner tokens list  (IERC721-Enumerable)
  mapping(uint256 => uint256) private _ownedTokensIndex;

  // Array with all token ids, used for enumeration (IERC721-Enumerable)
  uint256[] private _allTokens;

  // Mapping from token id to position in the allTokens array (IERC721-Enumerable)
  mapping(uint256 => uint256) private _allTokensIndex;

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
    return _balances[owner];
  }

  function ownerOf(uint256 tokenId)
    public
    view
    virtual
    override
    returns (address)
  {
    address owner = _owners[tokenId];
    if (owner == address(0)) revert TokenDoesNotExist();
    return owner;
  }

  function maxMint() public view returns (uint8) {
    return _maxMint;
  }

  function pricePerToken() public view returns (uint256) {
    return _pricePerToken;
  }

  function safeTransferFrom(
    address from,
    address to,
    uint256 tokenId
  ) public virtual override {
    safeTransferFrom(from, to, tokenId, "");
  }

  function mint(uint256 _numToMint) public payable returns (uint256) {
    require(_numToMint < _maxMint, "You can mint a maximum of ${_maxMint}");
    require(
      msg.value >= _pricePerToken * _numToMint,
      "Not enough ETH sent, check price"
    );

    for (uint256 i; i < _numToMint; i++) {
      _withdrawToCredit(msg.sender);
      uint256 mintIndex = totalSupply();
      _safeMint(msg.sender, mintIndex, "");
    }

    return _allTokens.length;
  }

  function safeTransferFrom(
    address from,
    address to,
    uint256 tokenId,
    bytes memory data
  ) public virtual override {
    if (!_isApprovedOrOwner(_msgSender(), tokenId))
      revert IsNotApprovedOrOwner();
    _safeTransfer(from, to, tokenId, data);
  }

  function transferFrom(
    address from,
    address to,
    uint256 tokenId
  ) public virtual override {
    _transfer(from, to, tokenId);
  }

  function approve(address to, uint256 tokenId) public virtual override {
    address owner = ERC721.ownerOf(tokenId);
    require(to != owner, "ERC721: approval to current owner");

    if (_msgSender() != owner) revert IsNotApprovedOrOwner();

    _approve(to, tokenId);
  }

  function setApprovalForAll(address operator, bool approved)
    public
    virtual
    override
  {
    _setApprovalForAll(_msgSender(), operator, approved);
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

  function isApprovedForAll(address owner, address operator)
    public
    view
    virtual
    override
    returns (bool)
  {
    return _operatorApprovals[owner][operator];
  }

  function _exists(uint256 tokenId) internal view virtual returns (bool) {
    return _owners[tokenId] != address(0);
  }

  function _safeTransfer(
    address from,
    address to,
    uint256 tokenId,
    bytes memory data
  ) internal virtual {
    _transfer(from, to, tokenId);
    require(
      _checkOnERC721Received(from, to, tokenId, data),
      "ERC721: transfer to non ERC721Receiver implementer"
    );
  }

  function _transfer(
    address from,
    address to,
    uint256 tokenId
  ) internal virtual {
    if (
      !_isApprovedOrOwner(_msgSender(), tokenId) ||
      ERC721.ownerOf(tokenId) != from
    ) revert IsNotApprovedOrOwner();

    if (to == address(0)) revert InvalidInputZeroAddress();
    _withdrawToCredit(to);
    _withdrawToCredit(from);
    _beforeTokenTransfer(from, to, tokenId);

    // Clear approvals from the previous owner
    _approve(address(0), tokenId);

    _balances[from] -= 1;
    _balances[to] += 1;
    _owners[tokenId] = to;

    emit Transfer(from, to, tokenId);

    _afterTokenTransfer(from, to, tokenId);
  }

  function _isApprovedOrOwner(address spender, uint256 tokenId)
    internal
    view
    virtual
    returns (bool)
  {
    if (!_exists(tokenId)) revert TokenDoesNotExist();
    address owner = ERC721.ownerOf(tokenId);
    return (spender == owner ||
      isApprovedForAll(owner, spender) ||
      getApproved(tokenId) == spender);
  }

  function _setApprovalForAll(
    address owner,
    address operator,
    bool approved
  ) internal virtual {
    require(owner != operator, "ERC721: approve to caller");
    _operatorApprovals[owner][operator] = approved;
    emit ApprovalForAll(owner, operator, approved);
  }

  function _safeMint(
    address to,
    uint256 tokenId,
    bytes memory data
  ) internal virtual {
    _mint(to, tokenId);
    if (!_checkOnERC721Received(address(0), to, tokenId, data))
      revert NonERC721Receiver();
  }

  function _checkOnERC721Received(
    address from,
    address to,
    uint256 tokenId,
    bytes memory data
  ) private returns (bool) {
    if (to.isContract()) {
      try
        IERC721Receiver(to).onERC721Received(_msgSender(), from, tokenId, data)
      returns (bytes4 retval) {
        return retval == IERC721Receiver.onERC721Received.selector;
      } catch (bytes memory reason) {
        if (reason.length == 0) {
          revert("ERC721: transfer to non ERC721Receiver implementer");
        } else {
          /// @solidity memory-safe-assembly
          assembly {
            revert(add(32, reason), mload(reason))
          }
        }
      }
    } else {
      return true;
    }
  }

  function _mint(address to, uint256 tokenId) internal virtual {
    if (to == address(0)) revert InvalidInputZeroAddress();
    console.log("tokenID", tokenId);
    if (_exists(tokenId)) revert TokenAlreadyExists();

    _beforeTokenTransfer(address(0), to, tokenId);

    _balances[to] += 1;
    _owners[tokenId] = to;

    emit Transfer(address(0), to, tokenId);

    _afterTokenTransfer(address(0), to, tokenId);
  }

  function _afterTokenTransfer(
    address from,
    address to,
    uint256 tokenId
  ) internal virtual {}

  function _beforeTokenTransfer(
    address from,
    address to,
    uint256 tokenId
  ) internal virtual {
    if (from == address(0)) {
      _addTokenToAllTokensEnumeration(tokenId);
    } else if (from != to) {
      _removeTokenFromOwnerEnumeration(from, tokenId);
    }
    if (to == address(0)) {
      _removeTokenFromAllTokensEnumeration(tokenId);
    } else if (to != from) {
      _addTokenToOwnerEnumeration(to, tokenId);
    }
  }

  function _approve(address to, uint256 tokenId) internal virtual {
    _tokenApprovals[tokenId] = to;
    emit Approval(ERC721.ownerOf(tokenId), to, tokenId);
  }

  // ENUMERATION

  function tokenOfOwnerByIndex(address owner, uint256 index)
    public
    view
    virtual
    returns (uint256)
  {
    require(
      index < ERC721.balanceOf(owner),
      "ERC721Enumerable: owner index out of bounds"
    );
    return _ownedTokens[owner][index];
  }

  function totalSupply() public view virtual returns (uint256) {
    return _allTokens.length;
  }

  function tokenByIndex(uint256 index) public view virtual returns (uint256) {
    require(
      index < ERC721.totalSupply(),
      "ERC721Enumerable: global index out of bounds"
    );
    return _allTokens[index];
  }

  function _addTokenToOwnerEnumeration(address to, uint256 tokenId) private {
    uint256 length = ERC721.balanceOf(to);
    _ownedTokens[to][length] = tokenId;
    _ownedTokensIndex[tokenId] = length;
  }

  function _addTokenToAllTokensEnumeration(uint256 tokenId) private {
    _allTokensIndex[tokenId] = _allTokens.length;
    _allTokens.push(tokenId);
  }

  function _removeTokenFromOwnerEnumeration(address from, uint256 tokenId)
    private
  {
    uint256 lastTokenIndex = ERC721.balanceOf(from) - 1;
    uint256 tokenIndex = _ownedTokensIndex[tokenId];

    if (tokenIndex != lastTokenIndex) {
      uint256 lastTokenId = _ownedTokens[from][lastTokenIndex];

      _ownedTokens[from][tokenIndex] = lastTokenId; // Move the last token to the slot of the to-delete token
      _ownedTokensIndex[lastTokenId] = tokenIndex; // Update the moved token's index
    }

    delete _ownedTokensIndex[tokenId];
    delete _ownedTokens[from][lastTokenIndex];
  }

  function _removeTokenFromAllTokensEnumeration(uint256 tokenId) private {
    uint256 lastTokenIndex = _allTokens.length - 1;
    uint256 tokenIndex = _allTokensIndex[tokenId];

    uint256 lastTokenId = _allTokens[lastTokenIndex];

    _allTokens[tokenIndex] = lastTokenId; // Move the last token to the slot of the to-delete token
    _allTokensIndex[lastTokenId] = tokenIndex; // Update the moved token's index

    delete _allTokensIndex[tokenId];
    _allTokens.pop();
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

    string memory baseURI = _baseURI();
    return
      bytes(baseURI).length != 0
        ? string(abi.encodePacked(baseURI, tokenId.toString()))
        : "";
  }

  //--------------------------------------------------------------
  mapping(address => uint256) credit;
  uint256 dividendPerToken;
  mapping(address => uint256) xDividendPerToken;

  event FundsReceived(uint256 value, uint256 dividendPerToken);

  receive() external payable {
    updateDividendPerToken();
  }

  function updateDividendPerToken() internal {
    require(totalSupply() != 0, "No tokens minted");
    dividendPerToken += msg.value / totalSupply();
    console.log("new dividen per share");
    //emit FundsReceived(msg.value, dividendPerToken);
  }

  function withdraw() external {
    uint256 holderBalance = balanceOf(_msgSender());
    require(holderBalance != 0, "DToken: caller possess no shares");

    uint256 amount = ((dividendPerToken - xDividendPerToken[_msgSender()]) *
      holderBalance);
    amount += credit[_msgSender()];
    credit[_msgSender()] = 0;
    xDividendPerToken[_msgSender()] = dividendPerToken;

    (bool success, ) = payable(_msgSender()).call{ value: amount }("");
    require(success, "DToken: Could not withdraw eth");
  }

  function _withdrawToCredit(address to_) private {
    uint256 recipientBalance = balanceOf(to_);
    uint256 amount = (dividendPerToken - xDividendPerToken[to_]) *
      recipientBalance;
    credit[to_] += amount;
    xDividendPerToken[to_] = dividendPerToken;
  }
}

library SafeMathUint {
  function toInt256Safe(uint256 a) internal pure returns (int256) {
    int256 b = int256(a);
    require(b >= 0);
    return b;
  }
}

library SafeMathInt {
  function mul(int256 a, int256 b) internal pure returns (int256) {
    // Prevent overflow when multiplying INT256_MIN with -1
    // https://github.com/RequestNetwork/requestNetwork/issues/43
    require(!(a == -2**255 && b == -1) && !(b == -2**255 && a == -1));

    int256 c = a * b;
    require((b == 0) || (c / b == a));
    return c;
  }

  function div(int256 a, int256 b) internal pure returns (int256) {
    // Prevent overflow when dividing INT256_MIN by -1
    // https://github.com/RequestNetwork/requestNetwork/issues/43
    require(!(a == -2**255 && b == -1) && (b > 0));

    return a / b;
  }

  function sub(int256 a, int256 b) internal pure returns (int256) {
    require((b >= 0 && a - b <= a) || (b < 0 && a - b > a));

    return a - b;
  }

  function add(int256 a, int256 b) internal pure returns (int256) {
    int256 c = a + b;
    require((b >= 0 && c >= a) || (b < 0 && c < a));
    return c;
  }

  function toUint256Safe(int256 a) internal pure returns (uint256) {
    require(a >= 0);
    return uint256(a);
  }
}
