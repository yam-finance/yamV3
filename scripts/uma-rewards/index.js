let Web3 = require("web3")
let web3 = new Web3('https://mainnet.infura.io/v3/18533a1dfcd146b8994f38b8e6af372c')
let ABIS = require('./abis.js')
const WETH = new web3.eth.Contract(ABIS.ERC20_ABI, '0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2')

let paymentPeriods = [{
  startBlock: 11826823,
  amount: 750000000000000000000n * 8n / 10n,
  endBlock: 11872352,
}, {
  startBlock: 11872068,
  amount: 891197364599133493182n * 8n / 10n,
  endBlock: 11917648,
}, {
  startBlock: 11917506,
  amount: 1021370000000000000000n * 8n / 10n,
  endBlock: 11962932,
}
]
let contracts = [{
  emp: '0xEAA081a9fad4607CdF046fEA7D4BF3DfEf533282', //uGAS FEB
  pool: '0x4a8a2ea3718964ed0551a3191c30e49ea38a5ade',
  periodData: [],
  expire: 11948960,
}, {
  emp: '0xfA3AA7EE08399A4cE0B4921c85AB7D645Ccac669', //uGAS MAR
  pool: '0x683ea972ffa19b7bad6d6be0440e0a8465dba71c',
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
        ethBalance = BigInt((await WETH.methods.balanceOf(contract.pool).call({}, period.startBlock)).toString())
        totalSupply = BigInt((await contract.poolContract.methods.totalSupply().call({}, period.startBlock)).toString())
      } catch (e) {
        console.log(period.startBlock)
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