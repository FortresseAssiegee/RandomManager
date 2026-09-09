// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

import "./interfaces/IRandomProject.sol";
import "./interfaces/IBLSVerifier.sol";
import "./libraries/BLS256.sol";

// 核心定位：每个项目自己的随机数请求合约。
// 每个项目一个 RandomProject 最小代理，逻辑一样，但状态独立。
contract RandomProject is
    Initializable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable,
    IRandomProject
{
    address public manager;
    bytes32 public projectId;
    address public verifier;
    BLS256.G2Point blsPublicKey;

    uint256 public requestId;

    enum RequestStatus {
        None,
        Pending,
        Fulfilled,
        Consumed
    }

    // 随机请求结构
    struct RandomRequest {
        address requester;
        bytes32 userSeed;
        uint256 blockNumber;
        uint256 randomness;
        RequestStatus status;
    }
    // 记录请求
    mapping(uint256 => RandomRequest) request;

    // 事件
    event RandomnessRequested(uint256 indexed requestId, address indexed requester, bytes32 userSeed);
    event RandomnessFulfilled(uint256 indexed requestId, uint256 randomness);
    event RandomnessConsumed(uint256 indexed requestId, uint256 randomness);

    // 错误
    error RequestNotFound(uint256 requestId);
    error RequestNotPending(uint256 requestId);
    error RandomnessNotFulfilled(uint256 requestId);
    error InvalidSignature();

    modifier onlyManager() {
        require(msg.sender == manager, "Only manager can call");
        _;
    }

    function initialize(
        address manager_,
        address owner_,
        bytes32 projectId_,
        address verifier_,
        BLS256.G2Point calldata publicKey_
        // Q:calldata是什么类型，这里为什么用这个类型？
        // A:calldata 不是数据类型，而是 Solidity 的“数据位置”。
        // 它表示参数来自外部调用输入，只读，不会复制到内存里。
        // 原因是 G2Point 是结构体，外部函数传结构体时用 calldata 更省 gas。
        // 因为这里只是读取并保存它，不需要在函数里修改它。
        // 如果用 memory，Solidity 会把整个结构体复制到内存，增加 gas 成本。
        // 所以这里用 calldata 是为了节省 gas，符合最佳实践。
        // 如果参数是简单类型（如 uint256），用 memory 或 calldata 差别不大，但对于复杂类型（如 struct 或 array），用 calldata 可以显著降低 gas 成本。
        // 总之，calldata 是外部函数参数的最佳选择，尤其是当参数是复杂数据结构时。
    ) external initializer {
        // Q:initializer是什么类型。这里为什么要用这个类型
        // A:initializer 不是数据类型，而是 OpenZeppelin 提供的一个修饰符（modifier）。
        // 它用于标记一个函数为“初始化函数”，只能被调用一次。
        // 这是因为在使用代理模式部署合约时，构造函数不会被调用，所以需要一个特殊的函数来初始化合约状态。
        // initializer 修饰符会检查这个函数是否已经被调用过，如果是第二次调用就会 revert，确保初始化逻辑只执行一次。

        // 初始化 manager、owner、projectId、verifier、BLS 公钥
        manager = manager_;
        projectId = projectId_;
        verifier = verifier_;
        blsPublicKey = publicKey_;
        // 调用 __Ownable_init(owner_)
        __Ownable_init(owner_);
        // 调用 __Pausable_init()
        __Pausable_init();
        // 调用 __ReentrancyGuard_init()
        __ReentrancyGuard_init();
    }

    // 创建随机数请求
    function requestRandomness(
        bytes32 userSeed // 用户自定义种子，增加随机性，防止预言机攻击
        // Q:随机数是链下生成的吗？
        // A:是的，随机数是在链下生成的。用户调用 requestRandomness 提交一个随机数请求，包含一个 userSeed 作为输入。
        // 然后链下服务（比如一个预言机）会监听这个事件，获取请求信息，生成一个随机数，并使用 BLS 签名对请求消息进行签名。
        // 最后链下服务会调用 fulfillRandomness，提交签名和随机数到链上，
        // 合约会验证签名的有效性，如果验证通过，就将随机数保存到链上供用户查询和消费。
        // Q2:userSeed就是链下生成？传到链上记录的是这个userSeed吗？还是随机数？还是两者都有？
        // A2:userSeed 是用户提供的一个输入参数，记录在链上。
    )
        external
        whenNotPaused
        returns (uint256)
    {
        // requestId 自增
        requestId++;
        // 保存请求人、seed、状态、区块号
        request[requestId] = RandomRequest({
            requester: msg.sender,
            userSeed: userSeed,
            blockNumber: block.number,
            randomness: 0,
            status: RequestStatus.Pending
        });

        // emit RandomnessRequested
        emit RandomnessRequested(requestId, msg.sender, userSeed);

        return requestId;
    }

    // 链下服务调用 fulfillRandomness 提交 BLS 签名
    function fulfillRandomness(uint256 _requestId, BLS256.G1Point calldata signature)
        external
        nonReentrant
        whenNotPaused
    {
        // Q:nonReentrant whenNotPaused 是什么类型？？
        // A:nonReentrant 和 whenNotPaused 都是函数修饰符（modifier）。
        // nonReentrant 是 OpenZeppelin 提供的一个修饰符，用于防止重入攻击。
        // 它通过一个状态变量来跟踪函数是否正在执行，如果在函数执行过程中再次调用同一个函数，就会 revert。
        // whenNotPaused 也是 OpenZeppelin 提供的一个修饰符，用于检查合约是否处于未暂停状态。
        // 如果合约被暂停了，调用这个函数就会 revert。

        _requireRequestExists(_requestId);

        // 链下服务提交 BLS 签名
        // 检验请求合法性：requestId 存在、状态为 pending
        if (request[_requestId].status != RequestStatus.Pending) {
            revert RequestNotPending(_requestId);
        }

        // 合约根据 requestId 重新构造 message
        bytes32 message = getRequestMessage(_requestId);

        // Q:这个IBLSVerifier怎么来的？？？如果是接口，为什么能调用？？
        // A:IBLSVerifier 是一个接口，定义了 verify 函数的签名。
        // 在 Solidity 中，接口只是一个抽象的定义，不包含实现。
        // 但是我们可以通过接口类型的变量（这里是 verifier）来调用实现了这个接口的合约。
        // 也就是说，verifier 变量应该是一个部署了 IBLSVerifier 接口的合约地址。
        // 当我们调用 IBLSVerifier(verifier).verify(...) 时，
        // 实际上是向 verifier 地址发送一个调用请求，执行 verify 函数的逻辑。
        bool valid = IBLSVerifier(verifier).verify(message, signature, blsPublicKey);
        // 验证不通过则 revert
        if (!valid) revert InvalidSignature();

        // 验证通过后生成随机数：
        uint256 randomness = uint256(keccak256(abi.encode(signature, message)));
        // 保存随机数
        request[_requestId].randomness = randomness;
        // 状态改成 fulfilled
        request[_requestId].status = RequestStatus.Fulfilled;
        // emit RandomnessFulfilled
        emit RandomnessFulfilled(_requestId, randomness);
    }

    // 返回 BLS 要签名的消息
    function getRequestMessage(uint256 _requestId) public view returns (bytes32) {
        _requireRequestExists(_requestId);
        // message 必须绑定 chainId、项目代理地址、
        // projectId、requestId、requester、userSeed
        return keccak256(
            abi.encode(
                block.chainid,
                address(this),
                projectId,
                _requestId,
                request[_requestId].requester,
                request[_requestId].userSeed
            )
        );
    }

    // 查询已经 fulfill 的随机数
    function getRandomness(uint256 _requestId) external view returns (uint256) {
        _requireRequestExists(_requestId);
        if (request[_requestId].status != RequestStatus.Fulfilled) {
            revert RandomnessNotFulfilled(_requestId);
        }
        // 未完成则 revert
        return request[_requestId].randomness;
    }

    // 项目方消费随机数
    function consumeRandomness(uint256 _requestId) external onlyOwner returns (uint256) {
        _requireRequestExists(_requestId);
        // 只能消费 fulfilled 状态的随机数，其他状态 revert
        if (request[_requestId].status != RequestStatus.Fulfilled) {
            revert RandomnessNotFulfilled(_requestId);
        }

        uint256 randomness = request[_requestId].randomness;
        // 消费后状态改成 consumed，防止重复消费
        request[_requestId].status = RequestStatus.Consumed;

        emit RandomnessConsumed(_requestId, randomness);

        // 返回随机数
        return randomness;
    }

    // 项目方更新 BLS 公钥
    function setPublicKey(BLS256.G2Point calldata newPublicKey) external onlyOwner {
        blsPublicKey = newPublicKey;
    }

    // 紧急暂停/恢复
    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function getRequest(uint256 _requestId)
        external
        view
        returns (address requester, bytes32 userSeed, uint256 blockNumber, uint256 randomness, uint8 status)
    {
        _requireRequestExists(_requestId);
        RandomRequest storage req = request[_requestId];

        return (req.requester, req.userSeed, req.blockNumber, req.randomness, uint8(req.status));
    }

    function _requireRequestExists(uint256 _requestId) internal view {
        if (request[_requestId].status == RequestStatus.None) {
            revert RequestNotFound(_requestId);
        }
    }
}
