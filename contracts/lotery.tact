message ChangePersend {
    persent: Int as unit64;
}


contract ContestPayment {
    let owner: address;
    let feeExempt: Map<address, bool> = Map();
    let contestPayments: Map<Int, Map<address, (Int, String)>> = Map();
    let balances: Map<address, Int> = Map();
    let persent: Int as unit64;
    init() {
        owner = msg.sender();
    }
    receive(msg: ChangePersend){
        throw_if(msg.sender() != owner, "Only owner can set winners");
        persent.set(ChangePersend.persent)
    }
    receive("pay") {
        let contestId: Int = msg.body().contestId;
        let sender: address = msg.sender();
        let amount: Int = msg.value();

        let isExempt: Bool = feeExempt.get(sender).getOrDefault(false);
        let fee: Int = isExempt ? 0 : (amount * persent) / 100n;
        let netAmount: Int = amount - fee;

        let contest = contestPayments.get(contestId).getOrDefault(Map());
        contest.set(sender, (netAmount, "in progress"));
        contestPayments.set(contestId, contest);
    }

    receive("payUSDT") {
        let contestId: Int = msg.body().contestId;
        let sender: address = msg.sender();
        let amount: Int = msg.body().amount;

        let isExempt: Bool = feeExempt.get(sender).getOrDefault(false);
        let fee: Int = isExempt ? 0 : (amount * 5n) / 100n;
        let netAmount: Int = amount - fee;

        let contest = contestPayments.get(contestId).getOrDefault(Map());
        contest.set(sender, (netAmount, "in progress"));
        contestPayments.set(contestId, contest);
    }

    receive("setWinners") {
        throw_if(msg.sender() != owner, "Only owner can set winners");

        let contestId: Int = msg.body().contestId;
        let winners: Map<address, Int> = msg.body().winners;

        let contest = contestPayments.get(contestId).getOrDefault(Map());
            for (winner, amount) in winners {
            contest.set(winner, (amount, "winner"));
            balances.set(winner, balances.get(winner).getOrDefault(0n) + amount);
        }
        contestPayments.set(contestId, contest);
    }

    receive("claim") {
        let contestId: Int = msg.body().contestId;
        let sender: address = msg.sender();

        let contest = contestPayments.get(contestId).getOrDefault(Map());
        let (amount, status) = contest.get(sender).getOrDefault((0n, "none"));

        throw_if(status != "winner", "Not a winner or already claimed");
        throw_if(amount <= 0n, "No winnings available");

        contest.set(sender, (0n, "claim"));
        contestPayments.set(contestId, contest);

        sender.transfer(amount);
    }

    receive("addFeeExempt") {
        throw_if(msg.sender() != owner, "Only owner can modify fee exemptions");
        let exemptAddress: address = msg.body().address;
        feeExempt.set(exemptAddress, true);
    }

    receive("removeFeeExempt") {
        throw_if(msg.sender() != owner, "Only owner can modify fee exemptions");
        let exemptAddress: address = msg.body().address;
        feeExempt.set(exemptAddress, false);
    }
}
