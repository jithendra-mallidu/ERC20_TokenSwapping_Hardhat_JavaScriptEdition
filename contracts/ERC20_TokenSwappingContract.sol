//SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract AtomicSwapERC20 {
    struct Swap {
        uint256 swapId;
        uint256 startTime;
        uint256 timeLock;
        address erc20ContractAddressDT;
        address erc20ContractAddressWDT;
        uint256 erc20TokenAmountDT;
        uint256 erc20TokenAmountWDT;
        address whoInitiatedTrade;
    }

    enum States {
        OPEN,
        CLOSED,
        EXPIRE
    }

    mapping(uint256 => Swap) public swaps;
    mapping(uint256 => States) public swapStates;

    event Open(
        uint256 _swapID,
        uint256 _timelock,
        address _erc20ContractAddressDT,
        address _erc20ContractAddressWDT,
        uint256 _erc20TokenAmountDT,
        uint256 _erc20TokenAmountWDT,
        address _whoInitiatedTrade
    );
    event Close(uint256 swapId);

    function open(
        uint256 _swapId,
        address _erc20ContractAddressDT,
        uint256 _erc20ValueDT,
        address _erc20ContractAddressWDT,
        uint256 _erc20ValueWDT,
        uint256 _timeLock
    ) public {
        IERC20 erc20ContractDT = IERC20(_erc20ContractAddressDT);
        require(
            erc20ContractDT.allowance(msg.sender, address(this)) >=
                _erc20ValueDT
        ); //1st
        require(
            erc20ContractDT.transferFrom(
                msg.sender,
                address(this),
                _erc20ValueDT
            )
        ); //2nd

        Swap memory swap = Swap({
            swapId: _swapId,
            startTime: block.timestamp,
            timeLock: _timeLock,
            erc20ContractAddressDT: _erc20ContractAddressDT,
            erc20ContractAddressWDT: _erc20ContractAddressWDT,
            erc20TokenAmountDT: _erc20ValueDT,
            erc20TokenAmountWDT: _erc20ValueWDT,
            whoInitiatedTrade: msg.sender
        });

        swaps[_swapId] = swap;
        swapStates[_swapId] = States.OPEN;

        emit Open(
            _swapId,
            _timeLock,
            _erc20ContractAddressDT,
            _erc20ContractAddressWDT,
            _erc20ValueDT,
            _erc20ValueWDT,
            msg.sender
        );
    }

    function close(uint256 _swapId) public onlyOpenSwaps(_swapId) {
        Swap memory swap = swaps[_swapId];
        swapStates[_swapId] = States.CLOSED;

        IERC20 erc20ContractAddressDT = IERC20(swap.erc20ContractAddressDT);
        IERC20 erc20ContractAddressWDT = IERC20(swap.erc20ContractAddressWDT);

        require(
            swap.erc20TokenAmountWDT <=
                erc20ContractAddressWDT.allowance(msg.sender, address(this))
        );

        //Transfer the erc20 funds from the withdraw trader to this contract
        require(
            erc20ContractAddressWDT.transferFrom(
                msg.sender,
                address(this),
                swap.erc20TokenAmountWDT
            )
        );

        //Transfer the erc20 funds from this contract to the closing trader
        require(
            erc20ContractAddressDT.transfer(msg.sender, swap.erc20TokenAmountDT)
        );

        //Transfer the erc20 funds from this contract to the trader who initiated the trade
        require(
            erc20ContractAddressWDT.transfer(
                swap.whoInitiatedTrade,
                swap.erc20TokenAmountWDT
            )
        );

        emit Close(_swapId);
    }

    function expire(
        uint256 _swapId
    ) public onlyOpenSwaps(_swapId) onlyOwnerofSwap(_swapId) {
        swapStates[_swapId] = States.EXPIRE;
        //Swap memory swap = swaps[_swapId];
        IERC20 erc20Contract = IERC20(swaps[_swapId].erc20ContractAddressDT);
        require(
            erc20Contract.transfer(
                swaps[_swapId].whoInitiatedTrade,
                swaps[_swapId].erc20TokenAmountDT
            )
        );

        // emit Expire(_swapId);
    }

    function check(
        uint256 _swapId
    )
        public
        view
        returns (
            address erc20ContractAddressDT,
            uint256 erc20TokenAmountDT,
            address erc20ContractAddressWDT,
            uint256 erc20TokenAmountWDT,
            uint256 timeLock,
            address whoInitiatedTrade
        )
    {
        Swap memory swap = swaps[_swapId];
        return (
            swap.erc20ContractAddressDT,
            swap.erc20TokenAmountDT,
            swap.erc20ContractAddressWDT,
            swap.erc20TokenAmountWDT,
            swap.timeLock,
            swap.whoInitiatedTrade
        );
    }

    modifier onlyOpenSwaps(uint256 _swapId) {
        require(swapStates[_swapId] == States.OPEN, "Its not OPEN for swap!");
        _;
    }

    modifier onlyOwnerofSwap(uint256 _swapId) {
        require(
            msg.sender == swaps[_swapId].whoInitiatedTrade,
            "You are not person who initiated the trade!"
        );
        _;
    }
}
