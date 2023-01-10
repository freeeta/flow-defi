// Lock Flow Tokens
// import FlowToken from 0x0ae53cb6e3f42a79
import FlowToken from 0x7e60df042a9c0868
import StakedFlowPool from 0xc8873a26b148ed14

transaction() {

    let participant: Address

    prepare(signer: AuthAccount) {

        self.participant = signer.address

        let starport <- StakedFlowPool.createStakedFlowPoolParticipant();
		// Store the vault in the account storage
		signer.save<@StakedFlowPool.StakedFlowPoolParticipant>(<-starport, to: /storage/starportParticipant)

        signer.link<&StakedFlowPool.StakedFlowPoolParticipant{StakedFlowPool.FlowLock}>(/public/participant, target: /storage/starportParticipant)

        log("StakedFlowPool participant was stored")
    }

    execute {
        getAccount(self.participant)
            .getCapability(/public/participant).borrow<&StakedFlowPool.StakedFlowPoolParticipant{StakedFlowPool.FlowLock}>() 
            ?? panic("Could not borrow StakedFlowPool participant")
    }
}