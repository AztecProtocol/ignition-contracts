import {Test} from "forge-std/Test.sol";

import {ATPFactoryNonces, IATPFactoryNonces} from "@atp/ATPFactoryNonces.sol";
import {IRegistry} from "@atp/Registry.sol";

import {MockERC20} from "test/mocks/MockERC20.sol";
import {IERC20} from "@oz/token/ERC20/IERC20.sol";

import {VirtualAztecToken, IVirtualAztecToken} from "src/uniswap-periphery/VirtualAztecToken.sol";

import {IContinuousClearingAuction} from "@twap-auction/interfaces/IContinuousClearingAuction.sol";

contract VirtualAztecTokenConstructor is Test {
    MockERC20 internal underlyingToken;
    ATPFactoryNonces internal atpFactory;
    IRegistry internal registry;

    IContinuousClearingAuction auctionAddress = IContinuousClearingAuction(makeAddr("auctionContract"));
    address strategyAddress = makeAddr("strategyContract");
    address foundationAddress = makeAddr("foundationAddress");

    string constant VIRTUAL_TOKEN_NAME = "Virtual-TOKEN";
    string constant VIRTUAL_TOKEN_SYMBOL = "VTOKEN";

    function setUp() public {
        underlyingToken = new MockERC20("Underlying Token", "UT");
        atpFactory = new ATPFactoryNonces(address(this), IERC20(address(underlyingToken)), 100, 100);
    }

    function test_whenTheAtpFactoryIsTheZeroAddress() public {
        // it should revert with ZeroAddress

        vm.expectRevert(abi.encodeWithSelector(IVirtualAztecToken.VirtualAztecToken__ZeroAddress.selector));
        new VirtualAztecToken(
            VIRTUAL_TOKEN_NAME,
            VIRTUAL_TOKEN_SYMBOL,
            IERC20(address(underlyingToken)),
            IATPFactoryNonces(address(0)),
            foundationAddress
        );
    }

    function test_whenTheUnderlyingTokenAddressIsTheZeroAddress() public {
        // it should revert with ZeroAddress

        vm.expectRevert(abi.encodeWithSelector(IVirtualAztecToken.VirtualAztecToken__ZeroAddress.selector));
        new VirtualAztecToken(
            VIRTUAL_TOKEN_NAME, VIRTUAL_TOKEN_SYMBOL, IERC20(address(0)), atpFactory, foundationAddress
        );
    }

    function test_whenTheFoundationAddressIsTheZeroAddress() public {
        // it should revert with ZeroAddress

        vm.expectRevert(abi.encodeWithSelector(IVirtualAztecToken.VirtualAztecToken__ZeroAddress.selector));
        new VirtualAztecToken(
            VIRTUAL_TOKEN_NAME, VIRTUAL_TOKEN_SYMBOL, IERC20(address(underlyingToken)), atpFactory, address(0)
        );
    }

    function test_whenAllParametersAreValid() public {
        // it should set the atp factory low amounts
        // it should set the atp factory stake amounts
        // it should set the underlying token address

        VirtualAztecToken virtualAztecToken = new VirtualAztecToken(
            VIRTUAL_TOKEN_NAME, VIRTUAL_TOKEN_SYMBOL, IERC20(address(underlyingToken)), atpFactory, foundationAddress
        );

        assertEq(address(virtualAztecToken.ATP_FACTORY()), address(atpFactory));
        assertEq(address(virtualAztecToken.UNDERLYING_TOKEN_ADDRESS()), address(underlyingToken));
        assertEq(address(virtualAztecToken.FOUNDATION_ADDRESS()), address(foundationAddress));
        assertEq(address(virtualAztecToken.owner()), address(this));
        assertEq(virtualAztecToken.name(), VIRTUAL_TOKEN_NAME);
        assertEq(virtualAztecToken.symbol(), VIRTUAL_TOKEN_SYMBOL);
    }
}
