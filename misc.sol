pragma solidity ^0.4.25;

contract Register {
    event log(address addr);
    
    function add(address addr) public {
        emit log(addr);
    }
}
