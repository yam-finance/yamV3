let Web3 = require("web3")
let web3 = new Web3('https://e8101fdbc4ce4457a4538787823415c8.eth.rpc.rivet.cloud')
let ABIS = require('./abis.js')
const WETH = new web3.eth.Contract(ABIS.ERC20_ABI, '0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2')
let util = require('util')
let paymentPeriods = [{
    startBlock: 11511766,
    amount: 261595388135783540000n,
    endBlock: 11556766,
  },
  {
    startBlock: 11553108,
    amount: 430562167652796400000n,
    endBlock: 11598108,
  },
  {
    startBlock: 11598841,
    amount: 452351672025212740000n,
    endBlock: 11643841,
  },
  {
    startBlock: 11644647,
    amount: 488782752830384000000n,
    endBlock: 11689647,
  },
  {
    startBlock: 11662836,
    amount: 55750000000000000000n,
    endBlock: 11707836,
  },
  {
    startBlock: 11690885,
    amount: 383631268416000000000n,
    endBlock: 11735885,
  },
  {
    startBlock: 11690885,
    amount: 355019000000000000000n,
    endBlock: 11735885,
  },
  {
    startBlock: 11735597,
    amount: 278800044943820900000n,
    endBlock: 11780597,
  },
  {
    startBlock: 11735597,
    amount: 442000000000000000000n,
    endBlock: 11780597,
  }
]
let contracts = [{
  emp: '0x516f595978D87B67401DaB7AfD8555c3d28a3Af4',
  pool: '0x25fb29d865c1356f9e95d621f21366d3a5db6bb0',
  expire: 11767000,
  periodData: []
}, {
  emp: '0xEAA081a9fad4607CdF046fEA7D4BF3DfEf533282',
  pool: '0x4a8a2ea3718964ed0551a3191c30e49ea38a5ade',
  periodData: []
}, {
  emp: '0xfA3AA7EE08399A4cE0B4921c85AB7D645Ccac669',
  pool: '0x683ea972ffa19b7bad6d6be0440e0a8465dba71c',
  periodData: []
}]

contracts.forEach((contract) => {
  contract.poolContract = new web3.eth.Contract(ABIS.POOL_ABI, contract.pool)
  contract.empContract = new web3.eth.Contract(ABIS.EMP_ABI, contract.emp)
})

let earnings = {}
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
      let ethBalance = BigInt((await WETH.methods.balanceOf(contract.pool).call({}, period.startBlock)).toString())
      let totalSupply = BigInt((await contract.poolContract.methods.totalSupply().call({}, period.startBlock)).toString())
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