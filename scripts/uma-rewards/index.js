let Web3 = require("web3")
let web3 = new Web3('https://mainnet.infura.io/v3/18533a1dfcd146b8994f38b8e6af372c')
let ABIS = require('./abis.js')
const WETH = new web3.eth.Contract(ABIS.ERC20_ABI, '0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2')
const USDC = new web3.eth.Contract(ABIS.ERC20_ABI, '0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48')
let paymentPeriods = [{
  startBlock: 12000974,
  amount: 5000000000000000000000n * 82n / 100n,
  endBlock: 12046295,
}, {
  startBlock: 12046295,
  amount: 10000000000000000000000n * 82n / 100n,
  endBlock: 12091616,
}, {
  startBlock: 12091616,
  amount: 10000000000000000000000n * 82n / 100n,
  endBlock: 12136937,
}
]
let contracts = [{
  createdAt: 11962464,
  emp: '0x4F1424Cef6AcE40c0ae4fc64d74B734f1eAF153C', //uSTONKS APR
  pool: '0xedf187890af846bd59f560827ebd2091c49b75df',
  periodData: [],
  collateralConversionRate: 1900n
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
  Object.keys(users).forEach((userAddress) => {
    if (users[userAddress].rewards) {
      console.log(userAddress)
    }
  })
  Object.keys(users).forEach((userAddress) => {
    if (users[userAddress].rewards) {
      console.log(users[userAddress].rewards.toString())
    }
  })

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
          ethBalance = BigInt((await USDC.methods.balanceOf(contract.pool).call({}, period.endBlock)).toString()) / contract.collateralConversionRate * (10n**12n)
        } else {
          ethBalance = BigInt((await WETH.methods.balanceOf(contract.pool).call({}, period.endBlock)).toString())

        }
        totalSupply = BigInt((await contract.poolContract.methods.totalSupply().call({}, period.endBlock)).toString())
      } catch (e) {
        console.log(contractIndex, periodIndex)
        console.log(e)
      }
      contract.periodData[periodIndex] = {
        ethPerLPToken: totalSupply * (10n ** 18n) / ethBalance
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
          if (liquidityEvent.blockNumber >= currentBlock && liquidityEvent.blockNumber <= finishBlock) {
            total += balance * BigInt(liquidityEvent.blockNumber - currentBlock)
            currentBlock = liquidityEvent.blockNumber
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