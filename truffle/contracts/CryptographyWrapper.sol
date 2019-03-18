pragma solidity ^0.4.24;

import "./Cryptography.sol";

contract CryptographyWrapper {

    function alphaData(address from, address to, uint256 value, uint256 t0, uint256 t1) public pure returns (bytes32) {
        return Cryptography.alphaData(from, to, value, t0, t1);
    }

    function betaData(bytes alpha) public pure returns (bytes32) {
        return Cryptography.betaData(alpha);
    }

    function verifyAlpha(bytes32 alphaData_, address from, bytes alpha) public pure returns (bool) {
        return Cryptography.verifyAlpha(alphaData_, from, alpha);
    }

    function verifyBeta(bytes32 betaData_, address to, bytes beta) public pure returns (bool) {
        return Cryptography.verifyBeta(betaData_, to, beta);
    }
}
