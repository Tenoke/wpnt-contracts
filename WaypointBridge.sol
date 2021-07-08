pragma solidity ^0.8.2;

import "./Waypoint.sol";
import "./ERC20/utils/SafeERC20.sol";

contract WaypointBridge {
    using SafeERC20 for Waypoint;
    
    string public name = "Waypoint Cross Chain";
    mapping(address => bool) public owners;
    mapping(uint => uint) public waypointFees;
    mapping(uint => uint) public nativeFees;
    mapping(uint => uint) public nativeFeesWithTransfer;
    mapping(uint => uint) public waypointFeesWithTransfer;
    address payable public deployer;
    uint public minAmount;
    mapping(uint32 => bool) public enabled;

    Waypoint waypoint;

    event AddedOwner(
        address onwer
    );

    event RemovedOwner(
        address onwer
    );

    event BridgeTransfer(
        bytes32 _to,
        uint amount,
        uint32 network,
        uint nativeFee,
        uint waypointFee,
        bool sendNative
    );


    constructor(Waypoint _waypoint) {
        waypoint = _waypoint;
        owners[msg.sender] = true;
        deployer = payable(msg.sender);
        nativeFees[1] = 1083853350568465664;
        nativeFees[2] = 208347351956;
        nativeFeesWithTransfer[1] = 7587610452716002816;
        nativeFeesWithTransfer[2] = 6356522809922;
        enabled[1] = false;
        enabled[2] = true;
        minAmount = 10000000000000000000;
        emit AddedOwner(msg.sender);
    }

    function transferBridge(bytes32 _to, uint amount, uint32 network) external returns (bool success) {
        require(enabled[network] == true, 'bridge must be [network]');
        require(amount > waypointFees[network] + minAmount, 'must send at least the minimum amount + enough for network fees');
        waypoint.safeTransferFrom(msg.sender, address(this), amount);
        waypoint.burn(waypoint.balanceOf(address(this)));
        emit BridgeTransfer(_to, amount - nativeFees[network], network, 0, waypointFees[network], false);
        return true;
    }

    function transferBridgeNative(bytes32 _to, uint amount, uint32 network) payable external returns (bool success) {
        require(enabled[network] == true, 'bridge must be enabled');
        require(msg.value == nativeFees[network], "must send correct fee amount");
        require(amount > minAmount, 'must send at least the minimum amount WPNT');
        waypoint.safeTransferFrom(msg.sender, address(this), amount);
        waypoint.burn(waypoint.balanceOf(address(this)));
        deployer.transfer(nativeFees[network]);
        emit BridgeTransfer(_to, amount, network, nativeFees[network], 0, false);
        return true;
    }


    function transferBridgeWithTransfer(bytes32 _to, uint amount, uint32 network) external returns (bool success) {
        require(enabled[network] == true, 'bridge must be [network]');
        require(amount > waypointFeesWithTransfer[network] + minAmount, 'must send at least the minimum amount + enough for network fees');
        waypoint.safeTransferFrom(msg.sender, address(this), amount);
        waypoint.burn(waypoint.balanceOf(address(this)));
        emit BridgeTransfer(_to, amount - nativeFees[network], network, 0, waypointFeesWithTransfer[network], true);
        return true;
    }

    function transferBridgeNativeWithTransfer(bytes32 _to, uint amount, uint32 network) payable external returns (bool success) {
        require(enabled[network] == true, 'bridge must be enabled');
        require(msg.value == nativeFeesWithTransfer[network], "must send correct fee amount");
        require(amount > minAmount, 'must send at least the minimum amount WPNT');
        waypoint.safeTransferFrom(msg.sender, address(this), amount);
        waypoint.burn(waypoint.balanceOf(address(this)));
        deployer.transfer(nativeFeesWithTransfer[network]);
        emit BridgeTransfer(_to, amount, network, nativeFeesWithTransfer[network], 0, true);
        return true;
    }


    function addOwner(address _to) external returns (bool success) {
        require(owners[msg.sender] == true, "request must be made by an owner");
        owners[_to] = true;
        emit AddedOwner(_to);
        return true;
    }

    function removeOwner(address _to) public returns (bool success) {
        require(owners[msg.sender] == true, "request must be made by an owner");
        delete owners[_to];
        emit RemovedOwner(_to);
        return true;
    }

    function changeDeployer(address payable _to) external returns (bool success) {
        require(owners[msg.sender] == true, "request must be made by an owner");
        deployer = _to;
        return true;
    }

    function changeNativeFee(uint32 network, uint fee) external returns (bool success) {
        require(owners[msg.sender] == true, "request must be made by an owner");
        nativeFees[network] = fee;
        return true;
    }
    function changeNativeFeesWithTransfer(uint32 network, uint fee) external returns (bool success) {
        require(owners[msg.sender] == true, "request must be made by an owner");
        nativeFeesWithTransfer[network] = fee;
        return true;
    }

    function changeWaypointFee(uint32 network, uint fee) external returns (bool success) {
        require(owners[msg.sender] == true, "request must be made by an owner");
        waypointFees[network] = fee;
        return true;
    }

    function changeWaypointFeeWithTransfer(uint32 network, uint fee) external returns (bool success) {
        require(owners[msg.sender] == true, "request must be made by an owner");
        waypointFeesWithTransfer[network] = fee;
        return true;
    }

    function changeminAmount(uint _minAmount) external returns (bool success) {
        require(owners[msg.sender] == true, "request must be made by an owner");
        minAmount = _minAmount;
        return true;
    }

    function changeEnabled(uint32 network, bool _enabled) external returns (bool success) {
        require(owners[msg.sender] == true, "request must be made by an owner");
        enabled[network] = _enabled;
        return true;
    }


}

