// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

import "./Token.sol";

contract CoinFlip is ERC20 {

    IERC20 public token;
    address tokenAddress;
    uint maxRoomSize = 8;
    mapping(uint => Game) public gameDatabase;
    mapping(address => bool) public flag;

    event Mint(address _to, uint amount);
    event BetPlaced(address);
    event BetWon(address, uint);
    event GameStarted(uint, address);
    event GameEnded(uint);

    constructor(
		address _tokenAddress
	) ERC20("Staked FlipCoin", "sFLP") {
        tokenAddress = _tokenAddress;
		token = IERC20(tokenAddress);
	}

    struct Game{
        address gameOwner;
        uint currentRoomSize;
        address[8] playerAddresses; //mapping inside struct cannot be implemented in solidity 0.8.12
        uint[8] betAmounts; 
        uint[8] calls; //cannot use "new" keyword inside structs
        bool[8] betSettled;
        bool gameSettled;
    }

    modifier minted {
        require(!flag[msg.sender], "Already minted bonus coins!!");
        _;
    }

    modifier hasBet(uint gameId, address _address) {
        bool exists = false;
        Game memory game = getGame(gameId);
        for(uint i = 0 ; i < game.currentRoomSize; i++){
            if(game.playerAddresses[i] == _address){
                exists = true;
            }
        }
        require(!exists, "Bet already placed");
        _;
    }

    function getBonusTokens() public{
        mintTokens(100);
        flag[msg.sender] = true;
        emit Mint(msg.sender, 100);
    }

    function mintTokens(uint amount) internal minted{
        _mint(msg.sender, amount);
    }

    function newGame(uint _gameId, uint _call, uint _amount) public hasBet(_gameId, msg.sender){
        require(gameDatabase[_gameId].gameOwner == address(0), "Game already exists!");
        address[8] memory _playerAddresses;
        uint[8] memory _betAmounts;
        uint[8] memory _calls;
        bool[8] memory _betSettled;
        Game memory game = Game(msg.sender, 0, _playerAddresses, _betAmounts, _calls, _betSettled, false);
        gameDatabase[_gameId] = game;
        placeBets(_gameId, _call, _amount);
        emit GameStarted(_gameId, msg.sender);
    }

    function getGame(uint _gameId) public view returns (Game memory game){
		return gameDatabase[_gameId];
	}

    function getRoomSize(uint gameId) public view returns(uint){
        return gameDatabase[gameId].currentRoomSize;
    }

    function placeBets(uint gameId, uint call, uint _amount) public hasBet(gameId, msg.sender){
        require(gameDatabase[gameId].gameOwner != address(0), "Game does not exist!");
        require(gameDatabase[gameId].playerAddresses.length == maxRoomSize, "Game Room Full!");
        require(_amount > 0, "Bet amount should be greater than 0!");
        _burn(msg.sender, _amount);
        uint index = getRoomSize(gameId);
        gameDatabase[gameId].currentRoomSize += 1;
        gameDatabase[gameId].playerAddresses[index] = msg.sender;
        gameDatabase[gameId].betAmounts[index] = _amount;
        gameDatabase[gameId].calls[index] = call;
        gameDatabase[gameId].betSettled[index] = false;
        emit BetPlaced(msg.sender);
    }

    function getGameowner(uint gameId) public view returns(address){
        return gameDatabase[gameId].gameOwner;
    }

    function vrf() internal view returns (uint result) {
        uint[1] memory bn;
        bn[0] = block.number;
        assembly {
        let memPtr := mload(0x40)
        if iszero(staticcall(not(0), 0xff, bn, 0x20, memPtr, 0x20)) {
                invalid()
            }
        result := mload(memPtr)
        }
        return uint(result)%2;
    }


    function rewardBets(uint gameId) public {
        uint randomNumber = vrf();
        settleBets(gameId, randomNumber);
        emit GameEnded(gameId);
    }

    function settleBets(uint gameId, uint _randomNumber) public returns(uint){
        Game memory _game = gameDatabase[gameId];
        uint roomSize = getRoomSize(gameId);
        for(uint i = 0; i < roomSize; i++){
            if(_game.calls[i] == _randomNumber){
                _mint(_game.playerAddresses[i], 2*_game.betAmounts[i]);
                _game.betSettled[i]= true;
                emit BetWon(_game.playerAddresses[i], 2*_game.betAmounts[i]);
            }
        }
        gameDatabase[gameId].gameSettled = true;
        return _randomNumber;
    }
    
}