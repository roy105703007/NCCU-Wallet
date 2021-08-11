pragma solidity ^0.4.23;
 
library SafeMath {
    function add(uint a, uint b) internal pure returns (uint c) {
        c = a + b;
        require(c >= a);
    }
    function sub(uint a, uint b) internal pure returns (uint c) {
        require(b <= a);
        c = a - b;
    }
    function mul(uint a, uint b) internal pure returns (uint c) {
        c = a * b;
        require(a == 0 || c / a == b);
    }
    function div(uint a, uint b) internal pure returns (uint c) {
        require(b > 0);
        c = a / b;
    }
}

contract ContractReceiver {
    function tokenFallback(address _from, uint _value, bytes _data) public;
}

contract ERC20Interface {
    function totalSupply() public constant returns (uint);
    function balanceOf(address who) public constant returns (uint);
    function transfer(address to, uint value) public returns (bool success);
    function transfer(address to, uint value, bytes data) public returns (bool success);
    function allowance(address tokenOwner, address spender) public constant returns (uint remaining);
    function approve(address spender, uint tokens) public returns (bool success);
    function transferFrom(address from, address to, uint tokens) public returns (bool success);
    
    event Transfer(address indexed from, address indexed to, uint value, bytes data);
    event Approval(address indexed tokenOwner, address indexed spender, uint tokens);
}

contract ERC20Token is ERC20Interface  {
    using SafeMath for uint;
    
    mapping(address => mapping(address => uint)) allowed;
    mapping(address => uint) balances;
    
    string public name;
    string public symbol;
    uint8 public decimals;
    uint256 public _totalSupply;
    uint64 public deadline;
    bool public valid = true;
    
    address owner;
    
    constructor(string _name, string _symbol, uint8 _decimals, uint256 __totalSupply, uint64 _deadline) public {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
        balances[msg.sender] = __totalSupply * (10 ** uint256(decimals));
        _totalSupply = balances[msg.sender];
        deadline = _deadline;
        owner = msg.sender;
        emit Transfer(address(0), owner, _totalSupply, "Issue.");
    }
    
    modifier isOwner(){
        require(owner == msg.sender);
        _;
    }
    
    // Function to access total supply of tokens .
    function totalSupply() public constant returns (uint) {
        return _totalSupply;
    }
    
    //點數是否有效
    function valid() public constant returns (bool _valid) {
        return valid;
    }
    
    // Function that is called when a user or another contract wants to transfer funds .
    function transfer(address _to, uint _value, bytes _data, string _custom_fallback) public returns (bool success) {
        require(valid);
        if(isContract(_to)) {
            require (balanceOf(msg.sender) >= _value);
            balances[msg.sender] = balances[msg.sender].sub(_value);
            balances[_to] = balances[_to].add(_value);
            assert(_to.call.value(0)(bytes4(keccak256(_custom_fallback)), msg.sender, _value, _data));
            emit Transfer(msg.sender, _to, _value, _data);
            return true;
        }
        else {
            return transferToAddress(_to, _value, _data);
        }
    }
    

    // Function that is called when a user or another contract wants to transfer funds .
    function transfer(address _to, uint _value, bytes _data) public returns (bool success) {
        require(valid);
        if(isContract(_to)) {
            return transferToContract(_to, _value, _data);
        }
        else {
            return transferToAddress(_to, _value, _data);
        }
    }
    
    function transfer(address _to, uint _value) public returns (bool success) {
        require(valid);
        bytes memory empty;
        if(isContract(_to)) {
            return transferToContract(_to, _value, empty);
        }
        else {
            return transferToAddress(_to, _value, empty);
        }
    }

    //assemble the given address bytecode. If bytecode exists then the _addr is a contract.
    function isContract(address _addr) private view returns (bool is_contract) {
        uint length;
        assembly {
                //retrieve the size of the code on target address, this needs assembly
                length := extcodesize(_addr)
        }
        return (length>0);
    }

    //function that is called when transaction target is an address
    function transferToAddress(address _to, uint _value, bytes _data) private returns (bool success) {
        require (balanceOf(msg.sender) >= _value);
        balances[msg.sender] = balances[msg.sender].sub(_value);
        balances[_to] = balances[_to].add(_value);
        emit Transfer(msg.sender, _to, _value, _data);
        return true;
    }
    
    //function that is called when transaction target is a contract
    function transferToContract(address _to, uint _value, bytes _data) private returns (bool success) {
        require (balanceOf(msg.sender) >= _value);
        balances[msg.sender] = balances[msg.sender].sub(_value);
        balances[_to] = balances[_to].add(_value);
        ContractReceiver receiver = ContractReceiver(_to);
        receiver.tokenFallback(msg.sender, _value, _data);
        emit Transfer(msg.sender, _to, _value, _data);
        return true;
    }
    
    function allowance(address tokenOwner, address spender) public constant returns (uint remaining) {
        return allowed[tokenOwner][spender];
    }
    //同意他人移轉點數
    function approve(address spender, uint tokens) public returns (bool success) {
        allowed[msg.sender][spender] = tokens;
        emit Approval(msg.sender, spender, tokens);
        return true;
    }
    //移轉他人點數
    function transferFrom(address from, address to, uint tokens) public returns (bool success) {
        bytes memory empty;
        balances[from] = balances[from].sub(tokens);
        allowed[from][msg.sender] = allowed[from][msg.sender].sub(tokens);
        balances[to] = balances[to].add(tokens);
        emit Transfer(from, to, tokens, empty);
        return true;
    }
    //owner對他人點數進行轉移
    function transferFromAtoB(address from, address to, uint value) isOwner public returns (bool success) {
        require(balanceOf(from) >= value);
        bytes memory empty;
        balances[from] = balances[from].sub(value);
        balances[to] = balances[to].add(value);
        emit Transfer(from, to, value, empty);
        return true;
    }

    function balanceOf(address _owner) public constant returns (uint balance) {
        return balances[_owner];
    }
    //發送時間到合約
    function time(uint64 _now) isOwner public {
        if(_now >= deadline){
            valid = false;
        }
    }
    
    function () public payable {
        revert();
    }

    function transferAnyToken(address tokenAddress, uint tokens) public isOwner returns (bool success) {
        return ERC20Interface(tokenAddress).transfer(owner, tokens);
    }
    //增加掛單
    function addExchange(ERC20Token t, uint a1, uint a2, uint64 _deadline) public {
        require(balanceOf(msg.sender) >= a1);
        require(valid);
        bytes memory _empty;
        Exchange ex = new Exchange(msg.sender, this, t, a1, a2,  _deadline);
        transferToAddress(ex, a1, _empty);
    }
}

contract Exchange is ContractReceiver{
    
    address owner;
    address t1;
    address t2;
    uint a1;
    uint a2;
    uint64 deadline;
    bool valid;
    
    event addExchangeEvent(address from);
    event doExchangeEvent(address from);
    event cancelExchangeEvent(address addr);
    
    constructor(address _owner, address _t1, address _t2, uint _a1, uint _a2, uint64 _deadline) public {
        owner = _owner;
        t1 = _t1;
        t2 = _t2;
        a1 = _a1;
        a2 = _a2;
        deadline = _deadline;
        valid = true;
        emit addExchangeEvent(_owner);
    }
    //點數A
    function getT1() public constant returns(address){
        return t1;
    }
    //點數B
    function getT2() public constant returns(address){
        return t2;
    }
    //點數A數量
    function getA1() public constant returns(uint){
        return a1;
    }
    //點數B數量
    function getA2() public constant returns(uint){
        return a2;
    }
    //掛單的人
    function getOwner() public constant returns(address){
        return owner;
    }
    //期限
    function getDeadline() public constant returns(uint64){
        return deadline;
    }
    //買單
    function tokenFallback(address _from, uint _value, bytes _data) public {
        require(_value == a2 && valid);
        emit doExchangeEvent(_from);
        ERC20Interface(t1).transfer(_from, a1);
        ERC20Interface(t2).transfer(owner, _value);
        valid = false;
    }
    //取消掛單
    function cancel() public {
        require(owner == msg.sender);
        ERC20Interface(t1).transfer(owner, a1);
        valid = false;
        emit cancelExchangeEvent(this);
    }
    //送時間到合約
    function time(uint64 _time) public {
        if(_time >= deadline){
            cancel();
        }
    }
}