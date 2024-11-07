// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {Deployers} from "@uniswap/v4-core/test/utils/Deployers.sol";
import {MockERC20} from "solmate/src/test/utils/mocks/MockERC20.sol";
import {PoolManager} from "v4-core/PoolManager.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {Currency, CurrencyLibrary} from "v4-core/types/Currency.sol";
import {PoolId, PoolIdLibrary} from "v4-core/types/PoolId.sol";
import {LPFeeLibrary} from "v4-core/libraries/LPFeeLibrary.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {PoolSwapTest} from "v4-core/test/PoolSwapTest.sol";
import {TickMath} from "v4-core/libraries/TickMath.sol";
import {StateLibrary} from "v4-core/libraries/StateLibrary.sol";
import {console} from "forge-std/console.sol";

import {NezlobinHook} from "../src/NezlobinHook.sol";

contract TestGasPriceFeesHook is Test, Deployers {
    using CurrencyLibrary for Currency;
    using PoolIdLibrary for PoolKey;

    NezlobinHook hook;

    

    function getCurrentFee(PoolId id) public view returns (uint24) {
        (, , , uint24 fee) = StateLibrary.getSlot0(manager, id);
        return fee;
    }
    
    function getCurrentTick(PoolId id) public view returns (int24) {
        (, int24 currentTick, , ) = StateLibrary.getSlot0(manager, id);
        return currentTick;
    }



    // https://github.com/Jaseempk/NZ-Directional-Fee/blob/main/test/NezlobinDFee.t.sol

    function setUp() public {
        // Deploy v4-core
        deployFreshManagerAndRouters();

        // Deploy, mint tokens, and approve all periphery contracts for two tokens
        deployMintAndApprove2Currencies();

        // Deploy our hook with the proper flags
        address hookAddress = address(
            uint160( 
                Hooks.AFTER_INITIALIZE_FLAG | 
                Hooks.BEFORE_SWAP_FLAG
            )
        );

        // Set gas price = 10 gwei and deploy our hook
        vm.txGasPrice(10 gwei);
        deployCodeTo("NezlobinHook", abi.encode(manager), hookAddress);
        hook = NezlobinHook(hookAddress);

        // Initialize a pool
        (key, ) = initPool(
            currency0,
            currency1,
            hook,
            LPFeeLibrary.DYNAMIC_FEE_FLAG, // Set the `DYNAMIC_FEE_FLAG` in place of specifying a fixed fee
            SQRT_PRICE_1_1
        );

        // Add some liquidity
        modifyLiquidityRouter.modifyLiquidity(
            key,
            IPoolManager.ModifyLiquidityParams({
                tickLower: -60,
                tickUpper: 60,
                liquidityDelta: 100 ether,
                salt: bytes32(0)
            }),
            ZERO_BYTES
        );

        modifyLiquidityRouter.modifyLiquidity(
            key,
            IPoolManager.ModifyLiquidityParams({
                tickLower: -120,
                tickUpper: -60,
                liquidityDelta: 100 ether,
                salt: bytes32(0)
            }),
            ZERO_BYTES
        );
    }

    function test_no_fee_impact() public {
        vm.warp(1);

        // Set up our swap parameters
        PoolSwapTest.TestSettings memory testSettings = PoolSwapTest
            .TestSettings({takeClaims: false, settleUsingBurn: false});

        IPoolManager.SwapParams memory params = IPoolManager.SwapParams({
            zeroForOne: true,
            amountSpecified: -0.00001 ether,
            sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1
        });

        uint256 balanceOfToken1Before = currency1.balanceOfSelf();
        swapRouter.swap(key, params, testSettings, ZERO_BYTES);

        uint256 balanceOfToken1After = currency1.balanceOfSelf();
        uint256 outputFromBaseFeeSwap = balanceOfToken1After - balanceOfToken1Before;

        assertGt(balanceOfToken1After, balanceOfToken1Before);

        uint24 fee = hook.calculateDynamicFee(key.toId(), true);
        console.log(fee);

        vm.warp(2);

        swapRouter.swap(key, params, testSettings, ZERO_BYTES);
        fee = hook.calculateDynamicFee(key.toId(), true);
        console.log(fee);

        assertEq(fee, 0);  // No change in the fee
    }

    function test_gas_fee_impact() public {
        vm.warp(1);
        // Set up our swap parameters
        PoolSwapTest.TestSettings memory testSettings = PoolSwapTest
            .TestSettings({takeClaims: false, settleUsingBurn: false});

        IPoolManager.SwapParams memory params = IPoolManager.SwapParams({
            zeroForOne: true,
            // amountSpecified: -10 ether,
            // amountSpecified: -0.01 ether,
            amountSpecified: -0.00001 ether,
            sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1
        });

        int24 tick = getCurrentTick(key.toId());

        uint256 balanceOfToken1Before = currency1.balanceOfSelf();
        swapRouter.swap(key, params, testSettings, ZERO_BYTES);

        tick = getCurrentTick(key.toId());
        console.logString("1 swap tick");
        console.log(tick);

        uint256 balanceOfToken1After = currency1.balanceOfSelf();
        uint256 outputFromBaseFeeSwap = balanceOfToken1After - balanceOfToken1Before;

        assertGt(balanceOfToken1After, balanceOfToken1Before);

        uint24 fee = hook.calculateDynamicFee(key.toId(), true);
        console.logString("--> Computed fee");
        console.log(fee);

        vm.warp(2);

        swapRouter.swap(key, params, testSettings, ZERO_BYTES);
        swapRouter.swap(key, params, testSettings, ZERO_BYTES);
        swapRouter.swap(key, params, testSettings, ZERO_BYTES);
        console.logString("--> 2 swap tick");
        console.log(tick);

        fee = hook.calculateDynamicFee(key.toId(), true);
        console.logString("--> Computed fee");
        console.log(fee);
        assertGt(fee, 0);  // No change in the fee
    }

    // FIXME: Need to check the evolution of fee


}