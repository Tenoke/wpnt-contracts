pragma solidity ^0.8.2;

import "./ERC20/ERC20.sol";
import "./WaypointCrossChain.sol";

contract Waypoint is ERC20 {
    mapping(address => bool) public owners;
    uint maxSupply = 50000000000000000000000000;
    WaypointCrossChain public waypointCrossChain;

    uint mintWait = 14400; // 4 hours

    mapping (address => uint256) currentMintLength;
    mapping (address => uint [2][]) mintings;

    event AddedOwner(
        address onwer
    );

    event RemovedOwner(
        address onwer
    );

    event Timestamp (
        uint timestap
    );

    event MintStarted (
        address _to,
        uint unlocksAt,
        uint amount
    );


    constructor(uint256 initialSupply) ERC20("Waypoint", "WPNT") {
        _mint(msg.sender, initialSupply);
        owners[msg.sender] = true;
        emit AddedOwner(msg.sender);

    }


    function mint(address _to, uint256 _amount) external returns (bool success) {
        // for use by the staking contract and cross-chain transfers
        // mintings occur after a delay to inform users in advance
        require(owners[msg.sender] == true, "request must be made by an owner");
        require(totalSupply() + _amount < maxSupply, "the total supply must be lower than the maximum supply");
        mintings[_to].push([block.timestamp + mintWait, _amount]);
        emit MintStarted(_to, block.timestamp + mintWait, _amount);
        return true;
    }

    function processMints(address _to) external returns (bool success) {
        if (mintings[_to].length <= currentMintLength[_to]) {
            return false;
        }
        uint timestamp = block.timestamp;
        uint amount = 0;
        uint length = 0;
        uint i;
        for (i=currentMintLength[_to];i<mintings[_to].length;i++) {
            if (timestamp > mintings[_to][i][0])
            {
                amount = amount + mintings[_to][i][1];
                length += 1;
                delete mintings[_to][i];
            } else {
                break;
            }
        }
        if (amount > 0) {
            currentMintLength[_to] = currentMintLength[_to] + length;
            _mint(_to, amount);
        }
        return true;
    }


    function burn(uint256 _amount) external returns (bool success) {
        // for use in cross-chain transfers
        require(balanceOf(msg.sender) >= _amount, "user must have enough funds to burn");
        _burn(msg.sender, _amount);
        return true;
    }


    function addOwner(address _to) external returns (bool success) {
        require(owners[msg.sender] == true, "request must be made by an owner");
        owners[_to] = true;
        emit AddedOwner(_to);
        return true;
    }

    function removeOwner(address _to) external returns (bool success) {
        require(owners[msg.sender] == true, "request must be made by an owner");
        delete owners[_to];
        emit RemovedOwner(_to);
        return true;
    }

    function combinedSupply() public view virtual returns (uint256) {
        return totalSupply() + waypointCrossChain.externalSupply();
    }
    function setWaypointCrossChainAddress(WaypointCrossChain _waypointCrossChain) external returns (bool success) {
        require(owners[msg.sender] == true, "request must be made by an owner");
        waypointCrossChain = _waypointCrossChain;
        return true;
    }


}
