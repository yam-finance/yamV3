let Web3 = require("web3")
let web3 = new Web3('https://mainnet.infura.io/v3/9aa3d95b3bc440fa88ea12eaa4456161')
let ABIS = require('./abis.js')
const WETH = new web3.eth.Contract(ABIS.ERC20_ABI, '0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2')
const USDC = new web3.eth.Contract(ABIS.ERC20_ABI, '0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48')
let paymentPeriods = [
/*
    {
        // 1633046400 | 01.10 | scUMA-1103
        startBlock: 13330090,
        amount: (2885000000000000000000n * 90n) / 100n,
        endBlock: 13527858,
    },
    {
        // 1635724800 | 01.11 | scUMA-1202
        startBlock: 13527858,
        amount: (6316000000000000000000n * 90n) / 100n,
        endBlock: 13680218,
    },
    {
        // 1635724800 | 25.11 | UMA
        startBlock: 13680218,
        amount: (1772000000000000000000n * 90n) / 100n,
        endBlock: 13717846,
    },
*/
    {
        // 1638316800 | 01.12 | scUMA-0106
        startBlock: 13717846,
        amount: (6454000000000000000000n * 90n) / 100n,
        endBlock: 13916160,
    },
]
let contracts = [
  {
    createdAt: 13334278,
    emp: '0xf35a80e4705c56fd345e735387c3377baccd8189', //uPUNK 1221
    pool: '0x9469313a1702dc275015775249883cfc35aa94d8',
    periodData: []
  },
  {
    createdAt: 13334204,
    emp: '0x7c62e5c39b7b296f4f2244e7eb51bea57ed26e4b', //uGAS 1221
    pool: '0xf6e15cdf292d36a589276c835cc576f0df0fe53a',
    periodData: []
  },  
]

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
      console.log(userAddress + ',' + web3.utils.fromWei(users[userAddress].rewards.toString(), 'ether'))
    }
  })

  console.log("Total: " + web3.utils.fromWei(totalRewards.toString(), 'ether'))
}

generateRewards()


function calculateRewards() {
  paymentPeriods.forEach((period) => {
    console.log(period)
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
      if (period.endBlock < contract.createdAt) {
        contract.periodData[periodIndex] = {
          ethPerLPToken: 0n
        }
        return
      }

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
        if (period.endBlock < contract.createdAt)
          return
        let currentBlock = period.startBlock > contract.createdAt ? period.startBlock : contract.createdAt
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

        let balance = BigInt((await contract.poolContract.methods.balanceOf(userAddress).call({}, period.endBlock)).toString())
        let total = 0n
        let finishBlock = contract.expire && contract.expire < period.endBlock ? contract.expire : period.endBlock
        userContractData.liquidityEvents.forEach((liquidityEvent) => {
          if (liquidityEvent.block >= currentBlock && liquidityEvent.block <= finishBlock) {
            total += balance * BigInt(liquidityEvent.block - currentBlock)
            currentBlock = liquidityEvent.block
            balance += liquidityEvent.amount
          }
        })
        total += balance * BigInt(finishBlock - currentBlock)
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