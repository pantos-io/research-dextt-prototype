module.exports.getTimestamp = function() {
    return web3.eth.getBlock(web3.eth.blockNumber).timestamp;
};

module.exports.signAlpha = async function(crypto, from, to, value, t0, t1) {
    let alphaData = await crypto.alphaData(from, to, value, t0, t1);
    return web3.eth.sign(from, alphaData);
};

module.exports.signBeta = async function(crypto, from, to, value, t0, t1) {
    let betaData = await crypto.betaData(await module.exports.signAlpha(crypto, from, to, value, t0, t1));
    return web3.eth.sign(to, betaData);
};

module.exports.advanceTime = async function(seconds) {
    web3.currentProvider.send({jsonrpc: "2.0", method: "evm_increaseTime", params: [seconds], id: 0});
    web3.currentProvider.send({jsonrpc: "2.0", method: "evm_mine", params: [], id: 0});
};

module.exports.unlock = async function(sut, sender) {
    await sut.unlock(sender);
};