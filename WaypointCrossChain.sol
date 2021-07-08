pragma solidity ^0.8.2;

import "./Waypoint.sol";
import "./ERC20/utils/SafeERC20.sol";

contract WaypointCrossChain {
    using SafeERC20 for Waypoint;
    
    string public name = "Waypoint Cross Chain";
    mapping(address => bool) public owners;
    uint _externalSupply = 0;
    Waypoint waypoint;
    bool waypointSet = false;

    event AddedOwner(
        address onwer
    );

    event RemovedOwner(
        address onwer
    );

    constructor() {
        owners[msg.sender] = true;
        emit AddedOwner(msg.sender);

    }

    function increaseExternalSupply(uint amount) external {
        require(owners[msg.sender] == true, "request must be made by an owner");
        _externalSupply = _externalSupply + amount;
    }

    function decreaseExternalSupply(uint amount) external {
        require(owners[msg.sender] == true, "request must be made by an owner");
        _externalSupply = _externalSupply - amount;
    }


    function externalSupply() public view virtual returns (uint amount) {
        return _externalSupply;   
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

    function setWaypointAddress(Waypoint _waypoint) public returns (bool success) {
        require(owners[msg.sender] == true, "request must be made by an owner");
        require(waypointSet == false, "cannot reset waypoint");
        waypoint = _waypoint;
        waypointSet = true;
        return true;
    }

}
