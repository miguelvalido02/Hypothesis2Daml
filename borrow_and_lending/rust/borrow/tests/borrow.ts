//Borrow and lending © 2025 by Miguel Valido is licensed under CC BY 4.0 
import * as anchor from "@coral-xyz/anchor";
import { Program } from "@coral-xyz/anchor";
import { Borrow } from "../target/types/borrow";
import { assert } from "chai";


describe("borrow", () => {
    // Configure the client to use the local cluster.
    const provider = anchor.AnchorProvider.env();
    anchor.setProvider(provider);
    const program = anchor.workspace.Borrow as Program<Borrow>;

    it("Initializes the lending pool", async () => {
        // Generate a new keypair for the admin
        const admin = anchor.web3.Keypair.generate();
        console.log("Admin Public Key:", admin.publicKey.toBase58());

        // Airdrop some SOL to the admin to pay for transactions
        await provider.connection.confirmTransaction(
            await provider.connection.requestAirdrop(admin.publicKey, anchor.web3.LAMPORTS_PER_SOL)
        );

        // Derive the PDA for the lending pool
        const [lendingPoolPda, bump] = anchor.web3.PublicKey.findProgramAddressSync(
            [Buffer.from("lending_pool")],
            program.programId
        );
        console.log("Lending Pool PDA:", lendingPoolPda.toBase58());

        // Define the pool token account
        const poolTokenAccount = anchor.web3.Keypair.generate();
        console.log("Pool Token Account Public Key:", poolTokenAccount.publicKey.toBase58());

        // Create and initialize the lending pool
        await program.rpc.initialize(
            [], // Empty borrow_tokens array for simplicity
            [], // Empty collateral_tokens array for simplicity
            poolTokenAccount.publicKey,
            {
                accounts: {
                    lendingPool: lendingPoolPda,
                    admin: admin.publicKey,
                    systemProgram: anchor.web3.SystemProgram.programId,
                },
                signers: [admin],
            }
        );

        console.log("Lending pool initialized successfully.");

        // Fetch the lending pool account
        const lendingPoolAccount = await program.account.lendingPool.fetch(lendingPoolPda);
        assert.ok(lendingPoolAccount.admin.equals(admin.publicKey));
        assert.ok(lendingPoolAccount.poolTokenAccount.equals(poolTokenAccount.publicKey));

    });
});
