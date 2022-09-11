pragma solidity >=0.5.0 <=0.7.0;

contract LeaseContract {
    struct Lease {
        address payable landlord; // the landlord
        address payable tenant; // the tenant
        string location; // property location
        uint term; // lease term
        uint rent; // monthly rent
        uint securityDeposit; // security deposit
        uint earlyPenalty; // early termination penalty
        uint creationTimestamp; // creation timestamp
        uint signedTimestamp; // contract retification timestamp
        uint moveinTimestamp; // The tenant occupation timestamp;
     }
    enum LeaseState {Created, Signed, Occupied, Terminated}
    Lease public lease;
    struct Deposit { 
        uint sequence;
        uint amount;
    }
    Deposit[] public deposits;
    uint public balance = 0;
    uint public totalReceived = 0;
    uint public securityDeposited;
    LeaseState public state;
    constructor(uint _rent, uint _term, uint _securityDeposit, uint _earlyPenalty, string memory _location) public payable {
        lease.landlord = msg.sender;
        lease.location = _location;
        lease.rent = _rent;
        lease.term = _term;
        lease.securityDeposit = _securityDeposit;
        lease.earlyPenalty = _earlyPenalty;
        lease.creationTimestamp = block.timestamp;
        state = LeaseState.Created;
     }


    modifier inState(LeaseState _state){ 
        if (state != _state) revert();
        _;
    }
    modifier onlyLandlord(){
        if(msg.sender != lease.landlord) revert();
        _;
    }
    modifier notLandlord(){
        if(msg.sender == lease.landlord) revert();
        _;
    }
    modifier onlyTenant(){
        if(msg.sender != lease.tenant) revert();
        _;
    }
    modifier payInFull(){
        if(_rent < lease.rent) revert();
        _;
    }

    event securityDepositPaid(address indexed _tenant, uint _amount, uint _timestamp);
    event leaseSigned(address indexed _tenant, uint _signedTimestamp);
    event rentPaid(address indexed _tenant, uint _timestamp);
    event leaseTerminated(address indexed _by, string _reason, uint _timestamp);

    //Lease signed by tenant
    function signLease() public payable inState(LeaseState.Created) notLandlord {
        lease.tenant = msg.sender;
        securityDeposited = msg.value;
        require( securityDeposited >= lease.securityDeposit);
        lease.signedTimestamp = block.timestamp;
        state = LeaseState.Signed;

        emit leaseSigned(lease.tenant, lease.signedTimestamp);
     }

    //tenant moves in
    function moveIn() public onlyTenant inState(LeaseState.Signed) onlyTenant {
        lease.moveInTimestamp = block.timestamp;
        state = LeaseState.Occupied;
     }

    //pay the monthly rent, and keep a record
    function payRent() public payable onlyTenant inState(LeaseState.Occupied) payInFull(msg.value + balance) { 
        emmit rentPaid(lease.tenant, block.timestamp);
        totalReceived++;
        balance += msg.value - lease.rent;//keeps track of balance
        deposits.push(Deposit({sequence : totalReceived, amount : msg.value}));
        lease.landlord.transfer(msg.value);
    }

    //terminate the lease when it is mature
    function leaseDue() public inState(LeaseState.Occupied) onlyLandlord { 
        emit leaseTerminated(lease.landlord, "lease due"), block.timestamp);
        //if the lease term is due, return security deposit to tenant and rest to landlord
        require (totalReceived >= lease.term);
        state = LeaseState.Terminated;
        lease.tenant.transfer(securityDeposited);
        lease.landlord.transfer(address(this).balance);
    }

    //evict the tenant for missing pay
    function evict() public inState(LeaseState.Occupied) onlyLandlord { 
        emit leaseTerminated(lease.landlord, "eviction", block.timestamp);
        require(totalReceived < lease.term && balance < lease.rent);
        state = LeaseState.Terminated;
        lease.landlord.transfer(address(this).balance);
    }

    //terminate the lease early by tenant
    function terminateEarly() public payable inState(LeaseState.Occupied) onlyTenant { 
        emit leaseTerminated(lease.tenant, "early termination", block.timestamp);
        //tenant terminates the lease early, pay penalty and return balance to landlord
        require (totalReceived < lease.term && msg.value >= lease.earlyPenalty);
        state = LeaseState.Terminated;
        lease.landlord.transfer(address(this).balance);
    }

}