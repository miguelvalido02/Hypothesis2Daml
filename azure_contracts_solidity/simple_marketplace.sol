pragma solidity >=0.4.25 <0.6.0;

contract SimpleMarketplace {
    enum StateType {
        ItemAvailable,
        OfferPlaced,
        Accepted
    }

    address public InstanceOwner;
    string public Description;
    int public AskingPrice;
    StateType public State;

    address public InstanceBuyer;
    int public OfferPrice;

    constructor(string memory description, int price) public {
        InstanceOwner = msg.sender;
        AskingPrice = price;
        Description = description;
        State = StateType.ItemAvailable;
    }

    // Pre Conditions: offerPrice > 0
    // Pre Conditions: State == ItemAvailable
    // Pre Conditions: InstanceOwner != msg.sender
    // Post Conditions: InstanceBuyer == msg.sender
    // Post Conditions: OfferPrice == offerPrice
    // Post Conditions: State == OfferPlaced
    function MakeOffer(int offerPrice) public {
        if (offerPrice == 0) {
            revert();
        }

        if (State != StateType.ItemAvailable) {
            revert();
        }

        if (InstanceOwner == msg.sender) {
            revert();
        }

        InstanceBuyer = msg.sender;
        OfferPrice = offerPrice;
        State = StateType.OfferPlaced;
    }

    // Pre Conditions: State == OfferPlaced
    // Pre Conditions: InstanceOwner == msg.sender
    // Post Conditions: InstanceBuyer == 0x
    // Post Conditions: State == ItemAvailable
    function Reject() public {
        if (State != StateType.OfferPlaced) {
            revert();
        }

        if (InstanceOwner != msg.sender) {
            revert();
        }

        InstanceBuyer = 0x0000000000000000000000000000000000000000;
        State = StateType.ItemAvailable;
    }

    // Pre Conditions: MISSING-> State == OfferPlaced
    // Pre Conditions: InstanceOwner == msg.sender
    // Post Conditions: State == Accepted
    function AcceptOffer() public {
        if (msg.sender != InstanceOwner) {
            revert();
        }

        State = StateType.Accepted;
    }
}
