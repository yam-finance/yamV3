const { toChecksumAddress } = require('ethereumjs-util')
let RAW_UMA_REWARDS = [require('./bonus-uma-rewards-ustonks-apr.js'), require('./regular-uma-rewards-apr.js')]

let RAW_YAM_REWARDS = [require('./bonus-yam-rewards-ugas-jun.js'), require('./bonus-yam-rewards-ustonks-apr.js')]

let accountsToExclude = ['0xd2cb51a362431b6c88336b08aa60b8e8637d21d7', '0xd25b60d3180ca217fdf1748c86247a81b1aa43d6', '0xffb607418dbeab7a888e079a34be28a30d8e1de2']

function combine(maps) {
    let output = {}
    maps.forEach((map) => {
        Object.keys(map).forEach((key) => {
            if (output[key] === undefined) {
                output[key] = 0n
            }
            output[key] += map[key]
        })
    })
    return output
}

function print(map) {
    let total = 0n
    Object.keys(map).forEach((key) => {

        if (accountsToExclude.includes(key)) {
            return
        }
        total += map[key]
        console.log(`TOKEN.transfer(${toChecksumAddress(key)}, ${map[key].toString()});`)
    })
    Object.keys(map).forEach((key) => {
        if (accountsToExclude.includes(key)) {
            console.log("EXCLUDING: " + key + ", " + map[key])
        }
    })
    console.log("OUTFLOW: " + total.toString())
}



let combinedUMARewards = combine(RAW_UMA_REWARDS)

let combinedYAMRewards = combine(RAW_YAM_REWARDS)


console.log("\n\n\nUMA REWARDS")
print(combinedUMARewards)


console.log("\n\n\nYAM REWARDS")
print(combinedYAMRewards)

