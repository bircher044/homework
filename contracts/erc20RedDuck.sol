// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./SafeMath.sol";

abstract contract ERC20Interface {
    event Transfer(address indexed from, address indexed to, uint tokens);
    event Approval(address indexed tokenOwner, address indexed spender, uint tokens);
}

contract erc20RedDuck is ERC20Interface, SafeMath {
    string public name;  // название монеты
    string public symbol; // символ нашей монеты
    uint8 public decimals; // количество цифр после запятой
    uint public coin_price; // wei за 1 олексириум
    uint16 public voting_duration; //время на голосование в минутах
    uint public voting_summ; //тут храним текущий результат голосования
    uint public voting_end; // время конца голосования
    uint public possible_price; //тут храним цену за которую голосуем, до тех пор, пока не закончилось голосование
    uint public voting_id; // номер текущего голосования
    uint public _totalSupply; // количество монет
    address public owner; // тут всегда храним аккаунт создателя (наш). С него будет отправляться запрос на остановку голосования через 50 минут после старта

    mapping(address => uint) balances;
    mapping(address => mapping(address => uint)) allowed;
    mapping(address => mapping(uint => bool)) is_voted;

    /*
     базовый конструктор erc20

     */
    constructor(uint8 decimals_, uint totalSupply_, uint coin_price_, uint16 voting_duration_) {
        name = "Oleksiirium";
        symbol = "Olx";
        decimals = decimals_;
        _totalSupply = totalSupply_;
        coin_price = coin_price_;
        voting_duration = voting_duration_;

        balances[msg.sender] = _totalSupply;
        emit Transfer(address(0), msg.sender, _totalSupply);
        owner = msg.sender;
    }

    function totalSupply() public view returns (uint) {
        return _totalSupply  - balances[address(0)];
    }

    function CurrentCoinPrice() external view returns (uint){
        return coin_price;
    }

    function balanceOf(address tokenOwner) public view returns (uint balance) {
        return balances[tokenOwner];
    }

    function allowance(address tokenOwner, address spender) public view returns (uint remaining) {
        return allowed[tokenOwner][spender];
    }

    function approve(address spender, uint tokens) public returns (bool success) {
        allowed[msg.sender][spender] = tokens;

        emit Approval(msg.sender, spender, tokens);
        
        return true;
    }

    function transfer(address to, uint tokens) public returns (bool success) {
        balances[msg.sender] = safeSub(balances[msg.sender], tokens);
        balances[to] = safeAdd(balances[to], tokens);

        emit Transfer(msg.sender, to, tokens);

        return true;
    }

     function transferFrom(address from, address to, uint tokens) public returns (bool success) {
        balances[from] = safeSub(balances[from], tokens);
        allowed[from][msg.sender] = safeSub(allowed[from][msg.sender], tokens);
        balances[to] = safeAdd(balances[to], tokens);

        emit Transfer(from, to, tokens);
        
        return true;
    }

    function callvoting(uint new_price) public returns (bool success) {
        require(balances[msg.sender] >= _totalSupply/20, "Your balance is too low to start voiting."); //чтобы вызвать голосование надо хотя бы 5 процентов от эмиссии
        require(voting_end < block.timestamp, "Another voting is already started"); //проверяем, нет ли уже запущенного голосования

        voting_end = block.timestamp + voting_duration;  //последняя минута голосования
        voting_summ = 0; //при запуске голосования голоса обнуляем
        possible_price = new_price; // запоминаем за что голосуем
        voting_id++; //считаем текущий номер голосования

        return true;
    }

    function vote(bool decision) public returns (bool success){
        if(block.timestamp > voting_end) //если время на голосование уже вышло, но оно по какой-то причине не остановилось, остановим при следующей попытке голоса
        stopvoting();

        require(block.timestamp < voting_end, "The voting has been ended."); //не поздно ли голосуем
        require(!is_voted[msg.sender][voting_id], "You have already voited."); //не голосовал ли этот кошелёк в этом голосовании

        is_voted[msg.sender][voting_id] = true; //теперь проголосовал
        decision == true ? voting_summ += balances[msg.sender] : voting_summ -= balances[msg.sender]; // в зависимости от решения, отнимаем или плюсуем баланс проголосовавшего от общего банка проголосовавших
        
        return true;
    }

    function stopvoting() public returns (bool success){  //эту функцию вызываем мы сами с помощью ether.js ровно через 50 минут после начала голосования
        require(voting_end < block.timestamp, "The voting should stop later"); //не рано ли запустили (ну а вдруг)
        require(msg.sender == owner, "You have not permission to stop voiting"); //никто кроме создателя останавливать не может

        if(voting_summ >= 0 )  //если вес голосов "за" больше то меняем текущую цену монеты
        coin_price = possible_price;
        
        return true;
    }

    function buy() external payable {
        uint256 _cost = msg.value / coin_price; // сколько олексириума стоит отправленный эфир 
        if(_cost > balances[owner]){
            revert("Cannot sell Oleksiirium for now"); // если на нашем кошельке недостаточно денег чтобы оплатить покупку - возвращаем эфир отправителю
        }
        else transfer(msg.sender, _cost); //отправляем олексириум покупателю по текущему курсу
    }
    
    function sell(uint256 _amount) external {
        require(_amount <= balances[msg.sender], "You don`t have this count of tokens"); 

        balances[msg.sender] = safeSub(balances[msg.sender], _amount); // отнимаем с аккаунта олексириум, который продаёт пользователь
        balances[address(this)] = safeAdd(balances[address(this)], _amount); //добавляем олексириум нам

        emit Transfer(msg.sender, address(this), _amount); //такие штуки надо записывать в блокчейн
        
        payable(msg.sender).transfer(_amount / coin_price); //отправляем эфир по текущему курсу
    }



}