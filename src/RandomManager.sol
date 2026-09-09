// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/proxy/Clones.sol";

import "./interfaces/IRandomManager.sol";
import "./RandomProject.sol";
import "./libraries/BLS256.sol";

// 核心定位：项目代理工厂 + 项目代理注册中心。
// 用 OpenZeppelin Clones 部署 EIP-1167 最小代理。
// OpenZeppelin 文档里 Clones 支持 cloneDeterministic 和 predictDeterministicAddress，正好适合你的 CREATE2 需求。
contract RandomManager is IRandomManager {
    address public immutable implementation;
    address public immutable verifier;

    mapping(bytes32 => address) public projectProxy; //项目 ID => 代理地址
    mapping(address => bool) public isProjectProxy; //代理地址 => 是否由管理合约创建
    //Q：为什么要记录 isProjectProxy？projectProxy 已经记录了项目 ID 和代理地址的映射关系，
    // 为什么还需要一个单独的 mapping 来记录代理地址是否由管理合约创建呢？
    //A：记录 isProjectProxy 的主要原因是为了快速验证一个给定的代理地址是否是由管理合约创建的。
    // 这在某些情况下可能会非常有用，比如在 fulfillRandomness 函数中，我们需要验证调用者是否是一个合法的项目代理地址。
    // 如果我们只使用 projectProxy 来验证，我们需要遍历整个 projectProxy 映射来检查是否存在一个项目 ID 对应这个代理地址，
    // 这样的操作在 Solidity 中是非常低效的，因为映射不支持迭代。
    // 通过使用 isProjectProxy，我们可以直接通过代理地址进行 O(1) 的查找，
    // 快速判断这个地址是否是一个合法的项目代理地址，从而提高函数的执行效率和安全性。
    // Q:都是映射，为什么isProjectProxy可以直接通过代理地址进行 O(1) 的查找，而 projectProxy 不能？
    // A:在 Solidity 中，映射（mapping）是一个键值对的数据结构，它允许你通过键（key）快速查找对应的值（value）。
    // 映射的查找操作是 O(1) 的，因为它使用哈希表实现。
    // 在 projectProxy 映射中，键是项目 ID（bytes32），值是代理地址（address）。
    // 这意味着你可以通过项目 ID 快速查找对应的代理地址，但你不能直接通过代理地址查找项目 ID，因为映射不支持反向查找。
    // 在 isProjectProxy 映射中，键是代理地址（address），值是一个布尔值（bool），表示这个代理地址是否由管理合约创建。
    // 这样，你可以直接通过代理地址进行 O(1) 的查找，快速判断这个地址是否是一个合法的项目代理地址。

    event ProjectCreated(bytes32 indexed projectId, address indexed owner, address indexed proxy, bytes32 salt);
    error InvalidAddress();
    error ProjectAlreadyExists(bytes32 projectId);
    error ProjectNotExists(bytes32 projectId);

    constructor(address implementation_, address verifier_) {
        // Q:implementation_地址是怎么来的？为什么要传入？
        // A:implementation_ 地址是指向 RandomProject 逻辑合约的地址。
        // 在使用 EIP-1167 最小代理模式时，所有的代理合约都会共享同一个逻辑合约的代码。
        // 传入 implementation_ 地址的目的是为了让 RandomManager 知道应该使用哪个逻辑合约来创建新的代理合约。
        // 这个地址通常是在部署 RandomManager 之前，先部署 RandomProject 逻辑合约，
        // 然后将其地址作为参数传入 RandomManager 的构造函数。
        // 同样，verifier_ 地址是指向一个实现了 IBLSVerifier 接口的合约地址，用于验证 BLS 签名。
        // Q2:所以这个 implementation_ 地址就是 RandomProject 逻辑合约的地址吗？那为什么要传入，
        // 而不是在 RandomManager 内部直接部署一个 RandomProject 逻辑合约呢？
        // A2:是的，implementation_ 地址就是 RandomProject 逻辑合约的地址。
        // 之所以要传入而不是在 RandomManager 内部直接部署一个 RandomProject 逻辑合约，主要是为了分离部署过程和逻辑合约的管理。
        // 通过将 implementation_ 地址作为参数传入，部署者可以在部署 RandomManager 之前先部署 RandomProject 逻辑合约，
        // 并且可以选择使用不同版本的逻辑合约来创建代理。
        // 这种设计也使得 RandomManager 更加灵活，因为它不依赖于特定的逻辑合约地址，可以在需要时更换逻辑合约而不需要修改 RandomManager 的代码。
        // Q3:这种方式也就是可以进行对逻辑合约的升级?
        // A3:是的，这种方式确实支持对逻辑合约的升级。
        // 通过传入新的 implementation_ 地址，部署者可以让 RandomManager 创建新的代理合约时使用新的逻辑合约代码。

        // 逻辑合约地址
        if (implementation_ == address(0) || verifier_ == address(0)) {
            revert InvalidAddress();
        }

        implementation = implementation_;
        // 验证合约地址
        verifier = verifier_;
    }

    // 部署每个项目自己的最小代理合约
    // 记录 projectId => proxy
    // 校验某个代理是否由管理合约创建
    // 使用 CREATE2 预测和部署代理地址
    function createProject(
        bytes32 projectId, //项目 ID
        address owner, //项目所有者地址
        bytes32 userSalt, //用户自定义盐值
        BLS256.G2Point calldata publicKey //项目的 BLS 公钥
    )
        public
        returns (address)
    {
        address proxy;

        // 检查 projectId 未创建
        if (projectProxy[projectId] != address(0)) {
            revert ProjectAlreadyExists(projectId);
        }
        // 检验 owner 地址合法
        if (owner == address(0)) revert InvalidAddress();

        // 根据 projectId + owner + userSalt 生成最终 salt
        bytes32 salt = makeSalt(projectId, owner, userSalt);

        // 使用 Clones.cloneDeterministic(implementation, salt) 创建最小代理
        // 根据逻辑合约地址，克隆一个新的最小代理合约，返回一个新的代理地址 proxy
        proxy = Clones.cloneDeterministic(implementation, salt);

        // 调用 RandomProject(proxy).initialize(...)
        // Q:为什么要为合约传入proxy，合约构造的时候并没有参数，请问这个参数传到哪里去了？
        // A:这里的 RandomProject(proxy).initialize(...) 是在调用新创建的代理合约的 initialize 函数。
        // 由于我们使用了 OpenZeppelin 的 Clones 库来创建最小代理，这些代理合约的逻辑代码是共享的，但它们的状态是独立的。
        // 当我们调用 RandomProject(proxy).initialize(...) 时，实际上是在向 proxy 地址发送一个交易，执行 initialize 函数的逻辑。
        // 这个 initialize 函数会设置代理合约的状态变量，比如 manager、owner、projectId、verifier 和 blsPublicKey。
        // Q2:意思是poxy就是根据逻辑合约创建的一个新合约？
        // A2:是的，proxy 是根据 implementation（也就是 RandomProject 逻辑合约）创建的一个新的最小代理合约。
        // 这个代理合约会有自己的地址和状态，但它的代码是指向 implementation 的。
        RandomProject(proxy).initialize(address(this), owner, projectId, verifier, publicKey);

        // 记录 projectProxy[projectId] = proxy
        projectProxy[projectId] = proxy;
        // 记录 isProjectProxy[proxy] = true
        isProjectProxy[proxy] = true;
        // emit ProjectCreated
        emit ProjectCreated(projectId, owner, proxy, salt);

        return proxy;
    }

    // 提前预测代理地址
    function predictProjectAddress(bytes32 projectId, address owner, bytes32 userSalt)
        external
        view
        returns (address proxy)
    {
        // Q:检验，不知道这里逻辑对吗？
        // 如果项目已存在，直接返回已部署地址
        if (projectProxy[projectId] != address(0)) return projectProxy[projectId];

        bytes32 salt = makeSalt(projectId, owner, userSalt);
        // 内部调用 Clones.predictDeterministicAddress
        return Clones.predictDeterministicAddress(implementation, salt);
    }

    // 返回项目对应的代理地址
    function getProjectProxy(bytes32 projectId) external view returns (address) {
        // 检验是否存在 projectProxy[projectId]
        if (projectProxy[projectId] == address(0)) revert ProjectNotExists(projectId);
        return projectProxy[projectId];
    }

    // 统一生成 CREATE2 salt
    function makeSalt(bytes32 projectId, address owner, bytes32 userSalt) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(projectId, owner, userSalt));
    }
}
