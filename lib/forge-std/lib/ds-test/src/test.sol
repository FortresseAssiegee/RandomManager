// SPDX-License-Identifier: MIT
pragma solidity >=0.6.2;

contract DSTest {
    event log(string);
    event log_address(address);
    event log_bytes(bytes);
    event log_bytes32(bytes32);
    event log_int(int256);
    event log_named_address(string key, address val);
    event log_named_bytes(string key, bytes val);
    event log_named_bytes32(string key, bytes32 val);
    event log_named_decimal_int(string key, int256 val, uint256 decimals);
    event log_named_decimal_uint(string key, uint256 val, uint256 decimals);
    event log_named_int(string key, int256 val);
    event log_named_string(string key, string val);
    event log_named_uint(string key, uint256 val);
    event log_string(string);
    event log_uint(uint256);

    bool public IS_TEST = true;

    function fail() internal virtual {
        require(false, "DSTest fail");
    }

    function assertTrue(bool condition) internal virtual {
        if (!condition) fail();
    }

    function assertTrue(bool condition, string memory) internal virtual {
        assertTrue(condition);
    }

    function assertEq0(bytes memory a, bytes memory b) internal virtual {
        assertTrue(keccak256(a) == keccak256(b));
    }

    function assertEq0(bytes memory a, bytes memory b, string memory) internal virtual {
        assertEq0(a, b);
    }

    function assertEq(address a, address b) internal virtual {
        assertTrue(a == b);
    }

    function assertEq(bytes32 a, bytes32 b) internal virtual {
        assertTrue(a == b);
    }

    function assertEq(uint256 a, uint256 b) internal virtual {
        assertTrue(a == b);
    }

    function assertEq(int256 a, int256 b) internal virtual {
        assertTrue(a == b);
    }
}
