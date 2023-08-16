/* Autogenerated file. Do not edit manually. */
/* tslint:disable */
/* eslint-disable */
import { Signer, utils, Contract, ContractFactory, Overrides } from "ethers";
import type { Provider, TransactionRequest } from "@ethersproject/providers";
import type { PromiseOrValue } from "../common";
import type { CreditAccount, CreditAccountInterface } from "../CreditAccount";

const _abi = [
  {
    inputs: [],
    name: "CallerNotCreditManagerException",
    type: "error",
  },
  {
    inputs: [],
    name: "CallerNotFactoryException",
    type: "error",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: false,
        internalType: "uint8",
        name: "version",
        type: "uint8",
      },
    ],
    name: "Initialized",
    type: "event",
  },
  {
    inputs: [],
    name: "borrowedAmount",
    outputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "token",
        type: "address",
      },
      {
        internalType: "address",
        name: "targetContract",
        type: "address",
      },
    ],
    name: "cancelAllowance",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "_creditManager",
        type: "address",
      },
      {
        internalType: "uint256",
        name: "_borrowedAmount",
        type: "uint256",
      },
      {
        internalType: "uint256",
        name: "_cumulativeIndexAtOpen",
        type: "uint256",
      },
    ],
    name: "connectTo",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [],
    name: "creditManager",
    outputs: [
      {
        internalType: "address",
        name: "",
        type: "address",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "cumulativeIndexAtOpen",
    outputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "destination",
        type: "address",
      },
      {
        internalType: "bytes",
        name: "data",
        type: "bytes",
      },
    ],
    name: "execute",
    outputs: [
      {
        internalType: "bytes",
        name: "",
        type: "bytes",
      },
    ],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [],
    name: "factory",
    outputs: [
      {
        internalType: "address",
        name: "",
        type: "address",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "initialize",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "token",
        type: "address",
      },
      {
        internalType: "address",
        name: "to",
        type: "address",
      },
      {
        internalType: "uint256",
        name: "amount",
        type: "uint256",
      },
    ],
    name: "safeTransfer",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [],
    name: "since",
    outputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "uint256",
        name: "_borrowedAmount",
        type: "uint256",
      },
      {
        internalType: "uint256",
        name: "_cumulativeIndexAtOpen",
        type: "uint256",
      },
    ],
    name: "updateParameters",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [],
    name: "version",
    outputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
] as const;

const _bytecode =
  "0x608060405234801561001057600080fd5b50610edb806100206000396000f3fe608060405234801561001057600080fd5b50600436106100d45760003560e01c806354fd4d5011610081578063c45a01551161005b578063c45a0155146101a4578063c75b5a71146101ca578063d1660f99146101dd57600080fd5b806354fd4d501461014f5780638129fc1c14610157578063c12c21c01461015f57600080fd5b80631afbb7a4116100b25780631afbb7a41461011d5780631cff79cd146101265780633dc54b401461014657600080fd5b806316128211146100d957806317d11a15146100ee57806319a160391461010a575b600080fd5b6100ec6100e7366004610bd1565b6101f0565b005b6100f760035481565b6040519081526020015b60405180910390f35b6100ec610118366004610c1c565b61024c565b6100f760025481565b610139610134366004610c7e565b6102c9565b6040516101019190610dcc565b6100f760045481565b6100f7600181565b6100ec610344565b60015461017f9073ffffffffffffffffffffffffffffffffffffffff1681565b60405173ffffffffffffffffffffffffffffffffffffffff9091168152602001610101565b60005461017f9062010000900473ffffffffffffffffffffffffffffffffffffffff1681565b6100ec6101d8366004610ddf565b610502565b6100ec6101eb366004610e12565b6105ab565b60015473ffffffffffffffffffffffffffffffffffffffff163314610241576040517f1f51116700000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b600291909155600355565b60005462010000900473ffffffffffffffffffffffffffffffffffffffff1633146102a3576040517fb126b84800000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b6102c573ffffffffffffffffffffffffffffffffffffffff8316826000610622565b5050565b60015460609073ffffffffffffffffffffffffffffffffffffffff16331461031d576040517f1f51116700000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b61033d73ffffffffffffffffffffffffffffffffffffffff841683610822565b9392505050565b600054610100900460ff16158080156103645750600054600160ff909116105b8061037e5750303b15801561037e575060005460ff166001145b61040f576040517f08c379a000000000000000000000000000000000000000000000000000000000815260206004820152602e60248201527f496e697469616c697a61626c653a20636f6e747261637420697320616c72656160448201527f647920696e697469616c697a656400000000000000000000000000000000000060648201526084015b60405180910390fd5b600080547fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff00166001179055801561046d57600080547fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff00ff166101001790555b600080547fffffffffffffffffffff0000000000000000000000000000000000000000ffff1633620100000217905580156104ff57600080547fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff00ff169055604051600181527f7f26b83ff96e1f2b6a682f133852f6798a09c465da95921460cefb38474024989060200160405180910390a15b50565b60005462010000900473ffffffffffffffffffffffffffffffffffffffff163314610559576040517fb126b84800000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b600180547fffffffffffffffffffffffff00000000000000000000000000000000000000001673ffffffffffffffffffffffffffffffffffffffff949094169390931790925560025560035543600455565b60015473ffffffffffffffffffffffffffffffffffffffff1633146105fc576040517f1f51116700000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b61061d73ffffffffffffffffffffffffffffffffffffffff84168383610866565b505050565b8015806106c257506040517fdd62ed3e00000000000000000000000000000000000000000000000000000000815230600482015273ffffffffffffffffffffffffffffffffffffffff838116602483015284169063dd62ed3e90604401602060405180830381865afa15801561069c573d6000803e3d6000fd5b505050506040513d601f19601f820116820180604052508101906106c09190610e4e565b155b61074e576040517f08c379a000000000000000000000000000000000000000000000000000000000815260206004820152603660248201527f5361666545524332303a20617070726f76652066726f6d206e6f6e2d7a65726f60448201527f20746f206e6f6e2d7a65726f20616c6c6f77616e6365000000000000000000006064820152608401610406565b60405173ffffffffffffffffffffffffffffffffffffffff831660248201526044810182905261061d9084907f095ea7b300000000000000000000000000000000000000000000000000000000906064015b604080517fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe08184030181529190526020810180517bffffffffffffffffffffffffffffffffffffffffffffffffffffffff167fffffffff00000000000000000000000000000000000000000000000000000000909316929092179091526108bc565b606061033d838360006040518060400160405280601e81526020017f416464726573733a206c6f772d6c6576656c2063616c6c206661696c656400008152506109c8565b60405173ffffffffffffffffffffffffffffffffffffffff831660248201526044810182905261061d9084907fa9059cbb00000000000000000000000000000000000000000000000000000000906064016107a0565b600061091e826040518060400160405280602081526020017f5361666545524332303a206c6f772d6c6576656c2063616c6c206661696c65648152508573ffffffffffffffffffffffffffffffffffffffff16610ae39092919063ffffffff16565b80519091501561061d578080602001905181019061093c9190610e67565b61061d576040517f08c379a000000000000000000000000000000000000000000000000000000000815260206004820152602a60248201527f5361666545524332303a204552433230206f7065726174696f6e20646964206e60448201527f6f742073756363656564000000000000000000000000000000000000000000006064820152608401610406565b606082471015610a5a576040517f08c379a000000000000000000000000000000000000000000000000000000000815260206004820152602660248201527f416464726573733a20696e73756666696369656e742062616c616e636520666f60448201527f722063616c6c00000000000000000000000000000000000000000000000000006064820152608401610406565b6000808673ffffffffffffffffffffffffffffffffffffffff168587604051610a839190610e89565b60006040518083038185875af1925050503d8060008114610ac0576040519150601f19603f3d011682016040523d82523d6000602084013e610ac5565b606091505b5091509150610ad687838387610af2565b925050505b949350505050565b6060610adb84846000856109c8565b60608315610b88578251600003610b815773ffffffffffffffffffffffffffffffffffffffff85163b610b81576040517f08c379a000000000000000000000000000000000000000000000000000000000815260206004820152601d60248201527f416464726573733a2063616c6c20746f206e6f6e2d636f6e74726163740000006044820152606401610406565b5081610adb565b610adb8383815115610b9d5781518083602001fd5b806040517f08c379a00000000000000000000000000000000000000000000000000000000081526004016104069190610dcc565b60008060408385031215610be457600080fd5b50508035926020909101359150565b803573ffffffffffffffffffffffffffffffffffffffff81168114610c1757600080fd5b919050565b60008060408385031215610c2f57600080fd5b610c3883610bf3565b9150610c4660208401610bf3565b90509250929050565b7f4e487b7100000000000000000000000000000000000000000000000000000000600052604160045260246000fd5b60008060408385031215610c9157600080fd5b610c9a83610bf3565b9150602083013567ffffffffffffffff80821115610cb757600080fd5b818501915085601f830112610ccb57600080fd5b813581811115610cdd57610cdd610c4f565b604051601f82017fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe0908116603f01168101908382118183101715610d2357610d23610c4f565b81604052828152886020848701011115610d3c57600080fd5b8260208601602083013760006020848301015280955050505050509250929050565b60005b83811015610d79578181015183820152602001610d61565b50506000910152565b60008151808452610d9a816020860160208601610d5e565b601f017fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe0169290920160200192915050565b60208152600061033d6020830184610d82565b600080600060608486031215610df457600080fd5b610dfd84610bf3565b95602085013595506040909401359392505050565b600080600060608486031215610e2757600080fd5b610e3084610bf3565b9250610e3e60208501610bf3565b9150604084013590509250925092565b600060208284031215610e6057600080fd5b5051919050565b600060208284031215610e7957600080fd5b8151801515811461033d57600080fd5b60008251610e9b818460208701610d5e565b919091019291505056fea26469706673582212205d51d985b168cb9af50ba42d048d778352367969421fa57bb26433a199fa5c6364736f6c63430008110033";

type CreditAccountConstructorParams =
  | [signer?: Signer]
  | ConstructorParameters<typeof ContractFactory>;

const isSuperArgs = (
  xs: CreditAccountConstructorParams
): xs is ConstructorParameters<typeof ContractFactory> => xs.length > 1;

export class CreditAccount__factory extends ContractFactory {
  constructor(...args: CreditAccountConstructorParams) {
    if (isSuperArgs(args)) {
      super(...args);
    } else {
      super(_abi, _bytecode, args[0]);
    }
    this.contractName = "CreditAccount";
  }

  override deploy(
    overrides?: Overrides & { from?: PromiseOrValue<string> }
  ): Promise<CreditAccount> {
    return super.deploy(overrides || {}) as Promise<CreditAccount>;
  }
  override getDeployTransaction(
    overrides?: Overrides & { from?: PromiseOrValue<string> }
  ): TransactionRequest {
    return super.getDeployTransaction(overrides || {});
  }
  override attach(address: string): CreditAccount {
    return super.attach(address) as CreditAccount;
  }
  override connect(signer: Signer): CreditAccount__factory {
    return super.connect(signer) as CreditAccount__factory;
  }
  static readonly contractName: "CreditAccount";

  public readonly contractName: "CreditAccount";

  static readonly bytecode = _bytecode;
  static readonly abi = _abi;
  static createInterface(): CreditAccountInterface {
    return new utils.Interface(_abi) as CreditAccountInterface;
  }
  static connect(
    address: string,
    signerOrProvider: Signer | Provider
  ): CreditAccount {
    return new Contract(address, _abi, signerOrProvider) as CreditAccount;
  }
}