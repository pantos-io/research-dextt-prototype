pragma solidity ^0.4.24;

import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "./Cryptography.sol";

contract PBT is Ownable {
    using SafeMath for uint256;

    mapping(address => uint256) internal balances;

    mapping(address => bytes32) internal senderLock;
    mapping(bytes32 => address) internal alphaFrom;
    mapping(bytes32 => address) internal alphaTo;
    mapping(bytes32 => uint256) internal alphaValue;
    mapping(bytes32 => uint) internal alphaT0;
    mapping(bytes32 => uint) internal alphaT1;

    mapping(bytes32 => address) internal contestWinner;
    mapping(bytes32 => bytes32) internal contestSignature;

    mapping(address => bool) internal senderInvalid;
    mapping(address => uint) internal vetoT1;
    mapping(address => address) internal vetoWinner;
    mapping(address => bytes32) internal vetoSignature;
    mapping(address => bool) internal vetoFinalized;

    uint constant WITNESS_REWARD = 1;

    event Minted(address addr, uint256 value);
    event TransferInitiated(address from, address to, uint256 value, uint t0, uint t1, bytes alpha);
    event ContestStarted(address from, address to, uint256 value, uint t0, uint t1, bytes alpha, bytes beta);
    event TransferFinalized(address from, address to, uint256 value, uint t0, uint t1, address witness);

    event ContestPre(address from, address to, uint256 value, uint t0, uint t1, address sender);
    event ContestBetter(address from, address to, uint256 value, uint t0, uint t1, address sender);
    event ContestWorse(address from, address to, uint256 value, uint t0, uint t1, address sender);

    event VetoStarted(address from, address to, uint256 value, uint t0, uint t1, bytes alpha, bytes beta);
    event VetoFinalized(address from, address witness);

    event ErrorA(string message, address sender);

    uint256 internal totalSupply_;

    function totalSupply() public view returns (uint256) {
        return totalSupply_;
    }

    function balanceOf(address _owner) public view returns (uint256) {
        return balances[_owner];
    }

    function mint(address _owner, uint256 value) public onlyOwner {
        balances[_owner] += value;
        totalSupply_ += value;
        emit Minted(_owner, value);
    }

    function unlock(address sender) public onlyOwner {
        senderLock[sender] = bytes32(0);
    }

    function verifyPoi(address from, address to, uint256 value, uint t0, uint t1, bytes alpha, bytes beta) internal {
        bytes32 alphaData = Cryptography.alphaData(from, to, value, t0, t1);

        // if there is any pending tx, just finalize it to resolve avoidable conflicts
        //finalize(from);

        if (senderLock[from] == alphaData) return;

        bytes32 betaData = Cryptography.betaData(alpha);
        require(Cryptography.verifyAlpha(alphaData, from, alpha), "0");

        if (senderLock[from] == 0) {
            _require(Cryptography.verifyBeta(betaData, to, beta), "a");
            _require(t0 <= now, "b");
            _require(t1 > now, "c");
            _require(value > WITNESS_REWARD, "d");
            _require(balances[from] >= value, "e");

            alphaFrom[alphaData] = from;
            alphaTo[alphaData] = to;
            alphaValue[alphaData] = value;
            alphaT0[alphaData] = t0;
            alphaT1[alphaData] = t1;
            senderLock[from] = alphaData;

            emit ContestStarted(from, to, value, t0, t1, alpha, beta);
        }
        else if(!senderInvalid[from]) {
            senderInvalid[from] = true;
            balances[from] = 0;

            uint originalT0 = alphaT0[senderLock[from]];
            uint originalT1 = alphaT1[senderLock[from]];

            uint maxT1 = originalT1;
            if (t1 > maxT1) maxT1 = t1;
            if (now > maxT1) maxT1 = now;

            vetoT1[from] = maxT1 + (originalT1 - originalT0) + (t1 - t0);

            emit VetoStarted(from, to, value, t0, t1, alpha, beta);
        }
    }

    function _require(bool condition, string message) internal {
        if(!condition) emit ErrorA(message, tx.origin);
        require(condition);
    }

    function initiate(address to, uint256 value, uint t0, uint t1, bytes alpha) public {
        address from = msg.sender;

        bytes32 alphaData = Cryptography.alphaData(from, to, value, t0, t1);
        _require(senderLock[from] == 0 || senderLock[from] == alphaData, "f");
        _require(Cryptography.verifyAlpha(alphaData, from, alpha), "g");
        _require(t0 <= now, "h");
        _require(t1 > now, "i");
        _require(value > WITNESS_REWARD, "j");
        _require(balances[from] >= value, "k");

        emit TransferInitiated(from, to, value, t0, t1, alpha);
    }

    function contest(address from, address to, uint256 value, uint t0, uint t1, bytes alpha, bytes beta) public returns (bool) {
        emit ContestPre(from, to, value, t0, t1, msg.sender);
        bytes32 alphaData = Cryptography.alphaData(from, to, value, t0, t1);
        verifyPoi(from, to, value, t0, t1, alpha, beta);

        if (!senderInvalid[from]) {
            if (alphaT1[alphaData] > now) {
                bytes32 contestantSignature = Cryptography.contestantSignature(msg.sender, alphaData);

                if (contestSignature[alphaData] < contestantSignature) {
                    emit ContestBetter(from, to, value, t0, t1, msg.sender);
                    contestSignature[alphaData] = contestantSignature;
                    contestWinner[alphaData] = msg.sender;
                    return true;
                }
                else {
                    emit ContestWorse(from, to, value, t0, t1, msg.sender);
                    return false;
                }
            }
        }
        else {
            if (vetoT1[from] > now) {
                bytes32 vetoSignature_ = Cryptography.vetoSignature(msg.sender, from);

                if (vetoSignature[from] < vetoSignature_) {
                    vetoSignature[from] = vetoSignature_;
                    vetoWinner[from] = msg.sender;
                    return true;
                }
                else {
                    return false;
                }
            }
        }
    }

    function finalize(address from) public {
        address winner;
        uint t1;

        if (!senderInvalid[from]) {
            bytes32 alphaData = senderLock[from];
            t1 = alphaT1[alphaData];

            if ((alphaData != bytes32(0)) && (t1 <= now)) {
                winner = contestWinner[alphaData];

                address to = alphaTo[alphaData];
                uint256 value = alphaValue[alphaData];
                uint rawValue = value.sub(WITNESS_REWARD);

                balances[from] = balances[from].sub(value);
                balances[to] = balances[to].add(rawValue);
                balances[winner] = balances[winner].add(WITNESS_REWARD);

                senderLock[from] = bytes32(0);

                emit TransferFinalized(from, to, value, alphaT0[alphaData], t1, winner);
            }
        }
        else {
            t1 = vetoT1[from];
            if ((!vetoFinalized[from]) && (t1 <= now)) {
                winner = vetoWinner[from];

                balances[winner] = balances[winner].add(WITNESS_REWARD);

                vetoFinalized[from] = true;

                emit VetoFinalized(from, winner);
            }
        }
    }

    function lockStatus(address from) public view returns (uint) {
        return alphaT1[senderLock[from]];
    }

    function vetoStatus(address from) public view returns (uint) {
        return vetoT1[from];
    }

    function invalidStatus(address from) public view returns (bool) {
        return senderInvalid[from];
    }

    function getAlphaData(address from, address to, uint256 value, uint t0, uint t1) public pure returns (bytes32) {
        return Cryptography.alphaData(from, to, value, t0, t1);
    }

    function getBetaData(bytes alpha) public pure returns (bytes32) {
        return Cryptography.betaData(alpha);
    }

}
