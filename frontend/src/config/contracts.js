export const SEPOLIA_CHAIN_ID = 11155111;
export const SEPOLIA_CHAIN_HEX = "0xaa36a7";
export const DEFAULT_MANAGER_ADDRESS =
  import.meta.env.VITE_MANAGER_ADDRESS ||
  "0xfA2b73B9B314CD5033d819bDf58a8bD62D4a24c5";
export const DEFAULT_RPC_URL =
  import.meta.env.VITE_SEPOLIA_RPC_URL ||
  "https://ethereum-sepolia-rpc.publicnode.com";
export const EXPLORER_URL = "https://sepolia.etherscan.io";

export const MANAGER_ABI = [
  "function implementation() view returns (address)",
  "function verifier() view returns (address)",
  "function projectProxy(bytes32) view returns (address)",
  "function isProjectProxy(address) view returns (bool)",
  "function makeSalt(bytes32 projectId, address owner, bytes32 userSalt) pure returns (bytes32)",
  "function predictProjectAddress(bytes32 projectId, address owner, bytes32 userSalt) view returns (address proxy)",
  "function createProject(bytes32 projectId, address owner, bytes32 userSalt, tuple(uint256[2] x, uint256[2] y) publicKey) returns (address proxy)",
  "event ProjectCreated(bytes32 indexed projectId, address indexed owner, address indexed proxy, bytes32 salt)",
];

export const PROJECT_ABI = [
  "function manager() view returns (address)",
  "function owner() view returns (address)",
  "function projectId() view returns (bytes32)",
  "function verifier() view returns (address)",
  "function requestId() view returns (uint256)",
  "function paused() view returns (bool)",
  "function requestRandomness(bytes32 userSeed) returns (uint256)",
  "function getRequest(uint256 requestId) view returns (address requester, bytes32 userSeed, uint256 blockNumber, uint256 randomness, uint8 status)",
  "function getRequestMessage(uint256 requestId) view returns (bytes32)",
  "function getRandomness(uint256 requestId) view returns (uint256)",
  "function consumeRandomness(uint256 requestId) returns (uint256)",
  "function fulfillRandomness(uint256 requestId, tuple(uint256 x, uint256 y) signature)",
  "function setPublicKey(tuple(uint256[2] x, uint256[2] y) newPublicKey)",
  "function pause()",
  "function unpause()",
  "event RandomnessRequested(uint256 indexed requestId, address indexed requester, bytes32 userSeed)",
  "event RandomnessFulfilled(uint256 indexed requestId, uint256 randomness)",
  "event RandomnessConsumed(uint256 indexed requestId, uint256 randomness)",
  "event Paused(address account)",
  "event Unpaused(address account)",
];
