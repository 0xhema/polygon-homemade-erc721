// SPDX-License-Identifier: MIT
/**
   _____       ___     ___ __           ____  _ __      
  / ___/____  / (_)___/ (_) /___  __   / __ )(_) /______
  \__ \/ __ \/ / / __  / / __/ / / /  / __  / / __/ ___/
 ___/ / /_/ / / / /_/ / / /_/ /_/ /  / /_/ / / /_(__  ) 
/____/\____/_/_/\__,_/_/\__/\__, /  /_____/_/\__/____/  
                           /____/                        

- npm: https://www.npmjs.com/package/solidity-bits
- github: https://github.com/estarriolvetch/solidity-bits

 */
pragma solidity ^0.8.0;

/**
 * @dev This Library is a modified version of Openzeppelin's BitMaps library.
 * Functions of finding the index of the closest set bit from a given index are added.
 * The indexing of each bucket is modifed to count from the MSB to the LSB instead of from the LSB to the MSB.
 * The modification of indexing makes finding the closest previous set bit more efficient in gas usage.
 */

/**
 * @dev Library for managing uint256 to bool mapping in a compact and efficient way, providing the keys are sequential.
 * Largelly inspired by Uniswap's https://github.com/Uniswap/merkle-distributor/blob/master/contracts/MerkleDistributor.sol[merkle-distributor].
 */

library BitMaps {
  using BitScan for uint256;
  uint256 private constant MASK_INDEX_ZERO = (1 << 255);
  struct BitMap {
    mapping(uint256 => uint256) _data;
  }

  /**
   * @dev Returns whether the bit at `index` is set.
   */
  function get(BitMap storage bitmap, uint256 index)
    internal
    view
    returns (bool)
  {
    uint256 bucket = index >> 8;
    uint256 mask = MASK_INDEX_ZERO >> (index & 0xff);
    return bitmap._data[bucket] & mask != 0;
  }

  /**
   * @dev Sets the bit at `index` to the boolean `value`.
   */
  function setTo(
    BitMap storage bitmap,
    uint256 index,
    bool value
  ) internal {
    if (value) {
      set(bitmap, index);
    } else {
      unset(bitmap, index);
    }
  }

  /**
   * @dev Sets the bit at `index`.
   */
  function set(BitMap storage bitmap, uint256 index) internal {
    uint256 bucket = index >> 8;
    uint256 mask = MASK_INDEX_ZERO >> (index & 0xff);
    bitmap._data[bucket] |= mask;
  }

  /**
   * @dev Unsets the bit at `index`.
   */
  function unset(BitMap storage bitmap, uint256 index) internal {
    uint256 bucket = index >> 8;
    uint256 mask = MASK_INDEX_ZERO >> (index & 0xff);
    bitmap._data[bucket] &= ~mask;
  }

  /**
   * @dev Find the closest index of the set bit before `index`.
   */
  function scanForward(BitMap storage bitmap, uint256 index)
    internal
    view
    returns (uint256)
  {
    uint256 bucket = index >> 8;

    // index within the bucket
    uint256 bucketIndex = (index & 0xff);

    // load a bitboard from the bitmap.
    uint256 bb = bitmap._data[bucket];

    // offset the bitboard to scan from `bucketIndex`.
    bb = bb >> (0xff ^ bucketIndex); // bb >> (255 - bucketIndex)

    if (bb > 0) {
      unchecked {
        return (bucket << 8) | (bucketIndex - bb.bitScanForward256());
      }
    } else {
      while (true) {
        require(
          bucket > 0,
          "BitMaps: The set bit before the index doesn't exist."
        );
        unchecked {
          bucket--;
        }
        // No offset. Always scan from the least significiant bit now.
        bb = bitmap._data[bucket];

        if (bb > 0) {
          unchecked {
            return (bucket << 8) | (255 - bb.bitScanForward256());
          }
        }
      }
    }
  }

  function getBucket(BitMap storage bitmap, uint256 bucket)
    internal
    view
    returns (uint256)
  {
    return bitmap._data[bucket];
  }
}

library BitScan {
  uint256 private constant DEBRUIJN_256 =
    0x818283848586878898a8b8c8d8e8f929395969799a9b9d9e9faaeb6bedeeff;
  bytes private constant LOOKUP_TABLE_256 =
    hex"0001020903110a19042112290b311a3905412245134d2a550c5d32651b6d3a7506264262237d468514804e8d2b95569d0d495ea533a966b11c886eb93bc176c9071727374353637324837e9b47af86c7155181ad4fd18ed32c9096db57d59ee30e2e4a6a5f92a6be3498aae067ddb2eb1d5989b56fd7baf33ca0c2ee77e5caf7ff0810182028303840444c545c646c7425617c847f8c949c48a4a8b087b8c0c816365272829aaec650acd0d28fdad4e22d6991bd97dfdcea58b4d6f29fede4f6fe0f1f2f3f4b5b6b607b8b93a3a7b7bf357199c5abcfd9e168bcdee9b3f1ecf5fd1e3e5a7a8aa2b670c4ced8bbe8f0f4fc3d79a1c3cde7effb78cce6facbf9f8";

  /**
        @dev Isolate the least significant set bit.
     */
  function isolateLS1B256(uint256 bb) internal pure returns (uint256) {
    require(bb > 0);
    unchecked {
      return bb & (0 - bb);
    }
  }

  /**
        @dev Isolate the most significant set bit.
     */
  function isolateMS1B256(uint256 bb) internal pure returns (uint256) {
    require(bb > 0);
    unchecked {
      bb |= bb >> 256;
      bb |= bb >> 128;
      bb |= bb >> 64;
      bb |= bb >> 32;
      bb |= bb >> 16;
      bb |= bb >> 8;
      bb |= bb >> 4;
      bb |= bb >> 2;
      bb |= bb >> 1;

      return (bb >> 1) + 1;
    }
  }

  /**
        @dev Find the index of the lest significant set bit. (trailing zero count)
     */
  function bitScanForward256(uint256 bb) internal pure returns (uint8) {
    unchecked {
      return
        uint8(LOOKUP_TABLE_256[(isolateLS1B256(bb) * DEBRUIJN_256) >> 248]);
    }
  }

  /**
        @dev Find the index of the most significant set bit.
     */
  function bitScanReverse256(uint256 bb) internal pure returns (uint8) {
    unchecked {
      return
        255 -
        uint8(LOOKUP_TABLE_256[((isolateMS1B256(bb) * DEBRUIJN_256) >> 248)]);
    }
  }

  function log2(uint256 bb) internal pure returns (uint8) {
    unchecked {
      return
        uint8(LOOKUP_TABLE_256[(isolateMS1B256(bb) * DEBRUIJN_256) >> 248]);
    }
  }
}
