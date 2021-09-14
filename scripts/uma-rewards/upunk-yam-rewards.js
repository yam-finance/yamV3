let Web3 = require("web3")
let web3 = new Web3('http://192.168.1.39:8545')
let ABIS = require('./abis.js')
const WETH = new web3.eth.Contract(ABIS.ERC20_ABI, '0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2')
const USDC = new web3.eth.Contract(ABIS.ERC20_ABI, '0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48')
let paymentPeriods = [
  {
    startBlock: 12770312,
    amount: 5000000000000000000000n * 82n / 100n,
    endBlock: 12815267,
  },
  {
    startBlock: 12815268,
    amount: 5000000000000000000000n * 82n / 100n,
    endBlock: 12859855,
  }
]
let contracts = [{
  emp: '0xF8eF02C10C473CA5E48b10c62ba4d46115dd2288', //uPUNK 0921
  pool: '0x6e01db46b183593374a49c0025e42c4bb7ee3ffa',
  periodData: []
}]

contracts.forEach((contract) => {
  contract.poolContract = new web3.eth.Contract(ABIS.POOL_ABI, contract.pool)
  contract.empContract = new web3.eth.Contract(ABIS.EMP_ABI, contract.emp)
})


let users = {}
async function generateRewards() {
  await getLiquidityEvents()
  await calculateETHPerLPTokenPerContractPerPeriod()
  await calculateUserProvidedETHSecondsPerContractPerPeriod()
  calculateProvidedPerPeriod()
  calculateRewards()
  let totalRewards = 0n
  Object.keys(users).forEach((userAddress) => {
    if (users[userAddress].rewards) {
      totalRewards += users[userAddress].rewards
      console.log(userAddress + ',' + users[userAddress].rewards.toString())
    }
  })
  console.log("Total: "+ totalRewards.toString())

}

generateRewards()


function calculateRewards() {
  paymentPeriods.forEach((period) => {
    let totalEthSeconds = 0n
    Object.keys(period.users).forEach((userAddress) => {
      if (users[userAddress].rewards === undefined) {
        users[userAddress].rewards = 0n
      }
      users[userAddress].rewards += period.amount * period.users[userAddress] / period.totalETHSecondsProvided
    })
  })
}

function calculateProvidedPerPeriod() {
  Object.keys(users).map((userAddress) => {
    let user = users[userAddress]
    user.contracts.forEach((userContractData, contractIndex) => {
      let contract = contracts[contractIndex]
      userContractData.periods.forEach((userPeriodData, periodIndex) => {
        if (userPeriodData.ethSecondsProvided === 0n) {
          return
        }
        let period = paymentPeriods[periodIndex]
        if (period.totalETHSecondsProvided === undefined) {
          period.totalETHSecondsProvided = 0n
        }
        period.totalETHSecondsProvided += userPeriodData.ethSecondsProvided
        if (period.users === undefined) {
          period.users = {}
        }
        if (period.users[userAddress] === undefined) {
          period.users[userAddress] = 0n
        }
        period.users[userAddress] += userPeriodData.ethSecondsProvided
      })
    })
  })
}

async function calculateETHPerLPTokenPerContractPerPeriod() {
  await Promise.all(contracts.map(async (contract, contractIndex) => {
    await Promise.all(paymentPeriods.map(async (period, periodIndex) => {

      let ethBalance
      let totalSupply
      try {
        if (contract.collateralConversionRate !== undefined) {
          ethBalance = BigInt((await USDC.methods.balanceOf(contract.pool).call({}, period.endBlock)).toString()) / contract.collateralConversionRate * (10n ** 12n)
        } else {
          ethBalance = BigInt((await WETH.methods.balanceOf(contract.pool).call({}, period.endBlock)).toString())

        }
        totalSupply = BigInt((await contract.poolContract.methods.totalSupply().call({}, period.endBlock)).toString())
      } catch (e) {
        console.log(contractIndex, periodIndex)
        console.log(e)
      }
      if (totalSupply === undefined) {
        console.log(period.endBlock, contract)
      }
      try {
        contract.periodData[periodIndex] = {
          ethPerLPToken: totalSupply * (10n ** 18n) / ethBalance
        }
      } catch (e) {
        console.log(e, contractIndex, periodIndex)
      }
    }))

  }))
}

async function calculateUserProvidedETHSecondsPerContractPerPeriod() {
  await Promise.all(Object.keys(users).map(async (userAddress) => {
    let user = users[userAddress]
    await Promise.all(user.contracts.map(async (userContractData, contractIndex) => {
      let contract = contracts[contractIndex]
      await Promise.all(paymentPeriods.map(async (period, periodIndex) => {
        let currentBlock = period.startBlock
        let positionData = await contract.empContract.methods.positions(userAddress).call({}, currentBlock)
        if (positionData.rawCollateral.rawValue === '0') {
          let events = await contract.empContract.getPastEvents('PositionCreated', {
            sponsor: userAddress,
            fromBlock: period.startBlock,
            toBlock: period.endBlock
          })
          if (events.length === 0) {
            return
          }
        }

        let balance = BigInt((await contract.poolContract.methods.balanceOf(userAddress).call({}, period.startBlock)).toString())
        let total = 0n
        let finishBlock = period.endBlock
        userContractData.liquidityEvents.forEach((liquidityEvent) => {
          if (liquidityEvent.block >= currentBlock && liquidityEvent.block <= finishBlock) {
            total += balance * BigInt(liquidityEvent.block - currentBlock)
            currentBlock = liquidityEvent.block
            balance += liquidityEvent.amount
          }
        })
        total += balance * BigInt(finishBlock - currentBlock)
        if (total < 0n) {
          console.log(total, balance)
        }
        userContractData.periods[periodIndex] = {
          ethSecondsProvided: total * (10n ** 18n) / contract.periodData[periodIndex].ethPerLPToken
        }


      }))
    }))
  }))
}

async function getLiquidityEvents() {
  await Promise.all(contracts.map(async (contract, contractIndex) => {
    let liquidityMoves = await contract.poolContract.getPastEvents('Transfer', {
      fromBlock: 11000000,
      toBlock: 'latest'
    })
    liquidityMoves.forEach((liquidityMove) => {
      let to = liquidityMove.returnValues.to.toLowerCase(),
        from = liquidityMove.returnValues.from.toLowerCase()
      let data = {
        block: liquidityMove.blockNumber,
        amount: liquidityMove.returnValues.value
      }
      if (to !== '0x0000000000000000000000000000000000000000') {
        if (!users[to])
          users[to] = {
            contracts: []
          }

        if (!users[to].contracts[contractIndex])
          users[to].contracts[contractIndex] = {
            liquidityEvents: [],
            periods: []
          }

        users[to].contracts[contractIndex].liquidityEvents.push({
          block: liquidityMove.blockNumber,
          amount: BigInt(liquidityMove.returnValues.value)
        })
        users[to].contracts[contractIndex].liquidityEvents.sort(function (a, b) {
          return a.blockNumber - b.blockNumber
        })
      }

      if (from !== '0x0000000000000000000000000000000000000000') {
        if (!users[from])
          users[from] = {
            contracts: []
          }

        if (!users[from].contracts[contractIndex])
          users[from].contracts[contractIndex] = {
            liquidityEvents: [],
            periods: []
          }

        users[from].contracts[contractIndex].liquidityEvents.push({
          block: liquidityMove.blockNumber,
          amount: -BigInt(liquidityMove.returnValues.value)
        })
        users[from].contracts[contractIndex].liquidityEvents.sort(function (a, b) {
          return a.blockNumber - b.blockNumber
        })
      }
    })
  }))
}