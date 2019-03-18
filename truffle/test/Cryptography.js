const CryptographyWrapper = artifacts.require("CryptographyWrapper");

const truffleAssert = require('truffle-assertions');

//if(false) // noinspection UnreachableCodeJS
contract("Cryptography", function(accounts) {
    let sut;

    it("is deployed", async function() {
        sut = await CryptographyWrapper.deployed();
    });

    it("verifyAlpha positive", async function() {
        let alphaData = await sut.alphaData(accounts[0], accounts[1], 10, 0, 2);
        let alpha = web3.eth.sign(accounts[0], alphaData);

        assert.isTrue(await sut.verifyAlpha(alphaData, accounts[0], alpha), "not verified");
    });

    it("verifyAlpha negative", async function() {
        let alphaData1 = await sut.alphaData(accounts[0], accounts[1], 10, 0, 2);
        let alphaData2 = await sut.alphaData(accounts[0], accounts[1], 10, 1, 2);
        let alpha = web3.eth.sign(accounts[0], alphaData1);

        assert.isFalse(await sut.verifyAlpha(alphaData2, accounts[0], alpha), "invalid verified");
    });

    it("verifyBeta positive", async function() {
        let alphaData = await sut.alphaData(accounts[0], accounts[1], 10, 0, 2);
        let alpha = web3.eth.sign(accounts[0], alphaData);

        let betaData = await sut.betaData(alpha);
        let beta = web3.eth.sign(accounts[1], betaData);

        assert.isTrue(await sut.verifyBeta(betaData, accounts[1], beta), "not verified");
    });

    it("verifyBeta negative", async function() {
        let alphaData1 = await sut.alphaData(accounts[0], accounts[1], 10, 0, 2);
        let alphaData2 = await sut.alphaData(accounts[0], accounts[1], 10, 1, 2);
        let alpha1 = web3.eth.sign(accounts[0], alphaData1);
        let alpha2 = web3.eth.sign(accounts[0], alphaData2);

        let betaData1 = await sut.betaData(alpha1);
        let betaData2 = await sut.betaData(alpha2);
        let beta = web3.eth.sign(accounts[1], betaData1);

        assert.isFalse(await sut.verifyBeta(betaData2, accounts[1], beta), "not verified");
    });
});
