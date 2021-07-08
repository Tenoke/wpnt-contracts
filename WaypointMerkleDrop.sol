pragma solidity ^0.8.2;

import "./ERC20/IERC20.sol";
import "./MerkleProof.sol";
import "./ERC20/utils/SafeERC20.sol";
import "./Waypoint.sol";

contract WaypointMerkleDrop {
    using SafeERC20 for Waypoint;
    string public name = "Waypoint Airdrop";
    Waypoint public waypoint;
    bytes32 public merkleRoot;
    address public owner;

    // This is a packed array of booleans.
    mapping(uint256 => uint256) private claimedBitMap;

    event Claimed(uint256 index, address account, uint256 amount);

    constructor(Waypoint _waypoint, bytes32 merkleRoot_) {
        owner = msg.sender;
        waypoint = _waypoint;
        merkleRoot = merkleRoot_;
    }

    function isClaimed(uint256 index) public view returns (bool) {
        uint256 claimedWordIndex = index / 256;
        uint256 claimedBitIndex = index % 256;
        uint256 claimedWord = claimedBitMap[claimedWordIndex];
        uint256 mask = (1 << claimedBitIndex);
        return claimedWord & mask == mask;
    }

    function _setClaimed(uint256 index) private {
        uint256 claimedWordIndex = index / 256;
        uint256 claimedBitIndex = index % 256;
        claimedBitMap[claimedWordIndex] = claimedBitMap[claimedWordIndex] | (1 << claimedBitIndex);
    }

    function claim(uint256 index, address account, uint256 amount, bytes32[] calldata merkleProof) external {
        require(!isClaimed(index), 'MerkleDistributor: Drop already claimed.');

        // Verify the merkle proof.
        bytes32 node = keccak256(abi.encodePacked(index, account, amount));
        require(MerkleProof.verify(merkleProof, merkleRoot, node), 'MerkleDistributor: Invalid proof.');

        // Mark it claimed and send the token.
        _setClaimed(index);
        waypoint.safeTransfer(account, amount);

        emit Claimed(index, account, amount);
    }

    function withdraw(address _to, uint amount) external {
        // Add an option for the owner to withdraw what hasn't been claimed 
        require(msg.sender == owner, 'only owner can withdraw');
        waypoint.safeTransfer(_to, amount);
        
    }
}