import { ERC20 } from "solmate/tokens/ERC20.sol";

contract DAI is ERC20 {
    constructor() ERC20("DAI", "DAI", 18) {}

    function mint(address to, uint256 amount) public {
        _mint(to ,amount);
    }
}
