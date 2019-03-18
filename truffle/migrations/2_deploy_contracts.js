const PBT = artifacts.require('./PBT.sol');
const Cryptography = artifacts.require('./Cryptography.sol');

module.exports = function(deployer, network, accounts) {
    deployer.deploy(Cryptography);
    deployer.link(Cryptography, [PBT]);
    deployer.deploy(PBT);
};