// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import {LaunchboxERC20} from "./LaunchboxERC20.sol";

contract LaunchboxFactory is Ownable(msg.sender) {
    event TokenDeployed(address tokenAddress, address launchboxExchangeAddress, address creator);
    event LaunchboxExchangeImplementationUpdated(address newLaunchboxExchangeAddress);
    event TokenImplementationUpdated(address newTokenImplementationAddress);
    event UniswapRouterUpdated(address newRouter);

    address public immutable tokenImplementation;
    address public immutable launchboxExchangeImplementation;
    address public immutable router;
    /**
     * @notice Percentage of token supply to charge as fee
     */
    uint256 public platformFeePercentage;
    /**
     * @notice Percentage of token supply that goes to the token creator for community incentives
     */
    uint256 public communityPercentage;

    address payable communityTreasuryOwner;

    address payable platformFeeAddress;

    uint256 public marketCapThreshold;

    uint256 private constant MAX_TOKEN_DECIMALS = 18;
    uint256 private constant HUNDRED_PERCENTAGE = 100 * 1e18;

    error EmptyTokenImplementation();
    error EmptyLaunchboxExchangeImplementation();
    error EmptyAerodromeRouter();
    error FeeGreaterThanHundred();
    error EmptyPlatformFeeReceiver();

    constructor(
        address _tokenImplementation,
        address _launchboxExchangeImplementation,
        address _router,
        address _platformFeeReceiver,
        uint256 _marketCapThreshold,
        uint256 _platformFeePercentage,
        uint256 _communityAllocPercentage
    ) {
        if (_tokenImplementation == address(0)) {
            revert EmptyTokenImplementation();
        }
        if (_launchboxExchangeImplementation == address(0)) {
            revert EmptyLaunchboxExchangeImplementation();
        }
        if (_router == address(0)) revert EmptyAerodromeRouter();
        if (_platformFeePercentage + _communityAllocPercentage > HUNDRED_PERCENTAGE) {
            revert FeeGreaterThanHundred();
        }
        if (_platformFeeReceiver == address(0)) revert EmptyPlatformFeeReceiver();
        platformFeeAddress = payable(_platformFeeReceiver);
        platformFeePercentage = _platformFeePercentage;
        communityPercentage = _communityAllocPercentage;
        tokenImplementation = _tokenImplementation;
        launchboxExchangeImplementation = _launchboxExchangeImplementation;
        marketCapThreshold = _marketCapThreshold;
        router = _router;
    }

    function deployToken(string memory name, string memory symbol, string memory metadataURI, uint256 maxSupply)
        external
        payable
        returns (address, address)
    {
        // calculate platform fee
        uint256 feeFromTokenSupply = _calculatePlatformFee(maxSupply);
        // calculate community percentage
        uint256 communityAllocFromTokenSupply = _calculateCommunityFee(maxSupply);
        address tokenClone = Clones.clone(tokenImplementation);

        LaunchboxERC20.InitializeParams memory params = LaunchboxERC20.InitializeParams(
            name,
            symbol,
            metadataURI,
            maxSupply - (feeFromTokenSupply + communityAllocFromTokenSupply),
            feeFromTokenSupply,
            communityAllocFromTokenSupply,
            marketCapThreshold,
            launchboxExchangeImplementation,
            platformFeeAddress,
            router,
            msg.sender
        );

        address curveClone = LaunchboxERC20(tokenClone).initialize(params);

        emit TokenDeployed(tokenClone, curveClone, msg.sender);
        return (tokenClone, curveClone);
    }

    /**
     * @dev override renounce ownership to be impossible
     */
    function renounceOwnership() public override onlyOwner {
        revert();
    }

    function setPlatformFeePercentage(uint256 _platformFeePercentage) public onlyOwner {
        platformFeePercentage = _platformFeePercentage;
    }

    function setCommunityPerecentage(uint256 _communityPercentage) public onlyOwner {
        communityPercentage = _communityPercentage;
    }

    function setPlatformFeeAddress(address payable _platformFeeAddress) public onlyOwner {
        platformFeeAddress = _platformFeeAddress;
    }

    function setMarketCapThreshold(uint256 _newMarketCapThreshold) public onlyOwner {
        marketCapThreshold = _newMarketCapThreshold;
    }

    function _calculatePlatformFee(uint256 _totalSupply) internal returns (uint256) {
        return (_totalSupply * platformFeePercentage) / HUNDRED_PERCENTAGE;
    }

    function _calculateCommunityFee(uint256 _totalSupply) internal returns (uint256) {
        return (_totalSupply * communityPercentage) / HUNDRED_PERCENTAGE;
    }
}
