//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.15;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/Address.sol";

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
// Transfer to non ERC721Receiver implementer
error CantBeOwner();

/// @author Ebrahim Elbagory
/// @title ERC721
contract ERC721 is IERC721, ERC165, Ownable {
  using Address for address;

  string private _name;
  string private _symbol;

  // Mapping from token ID to owner address
  mapping(uint256 => address) private _owners;

  // Mapping owner address to token count
  mapping(address => uint256) private _balances;

  // Mapping from token ID to approved address
  mapping(uint256 => address) private _tokenApprovals;

  // Mapping from owner to operator approvals
  mapping(address => mapping(address => bool)) private _operatorApprovals;

  // Array with all token ids, used for enumeration
  uint256[] private _allTokens;

  // Mapping from token id to position in the allTokens array

  mapping(uint256 => uint256) private _allTokensIndex;

  constructor(string memory name_, string memory symbol_) {
    _name = name_;
    _symbol = symbol_;
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

  function safeTransferFrom(
    address from,
    address to,
    uint256 tokenId
  ) public virtual override {
    safeTransferFrom(from, to, tokenId, "");
  }

  function mint() public returns (uint256) {
    _safeMint(msg.sender, _allTokens.length, "");
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
    if (to == owner) revert CantBeOwner();
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
    if (owner != operator) revert CantBeOwner();
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
  ) internal virtual {}

  function _approve(address to, uint256 tokenId) internal virtual {
    _tokenApprovals[tokenId] = to;
    emit Approval(ERC721.ownerOf(tokenId), to, tokenId);
  }

  function totalSupply() public view virtual returns (uint256) {
    return _allTokens.length;
  }
}
