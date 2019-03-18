pragma solidity ^0.4.0;

import "openzeppelin-solidity/contracts/ECRecovery.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";

library Cryptography {
    bytes constant SIG_PREFIX = "\x19Ethereum Signed Message:\n32";

    function alphaData(address from, address to, uint256 value, uint256 t0, uint256 t1) public pure returns (bytes32) {
        return keccak256(abi.encodePacked("a", from, to, value, t0, t1));
    }

    function betaData(bytes alpha) public pure returns (bytes32) {
        return keccak256(abi.encodePacked("b", alpha));
    }

    function verifyAlpha(bytes32 alphaData_, address from, bytes alpha) public pure returns (bool) {
        bytes32 msgHash = keccak256(abi.encodePacked(SIG_PREFIX, alphaData_));

        return from == ECRecovery.recover(msgHash, alpha);
    }

    function verifyBeta(bytes32 betaData_, address to, bytes beta) public pure returns (bool) {
        bytes32 msgHash = keccak256(abi.encodePacked(SIG_PREFIX, betaData_));

        return to == ECRecovery.recover(msgHash, beta);
    }

    function contestantSignature(address contestant, bytes32 alphaData_) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(contestant, alphaData_));
    }

    function vetoSignature(address contestant, address conflictingSender) public pure returns (bytes32) {
        return keccak256(abi.encodePacked("v", contestant, conflictingSender));
    }
}
