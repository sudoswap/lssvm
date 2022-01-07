import {RouterRobustBaseERC20} from "../base/RouterRobustBaseERC20.sol";
import {UsingLinearCurve} from "../mixins/UsingLinearCurve.sol";
import {UsingMissingEnumerable} from "../mixins/UsingMissingEnumerable.sol";
import {UsingERC20} from "../mixins/UsingERC20.sol";

contract RouterRobustTest is RouterRobustBaseERC20, UsingLinearCurve, UsingMissingEnumerable, UsingERC20 {}