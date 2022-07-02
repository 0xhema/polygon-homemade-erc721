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

/// Address(0) is an invalid input
error InvalidInputZeroAddress();
/// Msg.sender is not approved to spend tokens or is not owner
error IsNotApprovedOrOwner();
/// Token doesn't exist
error TokenDoesNotExist();
/// Token already exists
error TokenAlreadyExists();
/// Transfer to non ERC721Receiver implementer
error NonERC721Receiver();
/// Max supply has been reached
error MaxSupplyReached();
/// Not enough ETH to mint
error NotEnoughETHtoMint();
/// Mint is over
error MintIsOver();
/// Can't Approve to caller
error FromCantBeTo();
/// Can't call function twice
error CantCallTwice();
/// Can't Withdraw
error WithdrawlFailed();
/// Must Mint More then 0
error MintLessThan1();
/// No Tokens have been minted
error MintHasNotStarted();
/// caller has no tokens
error HoldingZeroTokens();

/** @author Ebrahim Elbagory
 *  @title  Homemade ERC721
 *  @notice Ethereum Dividends from potential collected royalities
 *  @notice Set Royalty Reciever address as token address on exchange (Opensea)
 *  @dev    Gas Optimiziation using Bitmaps for minting and transfers
 */

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

  //Batch Heads for Bitmap
  BitMaps.BitMap private _batchHead;

  // Name of token 
  string private _name;
  // Symbol of Token
  string private _symbol;
  // Base URI for token 
  string private _baseTokenURI;
  // The maximum tokens someone can mint at a time
  uint8 private immutable _maxMint;
  // The cost per token at mint
  uint256 private immutable _pricePerToken = 1e17;
  // If the revenue of mint has been withdrawn and the contract has been locked
  bool internal withdrawIsLocked;
  // The dividend that should be paid per token 
  uint256 dividendPerToken;
  // Dividend Per token per user
  mapping(address => uint256) xDividendPerToken;
  // The amount of credit that a user has accumulated
  mapping(address => uint256) credit;
  // Mapping from token ID to owner address
  mapping(uint256 => address) private _owners;
  uint256 internal _minted;

  // Mapping from token ID to approved address
  mapping(uint256 => address) private _tokenApprovals;

  // Mapping from owner to operator approvals
  mapping(address => mapping(address => bool)) private _operatorApprovals;

 /**
  * @dev Emitted when owner withdraws revenue from mint and locks contract
  */
  event WithdrawAndLock(bool _withdrawAndLock);
  
 /**
  * @dev Emitted when `withdrawer` withdraws the `amount` of dividends earned
  */
  event withdrawlMade(address indexed withdrawer, uint256 amount);

  /** 
  * @notice executes on calls to the contract with no data (send(), transfer(), etc)
  * @dev If the contract has been withdrawn and locked then it will update the dividen per token when it recieves eth
  */
  receive() external payable {
    if (withdrawIsLocked) updateDividendPerToken();
  }

  /** @notice initializes contract
   *  @param name_ token name
   *  @param symbol_ token symbol
   *  @param baseTokenURI_ token URI I.E. https://ipfs/test/
   *  @param maxMint_ Max mint allowed per user I.E. 10
   */
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

   /**
   * @return name of collection as a string
   */
  function name() public view returns (string memory) {
    return _name;
  }

  /**
   * @return symbol of collection as a string
   */
  function symbol() public view returns (string memory) {
    return _symbol;
  }

   /**  
   *  @return maximum amount of tokens a user is allowed to mint at time
   */
  function maxMint() public view returns (uint8) {
    return _maxMint;
  }

  /**  
   *   @return price per token that each user is minting
   */
  function pricePerToken() public pure returns (uint256) {
    return _pricePerToken;
  }

  /**  @return balance of owner as a uint256
   *   @param owner address of user you are checking
   */

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

  /** @notice Withdraws ethereum collected in token minting
   *  @dev only allows owner to call function
   *  @dev only allows owner to call the function a single time (to protect user dividends)
   *  @dev users will not be able to mint anymore tokens after
   */
  function withdrawAndLock() external onlyOwner {
    if (withdrawIsLocked) revert CantCallTwice();
    withdrawIsLocked = true;
    payable(owner()).transfer(address(this).balance);
    emit WithdrawAndLock(withdrawIsLocked);
  }

  /** @notice allow for public to mint tokens
   *  @param _numberOfTokens number of tokens to mint
   *  @dev reverts if user is not sending enough ethereum
   *  @dev reverts if user is attempting to mint over the maximum tokens
   *  @dev users will not be able to mint anymore tokens after owner has withdrawn and locked contract
   */
  function mint(uint256 _numberOfTokens) public payable {
    if (_numberOfTokens > _maxMint) revert MaxSupplyReached();
    if (msg.value < (_pricePerToken * _numberOfTokens))
      revert NotEnoughETHtoMint();
    if (withdrawIsLocked) revert MintIsOver();

    _withdrawToCredit(msg.sender);
    _safeMint(msg.sender, _numberOfTokens);
  }

  /** @param tokenId This is the token id of the owner you want to find
   *  @return address of inputed token id's owner
   */
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

  /** @notice internal function that is used by bitmap data structure for gas optimization
   *  @param tokenId that is being queried
   *  @return owner of inputed token id's owner
   *  @return tokenIdBatchHead of the token (location of token data in bitmap data structure)
   */
  function _ownerAndBatchHeadOf(uint256 tokenId)
    internal
    view
    returns (address owner, uint256 tokenIdBatchHead)
  {
    if (!_exists(tokenId)) revert TokenDoesNotExist();
    tokenIdBatchHead = _getBatchHead(tokenId);
    owner = _owners[tokenIdBatchHead];
  }

  /** @notice Safely transfers `tokenId` token from `from` to `to`
   *  @dev if receipient is contract, it must implement IERC721Receiver-onERC721Received
   *  @dev overloaded function
   *  @dev checks if user is owner or approved to spend tokens
   *  @param from token owner
   *  @param to token recipient
   *  @param tokenId the token that is being transfer
   */
  function safeTransferFrom(
    address from,
    address to,
    uint256 tokenId
  ) public virtual override {
    safeTransferFrom(from, to, tokenId, "");
  }

  /** @notice Safely transfers `tokenId` token from `from` to `to`
   *  @notice To can't be zero address or be same as from
   *  @dev checks if receipient is ERC721Receiver implementor
   *  @dev overloaded function
   *  @dev checks if user is owner or approved to spend tokens
   *  @param from token owner
   *  @param to token recipient
   *  @param tokenId the token that is being transfer
   *  @param data I.E ""
   */
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

  /** @notice Transfers `tokenId` token from `from` to `to`
   *  @dev Usage of this method is discouraged, use {safeTransferFrom} whenever possible.
   *  @dev checks if user is owner or approved to spend tokens
   *  @param from token owner
   *  @param to token recipient
   *  @param tokenId the token that is being transfer
   */
  function transferFrom(
    address from,
    address to,
    uint256 tokenId
  ) public virtual override {
    if (!_isApprovedOrOwner(_msgSender(), tokenId))
      revert IsNotApprovedOrOwner();
    _transfer(from, to, tokenId);
  }

  /**
   *  @dev Gives permission to `to` to transfer `tokenId` token to another account.
   *  @dev The approval is cleared when the token is transferred.
   *  @dev Only a single account can be approved at a time, so approving the zero address clears previous approvals.
   *  @param operator token owner
   *  @param tokenId the token that is being gi
   */
  function approve(address operator, uint256 tokenId) public virtual override {
    address owner = ownerOf(tokenId);
    if (operator == _msgSender()) revert FromCantBeTo();

    if (!_isApprovedOrOwner(_msgSender(), tokenId) || msg.sender != owner)
      revert IsNotApprovedOrOwner();

    _approve(operator, tokenId);
  }

  /**
   *  @dev Gives permission to `operator` to transfer all of senders tokens to another account.
   *  @dev The approval is cleared when the token is transferred.
   *  @dev Only a single account can be approved at a time, so approving the zero address clears previous approvals.
   *  @param operator the address that the permissions will be granted to
   *  @param approved if the operator should have permissions or not
   */
  function setApprovalForAll(address operator, bool approved)
    public
    virtual
    override
  {
    if (operator == _msgSender()) revert FromCantBeTo();

    _operatorApprovals[_msgSender()][operator] = approved;
    emit ApprovalForAll(_msgSender(), operator, approved);
  }
  /**
   * @notice Returns the account approved for `tokenId` token.
   * @dev TokenId must exist
   */
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

 /**
  * @dev Returns whether `tokenId` exists.
  */
  function _exists(uint256 tokenId) internal view virtual returns (bool) {
    return tokenId < _minted;
  }   
  
 /** 
 * @dev See safeTransferFrom()
 */
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

  /** 
 * @dev See transferFrom()
 */
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

  /**
   * @return boolen if the `operator` is allowed to manage all of the assets of `owner`.
   */
  function isApprovedForAll(address owner, address operator)
    public
    view
    virtual
    override
    returns (bool)
  {
    return _operatorApprovals[owner][operator];
  }

  /**
   * @return boolen if `spender` is approved to spend `tokenId` or if owner of `tokenId`
   */
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
    /**
     * @dev Approve `operator` to operate on all of `owner` tokens
     * @param owner The owner of the tokens that are being approved to be spent
     * @param operator The address that will be able to spend the tokens
     * @param approved If the operator should be allowed to spend the tokens or not
     */
  function _setApprovalForAll(
    address owner,
    address operator,
    bool approved
  ) internal virtual {
    if (owner == operator) revert FromCantBeTo();
    _operatorApprovals[owner][operator] = approved;
    emit ApprovalForAll(owner, operator, approved);
  }
  /**
   * @dev Approve `to` to operate on `tokenId`
   */
  function _approve(address to, uint256 tokenId) internal virtual {
    _tokenApprovals[tokenId] = to;
    emit Approval(ownerOf(tokenId), to, tokenId);
  }

  /** 
 * @dev See mint()
 */
  function _safeMint(address to, uint256 quantity) internal virtual {
    _safeMint(to, quantity, "");
  }
 /** 
  * @dev See mint()
  */
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
  /** 
   * @dev See mint()
   */
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

  /**
   * @dev Hook that is called after a set of serially-ordered token ids are about to be transferred. This includes minting and burning.
   * @param from the owner of the token(s)
   * @param to the recipient of the token(s)
   * @param startTokenId the first token id to be transferred
   * @param quantity the amount to be transferred
   */
  function _afterTokenTransfer(
    address from,
    address to,
    uint256 startTokenId,
    uint256 quantity
  ) internal virtual {}

  /**
   * @dev Hook that is called before a set of serially-ordered token ids are about to be transferred. This includes minting and burning.
   * @dev Reverts if from or to is address(0) To burn tokens send to different address (0x000000000000000000000000000000000000dEaD)
   * @param from the owner of the token(s)
   * @param to the recipient of the token(s)
   * @param startTokenId the first token id to be transferred
   * @param quantity the amount to be transferred
   */

  function _beforeTokenTransfer(
    address from,
    address to,
    uint256 startTokenId,
    uint256 quantity
  ) internal virtual {
    if(from == address (0) || to == address(0)) return;
    _withdrawToCredit(to);
    _withdrawToCredit(from);
  }

  // ENUMERATION
  /**
   * @dev Returns the total amount of tokens stored by the contract.
   */
  function totalSupply() public view virtual override returns (uint256) {
    return _minted;
  }

  /**
   * @dev Returns a token ID at a given `index` of all the tokens stored by the contract.
   * Use along with {totalSupply} to enumerate all tokens.
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
   * @dev Returns a token ID owned by `owner` at a given `index` of its token list.
   * Use along with {balanceOf} to enumerate all of ``owner``'s tokens.
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

  /**
   * @dev Returns the batch head where the token information is stored
   */
  function _getBatchHead(uint256 tokenId)
    internal
    view
    returns (uint256 tokenIdBatchHead)
  {
    tokenIdBatchHead = _batchHead.scanForward(tokenId);
  }

  /**
   * @dev See _baseURI() 
   */
  function baseURI() public view returns (string memory) {
    return _baseURI();
  }
  /**
   * @dev Returns the baseURI for the collection
   */
  function _baseURI() internal view virtual returns (string memory) {
    return _baseTokenURI;
  }
  /**
   * @dev Returns the individual token URI for `tokenId`
   */
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

  /**
   * @dev Updates the Dividen Per Token everytime eth is sent to the contract
   */
  function updateDividendPerToken() internal {
    if (totalSupply() == 0) revert MintHasNotStarted();
    dividendPerToken += msg.value / totalSupply();
  }

  /**
   * @dev Allows holders to withdraw their dividends
   */
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

  /**
   * @dev Records dividends to address upon transfer
   */
  function _withdrawToCredit(address to_) private {
    uint256 recipientBalance = balanceOf(to_);
    uint256 amount = (dividendPerToken - xDividendPerToken[to_]) *
      recipientBalance;
    credit[to_] += amount;
    xDividendPerToken[to_] = dividendPerToken;
  }
  /**
   * @dev Returns the dividends earned of the `_user`
   * @param _user User address to query
   * @return amount Dividends earned in eth
   */
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
