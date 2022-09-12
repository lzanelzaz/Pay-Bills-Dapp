import Web3 from 'web3'
import { newKitFromWeb3 } from '@celo/contractkit'
import BigNumber from "bignumber.js"
import paybillsAbi from '../contract/paybills.abi.json'
import erc20Abi from "../contract/erc20.abi.json"

const ERC20_DECIMALS = 18
const MPContractAddress = "0xea5B18A53004FD1AFa0386236F5F08565943a0B0"
const cUSDContractAddress = "0x874069Fa1Eb16D44d622F2e0Ca25eeA172369bC1"

let kit
let contract
let bills = []

const connectCeloWallet = async function () {
  if (window.celo) {
    notification("⚠️ Please approve this DApp to use it.")
    try {
      await window.celo.enable()
      notificationOff()

      const web3 = new Web3(window.celo)
      kit = newKitFromWeb3(web3)

      const accounts = await kit.web3.eth.getAccounts()
      kit.defaultAccount = accounts[0]

      contract = new kit.web3.eth.Contract(paybillsAbi, MPContractAddress)
    } catch (error) {
      notification(`⚠️ ${error}.`)
    }
  } else {
    notification("⚠️ Please install the CeloExtensionWallet.")
  }
}

async function approve(_price) {
  const cUSDContract = new kit.web3.eth.Contract(erc20Abi, cUSDContractAddress)

  const result = await cUSDContract.methods
    .approve(MPContractAddress, _price)
    .send({ from: kit.defaultAccount })
  return result
}

const getBalance = async function () {
  const totalBalance = await kit.getTotalBalance(kit.defaultAccount)
  const cUSDBalance = totalBalance.cUSD.shiftedBy(-ERC20_DECIMALS).toFixed(2)
  document.querySelector("#balance").textContent = cUSDBalance
}

const getBills = async function() {
  const _bills = []
  for (let i = 1; i <= 12; i++) {
    let _bill = new Promise(async (resolve, reject) => {
      let p = await contract.methods.getBill(i).call()
      resolve({
        month: i,
        owner: p[0],
        electricityCost: new BigNumber(p[1]),
        waterCost: new BigNumber(p[2]),
        internetCost: new BigNumber(p[3]),
        total: new BigNumber(p[4]),
        isPaid: p[5]
      })
    })
    _bills.push(_bill)
  }
  bills = await Promise.all(_bills)
  renderBills()
}

function renderBills() {
  document.getElementById("bills").innerHTML = ""
  bills.forEach((_bill) => {
    const newDiv = document.createElement("div")
    newDiv.className = "col-md-4"
    newDiv.innerHTML = billTemplate(_bill)
    document.getElementById("bills").appendChild(newDiv)
  })
}

function isPaid(_isPaid) {
  if (_isPaid) return "Paid"
  else return "Not paid"
}

function billTemplate(_bill) {
  return `
    <div class="card mb-4">
    <div class="position-absolute top-0 end-0 bg-warning mt-4 px-2 py-1 rounded-start">
        ${isPaid(_bill.isPaid)}
      </div>
      <div class="card-body text-left p-4 position-relative">
      <h2 class="card-title fs-4 fw-bold mt-2">${_bill.month} month</h2>
        <div>
        ${identiconTemplate(_bill.owner)}
        </div>
        <p class="card-text mb-2">
          Electricity cost: ${_bill.electricityCost.shiftedBy(-ERC20_DECIMALS).toFixed(2)}
        </p>
        <p class="card-text mb-2">
          Water cost: ${_bill.waterCost.shiftedBy(-ERC20_DECIMALS).toFixed(2)}
        </p>
       <p class="card-text mb-2">
          Internet cost: ${_bill.internetCost.shiftedBy(-ERC20_DECIMALS).toFixed(2)}
        </p>
        <h2 class="card-title fs-4 fw-bold mt-2">Total: ${_bill.total.shiftedBy(-ERC20_DECIMALS).toFixed(2)}</h2>
        <div class="d-grid gap-2">
          <a class="btn btn-lg btn-outline-dark payBtn fs-6 p-3" id=${_bill.month}>
            Pay ${_bill.total.shiftedBy(-ERC20_DECIMALS).toFixed(2)} cUSD
          </a>
        </div>
      </div>
    </div>
  `
}

function identiconTemplate(_address) {
  const icon = blockies
    .create({
      seed: _address,
      size: 8,
      scale: 16,
    })
    .toDataURL()

  return `
  <div class="rounded-circle overflow-hidden d-inline-block border border-white border-2 shadow-sm m-0">
    <a href="https://alfajores-blockscout.celo-testnet.org/address/${_address}/transactions"
        target="_blank">
        <img src="${icon}" width="48" alt="${_address}">
    </a>
  </div>
  `
}

function notification(_text) {
  document.querySelector(".alert").style.display = "block"
  document.querySelector("#notification").textContent = _text
}

function notificationOff() {
  document.querySelector(".alert").style.display = "none"
}

window.addEventListener('load', async () => {
  notification("⌛ Loading...")
  await connectCeloWallet()
  await getBalance()
  await getBills()
  notificationOff()
});


const form  = document.getElementById("inputForm")
  form.addEventListener("submit", async (event) => {
    event.preventDefault()
    const params = [
        document.getElementById("month").value,
        new BigNumber(document.getElementById("electricityCost").value).shiftedBy(ERC20_DECIMALS)
        .toString(), 
        new BigNumber(document.getElementById("waterCost").value).shiftedBy(ERC20_DECIMALS)
        .toString(), 
        new BigNumber(document.getElementById("internetCost").value).shiftedBy(ERC20_DECIMALS)
        .toString(),
    ]
    notification(`⌛ Adding ${params[0]} month bill...`)
    try {
      const result = await contract.methods
        .createBill(...params)
        .send({ from: kit.defaultAccount })
    } catch (error) {
      notification(`⚠️ ${error}.`)
    }
    notification(`🎉 You successfully added ${params[0]} month bill.`)
    getBills()
  })

document.querySelector("#bills").addEventListener("click", async (event) => {
  if(event.target.className.includes("payBtn")) {
    const month = event.target.id
    notification("⌛ Waiting for payment approval...")
    try {
      await approve(bills[parseInt(month)-1].total)
    } catch (error) {
      notification(`⚠️ ${error}.`)
    }
    notification(`⌛ Awaiting payment for ${month} month...`)
    try {
      const result = await contract.methods
        .payBill(month)
        .send({ from: kit.defaultAccount })
      notification(`🎉 You successfully paid ${month} month.`)
      getBills()
      getBalance()
    } catch (error) {
      notification(`⚠️ ${error}.`)
    }
  }
})
