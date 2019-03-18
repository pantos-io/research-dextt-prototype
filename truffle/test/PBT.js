const PBT = artifacts.require("PBT");
const CryptographyWrapper = artifacts.require("CryptographyWrapper");

const Util = require("./Util.js");

const truffleAssert = require('truffle-assertions');

const MINT_NUMBER = 50;

let contests = 0;
let contestChanges = 0;

//if(false) // noinspection UnreachableCodeJS
contract("PBT", function(accounts) {
    let sut, crypto;

    let owner, nonOwner;

    it("is deployed", async function() {
        sut = await PBT.deployed();
        crypto = await CryptographyWrapper.deployed();
        owner = await sut.owner.call();
        nonOwner = accounts[1];
        if(accounts[0] !== owner) {
            nonOwner = accounts[0];
        }
    });

    it("has no tokens initially", async function() {
        assert.equal(await sut.balanceOf.call(accounts[0]), 0, "initial balance is not zero");
        assert.equal(await sut.totalSupply.call(), 0, "total supply is not zero");
    });

    it("mints new tokens on command", async function() {
        await sut.mint(accounts[0], MINT_NUMBER, {from: owner});
        assert.equal(MINT_NUMBER, await sut.balanceOf.call(accounts[0]), "balance after mint not correct");
        assert.equal(MINT_NUMBER, await sut.totalSupply.call(), "total supply after mint not correct");
    });

    it("does not mint new tokens for strangers", async function() {
        await truffleAssert.fails(
            sut.mint(accounts[0], MINT_NUMBER, {from: nonOwner}),
            truffleAssert.ErrorType.REVERT);
    });

    it("contest: positive", async function() {
        let from = accounts[0];
        await Util.unlock(sut, from);
        let to = accounts[1];
        let value = 10;
        let timespan = 120;
        let t0 = Util.getTimestamp();
        let t1 = Util.getTimestamp() + timespan;

        let alpha = await Util.signAlpha(crypto, from, to, value, t0, t1);
        let beta = await Util.signBeta(crypto, from, to, value, t0, t1);

        let tx = await sut.contest(from, to, value, t0, t1, alpha, beta, {from: accounts[1]});
        truffleAssert.eventEmitted(tx, 'ContestStarted');
    });

    it("contest: negative (alpha)", async function() {
        let from = accounts[0];
        await Util.unlock(sut, from);
        let to = accounts[1];
        let value = 10;
        let timespan = 120;
        let t0 = Util.getTimestamp();
        let t1 = Util.getTimestamp() + timespan;

        let alpha = await Util.signAlpha(crypto, from, to, value + 1, t0, t1);
        let beta = await Util.signBeta(crypto, from, to, value, t0, t1);

        await truffleAssert.fails(
            sut.contest(from, to, value, t0, t1, alpha, beta, {from: accounts[1]}),
            truffleAssert.ErrorType.REVERT);
    });

    it("contest: negative (beta)", async function() {
        let from = accounts[0];
        await Util.unlock(sut, from);
        let to = accounts[1];
        let value = 10;
        let timespan = 120;
        let t0 = Util.getTimestamp();
        let t1 = Util.getTimestamp() + timespan;

        let alpha = await Util.signAlpha(crypto, from, to, value, t0, t1);
        let beta = await Util.signBeta(crypto, from, to, value + 1, t0, t1);

        await truffleAssert.fails(
            sut.contest(from, to, value, t0, t1, alpha, beta, {from: accounts[1]}),
            truffleAssert.ErrorType.REVERT);
    });

    it("contest: negative (t0)", async function() {
        let from = accounts[0];
        await Util.unlock(sut, from);
        let to = accounts[1];
        let value = 10;
        let timespan = 120;
        let t0 = Util.getTimestamp() + timespan;
        let t1 = Util.getTimestamp() + 2 * timespan;

        let alpha = await Util.signAlpha(crypto, from, to, value, t0, t1);
        let beta = await Util.signBeta(crypto, from, to, value, t0, t1);

        await truffleAssert.fails(
            sut.contest(from, to, value, t0, t1, alpha, beta, {from: accounts[1]}),
            truffleAssert.ErrorType.REVERT);
    });

    it("contest: negative (t1)", async function() {
        let from = accounts[0];
        await Util.unlock(sut, from);
        let to = accounts[1];
        let value = 10;
        let timespan = 120;
        let t0 = Util.getTimestamp();
        let t1 = Util.getTimestamp() - timespan;

        let alpha = await Util.signAlpha(crypto, from, to, value, t0, t1);
        let beta = await Util.signBeta(crypto, from, to, value, t0, t1);

        await truffleAssert.fails(
            sut.contest(from, to, value, t0, t1, alpha, beta, {from: accounts[1]}),
            truffleAssert.ErrorType.REVERT);
    });

    it("contest: negative (value)", async function() {
        let from = accounts[0];
        await Util.unlock(sut, from);
        let to = accounts[1];
        let value = 1;
        let timespan = 120;
        let t0 = Util.getTimestamp();
        let t1 = Util.getTimestamp() + timespan;

        let alpha = await Util.signAlpha(crypto, from, to, value, t0, t1);
        let beta = await Util.signBeta(crypto, from, to, value, t0, t1);

        await truffleAssert.fails(
            sut.contest(from, to, value, t0, t1, alpha, beta, {from: accounts[1]}),
            truffleAssert.ErrorType.REVERT);
    });

    it("contest: negative (lock)", async function() {
        let from = accounts[0];
        await Util.unlock(sut, from);
        let to = accounts[1];
        let value = 10;
        let timespan = 120;
        let t0 = Util.getTimestamp();
        let t1 = Util.getTimestamp() + timespan;

        let alpha = await Util.signAlpha(crypto, from, to, value, t0, t1);
        let beta = await Util.signBeta(crypto, from, to, value, t0, t1);
        await sut.contest(from, to, value, t0, t1, alpha, beta, {from: accounts[1]});

        value++;
        alpha = await Util.signAlpha(crypto, from, to, value, t0, t1);
        beta = await Util.signBeta(crypto, from, to, value, t0, t1);

        await truffleAssert.fails(
            sut.contest(from, to, value, t0, t1, alpha, beta, {from: accounts[1]}),
            truffleAssert.ErrorType.REVERT);
    });
});
