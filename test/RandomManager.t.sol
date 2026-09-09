// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import "../src/RandomManager.sol";
import "../src/RandomProject.sol";
import "../src/libraries/BLS256.sol";
import "../src/verifier/MockBLSVerifier.sol";

contract RandomManagerTest is Test {
    RandomManager public randomManager;
    RandomProject public implementation;
    MockBLSVerifier public mockVerifier;

    bytes32 internal constant PROJECT_ID = bytes32("project1");
    bytes32 internal constant USER_SALT = bytes32("userSalt");
    address internal projectOwner = address(0x1234);

    function _publicKey() internal pure returns (BLS256.G2Point memory) {
        return BLS256.G2Point({x: [uint256(0), uint256(0)], y: [uint256(0), uint256(0)]});
    }

    function setUp() public {
        implementation = new RandomProject();
        mockVerifier = new MockBLSVerifier();
        randomManager = new RandomManager(address(implementation), address(mockVerifier));
    }

    function testConstructorStoresImplementationAndVerifier() public {
        assertEq(randomManager.implementation(), address(implementation));
        assertEq(randomManager.verifier(), address(mockVerifier));
    }

    //
    function testConstructorRejectsZeroAddress() public {
        // Q:vm是什么？
        // A:vm 是 Forge 提供的一个特殊对象，允许你在测试中模拟各种区块链环境和行为。
        // 你可以使用 vm 来设置区块链状态、模拟交易、检查事件、控制时间等。在这个测试中，
        // 我们使用 vm.expectRevert 来预期构造函数在接收到无效地址时会 revert，并且我们检查 revert 的错误类型是否正确。
        // Q2：vm.expectRevert(RandomManager.InvalidAddress.selector) 是什么意思？selector 是什么意思？
        // A2:vm.expectRevert(RandomManager.InvalidAddress.selector)
        // 是 Forge 测试框架中的一个函数调用，用于在测试中预期某个操作会触发revert，
        // 并且 revert 的错误类型是 RandomManager 合约中定义的 InvalidAddress 错误。
        // 在 Solidity 中，错误类型（error type）是通过一个唯一的标识符（selector）来表示的。
        // 这个 selector 是一个 4 字节的哈希值，它是通过对错误类型的名称进行 Keccak-256 哈希计算得到的。
        // 通过使用 selector，我们可以在测试中精确地检查 revert 的错误类型，而不仅仅是检查是否发生了 revert。
        vm.expectRevert(RandomManager.InvalidAddress.selector);
        // Q:这里为什么new一个新的 RandomManager？不是直接测试构造函数吗？
        // A:是的，这里我们确实是在测试构造函数。通过尝试创建一个新的 RandomManager 实例，并传入无效的地址，
        // 我们可以验证构造函数是否正确地处理了这种情况并触发了预期的 revert。
        // 这个测试的目的是确保构造函数在接收到无效地址时能够正确地拒绝并触发 InvalidAddress 错误。
        new RandomManager(address(0), address(mockVerifier));

        vm.expectRevert(RandomManager.InvalidAddress.selector);
        new RandomManager(address(implementation), address(0));
    }

    function testPredictProjectAddressMatchesCreatedProxy() public {
        address predicted = randomManager.predictProjectAddress(PROJECT_ID, projectOwner, USER_SALT);

        address proxy = randomManager.createProject(PROJECT_ID, projectOwner, USER_SALT, _publicKey());

        assertEq(proxy, predicted);
        assertTrue(proxy.code.length > 0);
    }

    function testCreateProjectRegistersProxy() public {
        address proxy = randomManager.createProject(PROJECT_ID, projectOwner, USER_SALT, _publicKey());

        assertEq(randomManager.projectProxy(PROJECT_ID), proxy);
        assertEq(randomManager.getProjectProxy(PROJECT_ID), proxy);
        assertTrue(randomManager.isProjectProxy(proxy));
    }

    function testCreateProjectInitializesProxyState() public {
        address proxy = randomManager.createProject(PROJECT_ID, projectOwner, USER_SALT, _publicKey());

        RandomProject project = RandomProject(proxy);

        assertEq(project.manager(), address(randomManager));
        assertEq(project.owner(), projectOwner);
        assertEq(project.projectId(), PROJECT_ID);
        assertEq(project.verifier(), address(mockVerifier));
    }

    function testPredictReturnsExistingProxyAfterCreate() public {
        address proxy = randomManager.createProject(PROJECT_ID, projectOwner, USER_SALT, _publicKey());

        address predictedAfterCreate = randomManager.predictProjectAddress(PROJECT_ID, projectOwner, USER_SALT);

        assertEq(predictedAfterCreate, proxy);
    }

    function testCannotCreateSameProjectTwice() public {
        randomManager.createProject(PROJECT_ID, projectOwner, USER_SALT, _publicKey());

        vm.expectRevert(abi.encodeWithSelector(RandomManager.ProjectAlreadyExists.selector, PROJECT_ID));
        randomManager.createProject(PROJECT_ID, projectOwner, USER_SALT, _publicKey());
    }

    function testCannotCreateProjectWithZeroOwner() public {
        vm.expectRevert(RandomManager.InvalidAddress.selector);
        randomManager.createProject(PROJECT_ID, address(0), USER_SALT, _publicKey());
    }

    function testGetProjectProxyRevertsWhenProjectDoesNotExist() public {
        vm.expectRevert(abi.encodeWithSelector(RandomManager.ProjectNotExists.selector, PROJECT_ID));
        randomManager.getProjectProxy(PROJECT_ID);
    }
}
