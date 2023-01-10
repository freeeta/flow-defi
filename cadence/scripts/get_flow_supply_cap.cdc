// This script reads the amount of locked Flow tokens

import StakedFlowPool from 0xc8873a26b148ed14

pub fun main(): UFix64 {

    let supplyCap = StakedFlowPool.getFlowSupplyCap()

    return supplyCap
}