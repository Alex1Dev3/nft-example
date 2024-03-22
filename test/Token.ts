import {
  loadFixture,
} from "@nomicfoundation/hardhat-toolbox/network-helpers"
import { expect } from "chai"
import { ethers } from "hardhat"

const PRICE_ONE = ethers.parseUnits("10", 18)
const PRICE_BATCH = ethers.parseUnits("50", 18)
const TEMP_NUMBER = ethers.parseUnits("1", 1)

describe("Token", function () {
  async function deployFixture() {
    const [owner, validatorUser, user] = await ethers.getSigners()

    const Token = await ethers.getContractFactory("Token")
    const token = await Token.deploy(validatorUser.address, PRICE_ONE, PRICE_BATCH, "")

    return { token, owner, validatorUser, user }
  }

  describe("Deployment", function () {
    it("Should init correct data", async function () {
      const {token, owner, validatorUser} = await loadFixture(deployFixture)

      expect(await token.owner()).to.equal(owner)
      expect(await token.validator()).to.equal(validatorUser)
      expect(await token.price()).to.equal(PRICE_ONE)
      expect(await token.batchPrice()).to.equal(PRICE_BATCH)
    })
  });

  describe("Mint", function () {
    it("Should signed mint only with valid signature", async function () {
      const {token, validatorUser,  user} = await loadFixture(deployFixture)

      // correct example

      let nonce = await token.totalSupply()
      let validator = validatorUser
      let hashUser = user.address

      let hash = await token.getHash(hashUser, nonce)
      let signature = await validator.signMessage(ethers.getBytes(hash))

      await token.connect(user).signedMint(signature)

      // incorrect example - wrong nonce

      nonce = await token.totalSupply() + TEMP_NUMBER

      hash = await token.getHash(hashUser, nonce)
      signature = await validator.signMessage(ethers.getBytes(hash))

      await expect(token.connect(user).signedMint(signature))
        .to.be.revertedWithCustomError(token,"WrongSignature")

      // incorrect example - wrong hash user

      nonce = await token.totalSupply()
      hashUser = validatorUser.address

      hash = await token.getHash(hashUser, nonce)
      signature = await validator.signMessage(ethers.getBytes(hash))

      await expect(token.connect(user).signedMint(signature))
        .to.be.revertedWithCustomError(token,"WrongSignature")

      // incorrect example - wrong validator

      hashUser = user.address
      validator = user

      hash = await token.getHash(hashUser, nonce)
      signature = await validator.signMessage(ethers.getBytes(hash))

      await expect(token.connect(user).signedMint(signature))
        .to.be.revertedWithCustomError(token,"WrongSignature")
    });
  });
})
