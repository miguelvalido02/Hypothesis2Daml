// Borrow and lending © 2025 by Miguel Valido is licensed under CC BY 4.0 

import { deploy } from './ethers-lib'
import { ethers } from 'ethers'

async function deployContracts() {
    const token1 = await deploy('TestToken', [])
    console.log(`Token 1 address: ${token1.address}`)

    const token2 = await deploy('TestToken', [])
    console.log(`Token 2 address: ${token2.address}`)

    const borrowLending = await deploy('BorrowAndLending', [
        [token1.address, token2.address],
        [token1.address, token2.address],
    ])
    console.log(`Borrow and lending address: ${borrowLending.address}`)

    return { token1, token2, borrowLending }
}

async function mintTokens(user, token1, token2) {
    const mintAmount = 1000 // Mint 1000 tokens

    // Mint Token1
    const token1MintTx = await token1.mint(user.address, mintAmount)
    await token1MintTx.wait()
    console.log(`Minted 1000 Token1 to ${user.address}`)

    // Mint Token2
    const token2MintTx = await token2.mint(user.address, mintAmount)
    await token2MintTx.wait()
    console.log(`Minted 1000 Token2 to ${user.address}`)

    // Verify balances
    const token1Balance = await token1.balanceOf(user.address)
    const token2Balance = await token2.balanceOf(user.address)
    console.log(`User Token1 balance: ${token1Balance}`)
    console.log(`User Token2 balance: ${token2Balance}`)
}

async function approveTokens(user, token1, token2, borrowLendingAddress) {
    const approveAmount = 1000 // Approve 1000 tokens

    // Approve Token1
    const token1ApproveTx = await token1
        .connect(user)
        .approve(borrowLendingAddress, approveAmount)
    await token1ApproveTx.wait()
    console.log(`Approved 1000 Token1 for ${borrowLendingAddress}`)

    // Approve Token2
    const token2ApproveTx = await token2
        .connect(user)
        .approve(borrowLendingAddress, approveAmount)
    await token2ApproveTx.wait()
    console.log(`Approved 1000 Token2 for ${borrowLendingAddress}`)
}

async function testWithdrawReverts(user, borrowLending, tokenAddress) {
    try {
        // Attempt to withdraw token1 or token2
        const withdrawTx = await borrowLending
            .connect(user)
            .withdraw(tokenAddress)
        await withdrawTx.wait()
        console.log('Withdraw succeeded unexpectedly! This should not happen!')
    } catch (e) {
        console.log('Withdraw reverted as expected')
    }
}

async function testBorrowReverts(
    user,
    borrowLending,
    borrowTokenAddress,
    borrowAmount,
    collateralTokenAddress,
    collateralAmount,
) {
    try {
        // Attempt to borrow token1 or token2
        const borrowTx = await borrowLending
            .connect(user)
            .borrow(
                borrowTokenAddress,
                borrowAmount,
                collateralTokenAddress,
                collateralAmount,
            )
        await borrowTx.wait()
        console.log('Borrow succeeded unexpectedly! This should not happen!')
    } catch (e) {
        console.log('Borrow reverted as expected')
    }
}

async function testRepayReverts(user, borrowLending, borrowTokenAddress) {
    try {
        // Attempt to repay without having a loan
        const repayTx = await borrowLending
            .connect(user)
            .repay(borrowTokenAddress)
        await repayTx.wait()
        console.log('Repay succeeded unexpectedly! This should not happen!')
    } catch (e) {
        console.log('Repay reverted as expected')
    }
}

async function testLendReverts(user, borrowLending, collateralTokenAddress) {
    try {
        // Attempt to lend more tokens than the user's balance
        const excessiveAmount = 100000 // 100,000 tokens
        const lendTx = await borrowLending
            .connect(user)
            .lend(collateralTokenAddress, excessiveAmount)
        await lendTx.wait()
        console.log('Lend succeeded unexpectedly! This should not happen')
    } catch (e) {
        console.log('Lend reverted as expected')
    }
}

async function lend(user, borrowLending, token, lendAmount, token_name) {
    await print_balance_token(user, token, token_name)
    try {
        const lendTx = await borrowLending
            .connect(user)
            .lend(token.address, lendAmount)
        await lendTx.wait()
        console.log(
            `${user.address}Successfully lent ${lendAmount}`,
        )
        await print_balance_token(user, token, token_name)
    } catch (e) {
        console.error(`Lend failed! This should not happen! ${e.message}`)
    }
}

async function withdraw(user, borrowLending, token, token_name) {
    await print_balance_token(user, token, token_name)

    try {
        const lendTx = await borrowLending
            .connect(user)
            .withdraw(token.address)
        await lendTx.wait()
        console.log(
            `Successfully withdrew`,
        )
        await print_balance_token(user, token, token_name)

    } catch (e) {
        console.error(`Withdraw failed! This should not happen! ${e.message}`)
    }
}

async function borrow(
    user,
    borrowLending,
    borrowToken,
    borrowAmount,
    collateralTokenAddress,
    collateralAmount,
    borrowTokenName
) {
    await print_balance_token(user, borrowToken, borrowTokenName)

    try {
        // Attempt to borrow token1 or token2
        const borrowTx = await borrowLending
            .connect(user)
            .borrow(
                borrowToken.address,
                borrowAmount,
                collateralTokenAddress,
                collateralAmount,
            )
        await borrowTx.wait()
        console.log('User Successfully borrowed!')
        await print_balance_token(user, borrowToken, borrowTokenName)

    } catch (e) {
        console.error(`Borrow failed! This should not happen! ${e.message}`)
    }
}

async function repay(user, borrowLending, borrowToken, borrowTokenName) {
    await print_balance_token(user, borrowToken, borrowTokenName)
    try {
        const repayTx = await borrowLending
            .connect(user)
            .repay(borrowToken.address)
        await repayTx.wait()
        console.log('User Successfully repayed!')
        await print_balance_token(user, borrowToken, borrowTokenName)
    } catch (e) {
        console.error(`Repay failed! This should not happen! ${e.message}`)
    }
}

async function mintAndApprove(users, token1, token2, contractAddress) {
    for (let i = 0; i < users.length; i++) {
        let user = users[i]
        await mintTokens(user, token1, token2)
        await approveTokens(user, token1, token2, contractAddress)
    }
}

async function testInitialStateReverts(user, borrowLending, token1, token2) {
    //Make sure that user cannot withdraw any token

    await testWithdrawReverts(user, borrowLending.address, token1.address)
    await testWithdrawReverts(user, borrowLending, token2.address)

    //Make sure that user cannot borrow any token
    await testBorrowReverts(
        user,
        borrowLending,
        token1.address,
        10,
        token2.address,
        40,
    )
    await testBorrowReverts(
        user,
        borrowLending,
        token1.address,
        10,
        token1.address,
        30,
    )
    await testBorrowReverts(
        user,
        borrowLending,
        token2.address,
        10,
        token1.address,
        30,
    )
    await testBorrowReverts(
        user,
        borrowLending,
        token2.address,
        10,
        token2.address,
        30,
    )

    //Make sure that user cannot repay
    await testRepayReverts(user, borrowLending, token1.address)
    await testRepayReverts(user, borrowLending, token2.address)

    //Make sure that user cannot lend more than the user balance
    await testLendReverts(user, borrowLending, token1.address)
    await testLendReverts(user, borrowLending, token2.address)
}

async function testFirstState(user, borrowLending, token1, token2) {
    //Make sure that user cannot repay
    await testRepayReverts(user, borrowLending, token1.address)
    await testRepayReverts(user, borrowLending, token2.address)

    //Make sure that user cannot withdraw token2
    await testWithdrawReverts(user, borrowLending, token2.address)

    //Withdraw 100 token1
    await withdraw(user, borrowLending, token1, "token1")
    // Now the user has lent 0

    await lend(user, borrowLending, token1, 100, "token1")
    //Now the user has lent 100 token1 again

    //Make sure user cannot borrow using collateral of wrong token
    await testBorrowReverts(
        user,
        borrowLending,
        token1.address,
        51,
        token2.address,
        100,
    )

    //Make sure user cannot borrow more than lentAmount/2
    await testBorrowReverts(
        user,
        borrowLending,
        token1.address,
        51,
        token1.address,
        100,
    )
    await testBorrowReverts(
        user,
        borrowLending,
        token2.address,
        51,
        token2.address,
        100,
    )

    //Make sure user cannot borrow due to limited liquidity in the pool
    await testBorrowReverts(
        user,
        borrowLending,
        token2.address,
        40,
        token1.address,
        100,
    )
}

async function testSecondState(user, user2, borrowLending, token1, token2) {
    //Make sure user2 cannot borrow any token2 due to limited liquidity
    await testBorrowReverts(user2, borrowLending, token2.address, 2, token2.address, 40)

    //Make sure user cannot borrow tokens again as he has no more collateral
    await testBorrowReverts(user, borrowLending, token2.address, 1, token1.address, 3)
    await testBorrowReverts(user, borrowLending, token1.address, 1, token1.address, 3)

}

async function print_balance_token(user, token, token_name) {
    const userBalance = await token.balanceOf(user.address)
    console.log(`${user.address} balance of ${token_name}: ${userBalance}`)
}

; (async () => {
    try {
        const [deployer, user, user2] = await ethers.getSigners()
        // Deploy contracts
        let { token1, token2, borrowLending } = await deployContracts()
        //Mint and approve tokens
        await mintAndApprove([user, user2], token1, token2, borrowLending.address)
        //Test initial state
        await testInitialStateReverts(user, borrowLending, token1, token2)

        //User lends 100 token1
        await lend(user, borrowLending, token1, 100, "token1")

        //--------------------------Now the user has lent 100 token1----------------------------
        await testFirstState(user, borrowLending, token1, token2)

        //User2 lends 40 token2
        await lend(user2, borrowLending, token2, 40, "token2")
        //------------------------Now user has lent 100 token1 and user2 has lent 40 token2----------

        await borrow(
            user,
            borrowLending,
            token2,
            39,
            token1.address,
            100,
            "token2"
        )

        //----------Now user has borrowed 39 token2 using 100 token1 as collateral and user2 has lent 40 token2--------------

        await testSecondState(user, user2, borrowLending, token1, token2)
        //User2 will borrow 1 token2 using 3 token2 as collateral
        await borrow(user2, borrowLending, token2, 1, token2.address, 3, "token2")

        //----User 2 has 37 collateral token2 and borrowed 1 token2 using 3 token2 and user has borrowed 39 token2 using 100 token1

        //User2 borrows 10 token1 using 37 token2
        await borrow(user2, borrowLending, token1, 10, token2.address, 37, "token1")

        //-----User 2 has borrowed 1 token2 and 10 token1 using all of his collateral and user has borrowed 39 token2 using 100 token1

        //Now make sure none of them can withdraw
        await testWithdrawReverts(user, borrowLending, token1.address)
        await testWithdrawReverts(user, borrowLending, token2.address)
        await testWithdrawReverts(user2, borrowLending, token1.address)
        await testWithdrawReverts(user2, borrowLending, token2.address)

        //Now user2 will repay his first loan of 1 token2 using 3 token2 as collateral
        await repay(user2, borrowLending, token2, "token2")

        //Now user2 will fail to withdraw his collateral = 3 token2 because the pool liquidity is only 1
        await testWithdrawReverts(user2, borrowLending, token2.address)

        await repay(user, borrowLending, token2, "token2")

        //Now that there is sufficient token2 in the pool user2 will withdraw

        await withdraw(user2, borrowLending, token2, "token2")

        //The current state is:
        //User2 has borrowed 10 token1 using 37 token2 collateral
        //User has lent 100 token1

        //Make sure user cannot withdraw his collateral of 100 token1 as the pool only has 90
        await testWithdrawReverts(user, borrowLending, token1.address)

        await repay(user2, borrowLending, token1, "token1")

        //Now user2 has 37 collateral of token2 and user has 100 token1
        //User can borrow again
        await borrow(user, borrowLending, token1, 15, token1.address, 31, "token1")

        //Now user has borrowed 15 token1 using 31 token1 as collateral. He has 69 lent token1
        //User2 has no loans and will now withdraw
        await withdraw(user2, borrowLending, token2, "token2")
        console.log("User2 balances:")
        await print_balance_token(user2, token1, "token1")
        await print_balance_token(user2, token2, "token2")

        //Cannot borrow as user already active loan of this token
        await testBorrowReverts(user, borrowLending, token1.address, 1, token1.address, 30)

        await repay(user, borrowLending, token1, "token1")

        await withdraw(user, borrowLending, token1, "token1")
        console.log("User balances:")
        await print_balance_token(user, token1, "token1")
        await print_balance_token(user, token2, "token2")


    } catch (e) {
        console.log(e.message)
    }
})()
