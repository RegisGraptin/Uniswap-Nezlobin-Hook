// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "v4-core/types/PoolId.sol";
import {Currency} from "v4-core/types/Currency.sol";
import {CurrencySettler} from "@uniswap/v4-core/test/utils/CurrencySettler.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {BeforeSwapDelta, toBeforeSwapDelta} from "v4-core/types/BeforeSwapDelta.sol";
import {BaseHook} from "v4-periphery/src/base/hooks/BaseHook.sol";
import {StateLibrary} from "v4-core/libraries/StateLibrary.sol";
import {Currency, CurrencyLibrary} from "v4-core/types/Currency.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "v4-core/types/BeforeSwapDelta.sol";
import {LPFeeLibrary} from "v4-core/libraries/LPFeeLibrary.sol";
import {Math} from "v4-periphery/lib/permit2/lib/openzeppelin-contracts/contracts/utils/math/Math.sol";

import {console} from "forge-std/console.sol";

contract NezlobinHook is BaseHook {
	
    using LPFeeLibrary for uint24;
    using StateLibrary for IPoolManager;
    using PoolIdLibrary for PoolKey;
    using CurrencyLibrary for Currency;

    uint24 public constant BASE_FEE = 3000; // 0.3%
    uint24 public constant MIN_FEE = 500; // 0.05%
    uint24 public constant MAX_FEE = 50000; // 5%  // TODO: What should be the max fee
    
    uint24 public constant SCALE = 1000;
    uint24 public constant C = 750; // 0.75%
    
    // Store the last blockTimestamp
    mapping(PoolId poolId => uint blockTimestamp) lastBlockTimestamps;

    // Track the last tick
    mapping(PoolId poolId => int24 lastTick) lastTicks;
    
    error MustUseDynamicFee();

	constructor(IPoolManager poolManager) BaseHook(poolManager) {}

	function getHookPermissions()
        public
        pure
        override
        returns (Hooks.Permissions memory)
    {
        return
            Hooks.Permissions({
                beforeInitialize: false,
                afterInitialize: true,
                beforeAddLiquidity: false,
                afterAddLiquidity: false,
                beforeRemoveLiquidity: false,
                afterRemoveLiquidity: false,
                beforeSwap: true,
                afterSwap: false,
                beforeDonate: false,
                afterDonate: false,
                beforeSwapReturnDelta: false,
                afterSwapReturnDelta: false,
                afterAddLiquidityReturnDelta: false,
                afterRemoveLiquidityReturnDelta: false
            });
    }

    function afterInitialize(
        address,
        PoolKey calldata key,
        uint160,
        int24 tick
    ) external override onlyPoolManager returns (bytes4) {
	
        // Check that the attached pool has dynamic fee
        if(!key.fee.isDynamicFee()) revert MustUseDynamicFee();

        // Save block information
    	lastBlockTimestamps[key.toId()] = block.timestamp;
        lastTicks[key.toId()] = tick;

        return this.afterInitialize.selector;
    }

    function beforeSwap(
        address,
        PoolKey calldata key,
        IPoolManager.SwapParams calldata params,
        bytes calldata
    )
        external
        override
        onlyPoolManager
        returns (bytes4, BeforeSwapDelta, uint24)
    {
        PoolId poolId = key.toId();
        
        // Check if we need to update the information
        if (lastBlockTimestamps[poolId] < block.timestamp) {
            lastBlockTimestamps[poolId] = block.timestamp;

            // Extract swap parameters
            bool zeroForOne = params.zeroForOne;

            uint24 newFee = calculateDynamicFee(poolId, zeroForOne);
            if (newFee == 0) {
                return (this.beforeSwap.selector, BeforeSwapDeltaLibrary.ZERO_DELTA, 0);        
            }

            // FIXME :: Analyse tick evolution throught price
            // Understand why gas price spread
            // Is it because of gas limit ???

            // Update last tick & fees
            (, int24 currentTick, , ) = poolManager.getSlot0(poolId);
            lastTicks[poolId] = currentTick;
            poolManager.updateDynamicLPFee(key, newFee);
        }


        // TODO: I am computing dynamic fee for a given block
        // But return the fee based on one action
        // Should I not compute it each time based on the tick behaviour and swap action ?

        return (this.beforeSwap.selector, BeforeSwapDeltaLibrary.ZERO_DELTA, 0);
    }


    function calculateDynamicFee(
        PoolId poolId,
        bool zeroForOne
    ) public view returns (uint24) { 
        // When return 0 --> no change in fee

        // Need to update the fee
        (, int24 currentTick, , uint24 baseFee) = poolManager.getSlot0(poolId);

        int24 tickDelta = currentTick - lastTicks[poolId];
        
        // No need to update the fee
        if (tickDelta == 0) { return 0; }

        console.logString("- tickDelta");
        console.log(tickDelta);

        // Normalize delta variation
        uint24 delta = tickDelta < 0 ? uint24(-tickDelta) : uint24(tickDelta);

        console.logString("- delta value:");
        console.log(delta);

        // Compute the delta fee
        uint256 ddeltaFee = (uint256(delta) * uint256(C)) / uint256(SCALE);
        console.log(ddeltaFee);
        uint24 deltaFee = uint24(ddeltaFee);
        console.log(deltaFee);

        // Update fee according the swap direction
        if (zeroForOne) {
            if (deltaFee > BASE_FEE - MIN_FEE) {
                return MIN_FEE;
            }
            return BASE_FEE - deltaFee;
        } else {
            return uint24(Math.min(
                BASE_FEE + deltaFee,
                MAX_FEE
            ));
        }


        // FIXME: Should we limit the fee variation ?
        // Instead of updating it directly, should we take the current fee of the pool
        // and apply a variation from it, instead of updating it directly.

    }


    // function getCurrentFee(PoolKey calldata key) public view returns (uint24) {
    //     PoolId id = PoolIdLibrary.toId(key);
    //     (, , , uint24 fee) = StateLibrary.getSlot0(manager, id);
    //     return fee;
    // }

	
}