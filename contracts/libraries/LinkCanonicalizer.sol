// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

library LinkCanonicalizer {
    bytes1 private constant LOWER_A = bytes1("a");
    bytes1 private constant LOWER_Z = bytes1("z");
    bytes1 private constant UPPER_A = bytes1("A");
    bytes1 private constant UPPER_Z = bytes1("Z");

    function canonicalize(string memory rawLink) internal pure returns (string memory) {
        bytes memory input = bytes(rawLink);
        if (input.length == 0) {
            return "";
        }

        // Lowercase and trim whitespace
        bytes memory lowered = _toLowerAndTrim(input);

        // Split into base and query string
        (bytes memory basePart, bytes memory query) = _splitQuery(lowered);

        // Remove trailing slash on path (but keep root slash)
        basePart = _stripTrailingSlash(basePart);

        if (query.length == 0) {
            return string(basePart);
        }

        bytes memory filtered = _filterUtmParams(query);
        if (filtered.length == 0) {
            return string(basePart);
        }

        return string(abi.encodePacked(basePart, "?", filtered));
    }

    function computeLinkId(string memory rawLink) internal pure returns (bytes32) {
        return keccak256(bytes(canonicalize(rawLink)));
    }

    function _toLowerAndTrim(bytes memory input) private pure returns (bytes memory) {
        uint256 start;
        uint256 end = input.length;
        while (start < input.length && _isWhitespace(input[start])) {
            start++;
        }
        while (end > start && _isWhitespace(input[end - 1])) {
            end--;
        }
        bytes memory output = new bytes(end - start);
        for (uint256 i = start; i < end; i++) {
            bytes1 char = input[i];
            if (char >= UPPER_A && char <= UPPER_Z) {
                output[i - start] = bytes1(uint8(char) + 32);
            } else {
                output[i - start] = char;
            }
        }
        return output;
    }

    function _splitQuery(bytes memory value) private pure returns (bytes memory basePart, bytes memory query) {
        for (uint256 i = 0; i < value.length; i++) {
            if (value[i] == bytes1("?")) {
                basePart = new bytes(i);
                for (uint256 j = 0; j < i; j++) {
                    basePart[j] = value[j];
                }
                uint256 queryLength = value.length - i - 1;
                query = new bytes(queryLength);
                for (uint256 j = 0; j < queryLength; j++) {
                    query[j] = value[i + 1 + j];
                }
                return (basePart, query);
            }
        }
        basePart = value;
        return (basePart, query);
    }

    function _stripTrailingSlash(bytes memory basePart) private pure returns (bytes memory) {
        if (basePart.length <= 1) {
            return basePart;
        }
        if (basePart[basePart.length - 1] == bytes1("/")) {
            bytes memory trimmed = new bytes(basePart.length - 1);
            for (uint256 i = 0; i < trimmed.length; i++) {
                trimmed[i] = basePart[i];
            }
            return trimmed;
        }
        return basePart;
    }

    function _filterUtmParams(bytes memory query) private pure returns (bytes memory) {
        bytes memory buffer = new bytes(query.length);
        uint256 bufferLength;
        uint256 start;
        while (start < query.length) {
            uint256 end = start;
            while (end < query.length && query[end] != bytes1("&")) {
                end++;
            }

            bool isUtm = _startsWithUtm(query, start, end);
            if (!isUtm) {
                if (bufferLength > 0) {
                    buffer[bufferLength++] = bytes1("&");
                }
                for (uint256 i = start; i < end; i++) {
                    buffer[bufferLength++] = query[i];
                }
            }

            start = end + 1;
        }

        bytes memory output = new bytes(bufferLength);
        for (uint256 i = 0; i < bufferLength; i++) {
            output[i] = buffer[i];
        }
        return output;
    }

    function _startsWithUtm(bytes memory query, uint256 start, uint256 end) private pure returns (bool) {
        if (end <= start + 4) {
            return false;
        }
        if (query[start] != bytes1("u") || query[start + 1] != bytes1("t") || query[start + 2] != bytes1("m") || query[start + 3] != bytes1("_")) {
            return false;
        }
        return true;
    }

    function _isWhitespace(bytes1 char) private pure returns (bool) {
        return char == 0x20 || char == 0x09 || char == 0x0d || char == 0x0a;
    }
}
